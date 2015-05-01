use warnings;
use strict;

package BTDT::Notification::TaskCreated;
use base qw/BTDT::TaskNotification/;

=head1 NAME

BTDT::Notification::TaskCreated - Notification that a task has been created

=head1 ARGUMENTS

C<task>

=head2 setup

Set it up.

=cut

sub setup {
    my $self = shift;
    $self->SUPER::setup(@_);
    if ($self->task->owner_id == BTDT::CurrentUser->nobody->id) {
        $self->subject(_("Up for grabs: %1 (#%2)",
                         ($self->subject||''), $self->task->record_locator));
    } else {
        $self->subject(_("New task: %1 (#%2)",
                         ($self->subject||''), $self->task->record_locator));
    }
}


sub _note {
    my $self = shift;

    # belt-and-suspenders check
    if ($self->to->id == $self->task->owner->id) {
        # the version that goes to the task doer
        return "@{[$self->actor->name]} <@{[$self->actor->email]}> would like you to do something";
    } elsif ( $self->to) {
        # to group members who may need to grab this
        return  "@{[$self->actor->name]} <@{[$self->actor->email]}> created a task and put it up for grabs";
    } else {
        # the version that goes to non-owners who need to know
        return "@{[$self->actor->name]} <@{[$self->actor->email]}> created a task";
    }
}


1;

