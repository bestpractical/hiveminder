use warnings;
use strict;


package BTDT::CurrentUser;

use base qw(Jifty::CurrentUser);

=head2 new PARAMHASH

Instantiate a new current user object, loading the user by paramhash:

   my $task = BTDT::Model::Task->new( BTDT::CurrentUser->new(email => 'system@localhost'));

if you give the param
    _bootstrap => 1

your object will be marked as a 'bootstrap' user.
You can use that to do an endrun around acls

=cut

sub _init {
    my $self = shift;
    my %args = (@_);

    if (delete $args{'_superuser'} ) {
        $self->is_superuser(1);
    }
    if (delete $args{'_bootstrap'} ) {
        $self->is_bootstrap_user(1);
    }
    $self->SUPER::_init(%args);
}


{

my %singleton_users = ();
sub _singleton_user {
    my ($class, $name, %args) = @_;
    # on test bootstrap, nobody is loaded (unsucessfully), so we need to verify the cache
    if (!$singleton_users{$name}) {
        my $object = $class->new( %args );
        return $object unless defined $object->id;
        $singleton_users{$name} = $object;
    }
    return $singleton_users{$name};
}

}

=head2 nobody

Returns the "nobody" current user, whose email address is C<nobody>.
Before DB version 0.2.33, nobody's email address was C<nobody@localhost>.

=cut

sub nobody {
  my $class = shift;
  return $class->_singleton_user( 'nobody', email => 'nobody' );
}

=head2 superuser

Returns the "superuser" current user, whose email address is C<superuser@localhost>.

=cut

sub superuser {
  my $class = shift;
  return $class->_singleton_user( 'superuser', email => 'superuser@localhost', _superuser => 1 );
}

=head2 access_level

Returns the current user's access_level. (From the user_object).
If there's no user_object, returns undef.

=cut

sub access_level {
    my $self = shift;
    if ($self->user_object) {
            return ($self->user_object->access_level(@_));
    } else {
        return undef;
    }
}

=head2 is_staff

Is this current user a staff member?

=cut

sub is_staff {
    my $self = shift;
    ($self->access_level || '') eq 'staff';
}

=head2 pro_account

Returns the current user's pro_account. (From the user_object).
If there's no user_object, returns undef.

=cut

sub pro_account {
    my $self = shift;
    if ($self->user_object) {
            return ($self->user_object->pro_account(@_));
    } else {
        return undef;
    }
}

=head2 has_feature

Returns whether the current user has a given feature. Staff always have access
to features.  Anonymous users never have features.

=cut

sub has_feature {
    my $self = shift;
    my $feature = shift;

    return 0 if not $self->id;
    return 1 if $self->access_level eq 'staff';

    if ( $feature eq 'TimeTracking' ) {
        return 1 if $self->pro_account;
    }
    else {
        return Jifty->config->app('FeatureFlags')->{$feature};
    }

    return 0;
}

=head2 has_group_with_feature

Returns whether the current user is in a group with a given feature.

=cut

sub has_group_with_feature {
    my $self = shift;
    my $feature = shift;

    return 0 if not $self->id;

    my $groups = $self->user_object->groups;

    while ( my $group = $groups->next ) {
        return 1 if $group->has_feature($feature);
    }

    return 0;
}

=head2 hashed_password_is STRING, TOKEN

Returns true if the user's password, when hashed together with TOKEN,
is equal to STRING.

=cut

sub hashed_password_is {
    my ($self, $hashedpw, $token) = @_;

    return($self->user_object->hashed_password_is($hashedpw, $token));
}

=head2 username

For the purposes of printing in log files and such, the username is
the user's email.

=cut

sub username {
    my $self = shift;
    return $self->user_object ? $self->user_object->email : undef;
}

1;
