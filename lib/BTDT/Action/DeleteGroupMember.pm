use warnings;
use strict;


=head1 NAME

BTDT::Action::DeleteGroupMember

=cut

package BTDT::Action::DeleteGroupMember;

use base qw/Jifty::Action::Record::Delete/;
use BTDT::Action::ArgumentCacheMixin;

=head2 record_class

This deletes L<BTDT::Model::GroupMember> objects.

=cut

sub record_class { 'BTDT::Model::GroupMember'  }

=head2 report_success

Add a message when we successfully delete a group membership

=cut

sub report_success {
    my $self = shift;
    my $group = shift;

    if (defined $group) {
        $self->result->message("Left the group '$group'");
    }
    else {
        $self->result->message("Left the group");
    }
}

=head2 take_action

Invalidate the argument cache

=cut

sub take_action {
    my $self = shift;
    my $group = $self->record->group->name;
    $self->SUPER::take_action or return;
    BTDT::Action::ArgumentCacheMixin->invalidate_cache($self->record);
    $self->report_success($group) if not $self->result->failure;
    return 1;
}

1;

