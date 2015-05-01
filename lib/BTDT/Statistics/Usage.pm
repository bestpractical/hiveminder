use strict;
use warnings;

package BTDT::Statistics::Usage;
use Jifty::Plugin::Monitoring;

#  - unconfirmed accounts (never logged in)
#  - signups with unaccepted eula
#  - signup and then immediately go pro [ask shawn]
#  - account cancellations [...?]
#  - sessions
#  - new published addresses
#  - task reviews today [...?]
#  - number of people who have used mini, gcal, widget, full UI [...]
#  - svn rev?
#  - LOC

=head1 NAME

BTDT::Statistics::Usage - Gather usage statistics

=cut

use vars qw/$NOW/;

monitor "tasks", every day, sub {
    $NOW = shift->now->clone;
    my $tasks = BTDT::Model::TaskCollection->new;
    $tasks->unlimit;
    data_point all => $tasks->count;
    data_point complete => count_from_tokens( qw/complete/ );
    data_point accepted => count_from_tokens( qw/ not complete accepted / );
    data_point incomplete => count_from_tokens( qw/not complete/ );
    data_point group => count_from_tokens( qw/ not group personal / );

    data_point "created today" => created_today();
    data_point "completed today" => completed_today();

    data_point "modified today" => recent_tasks();
    data_point "tags modified today" => changed_tags();

    data_point "changed not by requestor today" => changed_not_by("requestor_id");
    data_point "changed not by owner today" => changed_not_by("owner_id");
    data_point "completed not by owner today" => completed_by_other();
    data_point "changed in a group" => group_changed();

    data_point "feedback today" => feedback();
    data_point "comments" => comments();
};

monitor "users", every day, sub {
    $NOW = shift->now->clone;
    my $users = BTDT::Model::UserCollection->new;
    $users->unlimit;
    data_point all => $users->count;
    $users->limit( column => 'pro_account', value => 1 );
    data_point pro => $users->count;

    data_point "active today" => count_active_users(1);
    data_point "pro active today" => count_active_pro_users(1);
    data_point "new today" => count_new_users(1);

    data_point "active this week" => count_active_users(7);
    data_point "pro active this week" => count_active_pro_users(7);

    data_point "pro today" => count_new_purchases();
    data_point "gift pro today" => count_purchase_with( gift => 1);
    data_point "renew today" => count_purchase_with( renewal => 1);
};

monitor "revenue", every day, sub {
    $NOW = shift->now->clone;
    data_point "all" => sum_revenue()->first->amount;
    data_point "today" => sum_revenue_today()->first->amount;
};

monitor yaks => every day, sub {
    $NOW = shift->now->clone;
    data_point count => int rand 100;
};

monitor imap => every day, sub {
    $NOW = shift->now->clone;
    my $sent = Jifty::Model::Metadata->load( 'imap_bytes_sent' );
    my $recv = Jifty::Model::Metadata->load( 'imap_bytes_received' );

    data_point "all sent" => $sent;
    data_point "all received" => $recv;

    data_point "sent today" => ($sent - (previous("all sent") || 0))/1024/1024;
    data_point "received today" => ($recv - (previous("all received") || 0))/1024/1024;
};

monitor im => every day, sub {
    $NOW = shift->now->clone;
    my $messages = Jifty::Model::Metadata->load( 'app_im_messages' );

    data_point "all received" => $messages;
    data_point "received today" => $messages - (previous("all received") || 0);

    require BTDT::IM;

    for my $protocol (@BTDT::IM::protocols) {
        my $messages = Jifty::Model::Metadata->load("app_\L${protocol}\E_messages");
        data_point "all $protocol received" => $messages;
        data_point "$protocol received today" => $messages - (previous("all $protocol received") || 0);
    }
};

=head1 METHODS

=head2 limit_to_today COLLECTION, COLUMN [, ALIAS] [, DAYS]

Given a L<Jifty::DBI::Collection> C<COLLECTION>, assumes that the
given C<COLUMN> is a timestamp column, and limits the query to rows
where the column is within the past day.  C<ALIAS> defaults to C<main>
unless specified.

=cut

