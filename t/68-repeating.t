use warnings;
use strict;

=head1 DESCRIPTION

This is a template for your own tests. Copy it and modify it.

=cut

use BTDT::Test tests => 82;

ok(1, "Loaded the test script");

my $server = BTDT::Test->make_server;
my $URL = $server->started_ok;

use_ok('BTDT::Model::TaskCollection');
use_ok('BTDT::ScheduleRepeats');


my $gooduser = BTDT::CurrentUser->new(email => 'gooduser@example.com');

# Create a task "Pay Rent", tagged [money]. Set its due date for 1 Jan 2005
my $task = BTDT::Model::Task->new(current_user => $gooduser);
$task->create( summary => 'Pay Rent', tags => 'money', due => '2005-01-01');
ok($task->id, $task->summary);
is($task->tags, 'money');
is ($task->due, '2005-01-01');


# Set it to recur every month
$task->set_repeat_period('months');
$task->set_repeat_every(1);
$task->set_repeat_stacking(1);
$task->set_repeat_days_before_due(5);

is($task->repeat_period,'months');
is($task->repeat_every,'1');
is($task->repeat_stacking,1);
is ($task->repeat_days_before_due, 5);
is ($task->last_repeat->id, $task->id, "We got the last_repeat set right");
is ($task->repeat_of->id, $task->id, "we got the repeat_of set right");

my $create_on = DateTime->new( year=> 2005, month => 2, day => 1);
$create_on = $create_on->subtract(days => 5);
$task->load($task->id); # Get the updated properties
is ($task->repeat_next_create->ymd, $create_on->ymd);



{

# Run the recurrence scheduler
ok(BTDT::ScheduleRepeats->new->run(skip_time_zone => 1));

# verify that there is a "Pay rent" due 1 Feb 2005
my $feb = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$feb->from_tokens(qw(due 2005-02-01));
is($feb->count,1, q{created one!});
my $feb_due = $feb->first;
is($feb->first->tags , 'money', "Tags repeat!");

# Verify that there are only two "pay rent" tasks
my $tasks = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$tasks->from_tokens(qw(summary rent));
is($tasks->count, 2);
}

{

# Run the recurrence scheduler
ok(BTDT::ScheduleRepeats->new->run(skip_time_zone => 1));

# verify that there is a "Pay rent" due 1 Feb 2005
my $new = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$new->from_tokens(qw(due 2005-03-01));
is($new->count,1, q{created one!});

# Verify that there are only 3 "pay rent" tasks
my $tasks = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$tasks->from_tokens(qw(summary rent));
is($tasks->count, 3);
}

# 


# Delete the first pay rent task

$task->delete();
{

# Run the recurrence scheduler
ok(BTDT::ScheduleRepeats->new->run(skip_time_zone => 1));

# verify that there is a "Pay rent" due 1 Mar 2005
my $new = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$new->from_tokens(qw(due 2005-03-01));
is($new->count,1, q{Most recent still there} );

# Verify that there are only 2 "pay rent" tasks
my $tasks = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$tasks->from_tokens(qw(summary rent));
is($tasks->count, 2, "Didn't create another one, once we lobotomized the master");
}


{
# Create a task "Pay Rent on the Moon", tagged [money]. Set its due date for 1 Jan 2030
my $task = BTDT::Model::Task->new(current_user => $gooduser);
$task->create( summary => 'Pay Rent on the Moon', tags => 'money', due => '2030-01-01');
ok($task->id, $task->summary);
is($task->tags, 'money');
is ($task->due, '2030-01-01');


# Set it to recur every month
# Set it to recur every month
$task->set_repeat_period('months');
$task->set_repeat_every(1);
$task->set_repeat_stacking(1);
$task->set_repeat_days_before_due(5);

# Make sure we have only one  "Pay Rent on the Moon"
my $old = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$old->from_tokens(qw(summary Moon));
is($old->count(), 1, "After scheduling, still just 1");
# Run the recurrence scheduler
ok(BTDT::ScheduleRepeats->new->run(skip_time_zone => 1));

# Make sure we have only one  "Pay Rent on the Moon"
my $new = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$new->from_tokens(qw(summary Moon));
is($new->count(), 1, "After scheduling, still just 1");
}


{
# Create a task "Water the Dog", tagged [pets]. Set its due date for 1 Jan 2001
my $task = BTDT::Model::Task->new(current_user => $gooduser);
$task->create( summary => 'Water the Dog', tags => 'pets', due => '2001-01-01');
ok($task->id, $task->summary);
is($task->tags, 'pets');
is ($task->due, '2001-01-01');


# Set it to recur every month
$task->set_repeat_period('months');
$task->set_repeat_every(1);
# Turn off stacking
$task->set_repeat_stacking('0');
$task->set_repeat_days_before_due(40);

{
# Make sure we have only one  "Water the Dog"
my $old = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$old->from_tokens(qw(summary Dog));
is($old->count(), 1, "Before scheduling, we have only 1");
}
# Run the recurrence scheduler
ok(BTDT::ScheduleRepeats->new->run(skip_time_zone => 1));
ok(BTDT::ScheduleRepeats->new->run(skip_time_zone => 1));
{
# Make sure we still have only one  "Water the Dog", since we repeated before it was done
my $postsched = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$postsched->from_tokens(qw(summary Dog));
is($postsched->count(), 1, "After scheduling, still just 1");
}

$task->set_complete('true');
ok(BTDT::ScheduleRepeats->new->run(skip_time_zone => 1));


# Make sure we have two  "Water the Dog"
my $new = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$new->from_tokens(qw(summary Dog));
is($new->count(), 2, "After scheduling, we have two");

ok(BTDT::ScheduleRepeats->new->run(skip_time_zone => 1));

# Make sure we have two  "Water the Dog"
my $seconduncomplete = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$seconduncomplete->from_tokens(qw(summary Dog));
is($seconduncomplete->count(), 2, "After scheduling, we have two");

while (my $item = $new->next) { 
    $item->set_complete(1);
    ok($item->complete);
}

ok(BTDT::ScheduleRepeats->new->run(skip_time_zone => 1));

# Make sure we have three  "Water the Dog"
my $thirduncomplete = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$thirduncomplete->from_tokens(qw(summary Dog));
is($thirduncomplete->count(), 3, "After completing the first two and then rescheduling, we have 3");

# Change the task to be scheduled only once, make sure it isn't repeated
{
    my ($task) = grep { !$_->complete } @{ $thirduncomplete->items_array_ref };
    ok($task, "we have an incomplete task");

    $task->set_repeat_period('once');
    $task->set_complete(1); # this task isn't stacking
}

ok(BTDT::ScheduleRepeats->new->run(skip_time_zone => 1));

my $after_unschedule = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$after_unschedule->from_tokens(qw(summary Dog));
is($after_unschedule->count(), 3, "Rescheduling a task to once stops it from repeating");
}

