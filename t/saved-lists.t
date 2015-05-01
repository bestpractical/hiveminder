use warnings;
use strict;

use BTDT::Test 'no_plan';

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL  = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech( $URL );
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->html_ok;
$mech->content_like(qr/Logout/i, "logged in");

# Setup pro user
my $gooduser = BTDT::CurrentUser->new( email => 'gooduser@example.com' );
my $user = BTDT::Model::User->new( current_user => BTDT::CurrentUser->superuser );
$user->load( $gooduser->id );
$user->set_pro_account('t');

# Save a list
$mech->get_ok( $URL . '/list/owner/me' );
$mech->content_contains('Search for tasks');
$mech->content_contains('Owner me</span>');
$mech->follow_link_ok( text => 'Save List' );
$mech->content_contains('Save as new list');
$mech->content_lacks('Update existing list');
$mech->fill_in_action_ok(
    $mech->moniker_for("BTDT::Action::CreateList"),
    name => '01 test list'
);
$mech->submit_html_ok();
$mech->content_contains('List saved', 'saved list');
$mech->content_contains('01 test list', 'title is correct');

# Go to another list and see if the saved one shows up
$mech->get_ok( $URL . '/list/owner/me/not/complete' );
$mech->content_contains('Search for tasks');
$mech->content_contains('Owner me not complete</span>');
$mech->follow_link_ok( text => 'Save List' );
$mech->content_contains('Save as new list');
$mech->content_contains('Update existing list', 'update list form shown');
$mech->content_contains('01 test list</option>', 'saved list shown');
$mech->fill_in_action_ok(
    $mech->moniker_for("BTDT::Action::CreateList"),
    name => '02 foobar'
);
$mech->submit_html_ok();
$mech->content_contains('List saved');
$mech->content_contains('02 foobar');

# Update a list
$mech->get_ok( $URL . '/list/owner/me/not/complete/query/moose' );
$mech->content_contains('Search for tasks');
$mech->content_contains('Owner me not complete query moose</span>');
$mech->follow_link_ok( text => 'Save List' );
$mech->content_contains('Save as new list');
$mech->content_contains('Update existing list');
$mech->content_contains('01 test list</option>');
$mech->content_contains('02 foobar</option>');

# Update the list
$mech->fill_in_action_ok(
    $mech->moniker_for("BTDT::Action::ChangeListTokens"),
    id => 1
);
$mech->submit_html_ok();
$mech->content_contains('Update');
$mech->content_contains('01 test list');

# Check /lists
$mech->get_ok( $URL . '/lists' );
$mech->content_contains('01 test list');
$mech->content_contains('02 foobar');



