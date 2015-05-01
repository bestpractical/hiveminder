use warnings;
use strict;

use BTDT::Test;

eval "use Cache::Memcached";
plan skip_all => "Cache::Memcached required for testing user groups caching" if $@;

require IO::Socket::INET;
# check if there's a running memcached on the default port, skip otherwise
plan skip_all => "Testing user groups caching requires a memcached running on the default port"
    unless IO::Socket::INET->new('127.0.0.1:11211');

plan 'no_plan';

use_ok( 'BTDT::Model::Group' );
use_ok( 'BTDT::CurrentUser' );

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;

my $mech = BTDT::Test->get_logged_in_mech($URL);
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->content_like(qr/Logout/i,"Logged in!");
like($mech->uri, qr{/todo}i, "Redirected to the inbox"); 

ok($mech->find_link(text => "Groups"), "Found groups link");
$mech->follow_link_ok(text => "Groups");

like($mech->uri, qr|/groups|, "Got group page");
make_and_verify_group($mech, name => 'my folks', desc => 'stuff');

# Test invitations.
$mech->follow_link_ok(text => 'my folks');
$mech->follow_link_ok(text => 'Manage');
my @emails = BTDT::Test->messages;
my $email_count = scalar @emails;

#Invite otheruser@example.com to group 1
$mech->fill_in_action_ok('invite',
    email => 'otheruser@example.com',
    role  => 'member',
);
$mech->submit_html_ok;
$mech->content_contains('otheruser@example.com to join my folks');

@emails = BTDT::Test->messages;
is(scalar @emails, $email_count + 1, "1 message sent");

my $confirm_mail = $emails[-1];
ok($confirm_mail, "Sent an invite email");
$confirm_mail->body =~ qr!(http://.+groups/invitation/accept/\d+)!;
my $confirm_URL = $1;
$confirm_URL =~ s!http://hiveminder.com!$URL!;

# Create an unowned task in the group
ok($mech->find_link(text => "Up for grabs"));
$mech->follow_link_ok(text => "Up for grabs");
ok($mech->find_link(text => "Braindump"));
$mech->follow_link_ok(text => "Braindump");
$mech->fill_in_action_ok('quickcreate',
    text => 'A task owned by nobody [owner: nobody]');
$mech->submit_html_ok(form_name => 'quickcreate', button => 'Create');
$mech->content_like(qr|A task owned by nobody</a>|, "Braindump into group appeared to work");

# accept the group re-invitation with the correct user.
$mech->follow_link_ok(text => "Logout");
$mech = BTDT::Test->get_logged_in_mech($URL, 'otheruser@example.com', 'something');
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->content_like(qr/Logout/i,"Logged in!");
like($mech->uri, qr{/todo}i, "Redirected to the inbox"); 

$mech->get_html_ok($confirm_URL);
like($mech->uri, qr{groups/\d+}, "redirected to the group page");
$mech->content_contains("Welcome", "contains welcome message");
$mech->content_contains("my folks", "contains the name of the group");

# Test that the new user can see unowned tasks
ok($mech->find_link(text => "Up for grabs"));
$mech->follow_link_ok(text => "Up for grabs");
$mech->content_like(qr|A task owned by nobody</a>|, "Found task owned by nobody");


sub make_and_verify_group {
    my $m = shift;
    my %args = @_;  # name, desc


    $m->get_ok("$URL/groups");

    $m->content_lacks($args{'name'});
    $m->content_lacks($args{'desc'}) if (exists $args{'desc'});
    $m->follow_link_ok(text => 'New group');
    $m->content_contains("Create", "got group page");

    if ( exists($args{'desc'}) ) {
        $m->fill_in_action_ok('newgroup',
                              name => $args{'name'},
                              description => $args{'desc'},
                             );
    } else {
        $m->fill_in_action_ok('newgroup',
                              name => $args{'name'},
                             );
    }
    $m->submit_html_ok;
    like($m->uri, qr{/groups/\d+/manage}, "on a group page");
    $m->content_contains("Invite somebody", "got group invite");
    $m->content_contains("Manage group members", 
                         "got group members management");
    ok($m->find_link(text => "Manage"), "Found manage link");
    $m->follow_link_ok(text => "Manage");
    like($m->uri, qr{/groups/\d+/manage}, "on a group page");
    $m->content_contains("Edit this group", "got group edit");
    $m->content_contains("Incoming addresses", "got group incoming addresses");
    ok($m->find_link(text => "Groups"), "Found groups link");
    $m->follow_link_ok(text => "Groups");
}
