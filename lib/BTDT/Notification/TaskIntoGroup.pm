use warnings;
use strict;

package BTDT::Notification::TaskIntoGroup;
use base qw/BTDT::TaskNotification/;

=head1 NAME

BTDT::Notification::TaskIntoGroup - Notification that a task has been put into a group

=head1 ARGUMENTS

C<task>

=head2 setup

Set it up.

=cut

sub setup {
    my $self = shift;
    $self->SUPER::setup(@_);
    $self->subject(_("To group: %1 (#%2)",
                     $self->subject, $self->task->record_locator));
}


sub _note {
    my $self = shift;
    my $groupid = $self->change->new_value;
    my $group = BTDT::Model::Group->new(
        current_user => BTDT::CurrentUser->new(id => $self->to->id)
    );
    $group->load($groupid);
    my $groupname = $group->name;
    return "@{[$self->actor->name]} <@{[$self->actor->email]}> has moved a task into $groupname";
}


1;

