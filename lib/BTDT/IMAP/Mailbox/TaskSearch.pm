package BTDT::IMAP::Mailbox::TaskSearch;

use warnings;
use strict;

use base qw/BTDT::IMAP::Mailbox/;

__PACKAGE__->mk_accessors( qw/last_polled tokens tasks transaction_exceptions/ );

=head1 NAME

BTDT::IMAP::Mailbox::TaskSearch - Token-based task searches

=head1 METHODS

=head2 tokens [ARRAYREF]

Gets or sets the list of tokens in this task search.

=head2 transaction_exceptions

Returns a hashref, whose keys are the ids of transactions which we
expect to see appear in the mailbox, and have already added them as
messages; thus, they should be skipped when we run across them while
polling.

=head2 tasks [ARRAYREF]

Gets or sets the list of task ids which we know about last time this
mailbox was polled.

=head2 load_data

On initialization, find the highest UID used in this mailbox by this
user, and set UIDNEXT appropriately.  Also, make sure we have empty
refs for things.  Other mailboxes may attempt to shove things into
them, and even though we don't care, we need to make sure such
attempts don't explode.

=cut

sub load_data {
    my $self = shift;
    $self->SUPER::load_data(@_);
    my($max) = Jifty->handle->fetch_result("SELECT max(uid) FROM imapuids where user_id = ? and path = ?", $self->current_user->id, $self->full_path);
    $self->uidnext($max ? $max + 1 : 1000);
    $self->tasks({});
    $self->transaction_exceptions({});
}

=head2 load_original

Loads the set of tasks which match the tokens.

=cut

sub load_original {
    my $self = shift;

    Jifty->handle->begin_transaction;
    Jifty->handle->simple_query("SET TRANSACTION ISOLATION LEVEL SERIALIZABLE");

    eval {
        # Find max trasaction
        my($max) = Jifty->handle->fetch_result("SELECT max(id) FROM task_transactions");
        $self->last_polled($max);

        my($emails, $alias) = $self->email_collection;

        $self->messages([]);
        my %tasks;
        while ( my $obj = $emails->next ) {
            $tasks{$obj->task_id}=1;
            $self->add_task_email($obj, prefetched => 1);
        }
        $self->messages([sort {$a->uid <=> $b->uid} @{$self->messages}]);
        my $seq = 1;
        $_->sequence($seq++) for @{$self->messages};

        $self->tasks(\%tasks);
        $self->transaction_exceptions({});
    };
    $Net::IMAP::Server::Server->connection->logger->warn("ORIGINAL LOAD TRANSACTION BLOCK: $@")
        if $@;

    Jifty->handle->commit;
}

=head2 status

Make sure that messages get purged from memory on a STATUS operation

=cut

