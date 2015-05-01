use warnings;
use strict;

=head1 NAME

BTDT::Model::GroupMember

=head1 DESCRIPTION

Group members have an actor_id, a group_id, and a role (guest, member
or organizer).

=cut

package BTDT::Model::GroupMember;
use BTDT::Model::Group;
use BTDT::Model::User;
use base  qw( BTDT::Record );

use Jifty::DBI::Schema;
use Jifty::Record schema {
    column actor_id =>
        refers_to BTDT::Model::User,
        label is 'User',
        is immutable;

    # This *must* be immutable to avoid people injecting themselves into
    # other groups by frobbing their GroupMember entries on other groups.
    column group_id =>
        refers_to BTDT::Model::Group,
        label is 'Group',
        is immutable;

    column role     =>
        type is 'varchar',
        default is 'member',
        label is 'Role',
        since '0.2.0',
        valid_values are qw(guest member organizer);
};

use Jifty::RightsFrom column => 'group';

=head2 current_user_can

The user who is a member can always delete this entry and leave the
group, *unless* they're the only administrator.

Otherwise, defer to checking rights on the group.

=cut

sub current_user_can {
    my $self = shift;
    my $right = shift;

    # I can remove myself from a group
    return 1
      if    $right eq 'delete'
         && $self->__value('actor_id') == $self->current_user->id
         && (!$self->group->current_user_can('manage') || $self->group->organizers->count > 1);

    return $self->SUPER::current_user_can($right, @_);
}

=head2 after_create

Purge the user's cache of group memberships.

=cut

sub after_create {
    my $self = shift;
    my ($id) = @_;
    return unless $$id;

    $self->load_by_cols( id => $$id );
    $self->actor->purge_cached_group_ids;
    return 1;
}

=head2 after_delete

Purge the user's cache of group memberships.

=cut

sub after_delete {
    my $self = shift;
    $self->actor->purge_cached_group_ids;
    return 1;
}

1;