sub limit_to_today {
    my ($collection, $column, $alias, $days) = @_;
    $days ||= 1;
    $collection->limit(
        alias    => $alias || 'main',
        column   => $column,
        operator => '>=',
        value    => $NOW->clone->subtract( days => $days )->ymd,
        entry_aggregator => 'AND',
    );
    $collection->limit(
        alias    => $alias || 'main',
        column   => $column,
        operator => '<',
        value    => $NOW->ymd,
        entry_aggregator => 'AND',
    );
}

=head2 limit_to_not_developers COLLECTION [, TASK_ALIAS]

Filters out changes to tasks done by BPS developers -- that is, tasks
in the C<Best Practical>, C<hiveminders>, or C<hiveminders feedback>
groups.

=cut

sub limit_to_not_developers {
    my ($collection, $alias) = @_;
    $alias ||= $collection->join( column1 => "task_id", table2 => "tasks", column2 => "id");

    $collection->open_paren('not_us');
    for my $name ("Best Practical", "hiveminders", "hiveminders feedback") {
        my $group = BTDT::Model::Group->load_by_cols( name => $name );
        $collection->limit(
            alias      => $alias,
            column     => 'group_id',
            operator   => '!=',
            value      => $group->id,
            subclause  => 'not_us',
            entry_aggregator => 'AND',
        );
    }
    $collection->close_paren('not_us');
    $collection->limit(
        alias      => $alias,
        column     => 'group_id',
        operator   => 'IS',
        value      => 'NULL',
        quote_value => 0,
        subclause  => 'not_us',
        entry_aggregator => 'OR',
    );
}

=head2 count_from_tokens TOKENS

Given a list of C<TOKENS>, returns the number of tasks which match the
search.

=cut

sub count_from_tokens {
    my $tasks = BTDT::Model::TaskCollection->new;
    $tasks->from_tokens( @_ );
    return $tasks->count;
}


=head2 recent_tasks [COLLECTION] [, TASKS_ALIAS]

Returns the number of distinct tasks modified in the last day.

=cut

sub recent_tasks {
    my $txns = shift || BTDT::Model::TaskTransactionCollection->new;
    my $tasks = shift;
    limit_to_today($txns, "modified_at");
    limit_to_not_developers($txns, $tasks);
    $txns->group_by( column => 'task_id' );
    return $txns->count;
}

=head2 created_today

Returns the number of tasks created today.

=cut

sub created_today {
    my $tasks = BTDT::Model::TaskCollection->new;
    limit_to_today($tasks, "created");
    limit_to_not_developers($tasks, 'main');
    return $tasks->count;
}

=head2 completed_today

Returns the number of tasks completed today.

=cut

sub completed_today {
    my $tasks = BTDT::Model::TaskCollection->new;
    $tasks->complete;
    limit_to_today($tasks, "completed_at");
    limit_to_not_developers($tasks, 'main');
    return $tasks->count;
}

=head2 feedback

Returns the number of feedback tasks created today.

=cut

sub feedback {
    my $tasks = BTDT::Model::TaskCollection->new;
    $tasks->group(48);
    limit_to_today($tasks, "created");
    return $tasks->count;
}

=head2 changed_tags

Returns the number of distinct tasks whose tags have been changed in
the last day.

=cut

sub changed_tags {
    my $txns = BTDT::Model::TaskTransactionCollection->new;
    my $histories = $txns->join(
        column1 => 'id',
        table2  => "task_histories",
        column2 => 'transaction_id',
    );
    $txns->limit( alias => $histories, column => 'field', value => 'tags' );
    return recent_tasks($txns);
}

=head2 changed_not_by COLUMN [, COLLECTION]

C<COLUMN> is either C<requestor_id> or C<owner_id>.  Returns the
number of distinct tasks which were changed not by (owner or
requestor, whichever C<COLUMN> dicated).

Note that this is tasks which were changed by somebody who is not the
B<current> I<whatever>.  This may well be different from who the
I<whatever> was at the time of the change!

=cut

sub changed_not_by {
    my $column = shift;
    my $txns = shift || BTDT::Model::TaskTransactionCollection->new;
    my $task = $txns->join(
        column1 => 'task_id',
        table2  => 'tasks',
        column2 => 'id',
    );
    $txns->limit(
        column => "created_by",
        operator => '!=',
        value  => $task . "." . $column,
        quote_value => 0,
    );
    return recent_tasks($txns, $task);
}

