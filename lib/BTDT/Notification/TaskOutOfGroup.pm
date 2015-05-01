use warnings;
use strict;

package BTDT::Notification::TaskOutOfGroup;
use base qw/BTDT::TaskNotification/;

=head1 NAME

BTDT::Notification::TaskOutOfGroup - Notification that a task has been taken out of a group

=head1 ARGUMENTS

C<task>

=head2 setup

Set it up.

=cut

sub setup {
    my $self = shift;
    $self->SUPER::setup(@_);
    $self->subject(_("From group: %1 (#%2)",
                     $self->subject, $self->task->record_locator));
}


sub _note { my $self = shift;
    return "@{[$self->actor->name]} <@{[$self->actor->email]}> has removed a task from the group XXX";
}


1;

