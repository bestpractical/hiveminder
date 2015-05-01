use strict;
use warnings;
use Test::MockTime 'set_fixed_time';
use BTDT::Test tests => 18;

# 24 hours before middle of DST no-hour
set_fixed_time('2010-03-13T07:30:00Z');

# setup {{{
my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech($URL);
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->html_ok;
$mech->content_like(qr/Logout/i, "logged in");
# }}}

$mech->fill_in_action_ok(
    "tasklist-new_item_create",
    summary => "dst boom [due tomorrow]",
);
$mech->submit_html_ok();

like($mech->uri, qr|/todo|, "Back at inbox");
$mech->content_contains('dst boom');



# inside the DST double-hour
set_fixed_time('2010-11-07T07:30:00Z');

# fork off another server for this second time change :( {{{
$server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

$URL = $server->started_ok;
$mech = BTDT::Test->get_logged_in_mech($URL);
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->html_ok;
$mech->content_like(qr/Logout/i, "logged in");
# }}}

$mech->fill_in_action_ok(
    "tasklist-new_item_create",
    summary => "dst again [due yesterday]",
);
$mech->submit_html_ok();
like($mech->uri, qr|/todo|, "Back at inbox");
$mech->content_contains('dst again');