=head2 group_changed

Returns the number of distinct group tasks that were changed.

=cut

sub group_changed {
    my $txns = shift || BTDT::Model::TaskTransactionCollection->new;
    my $task = $txns->join(
        column1 => 'task_id',
        table2  => 'tasks',
        column2 => 'id',
    );
    $txns->limit(
        alias  => $task,
        column => "group_id",
        operator => 'IS NOT',
        value  => "NULL",
        quote_value => 0,
    );
    return recent_tasks($txns, $task);
}

=head2 completed_by_other

Returns the number of distinct tasks that were completed by someone
other than their owner.

=cut

sub completed_by_other {
    my $txns = BTDT::Model::TaskTransactionCollection->new;
    my $histories = $txns->join(
        column1 => 'id',
        table2  => "task_histories",
        column2 => 'transaction_id',
    );
    $txns->limit( alias => $histories, column => 'field', value => 'complete' );
    return changed_not_by( "owner_id", $txns );
}

=head2 comments

Returns the number of distinct comments added in the last day.

=cut

sub comments {
    my $task_emails = BTDT::Model::TaskEmailCollection->new;
    my $txns = $task_emails->join(
        column1 => 'transaction_id',
        table2  => 'task_transactions',
        column2 => 'id',
    );
    limit_to_today($task_emails, "modified_at", $txns );
    limit_to_not_developers($task_emails);
    return $task_emails->count;
}

=head2 count_active_users [DAYS] [, COLLECTION]

Counts the number of users who've changed a task in the last DAYS days.

=cut

sub count_active_users {
    my $days = shift || 1;
    my $users = shift || BTDT::Model::UserCollection->new;

    my $usertxns_alias = $users->join(
        alias1  => 'main',
        column1 => 'id',
        table2  => 'task_transactions',
        column2 => 'created_by'
    );
    limit_to_today($users, "modified_at", $usertxns_alias, $days);

    $users->group_by( column => 'id', );

    $users = $users->count;
}

=head2 count_active_pro_users [DAYS]

As L<count_active_users>, but only for users who are pro.

=cut

sub count_active_pro_users {
    my $days = shift || 1;
    my $users = BTDT::Model::UserCollection->new;
    $users->limit( column => 'pro_account', value => 1 );
    return count_active_users($days, $users);
}

=head2 count_new_users [DAYS]

Counts the number of users who've joined in the last day.

=cut

sub count_new_users {
    my $days = shift || 1;
    my $users = BTDT::Model::UserCollection->new;
    limit_to_today($users, "created_on");
    return $users->count;
}

=head2 count_new_purchases [COLLECTION]

Counts the number of purchases in the last day.

=cut

sub count_new_purchases {
    my $collection = shift || BTDT::Model::PurchaseCollection->new;
    limit_to_today($collection, "created");
    return $collection->count;
}

=head2 count_purchase_with COLUMN VALUE

Counts purchases in the last day, with the givecn C<COLUMN> matching
the given C<VALUE>.

=cut

sub count_purchase_with {
    my ($column, $value) = @_;
    my $collection = BTDT::Model::PurchaseCollection->new;
    $collection->limit( column => $column, value => $value );
    return count_new_purchases($collection);
}

=head2 sum_revenue

Sums the successful revenue, in dollars, over all time.

=cut

sub sum_revenue {
    my $txns = BTDT::Model::FinancialTransactionCollection->new;
    $txns->column(
        column => "amount",
        function => "sum(amount)/100",
    );
    $txns->results_are_readable(1);   # Skips ACL checks which would inspect non-existant ->user_id
    $txns->order_by( function => 1 ); # Removes 'order by id'
    $txns->limit(
        column => "error_message",
        operator => "is",
        value => "NULL",
    );
    return $txns;
}

=head2 sum_revenue_today

Sums the successful revenue, in dollars, over the past day.

=cut

sub sum_revenue_today {
    my $txns = sum_revenue();
    limit_to_today($txns, "created");
    return $txns;
}


1;
