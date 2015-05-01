use warnings;
use strict;

package BTDT::Notification::TaskAccepted;
use base qw/BTDT::TaskNotification/;

=head1 NAME

BTDT::Notification::TaskAccepted - Notification that a task has been created

=head1 ARGUMENTS

C<task>

=head2 setup

Set it up.

=cut

sub setup {
    my $self = shift;
    $self->SUPER::setup(@_);
    $self->subject(_("Accepted: %1 (#%2)", $self->subject, $self->task->record_locator));
}


sub _note { my $self = shift;
    return "@{[$self->actor->name]} <@{[$self->actor->email]}> has accepted a task:";
}


1;

