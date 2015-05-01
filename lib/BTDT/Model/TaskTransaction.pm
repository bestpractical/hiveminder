use warnings;
use strict;

=head1 NAME

BTDT::Model::TaskTransaction

=head1 DESCRIPTION

Serves as a grouping method for L<BTDT::Model::TaskHistory> objects.
The transaction contains information about who did the modifications,
and at what time.  Individual changes are kept by the
L<BTDT::Model::TaskHistory> objects associated with this transaction.

=cut

package BTDT::Model::TaskTransaction;
use Jifty::DBI::Schema;
use BTDT::Model::TaskHistoryCollection;
use BTDT::Model::User;
use BTDT::Model::Task;

use base qw( BTDT::Record );

@BTDT::Model::TaskTransaction::IGNORE =
    qw(completed_at
       depended_on_by_summaries depended_on_by_ids depended_on_by_count
       depends_on_summaries     depends_on_ids     depends_on_count
       next_action_by           last_repeat
       attachment_count);

sub is_protected {1}
use Jifty::Record schema {

column
    task_id => refers_to BTDT::Model::Task,
    label is 'Task',
    is immutable;

column
    created_by => refers_to BTDT::Model::User,
    label is 'Created by', since '0.2.1',
    is immutable;

column
    modified_at => type is 'timestamp',
    label is 'Modified at',
    filters are qw( Jifty::Filter::DateTime Jifty::DBI::Filter::DateTime),
    since '0.2.1',
    is immutable;

column
    type => type is 'text',
    label is 'Type', since '0.2.7',
    is immutable,
    valid_values are qw(attachment create delete email update milestone timetrack mailloop);


column changes => refers_to BTDT::Model::TaskHistoryCollection by 'transaction_id';

column visible_changes => refers_to BTDT::Model::TaskHistoryCollection by 'transaction_id';

    column attachments =>
        references BTDT::Model::TaskAttachmentCollection by 'transaction_id',
        since '0.2.62';

    column time_estimate =>
        type is 'integer',
        label is 'Time estimate',
        since '0.2.95';

    column time_worked =>
        type is 'integer',
        label is 'Time worked',
        since '0.2.95';

    column time_left =>
        type is 'integer',
        label is 'Time left',
        since '0.2.95';

    column project =>
        references BTDT::Project,
        since '0.2.95';

    column milestone =>
        references BTDT::Milestone,
        since '0.2.95';

    column group_id =>
        references BTDT::Model::Group,
        since '0.2.96';

    column owner_id =>
        references BTDT::Model::User,
        since '0.2.97';
};

use Jifty::RightsFrom column => 'task';

=head2 since

This table first appeared in C<0.1.8>.

=cut

sub since {'0.1.8'}

=head2 create

Forces C<modified_at> to be the current time; defaults the
C<created_by> field to be the current user.

=cut

sub create {
    my $self = shift;
    my %args = (
        created_by => $self->current_user->user_object,
        @_,
        modified_at => DateTime->now->iso8601,
    );
    return $self->SUPER::create(%args);
}

=head2 deferred_create

Acts like L</create> but only actually creates the row in the database
when L</add_change> is first called.  If L</add_change> is never
called on this object, no row is created in the database.

=cut

sub deferred_create {
    my $self = shift;
    $self->{deferred_create} = {@_};
    return ( 1, "Creation deferred until later" );
}

=head2 force_real

If there is a deferred create pending, forces it into existance.

=cut

sub force_real {
    my $self = shift;
    $self->create( %{ delete $self->{deferred_create} } )
        if not $self->__value('id')
        and $self->{deferred_create};
}

=head2 update_next_repeat [VALUE]

If set to a true value, will call
L<BTDT::Model::Task/update_repeat_next_create> in L</commit>.

=cut

sub update_next_repeat {
    my $self = shift;
    $self->{update_next_repeat} = shift if @_;
    return $self->{update_next_repeat};
}

=head2 add_change COLUMN NEWVAL

Records a change in the given I<column> of the L<BTDT::Model::Task>
that this transaction is on, from the current value to the given
I<NEWVAL>.  This has the effect of creating a
L<BTDT::Model::TaskHistory> object.

