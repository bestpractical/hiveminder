package BTDT::RTM::Auth;

use strict;
use warnings;

use base 'BTDT::RTM';

=head1 NAME

BTDT::RTM::Auth - Authentication methods

=head1 METHODS

=head2 method_getFrob

Returns a unique hex frob, which is simply a session-id.

=cut

sub method_getFrob {
    my $class = shift;

    my $frob_sess = Jifty::Web::Session->new;
    $frob_sess->create;
    $frob_sess->set( rtm => 1 );

    $class->send_ok(
        frob => $frob_sess->id,
    );
}

=head2 method_getToken

From a frob which has been authenticated, unpack the C<auth_token>,
which is simply an authenticated session-id.

=cut

sub method_getToken {
    my $class = shift;

    my $frob = $class->params->{'frob'};
    $class->send_error( 101 => "No frob given" )
        unless $frob;

    my $frob_sess = Jifty::Web::Session->new;
    $frob_sess->load($frob);
    $class->send_error( 101 => "Invalid frob" )
        unless $frob_sess->id eq $frob;
    $class->send_error( 101 => "Invalid frob" )
        unless $frob_sess->get("rtm");
    $class->send_error( 101 => "Frob wasn't logged in" )
        unless $frob_sess->get("api_token");

    my $token_sess = Jifty::Web::Session->new;
    $token_sess->load( $frob_sess->get("api_token") );
    $class->send_error( 101 => "Internal frob mismatch?" )
        unless $frob_sess->get("api_token") eq $token_sess->id;
    $class->send_error( 101 => "Token is no longer logged in" )
        unless $token_sess->get("user_id");

    $frob_sess->remove_all;

    Jifty->web->temporary_current_user(
        BTDT::CurrentUser->new( id => $token_sess->get("user_id") ) );

    my $user = $class->user;
    $class->send_ok(
        auth => {
            token => $token_sess->id,
            perms => "delete",
            user  => {
                id       => $user->id,
                username => $user->email,
                fullname => $user->name,
            }
        }
    );
}

=head2 method_checkToken

Returns information about the current user if they are logged in.

=cut

sub method_checkToken {
    my $class = shift;
    $class->require_user;

    my $user = $class->user;
    $class->send_ok(
        auth => {
            token => $class->token,
            perms => "delete",
            user  => {
                id       => $user->id,
                username => $user->email,
                fullname => $user->name,
            }
        }
    );
}

1;