sub status {
    my $self = shift;
    return $self->SUPER::status(@_) if $self->last_polled;

    # We optimize for the case when the mailbox wasn't loaded
    my @keys = @_;
    my %found = (MESSAGES => 0, RECENT => 0, UNSEEN => 0);
    if (grep {/^(MESSAGES|RECENT|UNSEEN)$/} @keys) {
        # Don't do the search unless we need to
        my $emails = BTDT::Model::TaskEmailCollection->new(
            current_user => $self->current_user );
        my $txn_alias = $self->limit_emails($emails);
        my $alias = $emails->join(
            alias1  => $txn_alias,
            column1 => 'task_id',
            table2  => 'tasks',
            column2 => 'id',
            is_distinct => 1,
        );
        $self->task_collection($emails, $alias);
        my $flags = $emails->join(
            type    => 'left',
            alias1  => 'main',
            column1 => 'transaction_id',
            table2  => "BTDT::Model::IMAPFlagCollection",
            column2 => 'uid',
            is_distinct => 1,
        );
        $emails->limit( leftjoin => $flags, column => 'path', value => "TXN" );
        $emails->limit( leftjoin => $flags, column => 'user_id', value => $self->current_user->id );
        $emails->prefetch( alias => $flags,
                           class => 'BTDT::Model::IMAPFlag',
                           name  => "flags" );

        while (my $obj = $emails->next) {
            $found{MESSAGES}++;
            my $flags = {};
            if ($obj->prefetched("flags")) {
                $obj->prefetched("flags")->_is_readable(1);
                $flags->{$_} = 1 for @{$obj->prefetched("flags")->value || []};
            }
            $found{UNSEEN}++ unless $flags->{'\Seen'};
            $found{RECENT}++ if $flags->{'\Recent'};
        }
    }


    my %items;
    for my $i ( @keys ) {
        if ( $i =~ /^(MESSAGES|RECENT|UNSEEN)$/ ) {
            $items{$i} = $found{$i};
        } elsif ( $i eq "UIDVALIDITY" ) {
            my $uidvalidity = $self->uidvalidity;
            $items{$i} = $uidvalidity if defined $uidvalidity;
        } elsif ( $i eq "UIDNEXT" ) {
            my $uidnext = $self->uidnext;
            $items{$i} = $uidnext if defined $uidnext;
        }
    }
    return %items;
}

=head2 task_collection COLLECTION ALIAS

Takes the given collection, assuming that C<ALIAS> is the alias to a
L<BTDT::Model::TaskCollection>, and enforces the token search and task
ACLs.

=cut

sub task_collection {
    my $self = shift;
    my ($collection, $alias) = @_;

    $collection->task_search_on( $alias, tokens => @{$self->tokens});
}

=head2 email_collection

Returns a L<BTDT::Model::TaskEmailCollection> of the emails for this
token search, as well as the alias to the task join.  Prefetches the
UIDs and flags, as well.

=cut

sub email_collection {
    my $self = shift;
    my $emails = BTDT::Model::TaskEmailCollection->new(
        current_user => $self->current_user );
    my $txn_alias = $self->limit_emails($emails);
    my $alias = $emails->join(
        alias1  => $txn_alias,
        column1 => 'task_id',
        table2  => 'tasks',
        column2 => 'id',
        is_distinct => 1,
    );
    $self->task_collection($emails, $alias);
    my ($uids, $flags) = $self->prefetch_uids_flags($emails);
    return($emails, $alias, $uids, $flags);
}

=head2 threaded

Returns true if the mailbox has has a message for every TaskEmail, or
merely for each Task.  Defaults to the setting on L<BTDT::IMAP::Auth>.

=cut

sub threaded {
    my $self = shift;
    my $auth = $Net::IMAP::Server::Server->connection->auth;
    return $auth->options->{threaded};
}

=head2 limit_emails COLLECTION

Limit to only task_emails we care about.  In the case of non-threaded
mailbox trees, this means only those on CREATE transactions.

=cut

sub limit_emails {
    my $self = shift;
    my $emails = shift;
    $emails->columns(qw/id task_id transaction_id/);
    return "main" if $self->threaded;
    my $txns = $emails->join(
        alias1  => 'main',
        column1 => 'transaction_id',
        table2  => 'task_transactions',
        column2 => 'id',
        is_distinct => 1,
    );
    $emails->limit( alias => $txns, column => "type", value => "create", case_sensitive => 1 );
    $emails->prefetch( alias => $txns, name => "transaction" );
    return $txns;
}

=head2 transaction_collection

Returns a L<BTDT::Model::TaskTransactionCollection> of the token
search, as well as the alias to the task join.

=cut

sub transaction_collection {
    my $self = shift;
    my $txns = BTDT::Model::TaskTransactionCollection->new(
        current_user => $self->current_user );
    my $alias = $txns->join(
        alias1  => 'main',
        column1 => 'task_id',
        table2  => 'tasks',
        column2 => 'id',
        is_distinct => 1,
    );
    $self->task_collection($txns, $alias);
    return $txns;
}

