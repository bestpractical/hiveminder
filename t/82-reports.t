use warnings;
use strict;

use BTDT::Test tests => 8;

BTDT::Test->make_pro('gooduser@example.com');

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;

my $mech = BTDT::Test->get_logged_in_mech($URL);
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->content_like(qr/Logout/i,"Logged in!");
like($mech->uri, qr{/todo}i, "Redirected to the inbox"); 

ok($mech->find_link(text => "Reports"), "Found Reports link");
$mech->follow_link_ok(text => "Reports");

