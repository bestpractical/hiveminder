use warnings;
use strict;

package BTDT::Notification::TaskCompleted;
use base qw/BTDT::TaskNotification/;

=head1 NAME

BTDT::Notification::TaskCompleted - Notification that a task has been completed

=head1 ARGUMENTS

C<task>

=head2 setup

Set it up.

=cut

sub setup {
    my $self = shift;
    $self->SUPER::setup(@_);
    $self->subject(_("Done: %1 (#%2)", $self->task->summary, $self->task->record_locator));
}

sub _note {
    my $self = shift;
    return "@{[$self->actor->name]} <@{[$self->actor->email]}> has completed a task:";
}

# We don't want to show accept/decline when a task is complete
sub _accept_or_decline { '' }

1;

