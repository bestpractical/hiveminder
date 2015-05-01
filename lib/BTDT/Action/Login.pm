use warnings;
use strict;

=head1 NAME

BTDT::Action::Login

=cut

package BTDT::Action::Login;
use base qw/BTDT::Action Jifty::Action/;
use BTDT::CurrentUser;
use BTDT::Model::User;
use Digest::MD5 qw(md5_hex);
use HTTP::Date ();
use constant TOKEN_EXPIRE_TIME => 30;

=head2 arguments

Return the address and password form fields

=cut

sub arguments {
    return( { address => { label => 'Email address',
                           mandatory => 1,
                           ajax_validates => 1,
                            }  ,

              password => { type => 'password',
                            label => 'Password',
                            # mandatory in some cases; see validate_password
                            mandatory => 0,
                        },
              hashed_password => { type => 'hidden',
                            label => 'Hashed Password',
                        },
              remember => { type => 'checkbox',
                            label => 'Remember me?',
                            hints => 'Your browser can remember your Hiveminder login for you',
                            default => 0,
                          },
              token => { type => 'hidden',
                         label => 'token',
                         mandatory => 0 },

          });

}

=head2 validate_address ADDRESS

Makes sure that the address submitted is a legal email address and that there's a user in the database with it.

Overridden from Jifty::Action::Record.

=cut

sub validate_address {
    my $self  = shift;
    my $email = shift;

    unless ( $email =~ /\S\@\S/ ) {
        return $self->validation_error(address => "Are you sure that's an email address?" );
    }

    my $u = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
    $u->load_by_cols( email => $email );
    return $self->validation_error(address => 'We do not have an account that matches that address.') unless ($u->id);

    if ($u->is_deleted) {
        return $self->validation_error(address => 'You have deleted your account. Contact us at support@hiveminder.com if you wish to rejoin our hive.');
    } elsif ( $u->access_level eq 'nonuser' or not $u->email_confirmed) {
        return $self->validation_error(address => 'You have an account, but you need to activate it. Do you need a <a href="/splash/resend">new activation link</a>?' );
    }

    return $self->validation_ok('address');
}


=head2 validate_password PASSWORD

Makes sure that the password submitted actually exists, unless there's a token and a hashed
password.

Overridden from Jifty::Action::Record.

=cut

sub validate_password {
    my $self  = shift;
    my $pw = shift;
    my $token =  $self->argument_value('token') ||'';
    my $hashedpw =  $self->argument_value('hashed_password') ;


    if ($token eq '') { # we have no token, validate in a standard way
        if ($pw eq '') {
            return $self->validation_error(password => "You need to fill in the 'password' field" );
        }
    } else { # we have a token, so we should have a hashed pw
        my $emptypw = '';
        my $blankhash = md5_hex("$token $emptypw");
        if ($hashedpw eq $blankhash) {
            return $self->validation_error(password => "You need to fill in the 'password' field" );
        }

    }


    return $self->validation_ok('password');
}

=head2 validate_token TOKEN

Make sure we issued the token within the last 30 seconds, otherwise
time out the request.

=cut

sub validate_token {
    my $self = shift;
    my $value = shift;
    my $token = Jifty->web->session->get('login_token') ||'';
    Jifty->web->session->remove("login_token");
    if ($value) {
        if(int $value < (time - TOKEN_EXPIRE_TIME)) {
            return $self->validation_error(token => "Your login attempt has timed out. Please try again.");
        }
        if ($value ne $token) {
            return $self->validation_error(token => "That didn't work. Please try again.");
        }
    }
    return $self->validation_ok("token");
}

=head2 take_action

Actually check the user's password. If it's right, log them in.
Otherwise, throw an error.


=cut

sub take_action {
    my $self = shift;
    my $user = BTDT::CurrentUser->new( email => $self->argument_value('address'));

    my $password = $self->argument_value('password');
    my $token = $self->argument_value('token') || '';
    my $hashedpw = $self->argument_value('hashed_password');

    Jifty->web->current_user(BTDT::CurrentUser->new());

    if ($token ne '') {   # browser supports javascript, do password hashing
        unless ( $user->id  && $user->hashed_password_is($hashedpw, $token)){
            $self->result->error( 'You may have mistyped your email address or password. Give it another shot.' );
            return;
        }
    }
    else {  # no password hashing over the wire
        unless ( $user->id  && $user->password_is($password)){
            $self->result->error( 'You may have mistyped your email address or password. Give it another shot.' );
            return;
        }
    }

    unless ($user->user_object->email_confirmed) {
        $self->result->error( q{You haven't <a href="/splash/signup/confirm.html">confirmed your account</a> yet.} );
        return;
    }


    if ($user->user_object->access_level eq 'nonuser') {
        $self->result->error( q{You haven't actually signed up yet. You should never be able to see this error message. Get help by emailing us at: hiveminders@hiveminder.com. });
        return;


    }

    # Set up our login message
    $self->result->message("Welcome back, " . $user->user_object->name . "." );

    # Actually do the signin thing.
    Jifty->web->current_user($user);
    Jifty->web->session->expires($self->argument_value('remember') ? HTTP::Date::time2str( time() + 31536000 ) : undef);
    Jifty->web->session->set_cookie;

    return 1;
}

1;
