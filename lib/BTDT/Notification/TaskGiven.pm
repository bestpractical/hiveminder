use warnings;
use strict;

package BTDT::Notification::TaskGiven;
use base qw/BTDT::TaskNotification/;

=head1 NAME

BTDT::Notification::TaskGiven - Notification that a task has been given to someone

=head1 ARGUMENTS

C<task>

=head2 setup

Set it up. Currently we just use the default from the superclass.

=cut


=head2 send_one_message

Sets the subject conditionally depending on who we're sending mail
to, then sends the notification.

=cut

sub send_one_message {
    my $self = shift;

    my $subject = $self->subject;

    if ($self->change  && $self->to->id == $self->change->new_value) {
        $self->subject( _("For you: %1 (#%2)",
                          $self->subject, $self->task->record_locator) );
    } elsif ($self->change && ($self->change->new_value == BTDT::CurrentUser->nobody->id)) {
        $self->subject( _("Up for grabs: %1 (#%2)",
                          $self->subject, $self->task->record_locator) );
    } else {
        my $asker = BTDT::Model::User->new();
        $asker->load_by_cols(id =>  $self->change->new_value);
        $self->subject(  _("For %1: %2 (#%3)",
                           $asker->name, $self->subject, $self->task->record_locator) );
    }

    $self->SUPER::send_one_message;

    $self->subject($subject);  # ugh, hackish, but works.
}

sub _note {
    my $self = shift;
    if ($self->change && $self->to->id == $self->change->new_value) {
        # the version that goes to the new owner
        return "@{[$self->actor->name]} <@{[$self->actor->email]}> would like you to do something";
    }
    else {
    # the version that goes to non-owners who need to know
    my $asked = BTDT::Model::User->new();
    $asked->load_by_cols(id =>  $self->change->new_value);
    return "@{[$self->actor->name]} <@{[$self->actor->email]}> has asked @{[$asked->name]} <@{[$asked->email]}> to do something";
    }
}




1;

