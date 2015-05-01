use warnings;
use strict;

package BTDT::Bootstrap;

use base qw/Jifty::Bootstrap/;

use BTDT::CurrentUser;
use BTDT::Model::User;

=head1 NAME

BTDT::Bootstrap

=cut

=head2 run

C<run> is the workhorse method for the Bootstrap class. This takes care of setting up
internal datastrutures and initializing things. In the case of BTDT, it creates a system
user.

=cut

sub run {

    my $bootstrap_currentuser = BTDT::CurrentUser->new( _bootstrap => '1' );

    my @users = (
        {
            email        => 'superuser@localhost',
            access_level => 'administrator',
        },
        {
            email        => 'nobody',
            access_level => 'guest',
            name         => 'Nobody',
        }
    );

    for my $user (@users) {
        my $u =
          BTDT::Model::User->new( current_user => $bootstrap_currentuser );
        my ( $id, $msg ) = $u->create(%$user);
        unless ( $u->id ) {
            Jifty->log->error("Couldn't create user with email $user->{email}: $msg");
        }
    }

}

1;
