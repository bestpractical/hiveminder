use warnings;
use strict;

# {{{ Setup
use Test::MockTime qw( :all );
set_fixed_time('2007-01-05T06:08:53Z');
use BTDT::Test tests => 197;

my $admin     = BTDT::CurrentUser->superuser;

my $gooduser  = BTDT::Model::User->new(current_user => $admin);
$gooduser->load_by_cols(email => 'gooduser@example.com');
my $gooduser_cu = BTDT::CurrentUser->new( email => 'gooduser@example.com' );

my $otheruser = BTDT::Model::User->new(current_user => $admin);
$otheruser->load_by_cols(email => 'otheruser@example.com');
my $otheruser_cu = BTDT::CurrentUser->new( email => 'otheruser@example.com' );

Jifty->web->current_user($gooduser_cu);
BTDT::Model::Task->new( current_user => $gooduser_cu )->create(summary => "Some task", description => "With a description");

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;

my $mech = BTDT::Test->get_logged_in_mech($URL);

# }}}

isa_ok($mech, 'BTDT::Test::WWW::Mechanize');
$mech->content_like(qr/Logout/i,"Logged in!");

# ===== BEGIN TESTS FOR Personal TASKS ASSIGNED TO SELF =================

# Comment on the task.
ok($mech->find_link( text => "Some task" ), "Task view link exists");
$mech->follow_link_ok( text => "Some task" );
$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 3),                         
			 comment => 'commenty fresh' );
$mech->submit_html_ok();
$mech->content_contains('commenty fresh');

# Make sure we didn't get our own comment on a Personal task
BTDT::Test->setup_mailbox();
my @emails = BTDT::Test->messages;
is(scalar @emails, 0, "No comment mail to self on Personal tasks");


BTDT::Test->trigger_reminders();
@emails = BTDT::Test->messages;
is(scalar @emails, 0, "no Daily reminder mail when there's nothing to do");

BTDT::Test->setup_mailbox();

# ==== BEGIN TESTS FOR Personal TASKS ASSIGNED OUT TO OTHER USERS ======

update_task('Some task', owner_id => $otheruser->email);

# Check that we got sent mail about it
@emails = BTDT::Test->messages;
is(scalar @emails, 1, "Got one email");

use Email::Simple;
my $assigned_mail = $emails[-1] || Email::Simple->new('');
is($assigned_mail->header("To"), 'otheruser@example.com', 'Email goes to right place');
like ($assigned_mail->header('From'), qr{Good Test User with Hiveminder}, 'message had the right from address');
is($assigned_mail->header("Subject"), "For you: Some task (#5)", "Right subject");
##is($assigned_mail->header("Sender"), "donotreply\@hiveminder.com", "Set the Sender header");

# hopefully this is flexible and rigorous at the same time.
like($assigned_mail->body(), qr{would like you to do something}, 'mail to new owner contains proper assignment text');
like($assigned_mail->body(), qr{With a description}, "assigned email had the right body text: task description");


