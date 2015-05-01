use warnings;
use strict;

package BTDT::TaskNotification;

use base qw/BTDT::Notification/;

use Email::Simple;
use Email::MIME::Creator;
use Date::Manip;
use Encode;

__PACKAGE__->mk_accessors(qw/task transaction proxy change/);

=head2 DESCRIPTION

A set of notifications about a particular TaskTransaction.
These are subclassed extensively.

=cut

=head2 setup

Sets up the from, subject and recipients

=cut

sub setup {
    my $self = shift;
    $self->SUPER::setup(@_);
    $self->task->current_user(BTDT::CurrentUser->superuser);
    $self->from($self->comment_address);
    $self->subject($self->task->summary);
    $self->to_list($self->setup_recipients);
}

=head2 setup_recipients

Figures out who we should send this txn to

=cut


sub setup_recipients {
    my $self = shift;


        # XXX TODO: would this code be cleaner if we
        # always added:
        # actor, owner, requestor, group members and then
        # _Removed_ the wrong ones?

    my @recipients;

    # Let's do this as the superuser to get the right data
    my $transaction = BTDT::Model::TaskTransaction->new(current_user => BTDT::CurrentUser->superuser);
    $transaction->load($self->transaction->id);
    my $task = $transaction->task;
    my $group    = $task->group;

    # If the group doesn't want any mail, bail now with no recipients
    return if $group->id and $group->never_email;

    my $actor    = $self->actor;
    my $change  = $self->change;

    my $nobody_id = BTDT::CurrentUser->nobody->id;

    my $no_owner = 0;
    if (   $task->owner->id ==  $nobody_id
        || ($change
        and $change->field eq "owner_id"
        and (  $change->old_value == $nobody_id
            || $change->new_value == $nobody_id )
        ))
    {
        $no_owner = 1;
    }

    # XXX: another way to put this below is:
    # if the actor is also the requestor, they don't need to get mail
    # if the actor is the owner, they don't need to get mail
    # if the actor isn't the requestor, the requestor needs mail
    # if the actor isn't the owner, the owner needs mail


    #Notification scheme A  - always do this
    #  if it's a personal task,
    if ( !$group->id ) {

        # notify the requestor if they aren't the actor
        if ( $actor->id != $task->requestor->id ) {
                push @recipients, $task->requestor;
        }

        # notify the owner if they aren't the actor
        if ( $actor->id != $task->owner->id ) {
                push @recipients, $task->owner;
        }
    } else {
        if ($no_owner) {
            # notify all group members except the actor
            push @recipients, $_ for (grep { $_->id != $actor->id} @{$group->members->items_array_ref});
        } elsif ( $actor->id != $task->owner->id ) {
            # notify the owner
            push @recipients, $task->owner;
        }
        if ( $actor->id != $task->requestor->id && $group->has_member($task->requestor)) {
            push @recipients, $task->requestor;
        }

    }

    # On comment also: #Notification scheme B
    # XXX TODO: this doesn't uniquely identify Comment transactions
    if ( $self->isa('BTDT::Notification::TaskComment') and $transaction->comments->count) {
        if ( !$group->id ) {
            # Notify the actor
            push @recipients, $actor;
        } else {

            # Send email to non-member requestors
            push @recipients, $task->requestor;

            # Notify all group members if the group is set to do so
            if ($group->broadcast_comments) {
                push @recipients, $_ for (@{$group->members->items_array_ref});
            }
        }
    }
    if ( $change and $change->field eq "accepted" and $group->id ) {

        # On accept or decline
        # If it's a group task:
        # Notify the requestor if they're a group member and not the actor
        if (    $actor->id != $task->requestor->id
            and $group->has_member( $task->requestor ) )
        {
                push @recipients, $task->requestor;
        }

    }

    return @recipients;


}

=head2 actor

Returns the actor for this task txn

=cut

sub actor {
    my $self = shift;
    return $self->transaction->created_by;
}


=head2 comment_address

Returns this task's comment address

=cut


sub comment_address {
    my $self = shift;
    my $task = $self->task;
    my $from = _('Hiveminder');

    my $user = $self->actor->name;

    if (defined $task->group && $task->group->id) {
        if ($task->group->id) {
            $from = $user. ' / ' . $task->group->name . ' with '. $from;
        } else {
            # A user who isn't part of a group is sending mail back on a group task.
            # Most likely, current_user is a nonuser.
            $from = $user . ' with '. $from;
        }
    } else {  # this is a personal task
        $from = $user . ' with '. $from;
    }

    return Email::Address->new( $from => $task->comment_address)->format;

}

