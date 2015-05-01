use warnings;
use strict;

use BTDT::Test tests => 5, actual_server => 1;

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');
my $URL = $server->started_ok;

# REAL TESTS START HERE--------------------------------------
use_ok ('Hiveminder::Client');

my $client = Hiveminder::Client->new(username=>'bogus', password=>'faux');
is($client, undef, "Client can't log in properly with blank credentials");

# TRY TO LOG IN TO OUR LOCAL HM PROPERLY
$client = Hiveminder::Client->new( url => $URL );

# something trivial
$client->get('/groups/');
like($client->content, qr/alpha/);  # group 1 from BTDT::Test exists

1;
