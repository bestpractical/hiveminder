use warnings;
use strict;

=head1 NAME

BTDT::Model::Group

=head1 DESCRIPTION

Describes a group of L<BTDT::Model::User>s.

=cut

package BTDT::Model::Group;
use base qw( BTDT::Record );
use Jifty::DBI::Schema;
use BTDT::Model::GroupMemberCollection;
use BTDT::Model::PublishedAddressCollection;

use Jifty::Record schema {

column
    description => type is 'varchar',
    label is 'Description';

column
    name => type is 'varchar',
    label is 'Name', is distinct, is mandatory;

column
    broadcast_comments => is boolean,
    label is 'Send task comments to all group members?',
    hints is 'If unchecked, comments on tasks with owners are sent to only the owner and requestor',
    default is 't', since '0.2.91';

column
    never_email => is boolean,
    label is 'Never send task email to group members?',
    hints is 'If checked, no mail will ever be sent to group members about task changes',
    default is 'f', since '0.3.1';

column
    group_members => label is 'Members',
    refers_to BTDT::Model::GroupMemberCollection by 'group_id';

column
    published_addresses => label is 'Published addresses',
    refers_to BTDT::Model::PublishedAddressCollection by 'group_id';

column projects =>
    references BTDT::ProjectCollection by 'group_id';

column milestones =>
    references BTDT::MilestoneCollection by 'group_id';

    };

=head2 create

Create this group. Takes a param hash of "name" and "description". By
default, the user creating this group will become a group organizer.

=cut

sub create {
    my $self = shift;
    my ( $val, $msg ) = $self->SUPER::create(@_);
    unless ($val) {
        return ( $val, $msg );
    }
    # We have to be the superuser to add the user, since he's not yet
    # a member
    my $self_as_superuser = BTDT::Model::Group->new(current_user => BTDT::CurrentUser->superuser);
    $self_as_superuser->load($self->id);
    $self_as_superuser->_add_member( $self->current_user, "organizer" );

    return ( $val, $msg );
}

=head2 add_member USER ROLE

Adds USER to the group, as a ROLE for this group

XXX TODO: this should take named parameters.

=cut

sub add_member {
    my $self = shift;

    return unless $self->current_user_can('update');
    $self->_add_member(@_);
}

=head2 _add_member

A private function that performs the bulk of the work that add_member does
but doesn't check acls. We use this when creating the first member of a group.

=cut

sub _add_member {
    my $self  = shift;
    my $actor = shift;
    my $role  = shift;

    if ( $self->has_member($actor) ) {
        $self->log->warn("$actor already a member of $self");
    } else {
        my $member = BTDT::Model::GroupMember->new();
        $member->create(
            actor_id => $actor->id,
            group_id => $self->id,
            role     => $role,
        );
    }
}

=head2 has_member USER [PERMISSION]

Returns a boolean indicating whether or not the group has the member USER with a ROLE
that's at least ROLE

=cut

sub has_member {
    my $self = shift;
    my $user = shift;
    my $role = shift || 'guest';

    my $member = BTDT::Model::GroupMember->new();
    my ( $id, $msg ) = $member->load_by_cols(
        actor_id => $user->id,
        group_id => $self->id
    );

    if ($id) {
        my $got_perm = $member->role;

        # XXX TODO FIXME abstract out to a general role comparison"
        # function -- not sure where in the hierarchy it should fall
        my %levels = ( guest => 1, member => 2, organizer => 3 );
        return $levels{$got_perm} >= $levels{$role};
    } else {
        return;
    }
}

=head2 has_invitation USER [PERMISSION]

Returns a boolean indicating whether or not USER  has an outstanding invitation
to the group with role at least PERMISSION (defaults to 'see').

=cut

sub has_invitation {
    my $self = shift;
    my $user = shift;
    my $role = shift || 'guest';

    my $member = BTDT::Model::GroupInvitation->new(
        current_user => BTDT::CurrentUser->superuser );
    my ( $id, $msg ) = $member->load_by_cols(
        recipient_id => $user->id,
        group_id     => $self->id
    );

    if ( $id && !$member->cancelled ) {
        my $got_perm = $member->role;

        # XXX TODO FIXME abstract out to a general "role comparison"
        # function -- not sure where in the hierarchy it should fall
        my %levels = ( guest => 1, member => 2, organizer => 3 );
        return $levels{$got_perm} >= $levels{$role};
    } else {
        return;
    }
}

