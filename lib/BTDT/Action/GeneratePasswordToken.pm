use warnings;
use strict;

=head1 NAME

BTDT::Action::GeneratePasswordToken

=cut

package BTDT::Action::GeneratePasswordToken;
use base qw/BTDT::Action Jifty::Action/;

=head2 arguments

We need the email of the user we're fetching a token for, so we can
return the salt.

=cut

sub arguments {
    return( { address => { mandatory => 1 } });

}


=head2 take_action

Generate a token and throw it back to the browser.  Also, return the
user's password salt in $self->result->content.


=cut

sub take_action {
    my $self = shift;

    my $email = $self->argument_value('address');
    my $user = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
    $user->load_by_cols(email => $email);
    unless($user->id) {
        $self->result->error('No such user');
    }

    my $password = $user->_value('password');

    my $token = time();
    $self->result->content(token => $token);
    $self->result->content(salt  => ($password ? $password->[1] : ""));
    Jifty->web->session->set(login_token => $token);
}

1;
