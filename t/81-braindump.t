use warnings;
use strict;

# {{{ Setup
use BTDT::Test tests => 166;

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;

my $Class = 'BTDT::Action::ParseTasksMagically';
require_ok $Class;

my $gooduser = BTDT::CurrentUser->new( email => 'gooduser@example.com' );
my $admin    = BTDT::CurrentUser->superuser;
ok $gooduser;
Jifty->web->current_user($gooduser);

my $mech = BTDT::Test->get_logged_in_mech($URL);

isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->content_like(qr/Logout/i,"Logged in!");

my $tasks;
# }}}

# XXX this is done with Mech right now, but in an ideal world we'll
# be dual-testing it with Selenium too.

like($mech->uri, qr{/todo}i, "Redirected to the inbox"); 

# Test braindump from todo list
$mech->fill_in_action_ok('quickcreate', text => 'This is a test [of tags] not_a_tag');
$mech->click_button(value => 'Create');

$mech->content_contains('1 task created', 'braindumped from todo list');
$mech->content_contains('This is a test not_a_tag', 'Created a task') ;
$mech->content_lacks("This is a test [of tags] not_a_tag", 'Task name is correct');

# XXX WTF is this warning about the link not being found, but the test passes?
$mech->follow_link_ok(text => "This is a test not_a_tag");


is($mech->action_field_value($mech->moniker_for("BTDT::Action::UpdateTask"), 'tags'),
       'of tags', 'tags are right');

my ($today, $tomorrow, $today_datetime);
{ use DateTime; 
  $today_datetime = DateTime->now;
  $today_datetime->set_time_zone('America/New_York');
  $today = $today_datetime->ymd;
  my $dt2 = DateTime->now;
  $dt2->set_time_zone('America/New_York');
  $dt2->add (days => 1);
  $tomorrow = $dt2->ymd;
}

my @tasks;

@tasks = braindump_tasks_api("Do this today");
@tasks = grep {$_->summary =~ /Do this today/} @tasks;
is(@tasks, 1, 'Created Do this today');
is($tasks[0]->due, $today, "Due date for 'Do something today' is today");

@tasks = braindump_tasks_api("Do something tonight");
@tasks = grep {$_->summary =~ /Do something tonight/} @tasks;
is(@tasks, 1, 'Created Do something tonight');
is($tasks[0]->due, $today, "Due date for 'Do something tonight' is today");

@tasks = braindump_tasks_api("Release HTTP::Proxy 0.20");
@tasks = grep {$_->summary =~ /Release HTTP::Proxy/} @tasks;
is(@tasks, 1, 'Created Release HTTP::Proxy 0.20 task');
isnt($tasks[0]->due, '1920-01-01', "Due date for Release HTTP::Proxy 0.20 isn't inappropriately set");

@tasks = braindump_tasks_api("Do something when r4865 goes live");
@tasks = grep {$_->summary =~ / r4865 /} @tasks;
is(@tasks, 1, "Task parses 'when r4865 goes live' correctly") ;

# This is what glasser reported was showing up.
isnt($tasks[0]->due, '1969-12-31', "Due date for 'Do something when r4865 goes live' isn't inappropriately set");

is($tasks[0]->due, undef, "Due date for 'Do something when r4865 goes live' is blank");