# test through the web interface too
my $mech = BTDT::Test->get_logged_in_mech($URL);

isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->content_like(qr/Logout/i,"Logged in!");

$mech->fill_in_action_ok("tasklist-new_item_create",
                         summary => "collect chicken eggs",
                         due => '2006-11-15');
$mech->submit_html_ok();
like($mech->uri, qr|/todo|, "Back at inbox");
$mech->content_contains('collect chicken eggs');
$mech->follow_link_ok( text => "collect chicken eggs" );
$mech->fill_in_action_ok( $mech->moniker_for("BTDT::Action::UpdateTask"),
                          repeat_period   => 'days',
                          repeat_every    => 1,
                          repeat_stacking => 1);
$mech->click_button( value => 'Save' );
like($mech->uri,qr{/todo},"Redirected to inbox");
$mech->content_contains('updated');

ok(BTDT::ScheduleRepeats->new->run(skip_time_zone => 1));

my $chicken_tasks = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$chicken_tasks->from_tokens(qw(summary chicken not complete));
is($chicken_tasks->count(), 2, "After turning on repeat and rescheduling, we have 2 tasks");

$mech->follow_link_ok( text => "To Do" ); 
$mech->follow_link_ok( text => "collect chicken eggs" , n => 2 );
$mech->fill_in_action($mech->moniker_for('BTDT::Action::UpdateTask'),
                      complete=>1);
$mech->click_button( value => 'Save' ); 
$mech->content_contains("Task 'collect chicken eggs' updated");

$chicken_tasks->from_tokens(qw(summary chicken not complete));
is($chicken_tasks->count(), 1, "After collecting eggs, we have one task");

{
# Create a Clean the litterbox task and use it to check that
# changes to repeated tasks affect the master task that stores all
# the repeating metadata
my $task = BTDT::Model::Task->new(current_user => $gooduser);
$task->create( summary => 'Clean the litterbox', due => '2001-01-01');
ok($task->id, $task->summary);
is ($task->due, '2001-01-01');

# set it to recur every 5 days, but to stack
$task->set_repeat_period('days');
$task->set_repeat_every(5);
$task->set_repeat_stacking('1');
$task->set_repeat_days_before_due(2);

{
# Make sure we have only one  "Clean the litterbox"
my $old = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$old->from_tokens(qw(summary litterbox));
is($old->count(), 1, "Before scheduling, we have only 1");
}
# Run the recurrence scheduler
ok(BTDT::ScheduleRepeats->new->run(skip_time_zone => 1));
{
# Make sure we have two tasks, since we're stacking
my $postsched = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$postsched->from_tokens(qw(summary litterbox));
is($postsched->count(), 2, "After scheduling, we have two tasks");

# make sure we copied data forward from the master task
my $repeated_task = $postsched->last;
foreach my $attr (qw(repeat_period repeat_every repeat_stacking repeat_days_before_due)) {
    is($repeated_task->$attr,$task->$attr,"$attr copied correctly");
}

# clean up our two tasks
foreach my $t ($task, $repeated_task) {
    $t->set_complete(1);
    ok($t->complete);
}

}

ok(BTDT::ScheduleRepeats->new->run(skip_time_zone => 1));

# Make sure we have three  "Clean the litterbox" tasks 
my $third_repeat = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$third_repeat->from_tokens(qw(summary litterbox));
is($third_repeat->count(), 3, "After completing the first two and then rescheduling, we have 3");

my $recent_repeat = $third_repeat->last;
isnt($recent_repeat->complete,"Last task is the new uncompleted one");

# check that setting parameters on the new task percolates back to the master task

$recent_repeat->set_repeat_period('weeks');
$recent_repeat->set_repeat_every(9);
$recent_repeat->set_repeat_stacking(0);
$recent_repeat->set_repeat_days_before_due(19);

my $master_task = $recent_repeat->repeat_of;

foreach my $attr (qw(repeat_period repeat_every repeat_stacking repeat_days_before_due)) {
    is($recent_repeat->$attr,$master_task->$attr,"$attr copied back to the master correctly");
}

}

# TODO
# tests that actually check that we do sane things like repeat in two weeks 
# using the timeframe of the test run, rather than using dates far in the past 
# (always trigger a repeat) or far in the future (never repeat)
1;
