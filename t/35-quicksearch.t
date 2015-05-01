use warnings;
use strict;

=head1 DESCRIPTION

Tests the quicksearch feature

=cut

use BTDT::Test tests => 26;

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech($URL);

# Get more than one task
$mech->fill_in_action_ok("quicksearch", query => "task");
$mech->form_number(1); $mech->click_button( value => 'Search' );
like($mech->uri, qr|/search/query/task|);
$mech->content_contains("01 some task");
$mech->content_contains("02 other task");

# Get exactly one
$mech->fill_in_action_ok("quicksearch", query => "some");
$mech->form_number(1); $mech->click_button( value => 'Search' );
like($mech->uri, qr|/search/query/some|);
$mech->content_contains("01 some task");
$mech->content_lacks("02 other task");

# Searching by record-locator goes straight to the task
$mech->fill_in_action_ok("quicksearch", query => "3"); # the encoded form of id 1
$mech->form_number(1); $mech->click_button( value => 'Search' );
like($mech->uri, qr|/task/3|, "found 3");
$mech->content_contains("01 some task");
$mech->content_lacks("02 other task");

# Including the # works, too
$mech->fill_in_action_ok("quicksearch", query => "#3");
$mech->form_number(1); $mech->click_button( value => 'Search' );
like($mech->uri, qr|/task/3|, "Found #3");
$mech->content_contains("01 some task");
$mech->content_lacks("02 other task");

# Search description, too
$mech->fill_in_action_ok("quicksearch", query => "description");
$mech->form_number(1); $mech->click_button( value => 'Search' );
like($mech->uri, qr|/search/query/description|);
$mech->content_lacks("01 some task");
$mech->content_contains("02 other task");

# Multiple words caused infinite redirects at one point
$mech->fill_in_action_ok("quicksearch", query => "with description");
$mech->form_number(1); $mech->click_button( value => 'Search' );
like($mech->uri, qr|/search/query/with%20description|);
$mech->content_lacks("01 some task");
$mech->content_contains("02 other task");

1;