=head2 prefetch_uids_flags COLLECTION

Given a L<BTDT::Model::TaskEmailCollection>, joins it to
L<BTDT::Model::IMAPUIDCollection> and
L<BTDT::Model::IMAPUIDCollection>, giving the email a C<flags> and
C<uid> prefetch.

=cut

sub prefetch_uids_flags {
    my $self = shift;
    my $emails = shift;
    my $uids = $emails->join(
        type    => 'left',
        alias1  => 'main',
        column1 => 'transaction_id',
        table2  => "BTDT::Model::IMAPUIDCollection",
        column2 => 'transaction',
        is_distinct => 1,
    );
    $emails->limit( leftjoin => $uids, column => 'path', value => $self->full_path );
    $emails->limit( leftjoin => $uids, column => 'user_id', value => $self->current_user->id );
    $emails->prefetch( alias => $uids,
                       class => 'BTDT::Model::IMAPUID',
                       name  => "uid" );

    my $flags = $emails->join(
        type    => 'left',
        alias1  => 'main',
        column1 => 'transaction_id',
        table2  => "BTDT::Model::IMAPFlagCollection",
        column2 => 'uid',
        is_distinct => 1,
    );
    $emails->limit( leftjoin => $flags, column => 'path', value => "TXN" );
    $emails->limit( leftjoin => $flags, column => 'user_id', value => $self->current_user->id );
    $emails->prefetch( alias => $flags,
                       class => 'BTDT::Model::IMAPFlag',
                       name  => "flags" );
    $emails->order_by( alias => $uids, column => "uid");

    return ($uids, $flags);
}

=head2 add_task_email

Unimplemented because TaskSearch is an abstract base
class. Descendants are expected to implement this
subroutine.

=cut

sub add_task_email {die "Unimplemented";}

=head2 messages_for ID

Returns messages for the given task id.

=cut

sub messages_for {
    my $self = shift;
    my $id = shift;
    # XXX Can be indexed better
    return grep {$_->task_email->task_id == $id} @{$self->messages};
}

=head2 poll

On poll, we find a coherent set of tasks which need to get added or
removed.

=head2 last_polled [ID]

Gets or sets the highest transaction id which we have seen.

=cut

