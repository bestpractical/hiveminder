use warnings;
use strict;

=head1 DESCRIPTION

Test task review

=cut

use BTDT::Test tests => 49;

my $server = BTDT::Test->make_server;

my $URL = $server->started_ok();

ok($URL, "Started a server");





my $mech = BTDT::Test->get_logged_in_mech($URL);

# Create another task for testing
$mech->fill_in_action_ok('quickcreate',
                         text => "03 YAT\nAnother task [starts: yesterday]");
$mech->submit_html_ok();

$mech->content_contains('03 YAT', "Created yet another task");
$mech->content_contains('Another task', "Created another task");

{
    my $u2 = BTDT::Model::User->new( current_user => BTDT::CurrentUser->superuser ); $u2->load_by_cols(email => 'otheruser@example.com');
    my $cu = BTDT::CurrentUser->new( id => $u2->id );
    my $u1 = BTDT::Model::User->new( current_user => $cu ); $u1->load_by_cols(email => 'gooduser@example.com');
    my $task = BTDT::Model::Task->new( current_user => $cu ) ;
    my ($ok, $msg) = $task->create(
	summary => 'blah',
	requestor_id => $u2->id,
        owner_id => $u1->id,
	description => 'hate hate hate',
    );
}

is(scalar BTDT::Test->messages, 1, "Sent an email to u1 saying u2 gave him the task"); 

BTDT::Test->setup_mailbox;


$mech->follow_link_ok(text => "Task Review");
$mech->content_contains("Buckle up", "Got to to the task review page");
$mech->content_like(qr/All \s+ 5 \s+ of \s+ them/xi, "Has the right count");
# Get to the ``Okay'' form
$mech->form_number(2);
$mech->click_button(value => "Okay!");
#$mech->submit_html_ok();
#sleep 10 while 1 ;
$mech->content_contains("blah", "unaccepted task");
$mech->content_like(qr/1 \s+ of \s+ 5/xi, "Progress bar is correct");
$mech->form_number(2);
ok($mech->click_button(value => "Accept"));

is(scalar BTDT::Test->messages, 1, "Got a task-accepted message");
$mech->form_number(2);
ok($mech->click_button(value => "Done"));

$mech->content_contains("02 other task", "At the next task");
$mech->content_contains("3 of 5", "Progress bar is correct");
$mech->form_number(2);
my $days;
if ($mech->content =~ /Monday - (\d+ days?)/) {
$days = $1;
}

ok($mech->click_button(value => "Monday - $days"));
$mech->content_contains("03 YAT", "At the next task");
$mech->content_contains("4 of 5", "Progress bar is correct");
# Test braindump from task review
$mech->form_number(2);
$mech->fill_in_action_ok('quickcreate', text => '04 One more task');
$mech->click_button(value => 'Create');
$mech->content_contains('1 task created', 'braindumped from task review');
$mech->content_contains('04 One more task', 'Created a task');
$mech->content_contains('Back to Task Review', 'Page contains link back to task review');
$mech->form_number(2);
$mech->click_button(value => 'Back to Task Review');

$mech->content_contains("03 YAT", "At the right task");
$mech->content_contains("4 of 5", "Progress bar is still correct on 3 of 4");
$mech->form_number(2);

ok($mech->click_button(value => 'Today'));

BTDT::Test->setup_mailbox();

$mech->content_contains("Another task", "At the right task");
$mech->content_contains("5 of 5", "Progress bar is still correct on 4 of 4");

my $tid;
if ($mech->content =~ /Edit details for task (\w*)/) {
$tid = $1;
}
$mech->form_number(2);
ok($mech->click_button(value => 'Edit details for task '.$tid));

$mech->fill_in_action_ok($mech->moniker_for('BTDT::Action::UpdateTask'),
                         owner_id => 'otheruser@example.com');
$mech->form_number(2);
my $date;
if ($mech->content =~ /Next month - ((?:\d+) (?:\w+))/) {
    $date = $1;
}
ok($mech->click_button(value => "Next month - $date"));
$mech->content_contains("just looked at", "At the all done page");

my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
$task->load_by_locator($tid);
ok($task->starts > DateTime->now->add(days => 20), 'the starts of "in a month" made it through even when we changed owner');

is(scalar BTDT::Test->messages, 1, "Sent an email"); # two are for the assign/accept


$mech->get("$URL/todo");
$mech->content_contains('blah', "task was accepted");

$mech->get("$URL/search/complete");
$mech->content_contains('01 some task', 'Marked task 1 done');

$mech->get("$URL/search/starts/after/today");
$mech->content_contains('02 other task', 'Task 2 is still there');

$mech->get("$URL/search/not/owner/me");
$mech->content_contains('Another task', "Changed task 4's owner");

# Test that if we task review a list, we can get back to that list via
# the link at the end

$mech->follow_link_ok(text => "Task Review");
$mech->content_contains("All 1 of them");
$mech->form_number(2);
$mech->click_button(value => "Okay!");
$mech->content_contains("1 of 1", "Only one task here");
$mech->form_number(2);
$mech->click_button(value => 'Today');

$mech->content_contains("just looked at");
$mech->follow_link_ok(text => 'where you came from');
    like($mech->uri, qr{search/not/owner/me}, 'Got back to my search');

# create a completed task to make sure review doesn't hit complete tasks
my $gooduser = BTDT::CurrentUser->new( email => 'gooduser@example.com'  );
$task = BTDT::Model::Task->new( current_user => $gooduser ) ;
my ($ok, $msg) = $task->create(
    summary => 'this one is DONE!',
    complete => 1,
);
ok($ok, $msg);

$mech->get("$URL/list/complete/1/not/complete/1");
$mech->content_contains('this one is DONE!', "finished task shows up");

$mech->follow_link_ok(text => "Task Review");
$mech->form_number(2);
$mech->click_button(value => "Okay!");

$mech->content_contains("1 of 7", "all tasks are here");

1;