=cut

sub add_change {
    my $self = shift;
    my ( $field, $new ) = @_;

    $self->force_real;

    return unless $self->current_user_can("update");
    return if $self->type eq "create";

    my $old = $field eq "tags" ? $self->task->__value('tags') : $self->task->$field;
    $old = $old->id if UNIVERSAL::isa( $old, "BTDT::Record" );

    unless ($self->{cache}) {
        # We briefly cache the _original_ value before any changes are
        # applied, so we don't need to care about the order the
        # changes are applied when looking at task properties below.
        $self->{cache}{$_} = $self->task->$_ for qw/complete will_complete owner_id group_id project milestone/;
    }

    if ($field =~ qr/^time_(worked|left|estimate)$/) {
        my $old_s = defined $old ? BTDT::Model::Task->duration_in_seconds($old) : 0;
        my $new_s = BTDT::Model::Task->duration_in_seconds($new);
        my $method = "set_" . $field;
        warn "Setting $field for txn @{[$self->id]}, but it already has one?\n"
            if defined $self->$field;
        # Ignore time_left changes if the task is complete or won't complete
        $self->$method( ($new_s||0) - ($old_s ||0) )
            unless $field eq "time_left" and ($self->{cache}{complete} or not $self->{cache}{will_complete});
    } elsif ($field =~ /^(owner_id|group_id|project|milestone)$/ and $self->task->type eq "task") {
        $self->{timetracking}{$field eq "milestone" ? "milestone" : "timetrack"} = 1;
    } elsif ($field =~ /^(complete|will_complete)$/) {
        $self->{visibility} = (!$self->{cache}{complete} and $self->{cache}{will_complete});
    }

    my $change = BTDT::Model::TaskHistory->new();
    $change->create(
        task_id        => $self->task->id,
        field          => $field,
        old_value      => $old,
        new_value      => $new,
        transaction_id => $self->id,
    );

    return $change;
}

=head2 changes

Returns a L<BTDT::Model::TaskHistoryCollection> of all of the changes
in this transaction

=cut

=head2 visible_changes

Returns a L<BTDT::Model::TaskHistoryCollection> of all of the changes
which are user-visible in this transaction

=cut

sub visible_changes {
    my $self = shift;

    if ( my $prefetched_collection = $self->prefetched('visible_changes')) {
        return $prefetched_collection;
    }

    my $collection = BTDT::Model::TaskHistoryCollection->new;
    $collection->limit( column => 'transaction_id', value => $self->id );
    $collection->limit(
        column           => 'field',
        case_sensitive   => 1,
        operator         => '!=',
        entry_aggregator => 'AND',
        value            => $_
        )
        for @BTDT::Model::TaskTransaction::IGNORE;
    return $collection;
}

=head2 comments

Returns a L<BTDT::Model::TaskEmailCollection> of all of the emails
related to this transaction

=cut

sub comments {
    my $self    = shift;
    my $comments = BTDT::Model::TaskEmailCollection->new();
    $comments->limit(
        column   => 'transaction_id',
        operator => '=',
        value    => $self->id
    );
    return $comments;
}

=head2 commit

Save the transaction

=cut

