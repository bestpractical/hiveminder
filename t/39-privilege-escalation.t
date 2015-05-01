use warnings;
use strict;

=head1 DESCRIPTION

User ACLs for editing themselves need to prevent a user from modifying
heir own access_level

=cut

use BTDT::Test tests => 28;

my $server = Jifty::Test->make_server;
isa_ok( $server, 'Jifty::TestServer' );

my $URL  = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech($URL);
isa_ok( $mech, 'Jifty::Test::WWW::Mechanize' );
$mech->html_ok;
$mech->content_like( qr/Logout/i, "logged in" );

$mech->follow_link( text => "News" );
like( $mech->uri, qr|/news| );

# Check that we can't create a news item
ok( !$mech->moniker_for("CreateNews"), "New news creation action visible" );
ok( my $response = $mech->send_action(
        "CreateNews",
        title   => "Something",
        content => "A message"
    ),
    "Made news creation request"
);
ok( $response->{failure}, "Action failed" );
$mech->warnings_like([qr/tried to create a BTDT::Model::News without permission/, qr/Create of BTDT::Model::News failed/]);

# Try to update our access level
ok( $response = $mech->send_action(
        "UpdateUser",
        id           => $mech->current_user->id,
        access_level => 'staff',
    ),
    "Made privilege escalation request"
);
## Given that the "access_level" field doesn't exist on updates
## anymore, this doesn't fail -- it just silently does nothing.  Thus
## the alteration to this check
ok( not($response->{message}), "Action failed" );
#ok( $response->{failure}, "Action failed" );

# Try logging out and back in again, to double-check our ACLs
$mech = BTDT::Test->get_logged_in_mech($URL);
$mech->follow_link( text => "News" );
like( $mech->uri, qr|/news| );

# Check that we still can't create a news item
ok( !$mech->moniker_for("CreateNews"), "New news creation action visible" );
ok( $response = $mech->send_action(
        "CreateNews",
        title   => "Something",
        content => "A message"
    ),
    "Made news creation request"
);
ok( $response->{failure}, "Action failed" );
$mech->warnings_like([qr/tried to create a BTDT::Model::News without permission/, qr/Create of BTDT::Model::News failed/]);

# Make sure that we can't inject ourself as an administrator of
# arbitrary groups

my $gooduser = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
$gooduser->load_by_cols(email => 'gooduser@example.com');
ok($gooduser->id, 'Loaded Good User');

my $otheruser = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
$otheruser->load_by_cols(email => 'otheruser@example.com');
ok($otheruser->id, 'Loaded Other User');

my $target = BTDT::Model::Group->new(current_user => BTDT::CurrentUser->new(id => $gooduser->id));
$target->create(name => 'Hackme');
ok($target->id , 'Created a target group');

my $backdoor = BTDT::Model::Group->new(current_user => BTDT::CurrentUser->new(id => $otheruser->id));
$backdoor->create(name => 'Stepping Stone');
ok($backdoor->id, 'Created a stepping stone group');
ok($backdoor->current_user_can('manage'), "I'm an administrator of my new group");

my $target_as_attacker = BTDT::Model::Group->new(current_user => BTDT::CurrentUser->new(id => $otheruser->id));
$target_as_attacker->load($target->id);

ok(!$target_as_attacker->current_user_can('manage'), "Can't manage another group");

my $member = BTDT::Model::GroupMember->new(current_user => BTDT::CurrentUser->new(id => $otheruser->id));
$member->load_by_cols(actor_id => $otheruser->id, group_id => $backdoor->id);

ok($member->id, 'Loaded the membership backdoor');

# Set the group ID of the membership to the target group, thereby
# creating a group membership relationship between the attacker and
# the target group, with a role of "organizer"
my ($ok, $msg) = $member->set_group_id($target->id);
ok(!$ok, "Can't alter the GroupMember's group_id");

ok(!$target_as_attacker->current_user_can('manage'), "Still can't manage the other group");

1;

