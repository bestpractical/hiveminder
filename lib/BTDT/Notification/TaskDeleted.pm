use warnings;
use strict;

package BTDT::Notification::TaskDeleted;
use base qw/BTDT::TaskNotification/;

=head1 NAME

BTDT::Notification::TaskDeleted - Notification that a task has been deleted.

=head1 ARGUMENTS

C<task>

=head2 setup

Set it up.

=cut

sub setup {
    my $self = shift;
    $self->SUPER::setup(@_);
    $self->subject(_("Deleted: %1 (#%2)", $self->subject, $self->task->record_locator));
}


sub _note { my $self = shift;
    return "@{[$self->actor->name]} <@{[$self->actor->email]}> deleted a task:";
}


1;