sub poll {
    my $self = shift;
    return $self->load_original unless defined $self->last_polled;

    # Flush JDBI caches
    require Jifty::DBI::Record::Cachable;
    Jifty::DBI::Record::Cachable->flush_cache;

    # Start a new transaction so we don't get phantom reads.  This
    # guarantees that we see consistent state in all of the below
    # queries.  We can't set the txn as read-only, because recording
    # UID <-> txn mappings is a write.
    Jifty->handle->begin_transaction;
    Jifty->handle->simple_query("SET TRANSACTION ISOLATION LEVEL SERIALIZABLE");

    eval {

        # Find where we're going to be up-to-date to
        my($max) = Jifty->handle->fetch_result("SELECT max(id) FROM task_transactions");

        # Do a diff of the task list.  This could be better indexed.
        my %diff; $diff{$_}-- for keys %{$self->tasks};
        my $tasks = BTDT::Model::TaskCollection->new( current_user => $self->current_user );
        $self->task_collection( $tasks, "main" );
        $tasks->columns("id");
        $self->tasks({map {$_->id => 1} @{$tasks->items_array_ref}});
        $diff{$_}++ for keys %{$self->tasks};

        # Remove tasks which don't match now (negative $diff)
        my @expunge;
        for (map {$self->messages_for($_)} grep {$diff{$_} < 0} keys %diff) {
            $_->set_flag('\Deleted', 1);
            push @expunge, $_;
        }

        # Changes to old tasks
        my $changes = $self->transaction_collection;
        $changes->limit( entry_aggregator => 'AND', column => 'id', operator => '>', value => $self->last_polled );
        my @changes; my %already;
        while ( my $txn = $changes->next ) {
            next if $diff{$txn->task_id}; # Skip changes on tasks we've not added yet
            if ($self->trust_append) {
                next if $self->transaction_exceptions->{$txn->id};
            }
            my ($original) = grep {$_->is_task_summary} $self->messages_for($txn->task_id);
            push @changes, $original if $original and not $already{$original->sequence}++;
        }
        my @new;
        for my $old (@changes) {
            $old->set_flag('\Deleted', 1);
            push @expunge, $old;
            $old->delete_uid_mapping if $old->can('delete_uid_mapping'); # So the new one, below, doesn't find it

            push @new, $self->add_task_email( $old->task_email, uid => undef );
        }
        $self->SUPER::expunge([sort {$a <=> $b} map {$_->sequence} @expunge]);
        $_->clear_flag( '\Deleted', 1 ) for @expunge;
        $_->clear_flag( '\Seen', 1 ) for @new;

        # Add tasks which do now fit the bill (positive $diff)
        for my $task_id (grep {$diff{$_} > 0} keys %diff) {
            my $emails = BTDT::Model::TaskEmailCollection->new( current_user => $self->current_user );
            $emails->limit(column => 'task_id', operator => '=', value => $task_id);
            $self->limit_emails($emails);
            $self->prefetch_uids_flags($emails);
            while ( my $obj = $emails->next ) {
                $self->add_task_email($obj, prefetched => 1);
            }
        }

        # New emails for tasks which used to, and still do, fit the bill
        # We only need this if the user has threading enabled
        if ($self->threaded) {
            my($emails, $e_alias) = $self->email_collection;
            $emails->limit( entry_aggregator => 'AND', column => 'transaction_id', operator => '>', value => $self->last_polled );
            while ( my $obj = $emails->next ) {
                next if $diff{$obj->task_id}; # We added this already
                next if $self->transaction_exceptions->{$obj->transaction->id}; # We added this between polls
                $self->add_task_email($obj, prefetched => 1);
            }
        }

        # Remove transaction exceptions
        $self->transaction_exceptions({});

        # Update when the last changed id
        $self->last_polled($max);

    };
    $Net::IMAP::Server::Server->connection->logger->warn("TRANSACTION BLOCK: $@")
        if $@;
    # Finally, we commit the transaction.  We need this to be a
    # commit, and not a rollback, because adding flags and UID <-> txn
    # mappings is a write.
    Jifty->handle->commit;
}

=head2 add_task TASK PARAMHASH

Takes a L<BTDT::Model::Task> object, $task, extracts the
L<BTDT::Model::TaskEmail> of $task and passes it to
L</add_task_email> to create a message. May also take an
optional PARAMHASH to pass on to
L</add_task_email>. Returns the message created and forces
the server to poll the mailbox.

=cut

sub add_task {
    my $self = shift;
    my $task = shift;
    my %args = @_;
    my @comments = $self->threaded ? @{$task->comments->items_array_ref} : ($task->comments->first);
    my $matching = delete $args{matching} || $comments[0]->id;

    my $return;
    for my $comment (@comments) {
        my $message = $self->add_task_email($comment, %args);
        $return = $message if $comment->id == $matching;
        $self->transaction_exceptions->{$comment->transaction->id}++;
    }

    $self->tasks->{$task->id} = 1;
    $Net::IMAP::Server::Server->connection->force_poll;

    return $return;
}

=head2 unload

Purge messages if there are no other pending connections to this
mailbox.

=cut

sub unload {
    my $self = shift;
    $self->last_polled(undef);
    my @messages = @{$self->messages || []};
    $self->messages([]);
    $self->uids({});
    $self->tasks({});
    $self->transaction_exceptions({});
    $_->prep_for_destroy for @messages;
}

=head2 trust_append

Mailbox distrusts messages appended by users by default.

=cut

sub trust_append { 0; }

1;
