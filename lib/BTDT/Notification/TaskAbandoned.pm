use warnings;
use strict;

package BTDT::Notification::TaskAbandoned;
use base qw/BTDT::TaskNotification/;

=head1 NAME

BTDT::Notification::TaskAbandoned - Notification that a task has been created

=head1 ARGUMENTS

C<task>

=head2 setup

Set it up.

=cut

sub setup {
    my $self = shift;
    $self->SUPER::setup(@_);
    $self->subject(_("Abandoned: %1", $self->subject));
}


sub _note { my $self = shift;
    return "@{[$self->actor->name]} <@{[$self->actor->email]}> has given up a task:";
}


1;

