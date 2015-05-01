use warnings;
use strict;

=head1 DESCRIPTION

HTML structure testing

=cut

our @PAGES;

BEGIN {
    # XXX TODO: Test all the pages.  The ones here are only the biggest offenders.
    # The pages to test
    @PAGES = qw( /about/faq.html /about/team.html /todo );
}

use BTDT::Test tests => 4 + scalar @PAGES;

# Start server
my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');
my $URL = $server->started_ok;

# Get mech
my $mech = BTDT::Test->get_logged_in_mech($URL);
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->html_ok;

# Test the pages
for my $page ( @PAGES ) {
    $mech->get_html_ok( $URL . $page );
}

1;

