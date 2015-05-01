use warnings;
use strict;

=head1 DESCRIPTION

Test that feeds work with searches

=cut

use BTDT::Test tests => 20;

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');
my $URL = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech($URL);
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->content_like(qr/Logout/i,"Logged in!");

ok($mech->find_link( url => '/search' ), "Search link exists");
$mech->follow_link_ok( url => '/search' );

$mech->fill_in_action_ok("search", summary => "some");
$mech->submit_html_ok();

like($mech->uri, qr|/search/summary/some|, "At expected search path");

$mech->content_contains('01 some task', "Contains task that was searched for");
$mech->content_lacks('02 other task', "Missing task that doesn't match");

ok($mech->find_link( url_regex => qr|format/text| ), "Text feed link exists");
$mech->follow_link_ok( url_regex => qr|format/text| );

like($mech->uri, qr|/let/gooduser%40example.com .* tokens/summary%20some|x, "At proper feed path");

$mech->content_contains('01 some task', "Contains task that was searched for");
$mech->content_lacks('02 other task', "Missing task that doesn't match");

my $feed = $mech->uri;

$mech->back;
$mech->follow_link_ok( text => "Logout" );

$mech->get_ok( $feed );
$mech->content_contains('01 some task', "Contains task that was searched for");
$mech->content_lacks('02 other task', "Missing task that doesn't match");

1;

