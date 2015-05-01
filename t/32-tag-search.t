use warnings;
use strict;

use BTDT::Test tests => 75;

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech($URL);
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->html_ok;
$mech->content_like(qr/Logout/i, "logged in");

# Add some tags
ok($mech->find_link(text => "Edit"), "Link to edit exists");
$mech->follow_link_ok(text => "Edit");

ok($mech->find_link(text => "Edit"), "Second link to edit exists");
$mech->follow_link_ok(text => "Edit");

$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 1),
                         tags => q{foo bar baz word});

$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 2),
                         tags => q{baz troz zort "multi word"});

$mech->submit_html_ok();
like($mech->uri, qr|/todo|, "Back at inbox");

# Find the search page
ok($mech->find_link(url => '/search'));
$mech->follow_link_ok( url => '/search', "Found the search page");

# Just one tag
$mech->fill_in_action_ok("search", tag => "foo");
$mech->submit_html_ok();
$mech->content_contains("01 some task");
$mech->content_lacks("02 other task");
$mech->follow_link_ok( url => '/search', "Found the search page");

$mech->fill_in_action_ok("search", tag => "troz");
$mech->submit_html_ok();
$mech->content_lacks("01 some task");
$mech->content_contains("02 other task");
$mech->follow_link_ok( url => '/search', "Found the search page");
$mech->fill_in_action_ok("search", tag => "baz");
$mech->submit_html_ok();
$mech->content_contains("01 some task");
$mech->content_contains("02 other task");

# Parses multiple words correctly
$mech->follow_link_ok( url => '/search', "Found the search page");
$mech->fill_in_action_ok("search", tag => q{"multi word"});
$mech->submit_html_ok();
$mech->content_lacks("01 some task", "no some task");
$mech->content_contains("02 other task", "yes other task");
# Even with differing quotes
$mech->follow_link_ok( url => '/search', "Found the search page for 'multi word'");
$mech->fill_in_action_ok("search", tag => q{'multi word'});
$mech->submit_html_ok();
$mech->content_lacks("01 some task");
$mech->content_contains("02 other task");

# Doesn't give all tasks with superstrings of that tag
$mech->follow_link_ok( url => '/search', "Found the search page for ba");
$mech->fill_in_action_ok("search", tag => "ba");
$mech->submit_html_ok();
$mech->content_lacks("01 some task");
$mech->content_lacks("02 other task");

$mech->follow_link_ok( url => '/search', "Found the search page for word");
$mech->fill_in_action_ok("search", tag => "word");
$mech->submit_html_ok();
$mech->content_contains("01 some task", "no 01 on 'word'");
$mech->content_lacks("02 other task");

# Mutiple strings is an AND
$mech->follow_link_ok( url => '/search', "Found the search page for foo troz");
$mech->fill_in_action_ok("search", tag => "foo troz");
$mech->submit_html_ok();
$mech->content_lacks("01 some task"),;
$mech->content_lacks("02 other task");

# Mutiple strings is an AND
$mech->follow_link_ok( url => '/search', "Found the search page for foo troz");
$mech->fill_in_action_ok("search", tag => "baz troz");
$mech->submit_html_ok();
$mech->content_lacks("01 some task"),;
$mech->content_contains("02 other task");

# Negation is an AND
$mech->follow_link_ok( url => '/search', "Found the search page");
$mech->fill_in_action_ok("search", tag => "baz",  tag_not => "zort");
$mech->submit_html_ok();
$mech->content_contains("01 some task");
$mech->content_lacks("02 other task");

# And works with multiple strings
$mech->follow_link_ok( url => '/search', "Found the search page");
$mech->fill_in_action_ok("search", tag => "foo baz",  tag_not => "zort");
$mech->submit_html_ok();
$mech->content_contains("01 some task");
$mech->content_lacks("02 other task");


# Make sure we can search for tags that don't exist (This crashes as
# of 2006-08-15)
$mech->follow_link_ok(url => '/todo');
$mech->follow_link_ok( text => 'Search', "Found the search box");
$mech->fill_in_action_ok("tasklist-tasklistotherstuff-search", tag => "Thereisnotag");
$mech->click_button(value => 'Search');
$mech->content_contains("tag Thereisnotag");
$mech->content_lacks("01 some task");
$mech->content_lacks("02 other task");
