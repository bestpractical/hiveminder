use strict;
use warnings;

=head1 NAME

BTDT::Model::UserIM

=head1 DESCRIPTION

Represents a relation between a user and some kind of IM account.

=cut

package BTDT::Model::UserIM;
use Jifty::DBI::Schema;

use BTDT::Record schema {

column user_id =>
  is mandatory,
  refers_to BTDT::Model::User,
  label is 'User',
  is protected;

column screenname =>
  label is 'Screenname',
  default is '',
  type is 'varchar';

column protocol =>
  label is 'Protocol',
  default is 'AIM',
  valid_values are [qw(AIM Web Jabber Twitter)];

column auth_token =>
  type is 'varchar',
  default is '',
  render_as 'text',
  label is 'Authentication token',
  is protected;

column confirmed =>
  is boolean,
  label is 'Account confirmed?',
  is protected;

column created_on =>
  type is 'date',
  filters are 'Jifty::DBI::Filter::Date',
  label is 'Created on',
  since '0.2.69',
  default is defer { DateTime->now },
  is protected;

};

=head2 since

This first appeared in 0.2.41

=cut

sub since { '0.2.41' }

=head2 create PARAMHASH

Create a new user IM. Makes sure that the screenname is canonicalized according
to the desired protocol.

=cut

sub create {
    my $self = shift;
    my %args = (confirmed => 0, @_);

    if (!defined($args{auth_token})) {
        # make sure we don't generate two identical tokens

        for (1..20) {
            $args{auth_token} = String::Koremutake->new->integer_to_koremutake(int rand(128 ** 4));

            my $userim = BTDT::Model::UserIM->new(current_user => BTDT::CurrentUser->superuser);
            $userim->load_by_cols(auth_token => $args{auth_token});
            next if $userim->id;
            last;
        }

        unless ($args{auth_token}) {
            return (undef, "Tried to create a token 20 times and failed. Something bad is going on");
        }
    }

    $self->SUPER::create(%args);
}

=head2 current_user_can RIGHT [, ATTRIBUTES]

Seeing and editing IM addresses is based on your rights on the
user or group that the addresses are for.  Some finagling is necessary
because, if this is a create call, this object doesn't have a
C<user_id> or C<group_id> yet, so we must rely on the value in the
I<ATTRIBUTES> passed in.

=cut

sub current_user_can {
    my $self = shift;
    my $right = shift;
    my %args = @_;

    my $user;




    if ( UNIVERSAL::isa($args{user_id}, "BTDT::Model::User") ) {
        $user = $args{user_id};
    } elsif ( $args{user_id} || $self->__value('user_id') ) {
        $user = BTDT::Model::User->new();
        $user->load_by_cols( id => $args{user_id} || $self->__value('user_id') );
    } else {
        return 0;
    }


    if ($user->id eq $self->current_user->id) {
        # If it's the current'user's IM account, they can see it.
        if ($right eq 'read') { return 1}
        # the current user can create their own IM accounts
        if ($right eq 'create') { return 1}
        if ($right eq 'delete') { return 1}
    }

    return $self->SUPER::current_user_can($right, %args);
}

1;

