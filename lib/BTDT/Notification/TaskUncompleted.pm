use warnings;
use strict;

package BTDT::Notification::TaskUncompleted;
use base qw/BTDT::TaskNotification/;

=head1 NAME

BTDT::Notification::TaskUncompleted - Notification that a task has not been completed

=head1 ARGUMENTS

C<task>

=head2 setup

Set it up.

=cut

sub setup {
    my $self = shift;
    $self->SUPER::setup(@_);
    $self->subject(_("Incomplete: %1", $self->subject));
}


sub _note { my $self = shift;
    return "@{[$self->actor->name]} <@{[$self->actor->email]}> has marked a task as incomplete:";
}


1;

