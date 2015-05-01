use warnings;
use strict;

use BTDT::Test tests => 9;

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;

my $mech = BTDT::Test->get_logged_in_mech($URL);

isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->content_like(qr/Logout/i,"Logged in!");

$mech->fill_in_action_ok( "tasklist-new_item_create",
                          summary => 'task with compound tags ["compound tag"]' );
$mech->submit_html_ok();
$mech->content_contains('task with compound tags','compound tag task parsed correctly');
$mech->follow_link_ok(text => 'compound tag');
$mech->content_contains('task with compound tags',"filtering by tag finds task");