sub commit {
    my $self = shift;

    return unless $self->id;

    # It is possible that the visibility of the task changed between
    # start and end.  If so, we want to adjust the time_left on the
    # txn such that it zeros out, or re-instates, the task's time
    # left.
    if (exists $self->{visibility}) {
        my $now = (!$self->task->complete and $self->task->will_complete);
        if ($self->{visibility} and not $now) {
            # Going not-visible; set the time_left down to 0
            $self->set_time_left( ($self->time_left || 0) - ($self->task->time_left_seconds || 0) );
        } elsif (not $self->{visibility} and $now) {
            # Going visible; increase time_left
            $self->set_time_left( ($self->time_left || 0) + ($self->task->time_left_seconds || 0) );
        }
    }

    # If the visibility to specific searches (i.e., by owner, group,
    # project, or milestone) changed, we need to flag the change, such
    # that the search can note the change in the sum.
    if ($self->{timetracking}) {
        my %new = map {($_ => $self->task->$_)} qw/owner_id group_id project milestone/;
        $new{task_id} = $self->task_id;
        $new{$_} = $new{$_}->id for grep {ref $new{$_}} keys %new;

        my %old = map {($_ => $self->{cache}{$_})} qw/owner_id group_id project milestone/;
        $old{task_id} = $self->task_id;
        $old{$_} = $old{$_}->id for grep {ref $old{$_}} keys %old;

        my @times;
        if (exists $self->{timetracking}{milestone}) {
            # The milestone changed.  This is dealt with differently
            # than everything else, because milestones' estimates are
            # not the task's estimate, but the time left when it
            # entered the milestone.
            if ($old{milestone}) {
                # We're leaving a milestone, so find the estimite from
                # when we entered, and subtract it off.
                my $search = BTDT::Model::TaskTransactionCollection->new;
                $search->limit( column => "milestone", value => $old{milestone} );
                $search->limit( column => "task_id",   value => $self->task_id );
                $search->limit( column => "type",      value => "milestone" );
                $search->order_by({column => "modified_at"});
                my $prev = $search->last;
                if ($prev and $prev->id) {
                    $prev->create(
                        %old,
                        time_left     => -($self->task->time_left_seconds || 0),
                        time_estimate => -$prev->time_estimate,
                        type          => "milestone"
                    );
                    push @times, $prev;
                } else {
                    warn "Can't find previous milestone entry to snip off?";
                }
            }

            if ($new{milestone}) {
                # Create the entry into the milestone.  Note that if this
                # is not the _first_ time moving it into the milestone, we
                # revert to the first estimate, and don't take the current
                # time left as the estimate!
                my $search = BTDT::Model::TaskTransactionCollection->new;
                $search->limit( column => "milestone", value => $new{milestone} );
                $search->limit( column => "task_id",   value => $self->task_id );
                $search->limit( column => "type",      value => "milestone" );
                $search->order_by({column => "modified_at"});
                my $prev = $search->first;
                my $new = BTDT::Model::TaskTransaction->new;
                if ($prev and $prev->id) {
                    # We've been in this milestone before
                    $new->create(
                        %new,
                        time_left     => $self->task->time_left_seconds,
                        time_estimate => $prev->time_estimate,
                        type          => "milestone",
                    );
                } else {
                    # This is the first move into the milestone
                    $new->create(
                        %new,
                        time_left     => $self->task->time_left_seconds,
                        time_estimate => $self->task->time_left_seconds,
                        type          => "milestone",
                    );
                }
                push @times, $new;
            }
        }

        # If non-milestone things have changed, the case is slightly
        # simpler.  Note this isn't an elsif!  You can get both
        # milestone and non-milestone update flags for one change!
        if ($self->{timetracking}{timetrack}
            and (  ( $self->task->time_left_seconds || 0 ) != 0
                or ( $self->task->time_estimate_seconds || 0 ) != 0 )
            )
        {
            my $prev = BTDT::Model::TaskTransaction->new;
            $prev->create(
                %old,
                time_left     => -($self->task->time_left_seconds || 0),
                time_estimate => -($self->task->time_estimate_seconds || 0),
                type          => "timetrack"
            );
            push @times, $prev;
            my $new = BTDT::Model::TaskTransaction->new;
            $new->create(
                %new,
                time_left     => $self->task->time_left_seconds,
                time_estimate => $self->task->time_estimate_seconds,
                type          => "timetrack"
            );
            push @times, $new;
        }

        # Update all of the changes to have the same timestamp.  We
        # need to use __set because it's marked readonly at the
        # Jifty::DBI level.
        my $now = BTDT::DateTime->now;
        $_->__set(column => "modified_at", value => $now) for @times;
    }

    $self->task->update_repeat_next_create if $self->update_next_repeat;

    $self->send_notifications();
}

=head2 send_notification NotificationClassName

Perform notifications that should happen after a task update or creation.

Takes the name of the BTDT::Notification class and the change to send
a notification about.

=cut

