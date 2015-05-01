use warnings;
use strict;

=head1 DESCRIPTION

Assigning tasks to people who don't exist yet

=cut

use BTDT::Test tests => 33;

my $superuser = BTDT::CurrentUser->superuser;

# Make sure that user doesn't exist yet
my $user = BTDT::Model::User->new( current_user => $superuser );
$user->load_by_cols( email => 'newuser@example.com' );
ok( !$user->id, "User doesn't yet exist" );

# Log in
my $server = BTDT::Test->make_server;
my $URL    = $server->started_ok;
my $mech   = BTDT::Test->get_logged_in_mech($URL);
$mech->content_like( qr/Logout/i, "logged in" );

my @emails = BTDT::Test->messages;
is( scalar @emails, 0, "No email yet" );

# Create a task
$mech->fill_in_action_ok(
    $mech->moniker_for("CreateTask"),
    summary  => "Some new task",
    owner_id => 'newuser@example.com'
);
$mech->submit_html_ok;

# Check user again
$user = BTDT::Model::User->new( current_user => $superuser );
$user->load_by_cols( email => 'newuser@example.com' );
ok( $user->id, "User exists now" );
is( $user->access_level, "nonuser", "Is a nonuser" );

@emails = BTDT::Test->messages;
is( scalar @emails, 1, "Got one email" );

is( $emails[0]->header("To"),
    'newuser@example.com', "Email went to right place" );
is( $emails[0]->header("Subject"),
    "New task: Some new task (#5)",
    "Right subject"
);
    like(
	$emails[0]->body,
	qr/you to do something/,
	"Contains information about the task request"
	);

like(
    $emails[0]->body,
    qr/accept or decline/,
    "Contains information about task actions"
);
like(
    $emails[0]->body,
    qr|http://\S+/let/newuser%40example\.com/update_task/id/3|,
    "Contains a link to update the task"
);

my ($update_task) = $emails[0]->body =~ m|(http://\S+/update_task/id/3\S+)|;
$mech->follow_link_ok( text => "Logout" );
$mech->get($update_task);
$mech->content_like( qr/Some new task/, "Has the task" );

ok( $mech->moniker_for( "UpdateTask", id => 3 ), "Has a action" );
$mech->click_button( value => 'Accept');


ok( $mech->moniker_for( "UpdateTask", id => 3 ), "Has an update action" );

$mech->fill_in_action_ok( $mech->moniker_for( "UpdateTask", id => 3 ),
    summary => "Updated title" );
$mech->submit_html_ok;

$mech->content_like( qr/Join us!/, "Has signup plea" );
$mech->content_like(
    qr|http://\S+/let/newuser%40example\.com/activate_account/\w+|,
    "Has account activation link" );

like(
    $emails[0]->body,
    qr|http://\S+/let/newuser%40example\.com/activate_account/\w+|,
    "Email also had activation link"
);

# Activation
my ($web_activate)
    = $mech->content
    =~ qr|(http://\S+/let/newuser%40example\.com/activate_account/\w+)|;
my ($email_activate)
    = $emails[0]->body
    =~ qr|(http://\S+/let/newuser%40example\.com/activate_account/\w+)|;
is( $web_activate, $email_activate,
    "Same activation link in both email and web" );

$mech->get($web_activate);
ok( $mech->moniker_for("GoLegit"), "We have a registration action" );

$mech->fill_in_action_ok(
    $mech->moniker_for("GoLegit"),
    name             => "New User",
    password         => "password",
    password_confirm => "password",
);
$mech->submit_html_ok;

SKIP: {
    skip "Application EULA not in place", 3 unless BTDT->current_eula_version > 0;
    like($mech->uri, qr{/accept_eula}, "Redirected to the EULA accept page");
    $mech->fill_in_action_ok('accept_eula');
    ok($mech->click_button(value => 'Accept these terms and make our lawyers happy'));
}

# Check user again
Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
my $foo = BTDT::Model::User->new( current_user => $superuser );
$foo->load_by_cols( email => 'newuser@example.com' );
is( $foo->access_level, "guest",    "Is now a guest" );
is( $foo->name,         "New User", "Has a name now" );

like( $mech->uri, qr|/todo|, "At inbox" );

1;

