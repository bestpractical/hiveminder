use warnings;
use strict;

=head1 DESCRIPTION

Test that users can opt out of receiving email.

=cut

use BTDT::Test tests => 23;

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer', 'Started the server');

my $URL = $server->started_ok;

my $mech = BTDT::Test->get_logged_in_mech($URL);

$mech->fill_in_action_ok('tasklist-new_item_create', summary => "Test task");
$mech->submit_html_ok();

ok($mech->find_link( text => "Test task" ), "Task view link exists");
$mech->follow_link_ok( text => "Test task" );
$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 3),
                         owner_id => 'not_a_user@localhost');
$mech->submit_html_ok('Assigned task to not_a_user@localhost');

ok(scalar BTDT::Test->messages, "Sent an email");

my $other_user = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
$other_user->load_by_cols(email => 'not_a_user@localhost');

ok($other_user, "Assigning the task created a user");

$mech->follow_link_ok( text => 'Logout');

my @emails = BTDT::Test->messages;
my $body = $emails[0]->body;

my ($update_task) = $body =~ m|(http://\S+/update_task/id/3\S+)|;

like($body, qr/opt_out/, "Email contains an opt-out link");
$mech->get($update_task);
ok($mech->find_link(text_regex => qr/stop sending/i), "Found the opt-out link");
$mech->follow_link_ok(text_regex => qr/stop sending/i);
$mech->fill_in_action_ok('opt_out');
$mech->submit_html_ok();

$mech = BTDT::Test->get_logged_in_mech($URL);
$mech->get("/todo");

$mech->fill_in_action_ok('tasklist-new_item_create', summary => "Test task 2");
$mech->submit_html_ok('Created another task');

ok($mech->find_link( text => "Test task 2" ), "Task view link exists");
$mech->follow_link_ok( text => "Test task 2" );
$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 4),
                         owner_id => 'not_a_user@localhost');
$mech->submit_html_ok();

ok(scalar BTDT::Test->messages == 1, "Did not send an email once the user has opted out");

1;