=head2 preface

Print a 2-5 line summary of this mail, which should be sufficient
to tell the user what they need to know about this task.

=cut

sub preface {
    my $self = shift;
    return $self->_note;
}

=head2 body

The body of the notification includes a URL to the task, the task's
description, and a note to accept it (if need be).

=cut

sub body {
    my $self = shift;
    my $msg  = $self->_accept_or_decline('text');
    return $msg;
}

sub _accept_or_decline {
    my $self = shift;
    my $type = shift || 'text';
    my $msg  = "";

    if ( $self->to->id == $self->task->owner->id and not $self->task->accepted ) {
        if ( $type eq 'text' ) {
            $msg .= "\n" .
                     _("Take a moment to accept or decline this task. ".
                       "Either way, it's just \na hop, click and a jump away.") .
                    "\n" . "-" x 71 . "\n\n";
        }
        elsif ( $type eq 'html' ) {
            $msg .= qq{<div style="margin-top: 1.5em; padding: 0.8em; border: 1px solid #E48511; background-color: #F8F1D3;">} .
                    qq{<p style="padding: 0; margin: 0;">} .
                    _("Take a moment to accept or decline this task. ".
                      "Either way, it's just") .
                    ' <a href="'.$self->task_url.'">'.
                    _("a hop, click and a jump away").
                    "</a>.</p></div>";
        }
    }
    return $msg;
}

=head2 html_body

The HTML version of the body of the message contains the same
information as L</body> does.

=cut

sub html_body {
    my $self = shift;
    my $msg  = $self->_accept_or_decline('html');
    return $msg;
}

sub _task_description {
    my $self = shift;
    return length $self->task->description
                ? $self->task->description . "\n\n\n"
                : '';
}

=head2 footer

Print reply info and the footer

=cut

sub footer {
    my $self = shift;
    my $footer  = $self->_task_description;
       $footer .= $self->task->summary . "  # " . $self->task_url."\n";

    my $policy  = $self->SUPER::footer();
       $policy =~ s/^--\s*$//m;

       $footer .= "\n-- \n" . $self->_reply_info . $policy;
    return $footer;
}

=head2 html_footer

Returns the reply information and HTML footer.

=cut

sub html_footer {
    my $self = shift;
    my $footer = <<"    END";
<div>
  @{[ $self->_task_description ? $self->task->formatted_description : '' ]}
  <p>&#8594; Go to <a href="@{[$self->task_url]}">@{[Jifty->web->escape($self->task->summary)]}</a> (#@{[$self->task->record_locator]})</p>
</div>
    END
    $footer .= '<p style="color: #777; font-size: 0.9em;">'.$self->_reply_info.'</p>'
             . $self->SUPER::html_footer;
    return $footer;
}

sub _reply_info {
    my $self = shift;
    my $reply_details;

    if ($self->task->group->name) {
        $reply_details = <<ENDME;
If you reply to this message, your reply will be added to the task's notes
and Hiveminder will notify the other members of @{[$self->task->group->name]}.
ENDME
    } else {
        $reply_details = <<ENDME;
If you reply to this message, your reply will be added to the task's notes
and Hiveminder will notify the other folks involved with this task.
ENDME
    }

    return $reply_details;
}

=head2 task_url

Returns a url for this task, appropriate to the user being notified
(whoever is currently in "to")

=cut

sub task_url {
    my $self = shift;
    my $user =$self->to;
    my $url;

    if (defined $user->access_level) {
        $url = $user->access_level eq 'nonuser'
            ?  $self->magic_letme_token_for("update_task", id => $self->task->id)
            : $self->task->url;
    } else {
        # The current_user is a nonuser, but the to user is a guest/member;
        # nonusers don't have permissions to see that user's information.
        # This happens for nonusers accepting or declining tasks.
        # Since nonusers never send mail to other nonusers, this should be a
        # pretty safe workaround.

        $url = $self->task->url;
    }

    return $url;

}

# Not supposed to be needed!
sub _note {
    return "Hiveminder wants you to know:\n\n";
}

=head2 set_headers MESSAGE

Takes a given L<Email::Simple> object C<MESSAGE>, and adds a
C<X-Hiveminder-Group> header, if necessary.

=cut

sub set_headers {
    my $self = shift;
    my ($message) = @_;

    $self->SUPER::set_headers($message);
    $self->task->set_headers_on($message);
}

1;
