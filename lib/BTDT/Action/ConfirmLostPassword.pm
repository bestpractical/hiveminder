use warnings;
use strict;

=head1 NAME

BTDT::Action::ConfirmLostPassword - Confirm and reset a lost password

=head1 DESCRIPTION

This is the action run by the link in a user's email to confirm that their email
address is really theirs, when claiming that they lost their password.


=cut

package BTDT::Action::ConfirmLostPassword;
use base qw/BTDT::Action Jifty::Action/;

use BTDT::Model::User;

=head2 arguments

ConfirmEmail has the following fields: address, code, password, and password_confirm.
Note that it can get the first two from the confirm dhandler.

=cut

sub arguments {
    return( {
              password => {
                    type    => 'password',
                    sticky  => 0,
                    label   => 'New password',
              },
              password_confirm => {
                    type    => 'password',
                    sticky  => 0,
                    label   => 'Type your new password again.',
              }
          });
}

=head2 take_action

Resets the password.

=cut

sub take_action {
    my $self = shift;
    my $u = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
    $u->load_by_cols( email => Jifty->web->current_user->user_object->email );

    unless ($u) {
        $self->result->error( q|Huh. We can't find an account for you.  Please tell us about it at hiveminders@hiveminder.com.|);
    }

    my $pass = $self->argument_value('password');
    my $pass_c = $self->argument_value('password_confirm');

    # Trying to set a password (ie, submitted the form)
    unless (defined $pass and defined $pass_c and length $pass and $pass eq $pass_c) {
        $self->result->error("The passwords you typed don't match.  Give it another shot.");
        return;
    }

    unless ($u->set_password($pass)) {
        $self->result->error("Something bad happened.  You should probably come back later.");
        return;
    }
    # Log in!
    $self->result->message( "Your password has been reset.  Welcome back!" );
    Jifty->web->current_user(BTDT::CurrentUser->new(id => $u->id));
    return 1;

}

1;
