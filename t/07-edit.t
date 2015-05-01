use warnings;
use strict;

# {{{ Setup
use BTDT::Test tests => 22;

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');
my $URL = $server->started_ok;

my $mech = BTDT::Test->get_logged_in_mech($URL);
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
# }}}

$mech->html_ok;

$mech->content_like(qr/Logout/i,"Logged in!");

like($mech->uri, qr{/todo}i, "Redirected to the inbox"); 

ok($mech->find_link(text => "Preferences"), "Found user edit link");
$mech->follow_link_ok(text => "Preferences");

like($mech->uri, qr|/prefs|, "Got user edit page");
$mech->content_like(qr/preferences/i,"At user settings");

is($mech->action_field_value('useredit', 'email'), 'gooduser@example.com', "Email matches what was created");
is($mech->action_field_value('useredit', 'name'), 'Good Test User', "User name matches what was created");

$mech->fill_in_action_ok('useredit',
    'email' => 'moose@example.com',
    'name' => 'Newer Test User',
);
$mech->submit_html_ok();

my $testuser;

# commented out by jrv because we'd cache the not-updated user object and fail the password test.
# of course, if we would fail this test, we'll fail that one too.
#$testuser = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
#$testuser->load_by_cols(email => 'moose@example.com');
#is($testuser->email(), 'moose@example.com', "We got the right user out of the db");

ok($mech->find_link(text => "Security"), "Found password link");
$mech->follow_link_ok(text => "Security");

$mech->fill_in_action_ok('useredit',
    'password' => 's33kr3t',
    'password_confirm' => 's33kr3t',
    'current_password' => 'secret'
);
$mech->submit_html_ok();
$testuser = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
$testuser->load_by_cols(email => 'moose@example.com');
ok($testuser->password_is('s33kr3t'), "the password for this user is set right - " . $testuser->__value('password'));


like($mech->uri, qr|prefs/security|, "Got user password change page again");
$mech->content_like(qr/preferences/i,"Back at user settings");

is($mech->action_field_value('useredit', 'password'), '', "Password field is blank");

1;
