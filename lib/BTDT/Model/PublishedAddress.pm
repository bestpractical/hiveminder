package BTDT::Model::PublishedAddress;
use warnings;
use strict;

=head1 NAME

BTDT::Model::PublishedAddress

=head1 DESCRIPTION

An (email) address that feeds into the system.  PublishedAddresses
have an address, a L<BTDT::Action> they should execute, and either a
L<BTDT::Model::User> or a L<BTDT::Model::Group> that the address is
tied to.

=cut

use base  qw( BTDT::Record );
use Jifty::DBI::Schema;

use Jifty::Record schema {

    column address  =>
        type is 'varchar',
        label is 'Email address';

    column auto_attributes =>
        type is 'text',
        since is '0.2.39',
        label is 'Defaults',
        hints is 'Use braindump syntax to set defaults for everything that comes to this address. <br/>(ex [due: in 3 days] [priority: highest] [money])';

    column action   =>
        type is 'varchar',
        label is 'Action',
        default is 'CreateTask',
        is private,
        is immutable;

    column user_id  =>
        refers_to BTDT::Model::User,
        label is 'User',
        is immutable;

    column group_id =>
        refers_to BTDT::Model::Group,
        label is 'Group',
        is immutable;

    column auto_accept =>
        is boolean,
        label is 'Auto-accept',
        hints is 'Should Hiveminder automatically accept new tasks when they are created?',
        since '0.2.84';

};


=head2 since

This table first appeared in 0.2.12

=cut

sub since { '0.2.12' }

=head2 before_create

Generate a random address unless the user is pro and provided an address. Ensure
that we have only user_id or group_id.

=cut

sub before_create {
    my $self = shift;
    my $args = shift;

    # XXX: staff only for now
    my $pro = $self->current_user->id
              #&& $self->current_user->user_object->pro_account;
              && $self->current_user->user_object->access_level eq 'staff';

    delete $args->{address} unless $pro;

    # generate a random address
    if (!defined($args->{address}) || $args->{address} eq '') {
        $args->{address} = $self->generate_random_address;

        # unable to create an address due to uniqueness restrictions
        return 0 if !defined($args->{address});
    }

    # you can only create addresses for yourself
    $args->{user_id} = $self->current_user->id
        unless $self->current_user->is_superuser;

    # group takes precedence
    delete $args->{user_id} if $args->{user_id} && $args->{group_id};

    # XXX: check that we're in the group

    return 1;
}

=head2 generate_random_address

Generates a random email address. It will try up to twenty times to create
a unique address.

Will return C<undef> if no random address could be generated.

=cut

sub generate_random_address {
    my $generated;

    for (1..20) {
        my $address = String::Koremutake->new->integer_to_koremutake(int rand(128 ** 4));

        my $try = __PACKAGE__->new(current_user => BTDT::CurrentUser->superuser);
        $try->load_by_cols(address => $address);
        next if $try->id;

        return $address;
    }

    return undef;
}

=head2 canonicalize_address

Make sure that we lowercase the email address and strip the domain.

XXX: we also want to strip out "+text", I think.

=cut

sub canonicalize_address {
    my $self    = shift;

    my $address = lc shift;
    $address =~ s/\@.*//;

    return $address;
}

=head2 load_by_cols

Canonicalize the address, since we'll have C<@my.hiveminder.com> in BTDT::Action::EmailDispatch.

=cut

sub load_by_cols {
    my $self = shift;
    my %args = @_;

    $args{address} = $self->canonicalize_address($args{address})
        if exists $args{address};

    $self->SUPER::load_by_cols(%args);
}

=head2 current_user_can RIGHT [, ATTRIBUTES]

Seeing and editing published addresses is based on your rights on the
user or group that the addresses are for. Some finagling is necessary
because, if this is a create call, this object doesn't have a
C<user_id> or C<group_id> yet, so we must rely on the value in the
I<ATTRIBUTES> passed in.

=cut

sub current_user_can {
    my $self  = shift;
    my $right = shift;
    my %args  = @_;

    # not logged in? sorry!
    my $me = $self->current_user
        or return 0;

    # XXX: staff only for now
    my $pro = #$me->user_object->pro_account;
              $me->user_object->access_level eq 'staff';

    return 1 if $me->is_superuser;

    my $owner = $right eq 'create' ? $args{user_id}  : $self->__value('user_id');
    my $group = $right eq 'create' ? $args{group_id} : $self->__value('group_id');

    # upgrade to real user
    if ($owner && !ref($owner)) {
        my $id = $owner;
        $owner = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
        $owner->load($id);
    }

    # upgrade to real group
    if ($group && !ref($group)) {
        my $id = $group;
        $group = BTDT::Model::Group->new(current_user => BTDT::CurrentUser->superuser);
        $group->load($id);
    }

    # Owners and group members can read addresses
    if ( $right eq 'read' ) {
        return 1 if $owner and $owner->id == $me->id;
        return 1 if $group and $group->has_member($me->user_object);
    }

    # Users can create addresses owned by themselves
    # Group organizers can create group addresses
    elsif ( $right eq 'create' ) {
        if ( $group ) {
            return 1 if $group->has_member($me->user_object, 'organizer');
        }
        else {
            return 1 if $owner and $owner->id == $me->id;
        }
    }

    # Owners and group organizers can delete
    elsif ( $right eq 'delete' ) {
        if ( $group ) {
            return 1 if $group and $group->has_member($me->user_object, 'organizer');
        }
        else {
            return 1 if $owner and $owner->id == $me->id;
        }
    }

    # Owners and group organizers can update addresses
    elsif ($right eq 'update') {
        if (    ( $group and $group->has_member($me->user_object, 'organizer') )
             or ( $owner and $owner->id == $me->id ) )
        {
            # yes, we can update this model
            return 1 if not defined $args{column};

            # you can update these
            return 1 if $args{column} eq 'auto_attributes'
                     || $args{column} eq 'auto_accept';

            # only pro can update address
            return 1 if $args{column} eq 'address' && $pro;
        }
    }

    $self->SUPER::current_user_can($right, %args);
}

=head2 validate_auto_attributes VALUE

auto_attributes must be parsable as braindump syntax, with no leftovers.

=cut

sub validate_auto_attributes {
    my $self = shift;

    return unless @_;
    my $auto_attributes = shift;

    my $parsed_summary = BTDT::Model::Task->parse_summary($auto_attributes);
    if ($parsed_summary->{explicit}{summary}) {
        return (0,"'$parsed_summary->{explicit}{summary}' does not appear to be Braindump syntax");
    } else {
        return 1;
    }
}

=head2 validate_address VALUE

Addresses must be unique.

=cut

sub validate_address {
    my $self = shift;
    my $address = shift;

    my $check = BTDT::Model::PublishedAddress->new(current_user => BTDT::CurrentUser->superuser);
    $check->load_by_cols(address => $address);

    if ($check->id && $check->id != $self->id) {
        return (0, "That address is already taken");
    }

    return 1;
}

1;