# make sure that we get a daily reminder about tasks
BTDT::Test->setup_mailbox();
BTDT::Test->trigger_reminders();
@emails = BTDT::Test->messages;
is(scalar @emails, 1, "Daily reminder mail");
like($emails[0]->body, qr{Here's your daily}, "Got a reminder email");
like($emails[0]->header('Subject'), qr{Friday}, "included the date the mail is for");
is($emails[0]->header('To'), 'otheruser@example.com', "To address is correct");
unlike($emails[0]->header('Subject'), qr{nothing to do}, "Subject is correct");
like($emails[0]->body, qr{$URL/todo}, "Email contains a link to your todo list");
like($emails[0]->body, qr{Some task}, "It says there's 'Some task' to do (assigned but unaccepted yet)");
unlike($emails[0]->body, qr{Some task\n\s+Group:}s, "'Some task' is Personal and doesn't display a group in reminder mail");
unlike($emails[0]->body, qr{A group you can't see}, "No reminder task displays 'A group you can't see'");

like($emails[0]->body, qr{Tasks other people want you to do}, "Contains text about unaccepted tasks");
BTDT::Test->setup_mailbox();

# Comment on it.
update_task('Some task', comment => 'testing some other comment');

# Check comment notifications.
@emails = BTDT::Test->messages;
is(scalar @emails, 1, "Got one email comment");

my $comment_mail = $emails[-1] || Email::Simple->new('');
is($comment_mail->header("To"), 'otheruser@example.com', 'Comment email goes to right place');
like ($comment_mail->header('From'), qr{Good Test User with Hiveminder}, 'comment message had the right from address');
is($comment_mail->header("Subject"), "Comment: Some task (#5)", "Right subject");
#is($comment_mail->header("Sender"), "donotreply\@hiveminder.com", "comment mail set the Sender header");

my $comment2_re = qr{testing some other comment};
like($comment_mail->body(), $comment2_re, 'comment mail to new owner contains appropriate comment');

my $body = $comment_mail->body();
my @things = ($body =~ /$comment2_re/gs);
is(scalar @things, 2, "Comment 2 was found exactly twice, once for each part");

# ..and back in as new user
Jifty->web->current_user($otheruser_cu);

# Make sure we have the task
my $tasks = BTDT::Model::TaskCollection->new(current_user => $otheruser_cu);
$tasks->unlimit; # yes, we really want all rows
ok(@{$tasks->items_array_ref}, "We have a task");
is($tasks->items_array_ref->[0]->summary, 'Some task', 'We have Some task');

BTDT::Test->setup_mailbox();
# Add a comment 
update_task('Some task', comment => 'Some comment');

# Check that gooduser got it
@emails = BTDT::Test->messages;
is(scalar @emails, 1, "On a personal task, the commentor doesn't get mail but the requestor does, assuming they're different people");


$comment_mail = $emails[-1]  || Email::Simple->new('');
is($comment_mail->header("To"), 'gooduser@example.com', 'Email goes to right place');
like ($comment_mail->header('From'), qr{Other User with Hiveminder}, 'comment message for Some task had the right from address');
is($comment_mail->header("Subject"), "Comment: Some task (#5)", "Right subject");
like($comment_mail->body, qr/Some comment/, "Has the comment in the body");


# Mark it as completed
BTDT::Test->setup_mailbox();
update_task('Some task', complete => 1);

# Check that they got mail
@emails = BTDT::Test->messages;
is(scalar @emails, 1, "Got one more email");
my $complete_mail = $emails[-1];
is($complete_mail->header("To"), 'gooduser@example.com', 'Email goes to right place');

like ($complete_mail->header('From'), qr{Other User with Hiveminder}, 'Done message had the right from address');
is($complete_mail->header("Subject"), "Done: Some task (#5)", "Right subject");
like($complete_mail->body(), qr{has completed a task}, "Done email had the right body text: wording");
like($complete_mail->body(), qr{With a description}, "Done email had the right body text: task description");




# ===== BEGIN TESTS FOR GROUP TASKS ================================================

# ..and back in as original user
Jifty->web->current_user($gooduser_cu);

# clear the mailbox
BTDT::Test->setup_mailbox();
is(scalar BTDT::Test->messages(), 0, "Cleared out the mbox");

# Create a group
my $group_user = BTDT::CurrentUser->new( email => 'gooduser@example.com');
my $other_user = BTDT::CurrentUser->new( email => 'otheruser@example.com');
my $onlooking_user = BTDT::CurrentUser->new( email => 'onlooker@example.com');

ok($group_user->id, "Loaded user ".$group_user->id);
my $group = BTDT::Model::Group->new( current_user  => $group_user);
my $groupname = 'testgroup';
$group->create(name => $groupname);
ok($group->id, "Created group ".$group->id);
# Create an unowned group task as a group member
my $task = BTDT::Model::Task->new(current_user => $group_user);
my $summary1 = "Created by a good user in the group";
my $desc1 = "description here";
$task->create( group_id => $group->id, 
	       summary => $summary1,
	       description => $desc1,
	       owner_id => BTDT::CurrentUser->nobody->id);
ok($task->id,  "Created the task");
is ($task->requestor->id,$group_user->user_object->id);
@emails = BTDT::Test->messages;
is(scalar @emails, 0, "Sent no messages (the actor is the only group member)");



# add others to the group, make a task, see that both get mail
$group->add_member( $other_user->user_object => 'member');
$group->add_member( $onlooking_user->user_object => 'member');

my $task2 = BTDT::Model::Task->new(current_user => $group_user);
my $summary2 =  "Second task created by the same good user in the group";
my $desc2 = "description 2";
$task2->create( group_id => $group->id, summary => $summary2, 
		description => $desc2, owner_id => BTDT::CurrentUser->nobody->id);
ok($task2->id,  "Created the task");
is($task2->owner->id, BTDT::CurrentUser->nobody->id, "Created task belongs to nobody");
is($task2->group_id, $group->id, "Created task is in correct group");



@emails = BTDT::Test->messages;
is(scalar @emails, 2, "Sent one message to each of 2 other group members");

# Verify that I don't get mail but the group does
$assigned_mail = $emails[-2];

is($assigned_mail->header("To"), 'otheruser@example.com', 'Task-created email goes to right place');
like ($assigned_mail->header('From'), qr{Good Test User / testgroup with Hiveminder}, 'message had the right from address');
is($assigned_mail->header("Subject"), "Up for grabs: $summary2 (#7)", "Right subject");
#is($assigned_mail->header("Sender"), "donotreply\@hiveminder.com", "Set the Sender header");
like($assigned_mail->body(), qr{created a task and put it up for grabs}, 
     "up-for-grabs created email had the right body text: action request");
like($assigned_mail->body(), qr{$desc2}, "up-for-grabs email had the right body text: task description");
is($assigned_mail->header("X-Hiveminder-Group"), "testgroup", "Has X-Hiveminder-Group header");

$assigned_mail = $emails[-1];

is($assigned_mail->header("To"), 'onlooker@example.com', 'Task-created email goes to right place');
like ($assigned_mail->header('From'), qr{Good Test User / testgroup with Hiveminder}, 'message had the right from address');
is($assigned_mail->header("Subject"), "Up for grabs: $summary2 (#7)", "Right subject");
#is($assigned_mail->header("Sender"), "donotreply\@hiveminder.com", "Set the Sender header");
like($assigned_mail->body(), qr{created a task and put it up for grabs}, 
     "up-for-grabs created email had the right body text: action request");
like($assigned_mail->body(), qr{$desc2}, "up-for-grabs email had the right body text: task description");
is($assigned_mail->header("X-Hiveminder-Group"), "testgroup", "Has X-Hiveminder-Group header");


# clear the messages
BTDT::Test->setup_mailbox();

# Change the task owner to user otheruser
$mech->get($URL);
ok($mech->find_link(text => "Groups"), "Found groups link");
$mech->follow_link_ok(text => "Groups");
$mech->content_like(qr{$groupname}, 
		 "The $groupname group exists and I can see it");
$mech->follow_link_ok(text => "$groupname");
my $group_url = $mech->uri;
$mech->follow_link_ok(text => "All tasks");

$mech->content_like(qr{$summary2}, 
		 "The group task exists and I can see it");
$mech->follow_link_ok( text => $summary2);

$task = update_task($summary2, owner_id => $otheruser->email);
is($task->owner_id, $otheruser->id, "Owner was reassigned properly to otheruser");

@emails = BTDT::Test->messages;
is(scalar @emails, 2, "Sent one owner-changed message to each of 2 other group members");


$assigned_mail = $emails[-2] || Email::Simple->new('');

is($assigned_mail->header("To"), 'otheruser@example.com', 'Task-created email goes to right place');
like ($assigned_mail->header('From'), qr{Good Test User / testgroup with Hiveminder}, 'message had the right from address');

is($assigned_mail->header("Subject"), "For you: $summary2 (#7)", "Right subject for Assigned mails to other users");
#is($assigned_mail->header("Sender"), "donotreply\@hiveminder.com", "Set the Sender header");
like( $assigned_mail->body(), qr{would like you to do something}, 'mail to new owner contains proper text');
like($assigned_mail->body(), qr{$desc2}, "assigned-to-you email had the right body text: task description");
is($assigned_mail->header("X-Hiveminder-Group"), "testgroup", "Has X-Hiveminder-Group header");

$assigned_mail = $emails[-1] || Email::Simple->new('');
    
is($assigned_mail->header("To"), 'onlooker@example.com', 'Task-created email goes to right place');
like ($assigned_mail->header('From'), qr{Good Test User / testgroup with Hiveminder}, 'message had the right from address');
is($assigned_mail->header("Subject"), "For Other User: $summary2 (#7)", "Right subject for Assigned mails to other users");
like($assigned_mail->body(), qr{$desc2}, "assigned-to-someone-else email had the right body text: task description");
is($assigned_mail->header("X-Hiveminder-Group"), "testgroup", "Has X-Hiveminder-Group header");

#is($assigned_mail->header("Sender"), "donotreply\@hiveminder.com", "Set the Sender header");
like( $assigned_mail->body(), 
      qr{has asked Other User}, 
      'mail to others in group contains proper text.');


$mech->get($group_url);
$mech->follow_link_ok(text => "Up for grabs");

$mech->content_unlike(qr{$summary2}, "The group task was properly assigned away");

$mech->get($group_url);
$mech->follow_link_ok(text => "All tasks");
$mech->follow_link_ok(text => $summary1, "Link for $summary1 exists in group tasks");

BTDT::Test->setup_mailbox();

# mark the task completed
update_task($summary1, complete => 1);

# make sure that the requestor, owner, and group get mail.
@emails = BTDT::Test->messages;
is(scalar @emails, 2, "Sent one owner-changed message to each of 2 other group members");

my $completed_mail = $emails[-2] || Email::Simple->new('');

is($completed_mail->header("To"), 'otheruser@example.com', 'Task-created email goes to right place');
like ($completed_mail->header('From'), qr{Good Test User / testgroup with Hiveminder}, 'message had the right from address');

is($completed_mail->header("Subject"), "Done: $summary1 (#6)", "Right subject for Done mails to other users");
#is($completed_mail->header("Sender"), "donotreply\@hiveminder.com", "Set the Sender header");
like( $completed_mail->body(), qr{has completed}, 'Done mail to group contains proper text');
like($completed_mail->body(), qr{$desc1}, "done email had the right body text: task description");
is($assigned_mail->header("X-Hiveminder-Group"), "testgroup", "Has X-Hiveminder-Group header");

$completed_mail = $emails[-1] || Email::Simple->new('');
    
is($completed_mail->header("To"), 'onlooker@example.com', 'Task-created email goes to right place');
like ($completed_mail->header('From'), qr{Good Test User / testgroup with Hiveminder}, 'message had the right from address');
is($completed_mail->header("Subject"), "Done: $summary1 (#6)", "Right subject for Done mails to other users");
#is($completed_mail->header("Sender"), "donotreply\@hiveminder.com", "Set the Sender header");
like( $completed_mail->body(), qr{has completed}, 'Done mail to group contains proper text');
like($completed_mail->body(), qr{$desc1}, "done email had the right body text: task description");
is($assigned_mail->header("X-Hiveminder-Group"), "testgroup", "Has X-Hiveminder-Group header");


# XXX add tests for declined tasks and their associated mails, like in t/24
# XXX TaskTaken, TaskOutOfGroup, TaskIntoGroup

# Log out
ok($mech->find_link( text => "Logout" ), "Found logout link");
$mech->follow_link_ok( text => "Logout" );




# ---------
# an elaborate test to make sure that tasks with but-firsts aren't being shown
# in the daily reminder.
BTDT::Test->setup_mailbox();

$mech = BTDT::Test->get_logged_in_mech($URL);
# make sure that the default tasks #2 and #1 are in a butfirst relationship,
# so we can make sure that users aren't being reminded about tasks that are
# waiting on the completion of some other task.
$mech->get_ok($URL);

ok($mech->find_link( text => "01 some task" ), "Task 01 is on gooduser's todo");
$mech->follow_link_ok( text => "01 some task" );

# id 2 / rl 4 should depend on id 1 / RL 3; "task 2, but first task 1"
$mech->fill_in_action_ok('depends_on-new_item_create', summary => '#4');
$mech->submit_html_ok();
$mech->content_contains('02 other task', 'Page contains the dependency');

# change the owner of task 1, so that otheruser would stand to get mail about it.
update_task('01 some task', owner_id => $otheruser->email);

# now, change the owner of task 2, so that otheruser would stand to get mail about it.
update_task('02 other task', owner_id => $otheruser->email);

# XXX TODO: we should test this to see how it behaves when some other user owns
# the butfirst tasks.

# So now the tasks are unaccepted but belong to otheruser.
BTDT::Test->setup_mailbox(); 
BTDT::Test->trigger_reminders();
@emails = BTDT::Test->messages;
is(scalar @emails, 1, "Daily reminder mail, before task acceptance");
like($emails[0]->body, qr{Here's your daily}, "Got a reminder email");
is($emails[0]->header('To'), 'otheruser@example.com', "To address is correct");
unlike($emails[0]->header('Subject'), qr{nothing to do}, "Subject is correct");
unlike($emails[0]->body, qr{01 some task}, "01 some task doesn't show up (is an and-then)");

like($emails[0]->body, qr{Second task created by the same good user in the group}, "'Second task...' shows up in the reminder mail");
like($emails[0]->body, qr{Second task.*\n\s+Group: testgroup}s, "'Second task...' displays a group in reminder mail");
unlike($emails[0]->body, qr{A group you can't see}, "No reminder task displays 'A group you can't see'");
# XXX check to make sure all unaccepted tasks are showing up, waiting to be accepted

# Log out and log back in as otheruser
$mech = BTDT::Test->get_logged_in_mech($URL, 'otheruser@example.com', 'something');

# Accept 
$mech->accept_task_ok( '01 some task');
$mech->accept_task_ok( '02 other task');
# Complete so that it won't show up in the daily reminder as a unaccepted task
$mech->accept_task_ok( 'Second task created by the same good user in the group');

# Check reminders now that the tasks are accepted.
BTDT::Test->setup_mailbox();
BTDT::Test->trigger_reminders();
@emails = BTDT::Test->messages;
is(scalar @emails, 1, "Daily reminder mail, before task acceptance");
like($emails[0]->body, qr{Here's your daily}, "Got a reminder email");
is($emails[0]->header('To'), 'otheruser@example.com', "To address is correct");
unlike($emails[0]->header('Subject'), qr{nothing to do}, "Subject is correct");
unlike($emails[0]->body, qr{01 some task}, "01 some task doesn't show up (is an and-then)");
like($emails[0]->body, qr{02 other task}, "02 other task shows up (is a but-first for 01)");

# make sure there's no list of unaccepted tasks here
unlike($emails[0]->body, qr{Tasks other people want you to do}, "Email doesn't contain text about unaccepted tasks");



#Mark the but-first task done and make sure that reminders DTRT
update_task('02 other task', complete => 1);

BTDT::Test->setup_mailbox();
BTDT::Test->trigger_reminders();
@emails = BTDT::Test->messages;
is(scalar @emails, 1, "Daily reminder mail, before task acceptance");
like($emails[0]->body, qr{Here's your daily}, "Got a reminder email");
is($emails[0]->header('To'), 'otheruser@example.com', "To address is correct");
unlike($emails[0]->header('Subject'), qr{nothing to do}, "Subject is correct");
like($emails[0]->body, qr{01 some task}, 
       "01 some task shows up (is an and-then with completed but-first)");
unlike($emails[0]->body, qr{02 other task}, 
       "02 other task doesn't show up (because it's done)");


#======================================================================
# Make sure declined tasks aren't getting sent along in the daily reminder.

# Log out and log back in as gooduser
ok($mech->find_link( text => "Logout" ), "Found logout link");
$mech->follow_link_ok( text => "Logout" );
$mech = BTDT::Test->get_logged_in_mech($URL);

# Create a task
$mech->fill_in_action_ok('tasklist-new_item_create', 
			 summary => "Decline me", 
			 description => "testy");
$mech->submit_html_ok();

# Change the owner.
update_task("Decline me", owner_id => $otheruser->email);

# Check to make sure that unaccepted tasks show up in reminder mail.
BTDT::Test->setup_mailbox();
BTDT::Test->trigger_reminders();
@emails = BTDT::Test->messages;
is(scalar @emails, 1, "Daily reminder mail");
like($emails[0]->body, qr{Here's your daily}, "Got a reminder email");
is($emails[0]->header('To'), 'otheruser@example.com', "To address is correct");
unlike($emails[0]->header('Subject'), qr{nothing to do}, "Subject is correct");
like($emails[0]->body, qr{Decline me}, 
       "Requested task ('Decline me') shows up in reminder mail");
unlike($emails[0]->body, qr{Your tasks.*Decline me}s, 
       "Unaccepted task ('Decline me') doesn't show up in non-unaccepted section of reminder mail");

# Log out and log back in as otheruser
ok($mech->find_link( text => "Logout" ), "Found logout link");
$mech->follow_link_ok( text => "Logout" );

$mech = BTDT::Test->get_logged_in_mech($URL, 'otheruser@example.com', 'something');

BTDT::Test->setup_mailbox();
$mech->decline_task_ok( "Decline me");
ok($mech->find_link( text => "Logout" ), "Found logout link");
$mech->follow_link_ok( text => "Logout" );

# make sure that the task's ownership was bounced back to the assigner

@emails = BTDT::Test->messages;
is(scalar @emails, 1, "Sent 1 mail about a declined task");
is($emails[0]->header('To'), 'gooduser@example.com', "To address is correct");
like ($emails[0]->header('From'), qr{Other User with Hiveminder}, 'message had the right from address');
is($emails[0]->header("Subject"), "Declined: Decline me (#8)", "'Declined' mail with proper subject");


$mech = BTDT::Test->get_logged_in_mech($URL);
$mech->follow_link_ok( text => 'unaccepted task' );

ok($mech->find_link( text => "Decline me" ), 
   "'Decline me' task is on gooduser's unaccepted list after it was declined");

$task = BTDT::Model::Task->new();
$task->load_by_cols(summary => 'Decline me');
is($task->owner_id, $gooduser->id, 'After decline, owner was reassigned properly to assigner gooduser@example.com');

BTDT::Test->setup_mailbox();
BTDT::Test->trigger_reminders();
@emails = BTDT::Test->messages;
is(scalar @emails, 1, "Daily reminder mail, after task was declined");
like($emails[0]->body, qr{Here's your daily}, "Got a reminder email");
is($emails[0]->header('To'), 'otheruser@example.com', "To address is correct");
unlike($emails[0]->header('Subject'), qr{nothing to do}, "Subject is correct");
unlike($emails[0]->body, qr{Decline me}, 
       "Declined task doesn't show up in reminder mail");



#======================================================================

sub update_task {
    my $summary = shift;

    Jifty->web->response(Jifty::Response->new);
    Jifty->web->request(Jifty::Request->new);

    my $task = BTDT::Model::Task->new();
    $task->load_by_cols(summary => $summary);

    my $update = BTDT::Action::UpdateTask->new(arguments => {id => $task->id, @_});
    ok $update->validate, "task update input validated";
    $update->run;
    my $result = $update->result;
    ok $result->success, "task update ran successfully";

    return $task
}

1;


