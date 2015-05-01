use warnings;
use strict;

=head1 NAME

BTDT::Model::GroupInvitation

=head1 DESCRIPTION

Describes an invitation of a user to a group.  Fields are group_id,
message, recipient_id, sender_id, role, and cancelled.

=cut

package BTDT::Model::GroupInvitation;
use base  qw( BTDT::Record );
use BTDT::Model::Group;
use BTDT::Model::User;


use Jifty::DBI::Schema;

use Jifty::Record schema {
column group_id =>
  refers_to BTDT::Model::Group,
  label is 'Group',
  is immutable;
column message =>
  type is 'text',
  label is 'Message',
  is immutable;
column recipient_id =>
  refers_to BTDT::Model::User,
  label is 'Recipient',
  is immutable;
column sender_id =>
  refers_to BTDT::Model::User,
  label is 'Sender',
  is immutable;
column role =>
  type is 'varchar',
  default is 'guest',
  label is 'Role',
  since '0.2.0',
  valid_values are qw(guest member organizer),
  is immutable;
column cancelled =>
  is boolean,
  label is 'Cancelled',
  since '0.2.26';
};

use Jifty::RightsFrom column => 'group';

=head2 current_user_can

The invited user can read or delete the invitation. Otherwise, fall
back on checking permissions for our group.

=cut

sub current_user_can {
    my $self = shift;
    my $right = shift;
    my %attrs = @_;

    # The recipient needs to be able to see the invitation, and to
    # delete it when they accept or reject it.
    return 1 if (   ($right eq 'delete' || $right eq 'read')
                    && $self->current_user->id == $self->__value('recipient_id'));

    return $self->SUPER::current_user_can($right, %attrs);
}

=head2 autogenerate_action

Don't autogenerate a Create action for this model; use the
InviteToGroup action instead.

=cut

sub autogenerate_action {
    my $class = shift;
    my $action = shift;
    return ($action ne "Create");
}

1;