# Make sure that the example we give next to braindump is actually parsing properly
@tasks = braindump_tasks_api('Pay off kidnappers! [personal money "under the table"] tomorrow');
@tasks = grep {$_->summary =~ /Pay off kidnappers/} @tasks;
unlike($tasks[0]->summary, qr/Pay off kidnappers \[personal money/, 'Created Pay off kidnappers task without totally broken parsing') ;
is($tasks[0]->tags, 'money personal "under the table"', "Tags as documented in braindump syntax are correct");
is($tasks[0]->due, $tomorrow, "Due date for 'Pay off kidnappers' is tomorrow");
is($tasks[0]->priority, 4, "Priority for 'Pay off kidnappers' is 4 (high)");

#----------
# Make sure that the example from the docs parses properly
my $example = <<ENDME;
plan wedding!! [personal] tomorrow
  fun stuff to figure out
+order flowers [personal "dave and sarah"]
ENDME

@tasks = braindump_tasks_api($example, 2);
@tasks = grep {$_->summary =~ /plan wedding|order flowers/} @tasks;
is(@tasks, 2, "Created two tasks in one braindump");
is($tasks[0]->tags, 'personal', 'Tags as documented in braindump syntax are correct');
is($tasks[0]->due, $tomorrow, "Due date for 'plan wedding' is tomorrow");
is($tasks[0]->priority, 5, "Priority for 'plan wedding' is 5 (highest)");
is($tasks[1]->tags, '"dave and sarah" personal', "Tags as documented in braindump syntax are correct");
is($tasks[1]->priority, 4, "Priority for 'order flowers' is 4 (high)");

@tasks = braindump_tasks_api("Do this tomorrow");
@tasks = grep {$_->summary =~ /Do this tomorrow/} @tasks;
is(@tasks, 1, "Created Do this tomorrow");

# XXX: replace with mocktime?
my $date = $tasks[0]->due;
if ($date =~ /^(....)-(..)-(..)/) {
    my $dt = DateTime->new(year => $1, month => $2, day => $3);
    ok($dt > $today_datetime, "$dt is after $today_datetime");
} else {
    ok(0, "Couldn't parse $date");
}
     
#test the various magic syntax you can use to set properties of tasks
@tasks = braindump_tasks_api("Order Bobby's cake [due: tomorrow] [family] [owner: bobby\@example.com]");
@tasks = grep {$_->summary =~ /Order Bobby's cake/} @tasks;
is(@tasks, 1, "Created Order Bobby's cake");
is($tasks[0]->summary, "Order Bobby's cake", "All tags are removed properly");
is($tasks[0]->due, $tomorrow, "'due' syntax works in braindump");

my $bobby = BTDT::Model::User->new( current_user => $gooduser );
$bobby->load_by_cols( id => $tasks[0]->owner_id);

is($bobby->email, 'bobby@example.com', "'owner' syntax works in braindump");
is($tasks[0]->tags, 'family', "Tags mixed with magic braindump syntax are correct");

# test that owner "me" works
@tasks = braindump_tasks_api("Order fish [owner: me]");
@tasks = grep {$_->summary =~ /Order fish/} @tasks;
is(@tasks, 1, "Created Order fish");
is($tasks[0]->summary, "Order fish", "All tags are removed properly");

my $ourguy = BTDT::Model::User->new( current_user => $gooduser );
$ourguy->load_by_cols( id => $tasks[0]->owner_id );

is($ourguy->email, 'gooduser@example.com', "'owner' syntax works in braindump");

# test hide until and priority
my $iter = 0;
my $buy_presents = << 'PRESENTS';
Buy presents [hide until: tomorrow] [priority: highest]
Buy presents [hide: tomorrow] [priority: 5]
Buy presents [starts: tomorrow] [priority: Highest]
PRESENTS

@tasks = braindump_tasks_api($buy_presents, 3);
@tasks = grep {$_->summary =~ /Buy presents/} @tasks;
is(@tasks, 3, "Created three buy presents tasks");
for (@tasks)
{
    is($_->starts, $tomorrow, "'hide until' syntax works in braindump");
    is($_->priority, 5, "'priority' syntax works in braindump");
}

# make a group we can use for testing braindumping into a group
# and braindumping while within a group screen
$mech->get_ok("$URL/groups");
$mech->follow_link_ok(text => 'New group');
$mech->content_contains("Create", 'got group page');
$mech->fill_in_action_ok('newgroup',
    name => 'guards',
    description => 'Guards! Guards!'
);
$mech->submit_html_ok;
$mech->content_contains('guards','Created guards group');

my $guard_group = BTDT::Model::Group->new( current_user => $gooduser );
$guard_group->load_by_cols( name => 'guards' );

ok( defined $guard_group->id, "guards Group exists" );

@tasks = braindump_tasks_api('fetchez la vache [by: guard@example.com] [group: guards]');
@tasks = grep {$_->summary =~ /fetchez la vache/} @tasks;
is(@tasks, 1, "Created fetchez la vache task");

my $guard = BTDT::Model::User->new( current_user => $gooduser );
$guard->load_by_cols( id => $tasks[0]->owner_id);

is($guard->email, 'guard@example.com', "'by' as a synonym for 'owner' works in braindump");
is($tasks[0]->group_id, $guard_group->id, "'group' syntax works in braindump");

# test that owner "nobody" works in groups
@tasks = braindump_tasks_api("Order tacos [owner: nobody] [group: guards]");
@tasks = grep {$_->summary =~ /Order tacos/} @tasks;
is(@tasks, 1, "Created Order tacos");
is($tasks[0]->summary, "Order tacos", "All tags are removed properly");

my $noone = BTDT::Model::User->new( current_user => $gooduser );
$noone->load_by_cols( id => $tasks[0]->owner_id );

is($noone->email, 'nobody', "'owner' syntax works in braindump");


# XXX should test that braindumping using the link under a set of Group tabs
# creates tasks in that group, and that [group: Personal] overrides creating
# tasks in the current group

# if a user sends the same special syntax multiple times, we prefer their last one
@tasks = braindump_tasks_api("Buy OJ [hide: friday] [priority: low] [starts: monday] [prio: high] [hide until: tomorrow]");
@tasks = grep {$_->summary =~ /Buy OJ/} @tasks;
is(@tasks, 1, "Created Buy OJ task");
is($tasks[0]->starts, $tomorrow, "repeated 'starts' syntax works in braindump");
is($tasks[0]->priority, 4, "repeated 'priority' syntax works in braindump");

# check that we handle tags using syntax keywords properly
# we also should support colonless keywords
@tasks = braindump_tasks_api( "Frobnicate the widget [due: yesterday] [due] [priority] [due tomorrow]");
@tasks = grep {$_->summary =~ /Frobnicate the widget/} @tasks;
is(@tasks, 1, "Created Frobnicate task");
is($tasks[0]->due, $tomorrow, "colonless syntax works in braindump");
is($tasks[0]->tags, 'due priority', "syntax without values isn't consumed in braindump");

@tasks = braindump_tasks_api("Handle spaces [ due tomorrow]");
@tasks = grep {$_->summary =~ /Handle spaces/} @tasks;
is(@tasks, 1, "Created Handle spaces task");
is($tasks[0]->due, $tomorrow, "extraneous spaces don't break keywords in braindump");

@tasks = braindump_tasks_api("Handle repeated keywords [due ] [for tomorrow]");
@tasks = grep {$_->summary =~ /Handle repeated keywords/} @tasks;
is(@tasks, 1, "Created Handle repeated keywords task");
is($tasks[0]->tags, 'due for tomorrow', "repeated keywords aren't parsed as one giant keyword (found multiple tags)");
is($tasks[0]->due, undef, "repeated keywords aren't parsed as one giant keyword (no due date found)");

# check that we're parsing absolute dates properly
@tasks = braindump_tasks_api("plan xmas [due: 12/24/2009]");
@tasks = grep {$_->summary =~ /plan xmas/} @tasks;
is(@tasks, 1, "Created plan xmas task");
is($tasks[0]->due, '2009-12-24', "due in the far futures works in braindump");

# Check that bogus priorities don't drop the task on the ground
@tasks = braindump_tasks_api("Do something novel [prio: moose]");
@tasks = grep {$_->summary =~ /Do something novel/} @tasks;
is(@tasks, 1, "Created Do something novel");
is($tasks[0]->priority, 3, "Defaults to normal level");

# Also can't get priorities higher or lower than 5 and 1
@tasks = braindump_tasks_api("Really important [prio: 4857434]");
@tasks = grep {$_->summary =~ /Really important/} @tasks;
is(@tasks, 1, "Created Really important");
is($tasks[0]->priority, 5, "No higher than 5");

@tasks = braindump_tasks_api("Really not important [prio: 0]");
@tasks = grep {$_->summary =~ /Really not important/} @tasks;
is(@tasks, 1, "Created Really not important");
is($tasks[0]->priority, 1, "No lower than 1");

@tasks = braindump_tasks_api("Tags [mixed] with [text]");
@tasks = grep {$_->summary =~ /Tags with/} @tasks;
is(@tasks, 1, "Created Tags with (mixed in text)");
is($tasks[0]->tags, "mixed text", "Tags mixed in with text are properly parsed out");

@tasks = braindump_tasks_api("3353 and other four digit numbers confuse our date parsing");
@tasks = grep {$_->summary =~ /3353 and other four digit numbers/} @tasks;
is(@tasks, 1, "Created 3353 and other four digit numbers...");
is($tasks[0]->due, undef, "Correctly ignored numbers that confuse our parsers");

@tasks = braindump_tasks_api("This task is important and has mixed case [Priority: Higher]");
@tasks = grep {$_->summary =~ /This task is important and has mixed case/} @tasks;
is(@tasks, 1, "Created This task .. has mixed case");
is($tasks[0]->priority, "4", "Correctly parsed mixed case braindump syntax");

@tasks = braindump_tasks_api("This task is in a group via tokens", 1, "group guards");
@tasks = grep {$_->summary =~ /This task is in a group via tokens/} @tasks;
is(@tasks, 1, "Created a task in guards");
is($tasks[0]->group->name, "guards", "created a task in a group via tokens");

@tasks = braindump_tasks_api("let's test [hide: forever]", 1, "hide forever");
@tasks = grep {$_->summary =~ /let's test/} @tasks;
is(@tasks, 1, "Created a task");
ok(!$tasks[0]->will_complete, "task is hidden forever");

#===============================================================================
# make tasks from the homepage, with optional task counting. You'll
# need to do task content verification separately.
# no longer used!
sub braindump_tasks {
    my $m = shift;
    my $text = shift;
    my $numtasks = shift || 1;

    $m->get_ok($URL, "going back to todo list");
    $m->fill_in_action_ok('quickcreate', text => $text);
    $m->click_button(value => 'Create');

    if ($numtasks == 1) {
	$m->content_contains("1 task created", "braindumped from todo list and made 1 task");
    } else {
	$m->content_contains("$numtasks tasks created", "braindumped from todo list and made $numtasks tasks");
    }
}

#===============================================================================
# make tasks with the API, with optional task counting.
# returns all the tasks so you can grep out just the ones you want to look at
# the grepping should be a part of the subroutine but it's difficult to make
# sure there are no collisions and whatnot
sub braindump_tasks_api {
    my $text     = shift;
    my $numtasks = shift || 1;
    my $tokens   = shift || '';

    Jifty->web->response(Jifty::Response->new);
    Jifty->web->request(Jifty::Request->new);

    my $braindump = $Class->new(
        arguments => {
            text        => $text,
            tokens      => $tokens,
        }
    );

    ok $braindump->validate;
    $braindump->run;
    my $result = $braindump->result;
    ok $result->success;

    if ($numtasks == 1) {
        like($result->message, qr/\b1 task created/, "braindumped from todo list and made 1 task");
    } else {
        like($result->message, qr/\b$numtasks tasks created/, "braindumped from todo list and made $numtasks task");
    }

    my $tasks = BTDT::Model::TaskCollection->new(current_user => $gooduser);
    $tasks->unlimit; # yes, we really want all rows
    return @{$tasks->items_array_ref};
}