=head2 current_user_can

Ideally, we should be implementing:

Create: Yes.
See: Is it a group that I'm a viewer or memeber  of or that's public?
Edit, Manage: Is it a group that I'm an administrator of?


=cut

sub current_user_can {
    my $self  = shift;
    my $right = shift;

    # Do this here, to avoid deep recursion
    return 1 if ( $self->current_user->is_superuser );

    my $role = $self->current_user_role || '';

    if (   $right eq 'read_tasks'
        || $right eq 'read' )
    {
        if ( $role =~ /^(?:guest|member|organizer)$/ ) {
            return 1;
        }
    } elsif ( $right eq 'update_tasks'
        || $right eq 'create_tasks' )
    {
        if ( $role =~ /^(?:member|organizer)$/ ) { return 1 }
    }

# If the current user is a group organizer, they have the right to manage the group.
    elsif (
           $right eq 'manage'
        || $right eq 'update'

        )
    {
        if ( $role eq 'organizer' ) {
            return 1;
        }
    }
    # To delete, the user must be an organizer and the following
    # criteria for the group must be met:
    #
    #   * No published addresses
    #   * No outstanding invitations
    #   * No tasks
    #   * No other members besides the current user
    #
    elsif ( $right eq 'delete' ) {
        if (     $role eq 'organizer'
             and not $self->group_members->count > 1
             and not $self->published_addresses->count > 0
             and not $self->invitations->count > 0 )
        {
            my $group_tasks = BTDT::Model::TaskCollection->new;
            $group_tasks->group( $self->id );

            return 1 if not $group_tasks->count > 0;
        }
    }

    if (    $right eq 'create'
        and $self->current_user->user_object
        and $self->current_user->user_object->access_level ne 'nonuser' )
    {
        return 1;
    }

    elsif ( $right eq 'read'
        and $self->has_invitation( $self->current_user ) )
    {
        return 1;
    }

    return $self->SUPER::current_user_can($right);
}

=head2 before_delete

Deletes any remaining members before actually deleting the group.
This keeps foreign key contraints happy.

=cut

sub before_delete {
    my $self = shift;

    # Set the temporary user to the superuser to ease deletion
    my $members = $self->as_superuser->group_members;
    while ( my $member = $members->next ) {
        $member->delete;
    }

    return 1;
}

=head2 members

Returns a L<BTDT::Model::UserCollection> of the members of the group.

=cut

sub members {
    my $self = shift;

    my $users = BTDT::Model::UserCollection->new(
        current_user => $self->current_user );
    $users->in_group( $self->id );
    return $users;
}

=head2 guests

Returns a L<BTDT::Model::GroupMemberCollection> of the guests of the group.

=cut

sub guests {
    my $self = shift;

    my $guests = BTDT::Model::GroupMemberCollection->new;
    $guests->limit( column => 'group_id', value => $self->id );
    $guests->limit( column => 'role',     value => 'guest' );
    return $guests;
}

=head2 organizers

Returns a L<BTDT::Model::GroupMemberCollection> of all organizers
of the group.

=cut

# TODO: this should really return a BTDT::Model::UserCollection, but I don't understand
# Jifty::DBI->limit well enough to modify the UserCollection code

sub organizers {
    my $self = shift;

    my $organizers = BTDT::Model::GroupMemberCollection->new;
    $organizers->limit( column => 'group_id', value => $self->id );
    $organizers->limit( column => 'role',     value => 'organizer' );
    return $organizers;
}

=head2 possible_task_owners

Returns a L<BTDT::Model::UserCollection> of the possible task owners for a task in this group.
Currently this includes members of the group and folks invited to the group.

=cut

sub possible_task_owners {
    my $self = shift;

    my $users = BTDT::Model::UserCollection->new(
        current_user => $self->current_user );
    $users->in_group_or_invited( $self->id );
    $users->order_by( column => 'name', order => 'asc' );
    return $users;
}

=head2 current_user_role

Returns the current user's role for this group.

=cut

sub current_user_role {
    my $self = shift;

    my $member = BTDT::Model::GroupMember->new(
        current_user => BTDT::CurrentUser->superuser );

    $member->load_by_cols(
        group_id => $self->id,
        actor_id => $self->current_user->id
    );
    return ( $member->role );

}

=head2 invite PARAMHASH

Invite another user to join this group.

Takes a PARAMHASH containing

=over


=item recipient

Recipient is a scalar email address for someone the current user is inviting to this group

