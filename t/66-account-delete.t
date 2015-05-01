use warnings;
use strict;

use BTDT::Test tests => 11;
use Email::Simple;

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');
my $URL = $server->started_ok;

my $session = $$."-".int(rand(100));

my $mech = BTDT::Test->get_logged_in_mech( $URL );

$mech->get("/account/delete");
$mech->content_contains("CAN NOT BE RECOVERED", "we are serious!");
$mech->form_number(2);

$mech->click_button(value => "Delete my account");

like($mech->uri, qr{/account/delete}, "still at the same page");
$mech->content_contains("CAN NOT BE RECOVERED", "we are still serious!");
$mech->form_number(2);
$mech->click_button(value => "Yes, I'm sure, really delete my account.");

$mech->content_contains("Account deleted.", "success!");
like($mech->uri, qr{/splash}, "not logged in any more");

$mech->get("/todo");
like($mech->uri, qr{/splash}, "not logged in any more");

$mech->form_name('loginbox');
$mech->fill_in_action_ok('loginbox', address => 'gooduser@example.com', password => 'secret');
$mech->submit;

$mech->content_lacks("Welcome back", "make sure we're not logged in");
$mech->content_contains("You have deleted your account", "user is notified that he's been sacked");

