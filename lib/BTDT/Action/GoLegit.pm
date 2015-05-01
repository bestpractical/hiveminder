use warnings;
use strict;

=head1 NAME

BTDT::Action::GoLegit - Confirm and reset a lost password

=head1 DESCRIPTION

Hiveminder runs this action when a "nonuser" wants to sign up for a
real account.

=cut

package BTDT::Action::GoLegit;
use base qw/BTDT::Action Jifty::Action/;

__PACKAGE__->mk_accessors(qw/user_object/);

use BTDT::Model::User;

=head2 arguments

ConfirmEmail has the following fields: address, code, password, and password_confirm.
Note that it can get the first two from the confirm dhandler.

=cut

sub arguments {
    return( {
              password => { type => 'password', mandatory => 1, hints => 'Your password should be at least six characters long', label => 'Password' },
              name => { type => 'text', label => q{What's your real name?} },
              password_confirm => { type => 'password', label => 'Type your password again.', mandatory => 1 },
          });
}



=head2 setup

Load up our user to work with.

=cut

sub setup {
    my $self = shift;

    # Make a blank user object
    my $u = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
    $u->load_by_cols( email => Jifty->web->current_user->user_object->email );
    $self->user_object($u);
}


=head2 take_action

Resets the password.

=cut

sub take_action {
    my $self = shift;
    my $u = $self->user_object;

    unless ($u) {
        $self->result->error( "You have to have an account in order to reset your password.");
    }


    unless ($u->access_level eq 'nonuser') {
        $self->result->error(qq{This sign up form is only for users who have never had a Hiveminder account before. <a href="/splash/lostpass.html">You can reset your password here</a>.});
    }

        $u->set_name( $self->argument_value('name') );
    unless (
         $u->set_access_level('guest')
        && $u->set_email_confirmed('1')
        && $u->set_password($self->argument_value('password'))
    )
    {
        $self->result->error(
            q|There was an error setting up your account. Please try again later or email us for help at hiveminders@hiveminder.com|
        );
        return;
    }



    # Log in!
    $self->result->message( "Congratulations! You've activated your Hiveminder account.");
    Jifty->web->current_user(BTDT::CurrentUser->new(id => $u->id));
    return 1;

}

=head2 validate_password PASSWORD

make sure the two passwords entered match

XXX TODO CUT AND PASTE FROM SIGNUP. BAD BAD BAD

=cut

sub validate_password {
    my $self     = shift;
    my $password = shift;

    if ( $password and ( $password ne $self->argument_value('password_confirm') ) ) {
        return $self->validation_error( 'password' => "The passwords you typed don't match.  Give it another shot.");
    }

    my ( $ok, $msg ) = $self->user_object->validate_password($password);
    if ( not $ok ) {
        return $self->validation_error( 'password' => $msg );
    }

    return $self->validation_ok('password');
}


1;