=item role

A string role. Could be "member" "guest" or "organizer"

=back

=cut

sub invite {
    my $self = shift;
    my %args = (
        recipient => undef,
        role      => 'member',
        @_
    );

    unless ( $self->current_user_can('manage') ) {
        return ( undef, "You can't manage this group." );
    }

    my $recipient = BTDT::Model::User->new(
        current_user => BTDT::CurrentUser->superuser );
    $recipient->load_by_cols( email => $args{recipient} );

# if there's no user id, it means there is no user and we need to create a new one
    unless ( $recipient->id ) {
        my ( $id, $msg ) = $recipient->create(
            email           => $args{'recipient'},
            email_confirmed => 1
            ,    # assume that users being invited have good email addresses
            beta_features => 0,
            access_level  => 'nonuser',
            invited_by    => $self->current_user->id,
        );
        unless ($id) { return ( undef, $msg ) }
    }
    if ( $self->has_member($recipient) ) {
        return ( undef,
                  "No need to send an invitation. "
                . $recipient->name
                . " is already in "
                . $self->name );
    }
    if ( $self->has_invitation($recipient) ) {
        return ( undef,
                  $recipient->name
                . " seems to have been invited to "
                . $self->name
                . " already." );
    }

    my $invite = BTDT::Model::GroupInvitation->new(
        current_user => BTDT::CurrentUser->superuser );
    my ( $id, $msg ) = $invite->create(
        group_id     => $self->id,
        recipient_id => $recipient->id,
        sender_id    => $self->current_user->id,
        role         => $args{'role'}
    );

    unless ( $invite->id ) {
        $self->log->error( "invitation create failed: ", $msg );
        return ( undef,
            q{Something bad happened when we tried to create the invitation. }
                . q{We've logged the error and will try to get it fixed up as quickly as we can.}
        );
    }

    BTDT::Notification::GroupInvitation->new( invite => $invite, )->send;

    return ( $id, $msg );

}

=head2 invitations

Returns a L<BTDT::Model::GroupInvitationCollection> of invitations
that are outstanding in this group.

=cut

sub invitations {
    my $self    = shift;
    my $invites = BTDT::Model::GroupInvitationCollection->new(
        current_user => $self->current_user );
    $invites->limit( column => "group_id",  value => $self->id );
    $invites->limit( column => "cancelled", value => 0 );
    return $invites;
}

=head2 name

Either return the current group's name if the user can see it, otherwise return a "you can't see it" message

=cut

sub name {
    my $self = shift;
    my $name =  $self->_value('name');
    if (!$name and !$self->current_user_can('read')) {
            return q{(A group you can't see)};
        }
    return $name;
}

=head2 canonicalize_description

Descriptions get canonicalized like names. spacing gets stripped

=cut

sub canonicalize_description { return shift->canonicalize_name(@_)}

=head2 validate_name

Group names must not be all numbers

=cut

sub validate_name {
    my $self = shift;
    my $name = shift;

    return (0, "Your group name cannot be all numbers.")
        if $name =~ /^\d+$/;

    return 1;
}

=head2 has_feature

Returns whether the current group has a given feature.

=cut

sub has_feature {
    my $self = shift;
    my $feature = shift;

    return 0 if not $self->id;

    if ( $feature eq 'Projects' ) {
        return 1 if $self->name eq 'Best Practical'; # XXX TODO ACL
        return 1 if $self->name eq 'Projects demo';
    }
    return 1 if $self->current_user->has_feature($feature);

    return 0;
}

=head2 transactions

Returns a TaskTransactionCollection for all tasks in this group

=cut

sub transactions {
    my $self = shift;

    my $txns = BTDT::Model::TaskTransactionCollection->new;

    $txns->limit(
        column => 'group_id',
        value  => $self->id,
    );

    return $txns;
}

=head2 cached_group_members

Returns a flat array of user id, name, email for all L</possible_task_owners>
in a group.  Caches the result for 5min.  Used by various Mason components.

=cut

sub cached_group_members {
    my $self = shift;
    my @members = @{ Jifty->web->mason->cache->get("groupmembers-" . $self->id) || [] };
    unless (@members) {
        my $owners = $self->possible_task_owners;
        @members = map { $_->id, $_->name, $_->email } @$owners;
        Jifty->web->mason->cache->set(
            "groupmembers-" . $self->id => \@members,
            '5 min'
        );  
    }
    return @members;
}

1;
