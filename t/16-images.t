use warnings;
use strict;

use BTDT::Test tests => 8;

my $server  = Jifty::Test->make_server;

isa_ok($server, 'Jifty::TestServer');

my $URL     = $server->started_ok;
my $mech    = Jifty::Test::WWW::Mechanize->new();

for my $image (qw(honeycomb-3d.png test.png)) {
    $mech->get_ok("$URL/static/images/$image");
    my $res = $mech->response;
    
    is($res->header('Content-Type'), 'image/png', 'Content-Type is image/png');
    like($res->status_line, qr/^200/, 'Status line is from Mason');
}

