use warnings;
use strict;

use BTDT::Test 'no_plan';

my $server = Jifty::Test->make_server;
my $URL  = $server->started_ok;
my $mech = BTDT::Test::WWW::Mechanize->new;

$mech->get_ok("$URL/");
