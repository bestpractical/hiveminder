use warnings;
use strict;

use YAML;
use Data::Dumper;

use Jifty;
use BTDT::CurrentUser;

use BTDT::Test tests => 17;

my $Class = 'BTDT::Action::InviteNewUser';
require_ok $Class;

my $gooduser = BTDT::CurrentUser->new( email => 'gooduser@example.com' );
my $admin    = BTDT::CurrentUser->superuser;
ok $gooduser;
Jifty->web->current_user($gooduser);


# Test a successful invite
{
    Jifty->web->response(Jifty::Response->new);
    Jifty->web->request(Jifty::Request->new);

    my $action = $Class->new(
        arguments => {
            email        => 'foo@bar.com',
        }
    );

    ok $action->validate;
    $action->run;
    my $result = $action->result;
    ok $result->success;
    like $result->message, qr{^You\'ve invited foo\@bar.com to join};
}


# Test a duplicate invite
{
    Jifty->web->response(Jifty::Response->new);
    Jifty->web->request(Jifty::Request->new);
    my $action = $Class->new(
        arguments => {
            email        => 'foo@bar.com',
        }
    );

    ok !$action->validate;
    my $result = $action->result;
    ok $result->failure;
    like $result->field_error('email'), 
         qr{^Someone has already sent that person an invitation};
}


# Test inviting an existing address
{
    Jifty->web->response(Jifty::Response->new);
    Jifty->web->request(Jifty::Request->new);
    my $action = $Class->new(
        arguments => {
            email        => 'gooduser@example.com',
        }
    );

    ok !$action->validate;
    my $result = $action->result;
    ok $result->failure;
    like $result->field_error('email'),
         qr{^It turns out they already have an account};
}


# Test inviting a user who does not wish to be emailed
{
    my $grumpy_email = 'grumpy@grumpy.old.user';
    my $grumpy_user = BTDT::Model::User->new( current_user => $admin );
    $grumpy_user->create(
        email       => 'grumpy@grumpy.old.user',
        never_email => 1,
    );

    Jifty->web->response(Jifty::Response->new);
    Jifty->web->request(Jifty::Request->new);
    my $action = $Class->new(
        arguments => {
            email        => $grumpy_email,
        }
    );

    ok !$action->validate;
    my $result = $action->result;
    ok $result->failure;
    like $result->field_error('email'),
         qr{^$grumpy_email has chosen not to use Hiveminder};
}


# Test email validation
{
    Jifty->web->response(Jifty::Response->new);
    Jifty->web->request(Jifty::Request->new);
    my $action = $Class->new(
        arguments => {
            email        => 'wibble',
        }
    );

    ok !$action->validate;
    my $result = $action->result;
    ok $result->failure;
    like $result->field_error('email'),
         qr{^Are you sure that\'s an email address};
}