sub send_notification {
    my $self         = shift;
    my $notification = shift;

   # XXX The change parameter means that we'll only send mail about individual
   # changes at once, but we're running send_notification inside a for
   # loop over all the changes. Unless we want to be sending one big
   # mail summarizing all the changes made in this transaction, we
   # can't really use $self->changes.
    my $change   = shift;
    my $task     = $self->task;
    my $comments = $self->comments;

    # First comment on this commit
    my $proxy = $comments->first;

    # First comment on the create transaction -- this is the "last"
    # transaction because they're in reverse order
    # The task may have no transactions if it was just deleted
    my $reply;
    if ($task->transactions->count) {
        $reply = $task->transactions->last->comments->first;
    }
    else {
        # XXX: sending the notification generates a ton of warnings and doesn't
        # send the notification anyway. we should be trying harder to send out
        # the notification OR send it before we delete the task
        return;
    }

    # Proxy falls back to responding to the top message if we have no
    # headers to crib off of
    my @proxy = $proxy ? ( proxy_of => $proxy ) : ( reply_to => $reply );

    my $notification_class = "BTDT::Notification::$notification";
    unless ( Jifty::Util->require($notification_class) ) {
        $self->log->error("Couldn't find notification class $notification");
        return;
    }
    $notification_class->new(
        task        => $task,
        transaction => $self,

        # All the notification classes handle only 1 change at a time.
        change => $change,
        @proxy
    )->send;

}

=head2 send_notifications

Figure out which notifications to send and send em.

=cut

sub send_notifications {
    my $self     = shift;


    my $cu = $self->current_user();
    $self->current_user(BTDT::CurrentUser->superuser);

    my $changes  = $self->visible_changes;
    my $task     = $self->task;
    my $comments = $self->comments;

    my $type = $self->type || 'none';

    if ( $type eq "create" ) {
        $self->send_notification('TaskCreated');
    } elsif ( $type eq "delete" ) {
        $self->send_notification('TaskDeleted');
    } else {
        my @citems = @{$changes->items_array_ref};
        while ( my $c = $changes->next ) {
            next if ($c->field eq 'accepted' && !defined $c->new_value);
            next if ($c->field eq 'completed_at');
            if ( $c->field eq "complete" and $c->new_value ) {
                # * When a task is marked done
                $self->send_notification( 'TaskCompleted', $c );

            } elsif ( $c->field eq "complete" and !$c->new_value ) {
                # * When a task is marked not done
                $self->send_notification( 'TaskUncompleted', $c );
            } elsif ( $c->field eq "accepted"
                      and $c->new_value
                      and $c->task->owner_id != BTDT::CurrentUser->nobody->id
                      and $cu->id != BTDT::CurrentUser->superuser->id) {

                # * When a task is accepted
                $self->send_notification( 'TaskAccepted', $c );
            } elsif ( $c->field eq "accepted" and not $c->new_value ) {
                # * When a task is declined
                $self->send_notification( 'TaskDeclined', $c );

            } elsif ( $c->field eq 'group_id' and !$c->new_value ) {

                # * When someone moves a task into a group that isn't Personal
                $self->send_notification( 'TaskIntoGroup', $c );

            } elsif ( $c->field eq 'group_id' and !$c->old_value ) {

                # * When someone moves a task out of a group that isn't Personal
                $self->send_notification( 'TaskOutOfGroup', $c );

            } elsif ( $c->field
                and $c->field eq "owner_id"
                and $self->created_by->id == $c->new_value )
            {

                # * When a task is taken by a user
                $self->send_notification( 'TaskTaken', $c );

            } elsif ( $c->field
                and $c->field eq "owner_id"
                and $self->created_by->id != $c->new_value
                and $self->created_by->id != BTDT::CurrentUser->superuser->id,
                and $c->new_value != BTDT::CurrentUser->nobody->id )
            {
                # * When a task is given to another user
                $self->send_notification( 'TaskGiven', $c );

            } elsif ( $c->field
                and $c->field eq "owner_id"
                and $c->new_value == BTDT::CurrentUser->nobody->id )
            {

                # * When a task is abandoned by a user
                $self->send_notification( 'TaskAbandoned', $c );

            }

        }
        if ( $comments->count ) {

            # * When someone comments on a task
            $self->send_notification('TaskComment');
        }
    }

    $self->current_user($cu);
}

