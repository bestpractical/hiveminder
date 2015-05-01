use warnings;
use strict;

=head1 NAME

BTDT::Model::TaskTransactionCollection

=cut

package BTDT::Model::TaskTransactionCollection;
use base qw/BTDT::Collection/;

=head2 prefetch_common

Causes this collection to prefetch the task and the visible task
histories for all of the transactions.  That is, calling
L<BTDT::Model::TaskTransaction/task> or any methods on it, as well as
L<BTDT::Model::TaskTransaction/visible_changes> or any methods on the
objects it returns, will not incur another database query.

Returns the L<BTDT::Model::TaskCollection> alias and the
L<BTDT::Model::TaskHistoryCollection> alias.

=cut

sub prefetch_common {
    my $self = shift;
    my %args = (history => 1, task => 1, visible_only => 1, @_);
    my($tasks_alias, $histories);
    if ($args{task}) {
        $tasks_alias = $args{task_collection} || $self->join(
            alias1  => 'main',
            column1 => 'task_id',
            table2  => 'tasks',
            column2 => 'id',
            is_distinct => 1,
        );
        $self->prefetch( $tasks_alias => 'task' );
    }

    if ($args{history}) {
        $histories = $self->join(
            type    => 'left',
            alias1  => 'main',
            column1 => 'id',
            table2  => 'task_histories',
            column2 => 'transaction_id',
            is_distinct => 1,
        );
        if ($args{visible_only}) {
            $self->limit(
                leftjoin         => $histories,
                column           => 'field',
                case_sensitive   => 1,
                operator         => '!=',
                entry_aggregator => 'AND',
                value            => $_
                )
                for @BTDT::Model::TaskTransaction::IGNORE;
            $self->prefetch( $histories   => 'visible_changes' );
        } else {
            $self->prefetch( $histories   => 'changes' );
        }

    }

    return ($tasks_alias, $histories);
}

=head2 between PARAMHASH

Required keys to the paramhash:

=over

=item starting

A DateTime representing the first date for this collection. This should be
set to the GMT timezone, at midnight in whatever the user's local time is (so
pass in a DateTime 05:00:00 GMT for midnight EST)

=item ending

A DateTime representing the last date for this collection. See the C<starting>
argument doc for what we expect of the calling code.

=back

Returns the aliases to the "Tasks" and "TaskHistories" tables used during the search

=cut

sub between {
    my $self = shift;
    my %args = (@_);

    my $starting = $args{'starting'};
    my $ending = $args{'ending'};


    my $tasks = $self->join(
        alias1  => 'main',
        column1 => 'task_id',
        table2  => 'tasks',
        column2 => 'id',
        is_distinct => 1,
    );

    BTDT::Model::TaskCollection->default_limits(
        collection  => $self,
        tasks_alias => $tasks
    );

    $self->limit(
        column           => 'modified_at',
        case_sensitive   => 1,
        operator         => '>=',
        value            => $starting->ymd . ' ' . $starting->hms,
        entry_aggregator => 'AND'
    );
    $self->limit(
        column           => 'modified_at',
        case_sensitive   => 1,
        operator         => '<=',
        value            => $ending->ymd . ' ' . $ending->hms,
        entry_aggregator => 'AND'
    );

# XXX: these lines of code are commented out because we assume the calling code
# knows what it wants to do with timezones. this was breaking in a bad way with
# date (sans time) objects

# now that we're through using these things to search, it's safe to pull them from GMT to the user timezone
    #$starting->set_time_zone(
    #    $self->current_user->user_object->time_zone );
    #$ending->set_time_zone(
    #    $self->current_user->user_object->time_zone );

    return $self->prefetch_common(task_collection => $tasks);

}
1;