=head2 author

Returns the name of the author of the transaction, possibly just "You".

=cut

sub author {
    my $self = shift;
    return $self->current_user->id == $self->created_by->id
            ? 'You'
            : $self->created_by->name
}

=head2 summary

Returns a plaintext summary of the transaction.

=cut

sub summary {
    my $self = shift;
    my $comment = $self->summary_comment(@_);
    return '' unless $comment;
    return _("%1 ".$comment, $self->author);
}

=head2 summary_comment

Returns the descriptive part of the summary for this task transaction.
It's NOT localized. It's generally expected to be used by summary, which will localize it as

_("%1 ".$self->summary_comment, $self->created_by->name);

=cut

sub summary_comment {
    my $self = shift;
    my %args = @_;

    my $type = $self->task->type;
    my $the_task = "the $type";
    if ($args{show_task_locator}) {
        $the_task = "$type #" . BTDT::Record->record_locator($self->task_id);
    }


    if ( $self->type eq "create" ) {

        # XXX work around some odd permissions problems while debugging t/24
        if ( defined( $self->created_by->name ) ) {
            return "created $the_task";
        } else {
            Carp::cluck("Why don't we have acls to see the creator of this task @{[$self->created_by->id]} as user ".$self->current_user->id);
            return "Task created";
        }
    } elsif ( $self->type eq "delete" ) {
        return "deleted $the_task";
    } elsif ( $self->type eq "update" ) {
        my $changes = $self->visible_changes;
        if ( $changes->count > 1 ) {
            return "made some changes to $the_task";
        }
        elsif ($changes->count == 1) {
            return $changes->first->as_string(%args);
        }
        else {
            return "";
        }
    } elsif ( $self->type eq "email" ) {
        return "added a comment to $the_task";
    } elsif ( $self->type eq "attachment" ) {
        return "added an attachment to $the_task";
    } elsif ( $self->type eq "mailloop" ) {
        return "sent an email which caused a possible email loop";
    } else {
        return "";
    }
}

=head2 body

Returns the body of the update as a text string suitable to be passed
to Text::Markdown.  This includes a list of individual changes (if
there is more than one) as well as all comments related to the
transaction.

=cut

sub body {
    my $self = shift;

    my $body = "";
    my $changes = $self->visible_changes;
    if ( $self->type eq "update" and $changes->count > 1 ) {
        $body = join "\n", map { " * " . $_->as_string }
            grep { $_->as_string } @{ $changes->items_array_ref };
    }
    $body .= "\n\n" . $_->body for @{ $self->comments->items_array_ref };

    return $body;
}

=head2 as_ical_event

Returns the transaction as a L<Data::ICal::Entry::Event> object.

=cut

sub as_ical_event {
    my $self = shift;
    my $at   = $self->modified_at;
    $at =~ tr/ :-/T/d;

    my $created = $self->task->created;
    $created =~ tr/ :-/T/d;

    my $vevent = Data::ICal::Entry::Event->new();
    $vevent->add_properties(
        summary     => $self->task->summary . ": " . $self->summary,
        description => $self->body,
        url         => $self->task->url,
        organizer   => $self->created_by->name,
        dtstamp     => $at,
        dtstart     => $at,
        created     => $created,
        categories  => $self->task->tags,
    );

    return ($vevent);
}

=head2 as_atom_entry

Returns the transaction as an L<XML::Atom::Link> object.

=cut

sub as_atom_entry {
    my $self = shift;

    my $link = XML::Atom::Link->new;
    $link->type('text/html');
    $link->rel('alternate');
    $link->href( $self->task->url );

    my $entry = XML::Atom::Entry->new;
    $entry->add_link($link);
    $entry->title( $self->summary . " at " . $self->modified_at );

    $entry->updated( $self->modified_at->ymd('-').'T'.$self->modified_at->hms(':').'Z');
    my $author = XML::Atom::Person->new();
    $author->name( $self->created_by->name );
    $author->email( $self->created_by->email );
    $entry->author($author);

    $entry->content(BTDT->text2html($self->body));

    return $entry;
}

1;

