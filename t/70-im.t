use warnings;
use strict;

use BTDT::Test tests => 1872;
use BTDT::Test::IM;
our ($group1, $spectre);

my $gooduser = BTDT::CurrentUser->new( email => 'gooduser@example.com'  );
$gooduser->user_object->set_per_page(10);

my $response = msg("Test   er", "hello");
like($response, qr/hiveminder\.com/, "cold response mentions hiveminder.com");
like($response, qr/privacy policy/, "cold response mentions privacy policy (AOL requirement)");

my $userim = BTDT::Model::UserIM->new(current_user => BTDT::CurrentUser->superuser);
my ($val, $msg) = $userim->create(user_id => $gooduser->id);
ok($val,$msg);
my $auth_token = $userim->auth_token;
ok(length($auth_token) > 3, "auth token '$auth_token'  greater than 3 chars long (very low standards!)");

$response = msg("TESTER", $auth_token);
like($response, qr/Hooray!/, "successfully authed");
like($response, qr/create/, "auth message includes a bare list of commands");
like($response, qr/help/, "auth message includes mention of help command");
like($response, qr/privacy policy/, "auth mentions privacy policy (AOL requirement)");

# screenname for im_like
$BTDT::Test::IM::screenname = 'tester';

my $name = $gooduser->user_object->name;
like($response, qr/\Q$name\E/, "auth includes user's name");

$response = msg("t e s t e r", "create this is an IM create!");
like($response, qr/Created 1 task/, "response includes task creation");
like($response, qr/<#5>/, "response includes record locator");

my $tasks = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$tasks->unlimit; # yes, we really want all rows
my @tasks = grep {$_->summary =~ /IM/} @{$tasks->items_array_ref};
is(@tasks, 1, "a task was created");
is($tasks[0]->summary, "this is an IM create!", "create created a task with the correct summary");

$response = msg("tester", "bd IM create line 1<br />IM create line 2");
like($response, qr/Created 2 tasks/, "response includes 2 tasks created");
like($response, qr/<#6>/, "response includes record locator 1/2");
like($response, qr/<#7>/, "response includes record locator 2/2");

$tasks = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$tasks->unlimit; # yes, we really want all rows
@tasks = grep {$_->summary =~ /IM create line/} @{$tasks->items_array_ref};
is(@tasks, 2, "two tasks were created in one IM");
is($tasks[0]->summary, "IM create line 1", "create created task 1/2 with the correct summary (<br>)");
is($tasks[1]->summary, "IM create line 2", "create created task 2/2 with the correct summary (<br>)");

$response = msg("tester", "c IM create part a\nIM create part b");
like($response, qr/Created 2 tasks/, "response includes 2 tasks created");
like($response, qr/<#8>/, "response includes record locator 1/2");
like($response, qr/<#9>/, "response includes record locator 2/2");

$tasks = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$tasks->unlimit; # yes, we really want all rows
@tasks = grep {$_->summary =~ /IM create part/} @{$tasks->items_array_ref};
is(@tasks, 2, "two tasks were created in one IM with \\n instead of <br>");
is($tasks[0]->summary, "IM create part a", "create created task 1/2 with the correct summary (\\n)");
is($tasks[1]->summary, "IM create part b", "create created task 2/2 with the correct summary (\\n)");

my $otheruser = BTDT::CurrentUser->new( email => 'otheruser@example.com'  );

$response = msg("Other Tester", $auth_token);
unlike($response, qr/Hooray!/, "auth token good only once");
$response = msg("othertester", "help");
like($response, qr/hiveminder\.com/, "cold response still mentions hm.com");

my $otherim = BTDT::Model::UserIM->new(current_user => BTDT::CurrentUser->superuser);
$otherim->create(user_id => $otheruser->id);

$auth_token = $otherim->auth_token;
ok(length($auth_token) > 3, "auth token '$auth_token' greater than 3 chars long (very low standards!)");
$response = msg("tester", $auth_token);
unlike($response, qr/Hooray!/, "an AIM account can only be linked to one HM account");

$response = msg("oTHERtESTER", " \t $auth_token    <br>");
like($response, qr/Hooray!/, "successfully authed even with extra whitespace");
$name = $otheruser->user_object->name;
like($response, qr/\Q$name\E/, "auth includes user's name");

$response = msg("ot he rt es te r", "c kill that meddling gooduser!!\n    NOW!!");
like($response, qr/Created 1 task/, "response includes task creation");

$tasks = BTDT::Model::TaskCollection->new(current_user => $otheruser);
$tasks->unlimit; # yes, we really want all rows
@tasks = grep {$_->summary =~ /meddling/} @{$tasks->items_array_ref};
is(@tasks, 1, "a task was created");
is($tasks[0]->summary, "kill that meddling gooduser!!", "create created a task with the correct summary on the right user");

$tasks = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$tasks->unlimit; # yes, we really want all rows
@tasks = grep {$_->summary =~ /meddling/} @{$tasks->items_array_ref};
is(@tasks, 0, "gooduser didn't get otheruser's task");

# modal create {{{
is_command_help("tester", "help commands");

$response = msg("othertester", "create");
unlike($response, qr/Created \d+ task/, "no created tasks");
like($response, qr/to finish or type/, "response tells us how to stop the modal create");

$response = msg("othertester", "help create");
unlike($response, qr/Created \d+ task/, "no created tasks");
like($response, qr/to finish or type/, "response to a new task in a modal create includes message to stop creating");

$response = msg("othertester", "  it sure needs it");
unlike($response, qr/Created \d+ task/, "no created tasks");
like($response, qr/to finish or type/, "response to a new task in a modal create includes message to stop creating");

$response = msg("othertester", "play Cake\neat cake");
unlike($response, qr/Created \d+ task/, "no created tasks");
like($response, qr/to finish or type/, "response to a multiline modal create includes message to stop creating");

$response = msg("tester", ".");
unlike($response, qr/Created \d+ task/, "no created tasks");
unlike($response, qr/thank you/i, "response doesn't include end-modal-create thank you");
like($response, qr{Use <b>\?</b> or <b>help</b>}, "plain . gets the usual 'need help?' response");

$response = msg("othertester", ".");
like($response, qr/Created \d+ task/, "stop creating message does report task creation");
unlike($response, qr/to finish or type/, "response to modal create end doesn't tell us how to stop creating");

$tasks = BTDT::Model::TaskCollection->new(current_user => $otheruser);
$tasks->unlimit; # yes, we really want all rows
@tasks = @{$tasks->items_array_ref};
is(@tasks, 4, "3 create tasks created (plus 1 from before)");

@tasks = grep {$_->summary eq 'help create'} @{$tasks->items_array_ref};
is(@tasks, 1, "1/3 task really was created");
is($tasks[0]->description, 'it sure needs it', "task got a description correctly");

@tasks = grep {$_->summary eq 'play Cake'} @{$tasks->items_array_ref};
is(@tasks, 1, "2/3 task really was created");

@tasks = grep {$_->summary eq 'eat cake'} @{$tasks->items_array_ref};
is(@tasks, 1, "3/3 task really was created");

@tasks = grep {$_->summary eq '.'} @{$tasks->items_array_ref};
is(@tasks, 0, "no '.' task was created");

$response = msg("othertester", "help");
unlike($response, qr/Created 1 task/, "post modal creating doesn't assume task creation");
unlike($response, qr/to finish or type/, "post modal creating doesn't tell us how to stop creating");

msg("tester", "create");
msg("tester", "feed cat");
$response = msg("tester", 'cancel');
like($response, qr/OK\. I've canceled "Create" mode/, "'cancel' in modal create says it does abort");
unlike($response, qr/Created 1 task/);

$response = msg("tester", "todo feed");
unlike($response, qr/To commit the create/, "abort in modal create actually did stop");
unlike($response, qr/feed cat/, "feed cat didn't make it into todo list");

# actual bug
msg("tester", "create");
$response = msg("tester", ".");
like($response, qr/OK\. I've canceled "Create" mode/, "ending create immediately acts like a cancellation");
unlike($response, qr/To commit the create/, "create then immediate . does stop the create");

$response = msg("tester", "help");
like($response, qr/The four things you'll do/, "definitely left create mode");

$response = msg("tester", ".");
like($response, qr/Unknown command/, "for the benefit of later tests");
# }}}

# todo {{{
command_help_includes('todo');

$response = msg("othertester", "todo");
@tasks = split_task_list($response);
is(@tasks, 4, "4 tasks showed up for otheruser's todo");
is(grep(/meddling gooduser/, @tasks), 1, "todo showed 1/4 task correctly");
is(grep(/help create/,       @tasks), 1, "todo showed 2/4 task correctly");
is(grep(/play Cake/,         @tasks), 1, "todo showed 3/4 task correctly");
is(grep(/eat cake/,          @tasks), 1, "todo showed 4/4 task correctly");
unlike($response, qr/NOW!!/, "description didn't show up in multi-task list");

$response = msg("tester", "T");
@tasks = split_task_list($response);
is(@tasks, 7, "7 tasks showed up for gooduser's todo");
is(grep(/this is an IM create/,   @tasks), 1, "todo showed 1/7 task correctly");
is(grep(/01 some task/,           @tasks), 1, "todo showed 2/7 task correctly");
is(grep(/02 other task/,          @tasks), 1, "todo showed 3/7 task correctly");
is(grep(/create line 1/,          @tasks), 1, "todo showed 4/7 task correctly");
is(grep(/create line 2/,          @tasks), 1, "todo showed 5/7 task correctly");
is(grep(/create part a/,          @tasks), 1, "todo showed 6/7 task correctly");
is(grep(/create part b/,          @tasks), 1, "todo showed 7/7 task correctly");

# todo with args should search
$response = msg("tester", "t line");
@tasks = split_task_list($response);
is(@tasks, 2, "2 tasks showed up for gooduser's 'todo line'");
is(grep(/create line 1/,       @tasks), 1, "todo showed 4/7 task correctly");
is(grep(/create line 2/,       @tasks), 1, "todo showed 5/7 task correctly");

$response = msg("othertester", "t gooduser");
@tasks = split_task_list($response);
is(@tasks, 2, "received one task hit for todo gooduser by otheruser, plus its description");
like($tasks[0], qr/kill that meddling gooduser/, "task hit got the one we wanted");
like($response, qr/NOW!!/, "one-task list includes description");
like($response, qr/1 thing to do/, 'special one-item todo header');

# }}}

# searching {{{
command_help_includes('search');

$response = msg("tester", "search");
like($response, qr/I didn't understand that/, "search with no args gives an error message");

$response = msg("othertester", "search gooduser");
@tasks = split_task_list($response);
is(@tasks, 2, "received one task hit for search gooduser by otheruser, plus its description");
like($tasks[0], qr/kill that meddling gooduser/, "task hit got the one we wanted");
like($response, qr/NOW!!/, "one-task list includes description");
like($response, qr/1 search result(?!s)/, 'special one-item search header');

$response = msg("tester", "search gooduser");
unlike($response, qr/kill that meddling gooduser/, "search didn't hit the nasty task from otheruser");
@tasks = split_task_list($response);
is(@tasks, 0, "received no task hits for search gooduser by gooduser");
# }}}

# marking tasks as done {{{
command_help_includes('done');

$response = msg("tester", "done #6");
like($response, qr/Marking task <#6> as done/);

$response = msg("tester", "todo");
unlike($response, qr/<#6>/, "item we marked as done isn't in the todo list");

$response = msg("tester", "done 6");
like($response, qr/<#6> is already done/);

$response = msg("tester", "todo");
unlike($response, qr/<#6>/, "item we marked as done still isn't in the todo list");

$response = msg("tester", "done /create line 1");
like($response, qr/No matches/);

$response = msg("tester", "done /this should have no hits!");
like($response, qr/no matches/i);

$response = msg("tester", "done /create line");
like($response, qr/Marking task <#7> as done/);
unlike($response, qr/<#6>/, "done /foo doesn't complain about already-done tasks if there were newly finished tasks");

$response = msg("tester", "done #6 8");
like($response, qr/Marking task <#8> as done/);
like($response, qr/<#6> is already done/, "done #6 8 *does* complain about already-done tasks");

$response = msg("tester", "todo");
unlike($response, qr/<#8>/, "item we marked as done still isn't in the todo list");

$response = msg("tester", "done #792");
like($response, qr/Cannot find task <#792>/, "nonexistent record locator gives a good message");

$response = msg("tester", "done #jifty 9");
like($response, qr/Cannot find task <#JIFTY>/, "malformed record locator gives a good message");
like($response, qr/Marking task <#9> as done/, "done #jifty 9 still sets 9 as complete");

$response = msg("tester", "done xyzzy #fnord");
like($response, qr/Cannot find tasks <#FNORD> and <#XYZZY>/, "malformed record locators give a good message");

$response = msg("tester", "done #A");
like($response, qr/Cannot mark task <#A> as done/, "can't set someone else's task as done");

$response = msg("othertester", "done /ake");
like($response, qr/play Cake/, "when a search returns multiple things, the items are listed 1/2");
like($response, qr/eat cake/, "when a search returns multiple things, the items are listed 2/2");
like($response, qr{Send me <b>y</b> on a line by itself}, "when a search returns multiple things, ask for confirmation before committing");

$response = msg("othertester", "y");
like($response, qr/<#D>/, "response to a confirmation includes task #D");
like($response, qr/<#E>/, "response to a confirmation includes task #E");
like($response, qr/Marking .* as done/);

$response = msg("othertester", "todo");
unlike($response, qr/<#D>/, "#D no longer in todo");
unlike($response, qr/<#E>/, "#E no longer in todo");

$response = msg("tester", "done /e");
like($response, qr/<#3>/);
like($response, qr/#4/);
unlike($response, qr/Marking .* as done/);
unlike($response, qr/^\* /m, "no done items in the done list");

$response = msg("tester", "bd yee haw");
unlike($response, qr/Marking .* as done/, "we didn't commit the 'done'");
like($response, qr/Created 1 task/, "got the usual create response");

$response = msg("tester", "y");
like($response, qr{Use <b>\?</b> or <b>help</b>}, "y came too late, so give help message");

$response = msg("tester", "todo");
like($response, qr/<#3>/, "#3 not complete");
like($response, qr/<#4>/, "#4 not complete");
# }}}

# marking tasks as undone {{{
command_help_includes('undone');

$response = msg("tester", "undone #6");
like($response, qr/Marking task <#6> as not done/);

$response = msg("tester", "todo");
like($response, qr/#6/, "item we marked as undone is back on the todo list");

$response = msg("tester", "undone 6");
like($response, qr/<#6> is not done/);

$response = msg("tester", "undone /create line 1");
like($response, qr/No matches/);

$response = msg("tester", "undone /this should have no hits!");
like($response, qr/no matches/i);

$response = msg("tester", "undone /create line");
like($response, qr/Marking task <#7> as not done/);
unlike($response, qr/<#6>/, "undone /foo doesn't complain about already-undone tasks if there were newly unfinished tasks");

$response = msg("tester", "undone #6 8");
like($response, qr/Marking task <#8> as not done/);
like($response, qr/<#6> is not done/, "done #6 8 *does* complain about already-undone tasks");

$response = msg("tester", "todo");
like($response, qr/<#8>/, "item we marked as undone is in the todo list");

$response = msg("tester", "undone #792");
like($response, qr/Cannot find task <#792>/, "nonexistent record locator gives a good message");

$response = msg("tester", "undone #jifty 9");
like($response, qr/Cannot find task <#JIFTY>/, "malformed record locator gives a good message");
like($response, qr/Marking task <#9> as not done/, "undone #jifty 9 still sets 9 as incomplete");

$response = msg("tester", "undone xyzzy #fnord");
like($response, qr/Cannot find tasks <#FNORD> and <#XYZZY>/, "malformed record locators give a good message");

$response = msg("tester", "undone #A");
like($response, qr/Cannot mark task <#A> as not done/, "can't set someone else's task as undone");

$response = msg("othertester", "undone /ake");
like($response, qr/play Cake/, "when a search returns multiple things, the items are listed 1/2");
like($response, qr/eat cake/, "when a search returns multiple things, the items are listed 2/2");
like($response, qr{Send me <b>y</b> on a line by itself}, "when a search returns multiple things, ask for confirmation before committing");

$response = msg("othertester", "y");
like($response, qr/<#D>/, "response to a confirmation includes task #D");
like($response, qr/<#E>/, "response to a confirmation includes task #E");
like($response, qr/Marking .* as not done/);

$response = msg("othertester", "todo");
like($response, qr/<#D>/, "#D now in todo");
like($response, qr/<#E>/, "#E now in todo");

$response = msg("tester", "undone /e");
like($response, qr/No matches/);

$response = msg("tester", "bd funtastic");
unlike($response, qr/marked as undone/, "we didn't commit the 'undone'");
like($response, qr/Created 1 task/, "got the usual create response");

$response = msg("tester", "y");
like($response, qr{Use <b>\?</b> or <b>help</b>}, "y came too late, so give help message");

$response = msg("tester", "todo");
like($response, qr/<#3>/, "#3 still complete");
like($response, qr/<#4>/, "#4 still complete");
# }}}

# more todo {{{
# todo with args should search only incomplete tasks
$response = msg("tester", "create 03 nother task");
$response = msg("tester", "done /03 nother task");

$response = msg("tester", "t task");
@tasks = split_task_list($response);
is(@tasks, 2, "2 tasks showed up for gooduser's 'todo task'");
is(grep(/01 some task/,   @tasks), 1, "todo search showed 1/2 task correctly");
is(grep(/02 other task/,  @tasks), 1, "todo search showed 2/2 task correctly");
is(grep(/03 nother task/, @tasks), 0, "todo search didn't show completed task");

unlike($response, qr/\[priority: (?:normal|3)\]/, "didn't get [priority: normal]");
# }}}

# tags {{{
command_help_includes('tag');

msg("tester", "bd frob the config [snicker snack]"); 
msg("tester", "bd delete the config [due tomorrow] [aabbc]");

$response = msg("tester", "/config");
like($response, qr/snicker/, "search includes tags 1/3");
like($response, qr/snack/,   "search includes tags 2/3");
like($response, qr/aabbc/,   "search includes tags 3/3");

@tasks = split_task_list($response);
my ($taskfrob_locator, $taskdel_locator);
($taskfrob_locator) = map { /<#([^:]+)>:/; $1} grep { /frob/   } @tasks;
($taskdel_locator)  = map { /<#([^:]+)>:/; $1} grep { /delete/ } @tasks;

$response = msg("tester", "tag #$taskfrob_locator");
like($response, qr/I don't understand/, "tag with no new tags gives an error");

$response = msg("tester", "tag #$taskfrob_locator with");
like($response, qr/I don't understand/, "tag with no new tags gives an error");

$response = msg("tester", "tag #$taskfrob_locator []");
like($response, qr/I don't understand/, "tag with empty newtags gives appropriate error");

$response = msg("tester", "tag #$taskfrob_locator with talk-carl");
like($response, qr/talk-carl/, "response includes the tag we just added");
like($response, qr/<#$taskfrob_locator>/, "response includes the task we just touched");

$response = msg("tester", "tag #$taskdel_locator [talk-maureen]");
like($response, qr/Updated task <#$taskdel_locator> with tag: \[talk-maureen]/, "response to 'tag' looks correct, especially singular 'tag' in output if only one tag");

$response = msg("tester", "/config");
like($response, qr/talk-carl/,    "search includes new tags 1/2");
like($response, qr/talk-maureen/, "search includes new tags 2/2");

$response = msg("tester", "tag #$taskfrob_locator [snicker]");
is($response =~ /snicker/g, 1, "response includes the tag 'snicker' only once")
    or diag $response;
like($response, qr/<#$taskfrob_locator>/, "response includes the task we just touched");

$response = msg("tester", qq{tag #$taskfrob_locator with "la la"});
like($response, qr/la la/, "response includes 'la' twice since we quoted the tag");
like($response, qr/<#$taskfrob_locator>/, "response includes the task we just touched");

$response = msg("tester", "tag #$taskfrob_locator [he he]");
like($response, qr/<#$taskfrob_locator>/, "response includes the task we just touched");

$response = msg("tester", "todo config");
is(($response =~ s/snicker//g), 1, "todo includes the tag 'snicker' only once");
like($response, qr/la la/, "todo includes 'la' twice since we quoted the tag");
is(($response =~ s/\bhe\b//g), 1, "todo includes 'he' once since we didn't quote the tag");

$response = msg("tester", "tag #$taskfrob_locator #$taskdel_locator [multitasktag]");
like($response, qr/<#$taskfrob_locator>/, "response to multitask-tag includes task 1/2");
like($response, qr/<#$taskdel_locator>/, "response to multitask-tag includes task 2/2");

$response = msg("tester", "tag #$taskfrob_locator [a] [b] [c]");
like($response, qr/Updated task <#$taskfrob_locator> with tags: \[a] \[b] \[c]/, "adding multiple tags pluralizes 'tag' in the output correctly");

$response = msg("tester", "todo config");
like($response, qr/frob.*multitasktag/, "multitask-tag added tag 1/2");
like($response, qr/delete.*multitasktag/, "multitask-tag added tag 2/2");

# }}}

# untag {{{
command_help_includes('untag');

$response = msg("tester", "untag from #D");
like($response, qr/Remove which tags\?/);

$response = msg("tester", "untag '' from #D");
like($response, qr/Remove which tags\?/);

$response = msg("tester", "untag #D #$taskdel_locator [aabbc]");
like($response, qr/Removed \[aabbc\] from task <#$taskdel_locator>/);
like($response, qr/Task <#D> doesn't have \[aabbc]/);

$response = msg("tester", "untag blech 'talk maureen' from #$taskfrob_locator #D");
like($response, qr/Tasks <#D> and <#$taskfrob_locator> don't have \[blech\] \[talk maureen\]/);
# }}}

# comment {{{
command_help_includes('comment');

msg("tester", "c need to find shoelaces");
$response = msg("tester", "todo #K");
unlike($response, qr/\[comments: /, "no comments on the task yet");

$response = msg("tester", "comment #K see www.google.com");
like($response, qr/Added your comment to task <#K>/, "comment acknowledged");

my @comments = comments_on_task('K');
is(@comments, 2, "two comments on the task");
is(grep(/see www.google.com/, @comments), 1, "comments include our pointer to google");

$response = msg("othertester", "comment #K does no evil? ha ha ha");
like($response, qr/You can't comment on task <#K>/, "permissions error acknowledged");

@comments = comments_on_task('K');
is(@comments, 2, "still two comments on the task");
is(grep(/see www.google.com/, @comments), 1, "comments still includes our pointer to google");
is(grep(/does no evil/, @comments), 0, "no sign of otheruser's comment");

# modal comments
$response = msg("tester", "comment #K");
unlike($response, qr/Added your comment to task <#K>/, "no comment yet");
like($response, qr/to finish or type/, "response tells us how to stop the modal comment");

$response = msg("tester", "help");
unlike($response, qr/The four things you'll do/, "no help message");
unlike($response, qr/Added your comment to task <#K>/, "no comment yet");
like($response, qr/to finish or type/, "response tells us how to stop the modal comment");

$response = msg("tester", "this looks pretty do-able");
unlike($response, qr/The four things you'll do/, "no help message");
unlike($response, qr/Added your comment to task <#K>/, "no comment yet");
like($response, qr/to finish or type/, "response tells us how to stop the modal comment");

$response = msg("tester", "just make sure to shop around for prices");
unlike($response, qr/The four things you'll do/, "no help message");
unlike($response, qr/Added your comment to task <#K>/, "no comment yet");
like($response, qr/to finish or type/, "response tells us how to stop the modal comment");

$response = msg("tester", "done");
unlike($response, qr/The four things you'll do/, "no help message");
like($response, qr/Added your comment to task <#K>/, "comment finally added");
unlike($response, qr/to finish or type/, "no need to hear about how to stop the comment now");

$response = msg("tester", "comment #K");
unlike($response, qr/Added your comment to task <#K>/, "no comment yet");
like($response, qr/to finish or type/, "response tells us how to stop the modal comment");

$response = msg("tester", "cancel");
like($response, qr/OK\. I've canceled "Comment" mode/, "'cancel' in modal comment says it does abort");
unlike($response, qr/Added your comment to task <#K>/, "no comment");

@comments = comments_on_task('K');
is(@comments, 3, "exactly one new comment on the task");
my ($modal_comment) = grep /shop around for prices/, @comments;
like($modal_comment, qr/pretty do-able/, "modal comment produces one big comment 1/2");
like($modal_comment, qr/help/, "modal comment produces one big comment 2/2");

$response = msg("tester", "comment this\n");
like($response, qr/modal comment mode/, "trailing space still enters modal comment mode");
msg("tester", "cancel");

$response = msg("tester", "todo #K");
like($response, qr/\[comments: 2\]/, "we see that there are 2 comments on the task");
# }}}

# feedback {{{
command_help_includes('feedback');

setup_groups();
BTDT::Test->setup_mailbox();  # clear the emails.

$response = msg("tester", "feedback Go Catalyst!");
like($response, qr/Thanks for the feedback/);

my @emails = BTDT::Test->messages;
is(scalar @emails, 1, 
   'Feedback action sends mail to the right # of group members');

my $email = $emails[0] || Email::Simple->new('');
like($email->header('Subject'),
     qr{Up for grabs: Go Catalyst!}, 
     "Mail subject is correct");
is($email->header('To'),
   'otheruser@example.com',
   "Feedback went to other group members, not to submitter");

like($email->body, qr/extra info:/, "extra info is included");
like($email->body, qr/screenname: tester/, "screenname is included");
like($email->body, qr/protocol: AIM/, "protocol is included");

my $unpriv = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
$unpriv->create( email => 'unprivileged@example.com', name => 'unpriv');
ok($unpriv->id);

my $unprivim = BTDT::Model::UserIM->new(current_user => BTDT::CurrentUser->superuser);
$unprivim->create(user_id => $unpriv->id);
$auth_token = $unprivim->auth_token;

$response = msg("unpriv", $auth_token);
like($response, qr/Hooray!/, "unpriv authed");

BTDT::Test->setup_mailbox();  # clear the emails.
$response = msg("unpriv", "feedback kcabdeef");
like($response, qr/Thanks for the feedback/);

my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
$task->load_by_cols(summary => 'kcabdeef');

my @unprivemails = BTDT::Test->messages;
is(scalar @unprivemails, 2, 'On create, we notified the two group members');

BTDT::Test->setup_mailbox();  # clear the emails.
$task->comment("This is a reply from an adminny person");
@unprivemails = BTDT::Test->messages;
is(scalar @unprivemails, 3, 'On resolve, we notified the two group members and the requestor');

BTDT::Test->setup_mailbox();  # clear the emails.
$task->set_complete('t');
@unprivemails = BTDT::Test->messages;
is(scalar @unprivemails, 2, 'On resolve, we notified the two group members (but not the requestor)');

# modal feedback
$response = msg("tester", "feedback");
unlike($response, qr/Thanks for the feedback/, "'feedback' alone creates no feedback");
unlike($response, qr/feed us back/, "'feedback' alone no longer gives an error");
like($response, qr/on a line by itself/, "got some instruction as to how to commit the feedback");

$response = msg("tester", "how do I set profile??");
unlike($response, qr/Unknown command/, "modal feedback doesn't trigger unknown commands");
unlike($response, qr/Thanks for the feedback/, "one line of feedback is insufficient");
unlike($response, qr/feed us back/, "no error for modal feedback");
like($response, qr/to finish or type/, "still get some instruction as to how to commit the feedback");

$response = msg("othertester", "you click edit profile");
unlike($response, qr/to finish or type/, "othertester doesn't mess with tester's modal feedback");
like($response, qr/Unknown command/, "invalid command");

$response = msg("tester", "no. seriously.");
unlike($response, qr/Unknown command/, "modal feedback doesn't trigger unknown commands");
unlike($response, qr/Thanks for the feedback/, "one line of feedback is insufficient");
unlike($response, qr/feed us back/, "no error for modal feedback");
like($response, qr/to finish or type/, "still get some instruction as to how to commit the feedback");

BTDT::Test->setup_mailbox();  # clear the emails.

$response = msg("tester", ".");
unlike($response, qr/Unknown command/, "modal feedback end doesn't trigger unknown commands");
unlike($response, qr/feed us back/, "no error for ending modal feedback");
unlike($response, qr/to finish or type/, "no longer get some instruction as to how to commit the feedback");
like($response, qr/Thanks for the feedback/, "feedback committed message");

$response = msg("tester", "is this thing still on?");
unlike($response, qr/feed us back/, "no error for ending modal feedback");
unlike($response, qr/to finish or type/, "no longer get some instruction as to how to commit the feedback");
unlike($response, qr/Thanks for the feedback/, "feedback committed message");
like($response, qr/Unknown command/, "modal feedback ended");

@emails = BTDT::Test->messages;
is(scalar @emails, 1, 
   'Feedback action sends mail to the right # of group members');

$email = $emails[0] || Email::Simple->new('');
like($email->header('Subject'),
     qr{Up for grabs: how do I set profile\?\? no\. seriously\.}, 
     "Mail subject is correct");
is($email->header('To'),
   'otheruser@example.com',
   "Feedback went to other group members, not to submitter");

# aborting modal feedback
BTDT::Test->setup_mailbox();  # clear the emails.

$response = msg("tester", "feedback");
unlike($response, qr/Thanks for the feedback/, "'feedback' alone reates no feedback");
unlike($response, qr/feed us back/, "'feedback' alone no longer gives an error");
like($response, qr/on a line by itself/, "got some instruction as to how to commit the feedback");

$response = msg("tester", "come on guys help me!!!!! [priority 198327] [due today]");
unlike($response, qr/Unknown command/, "modal feedback doesn't trigger unknown commands");
unlike($response, qr/Thanks for the feedback/, "one line of feedback is insufficient");
unlike($response, qr/feed us back/, "no error for modal feedback");
like($response, qr/to finish or type/, "still get some instruction as to how to commit the feedback");

$response = msg("tester", "cancel");
unlike($response, qr/Unknown command/, "aborting modal feedback doesn't trigger unknown commands");
unlike($response, qr/Thanks for the feedback/, "aborting modal feedback doesns't give thanks");
unlike($response, qr/feed us back/, "no error for aborting modal feedback");
unlike($response, qr/to finish or type/, "don't get some instruction as to how to commit the feedback after abort");

@emails = BTDT::Test->messages;
is(scalar @emails, 0, 
   'No feedback generated');
# }}}

# second IM account for a user {{{
setup_screenname('gooduser@example.com' => 'incognito');
$response = msg("incognito", "done /this is an IM create");
like($response, qr/Marking task <#5> as done/);

$response = msg("tester", "done #5");
like($response, qr/<#5> is already done/);
# }}}

# random task {{{
command_help_includes('random');

$response = msg("tester", "random");
like($response, qr/Here's a random task/);

msg("othertester", "done /e");
msg("othertester", "y");
$response = msg("othertester", "todo");
like($response, qr/Nothing to do/, "othertester has no tasks left");

$response = msg("othertester", "random");
unlike($response, qr/Here's a random task/);
like($response, qr/Nothing to do/);

my $unpriv_cu = BTDT::CurrentUser->new( email => 'unprivileged@example.com' );
# set up a bunch of tasks for unpriv through the API for efficiency
for (1..10)
{
    BTDT::Model::Task->new(current_user => $unpriv_cu)->create(summary => "{$_}");
}

# now ask for ten random tasks, and make sure we get at least two different ones
# this has a 1e-27% chance of giving a false negative, I think that's
# acceptable :)
my $prev = -1;
my $passed = 0;
for (1..30)
{
    $im->received_message('unpriv', 'random');
    my @messages = $im->messages;
    my ($num) = $messages[0]{message} =~ /{(\d+)}/;

    # allow early bailing if the test passes
    $prev = $num if $prev == -1;
    if ($num != $prev)
    {
        $passed = 1;
        last;
    }
}

ok($passed, "no one task was shown all 10 times (if this fails try again, may be RNG trickery)");

msg("tester", "done /this is an IM create");

for (1..4)
{
    $response = msg("tester", "random IM create");
    like($response, qr/IM create (?:part|line) [ab12]/, "'random search' works $_/4");
}

$response = msg("tester", "random should have no hits");
like($response, qr/No matches/, "failing random search gives a special message");

$response = msg("tester", "random delete config");
like($response, qr/\[multitasktag talk-maureen\]/, "random shows square brackets for tags");
# }}}

# give {{{
command_help_includes('give');

$response = msg("tester", 'give #f');
like($response, qr/I don't understand/, "give without a target gives an error message");

$response = msg("tester", 'give #f otheruser@example.com');
like($response, qr/Gave task <#F> to otheruser\@example.com/, "give with a target gives the right message");

# what should happen if you give twice? shrug
#$response = msg("tester", 'give #f otheruser@example.com');
#like($response, qr/???/, "double give gives an error");

$response = msg("tester", "/yee haw");
like($response, qr/yee haw/, "given task still shows up in search of giver");

$response = msg("othertester", "/yee haw");
like($response, qr/yee haw/, "given task does show up in search of recipient");

$response = msg("tester", 'give 6 7 otheruser@example.com');
like($response, qr/Gave tasks <#6> and <#7> to otheruser\@example.com/, "giving multiple tasks (without locators, even) gives the right message");

im_like("show #6", qr/^.*\[owner: otheruser\@example\.com\]/, "owner is displayed");

$response = msg("tester", "/create line");
unlike($response, qr/yee haw/, "given tasks don't show up in search of giver");

$response = msg("othertester", "/create line");
like($response, qr/create line/, "given tasks do show up in search of recipient");

$response = msg("tester", 'give #G nonexistent@nowhere.com');
like($response, qr/Gave task <#G> to nonexistent\@nowhere.com/, "giving to a non-HM address still works");

$response = msg("tester", 'give #K zot!');
like($response, qr/I don't understand/, "giving to a bad address gives an error message");

$response = msg("tester", 'give #K gooduser@example.com');
like($response, qr/Giving task <#K> to yourself\?/, "giving to self gives an error message");

# take
$response = msg("tester", "take #L");
like($response, qr/Took task <#L>/, "take worked");

im_unlike("todo #L", qr/^.*\[owner: /, "no owner is displayed when we own the task");

# giving to nobody / abandoning tasks
$response = msg("tester", "give up #L");
like($response, qr/Abandoned task <#L>/, "give up reported success");

$response = msg("tester", "todo #L");
unlike($response, qr/#L/, "abandoned task doesn't show up in todo");

$task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
$task->load_by_locator('L');
is($task->owner_id, BTDT::CurrentUser->nobody->id, "task definitely looks abandoned 1/2");
ok($task->accepted, "task definitely looks abandoned 2/2");

# the first line of show is the short task summary
im_like("show #L", qr/^.*\[owner: nobody\]/);

# Can't abandon non-group task
$response = msg("tester", "give up #K");
like($response, qr/Cannot give away task <#K>/, "give up non-group gives an error message");
# }}}

# accept {{{
command_help_includes('accept');

$response = msg("tester", "accept");
like($response, qr/You have no unaccepted tasks/, "accept without arguments acts like 'what tasks can I accept' rather than 'accept the tasks in my context'");

$response = msg("othertester", "accept");
like($response, qr/\d+ unaccepted tasks:/, "othertester's unaccepted tasks recognized");

my $response2 = msg("othertester", "accept");
is($response2, $response, "no context for accept");

$response = msg("othertester", "accept #F");
like($response, qr/Accepted task <#F>/, "accept #F works");

$response = msg("othertester", "/yee haw");
like($response, qr/yee haw/, "accept <#F> actually accepted the task");

$response = msg("othertester", "accept /create");
like($response, qr/Accepted tasks <#6> and <#7>/, "accept /search works");

$response = msg("othertester", "/create");
like($response, qr/create line 1.*create line 2/s, "accept /search actually accepted the tasks");

$response = msg("othertester", "accept #5");
like($response, qr/You can't accept task <#5>/, "accept ungiven task gives sane error");

$response = msg("othertester", "decline #5");
like($response, qr/You can't decline task <#5>/, "decline ungiven task gives sane error");
like($response, qr/It's okay, you're not responsible for it anyway/, "nice human touch");

$response = msg("othertester", "accept #5 #6");
like($response, qr/You can't accept task <#5>/, "accept(ungiven and already-accepted tasks) gives sane error 1/2");
like($response, qr/You already own task <#6>/, "accept(ungiven and already-accepted tasks) gives sane error 2/2");

# have a guy give a task and try to accept it
$response = msg("tester", 'give #K othertester@example.com');
like($response, qr/Gave task <#K> to othertester\@example.com/);

$response = msg("tester", 'accept #K');
like($response, qr/You can't accept task <#K>/, "can't accept a task you gave");
# }}}

# decline {{{
command_help_includes('decline');

msg("tester", "c dooon't decline meee");
msg("tester", 'give these otheruser@example.com');

$response = msg("othertester", "decline");
like($response, qr/1 unaccepted task:/, "decline shows unaccepted tasks, not declined tasks in context");

$response = msg("othertester", "decline #Z");
like($response, qr/Declined task <#Z>/, "decline #Z reports success");

$response = msg("othertester", "todo");
unlike($response, qr/<#Z>/, "declining a task != accepting a task :)");

$response = msg("tester", "decline");
like($response, qr/<#Z>/, "the other guy declined a task, so we now have it in our unaccepted lisit");

$response = msg("tester", "c decline A\nb decline B\nb decline C");
my @locators = $response =~ /(#\w+)/g;
msg("tester", "give $locators[0] $locators[1] otheruser\@example.com");

# so tester requested 0 1 and 2. decline ownes 0 and 1 but are unaccepted
# make other decline with a search that would decline all three and make sure
# it only hit the two on his side
$response = msg("othertester", "decline");
like($response, qr/\d+ unaccepted tasks:/, "decline alone shows we have tasks to decide on");

$response = msg("othertester", "decline /decline");
like($response, qr/Declined tasks <$locators[0]> and <$locators[1]>/, "declined the two tasks given to us");
unlike($response, qr/$locators[2]/, "no mention of the task not given to us");

$response = msg("othertester", "decline");
unlike($response, qr/\d+ unaccepted tasks:/, "decline really did decline those tasks 1/5");
$response = msg("othertester", "todo /decline");
unlike($response, qr/$locators[0]|$locators[1]/, "decline really did decline those tasks 2/5");
$response = msg("othertester", "decline");
unlike($response, qr/$locators[0]|$locators[1]/, "decline really did decline those tasks 2/5");
$response = msg("tester", "decline");
like($response, qr/<$locators[0]>/, "decline really did decline those tasks 3/5");
like($response, qr/<$locators[1]>/, "decline really did decline those tasks 4/5");


$response = msg("othertester", "decline /decline");
like($response, qr/No matches/);

$response = msg("tester", "accept $locators[0] $locators[1]");
like($response, qr/Accepted tasks <$locators[0]> and <$locators[1]>/, "can't decline tasks you still own");

$response = msg("tester", "decline $locators[0] $locators[1]");
like($response, qr/You already own tasks <$locators[0]> and <$locators[1]>/, "can't decline tasks you still own");
# }}}

# delete {{{
command_help_includes('delete');

msg("tester", "c delete this task!!");
$response = msg("tester", "c delete this too");
my ($locator) = $response =~ /(#\w+)/;
msg("tester", "c and delete this");

$response = msg("othertester", "c please don't delete me");
my ($otherlocator) = $response =~ /(#\w+)/;

$response = msg("tester", "delete $locator");
like($response, qr/Deleted task <$locator>/, "deletion reports success");

$response = msg("tester", "/delete this too");
like($response, qr/No matches/, "deletion actually worked");

$response = msg("tester", "delete /delete");
unlike($response, qr/Deleted tasks/, "'delete /search' with multiple hits queries 1/2");
like($response, qr{Send me <b>y</b> on a line by itself}, "'delete /search' with multiple hits queries 2/2");

$response = msg("tester", "/delete");
unlike($response, qr/No matches/, "delete without confirmation didn't actually delete");

$response = msg("tester", "delete /delete");
unlike($response, qr/Deleted tasks/, "'delete /search' with multiple hits queries 1/2");
like($response, qr{Send me <b>y</b> on a line by itself}, "'delete /search' with multiple hits queries 2/2");

$response = msg("tester", "y");
like($response, qr/Deleted tasks/, "delete with confirmation reports success");

$response = msg("tester", "/delete");
like($response, qr/No matches/, "delete with confirmation did actually delete");

$response = msg("tester", "delete /should have no matches");
like($response, qr/No matches/);

$response = msg("tester", "delete $otherlocator");
like($response, qr/Cannot delete task <$otherlocator>/, "can't delete a task entirely owned by someone else");

$response = msg("tester", "delete #5 #6");
like($response, qr/Deleted tasks <#5> and <#6>/, "");

# }}}

# privacy {{{
command_help_includes('privacy');

$response = msg("tester", "help privacy");
like($response, qr{legal/privacy}, "help privacy mentions URL");

$response = msg("tester", "privacy");
unlike($response, qr/Unknown command/, "privacy is a genuine command");
like($response, qr{legal/privacy}, "privacy mentions URL");
# }}}

# due {{{
command_help_includes('due');

$response = msg("tester", "due #4");
like($response, qr/Task <#4> has no due date/, "due with no date just reports due date");

$response = msg("tester", "due #4 by today");
like($response, qr/<#4>/, "record locator included in response to due");
like($response, qr/today/, "today's date included in response to due");

$response = msg("tester", "due #4");
like($response, qr/Task <#4> is due today/, "due with no date just reports due date");

$response = msg("tester", "due #4 by 11/13/2003");
like($response, qr/<#4>/, "record locator included in response to due");
like($response, qr/2003-11-13/, "random date included in response to due");

$response = msg("tester", "due #4");
like($response, qr/Task <#4> was due 2003-11-13/, "due date in the past uses 'was due'");

my $a_bright_and_glorious_dawn = (localtime)[5] + 1900 + 42;
msg("tester", "t create");
$response = msg("tester", "due these by 01/01/$a_bright_and_glorious_dawn");
like($response, qr/$a_bright_and_glorious_dawn/, "response to due includes year in the distant future");

# for reporting multiple tasks' due dates:
#   distribute tasks into clumps where each clump represents the due date
#   sort the clumps from past to future
#   sort the tasks in each clump by locator
#   report each clump
# yeah it's a little overkill but worth it (and not too hard to implement)

$response = msg("tester", "due #9 #8");
like($response, qr/Tasks <#8> and <#9> are due $a_bright_and_glorious_dawn-\d\d-\d\d/, "single clump, multiple tasks");

$response = msg("tester", "due #8 #4");
like($response, qr/Task <#4> was due 2003-11-13/, "multiple tasks, one clump each 1/3");
like($response, qr/Task <#8> is due $a_bright_and_glorious_dawn-\d\d-\d\d/, "multiple tasks, one clump each 2/3");
like($response, qr/<#4>.*<#8>/s, "multiple tasks, one clump each 3/3");

$response = msg("tester", "due #9 #4 #8");
like($response, qr/Task <#4> was due 2003-11-13/, "one in clump A, two in clump B 1/3");
like($response, qr/Tasks <#8> and <#9> are due $a_bright_and_glorious_dawn-\d\d-\d\d/, "one in clump A, two in clump B 2/3");
like($response, qr/<#4>.*<#8>/s, "one in clump A, two in clump B 3/3");

$response = msg("othertester", "due #4 by tomorrow");
like($response, qr/Cannot set the due date on task <#4>/, "due reports acl failures correctly");

$response = msg("tester", "due #4");
like($response, qr/Task <#4> was due 2003-11-13/, "other user's due tomorrow didn't affect this");

$response = msg("othertester", "due #4 by never");
like($response, qr/Cannot set the due date on task <#4>/, "due never also reports acl failures correctly");

$response = msg("tester", "due #4");
like($response, qr/Task <#4> was due 2003-11-13/, "other user's due never didn't affect this");

$response = msg("tester", "due #4 by never");
like($response, qr/Unset the due date on task <#4>/, "due never reports success");

$response = msg("tester", "due #4");
like($response, qr/Task <#4> has no due date/, "due never actually worked");

# due in
$response = msg("tester", "due 4 in bananas");
like($response, qr/I don't know what you mean by 'bananas'/, "due in doesn't append 'from now' in its 'unparseable' error");

$response = msg("tester", "due 4 in");
like($response, qr/Task <#4> has no due date/, "due in with no data isn't an error");

$response = msg("tester", "due 4 in 1 day");
like($response, qr/Due date set to tomorrow on task <#4>/, "'due task in 1 day' acts like 'due at tomorrow");

my $in_10 = in_days(10);
$response = msg("tester", "due 4 in 10 days");
like($response, qr/Due date set to $in_10 on task <#4>/, "'due task in 10 days' also works");

my $in_7 = in_days(7);
$response = msg("tester", "due 4 in 1 week");
like($response, qr/Due date set to $in_7 on task <#4>/, "'due task in 1 week' also works");

my $in_7_21 = in_days(7*21);
$response = msg("tester", "due in 21 weeks");
like($response, qr/Due date set to $in_7_21 on task <#4>/, "'due task in (7*21) weeks' also works");

$response = msg("tester", "due 4 by never");
like($response, qr/Unset the due date on task <#4>/);
# }}}

# priority {{{
command_help_includes('priority');

$response = msg("tester", "priority #32");
like($response, qr/Task <#32> has normal priority/, "priority task shows task's priority");

$response = msg("tester", "priority #32 #33");
like($response, qr/Tasks <#32> and <#33> have normal priority/, "priority task task shows tasks' priority");

my @priorities = qw/lowest lowest low normal high highest highest/;

for (0..6)
{
    my $priority = $priorities[$_];

    # test numeric 0..6
    $response = msg("tester", "priority #32 $_");
    like($response, qr/Priority set to $priority on task <#32>/, "'priority #task $_' reports success");

    $response = msg("tester", "priority #32");
    like($response, qr/Task <#32> has $priority priority/, "'priority #task $_' correctly set priority");

    # test numeric 0..6 sans locator
    $response = msg("tester", "priority 32 $_");
    like($response, qr/Priority set to $priority on task <#32>/, "'priority task $_' reports success");

    $response = msg("tester", "priority 32");
    like($response, qr/Task <#32> has $priority priority/, "'priority task $_' correctly set priority");

    # test numeric 0..6 sans locator, priority first
    $response = msg("tester", "priority $_ 32");
    like($response, qr/Priority set to $priority on task <#32>/, "'priority $_ task' reports success");

    $response = msg("tester", "priority 32");
    like($response, qr/Task <#32> has $priority priority/, "'priority $_ task' correctly set priority");

    next if $_ == 0 || $_ == 6;

    # test word lowest..highest
    $response = msg("tester", "priority #32 $priority");
    like($response, qr/Priority set to $priority on task <#32>/, "'priority #task $priority' reports success");

    $response = msg("tester", "priority #32");
    like($response, qr/Task <#32> has $priority priority/, "'priority #task $priority' correctly set priority");

    # test word lowest..highest sans locator
    $response = msg("tester", "priority 32 $priority");
    like($response, qr/Priority set to $priority on task <#32>/, "'priority task $priority' reports success");

    $response = msg("tester", "priority 32");
    like($response, qr/Task <#32> has $priority priority/, "'priority task $priority' correctly set priority");

    # test word lowest..highest sans locator, priority first
    $response = msg("tester", "priority $priority 32");
    like($response, qr/Priority set to $priority on task <#32>/, "'priority $priority task' reports success");

    $response = msg("tester", "priority 32");
    like($response, qr/Task <#32> has $priority priority/, "'priority $priority task' correctly set priority");
}

$response = msg("tester", "todo decline A");
like($response, qr/highest/, "todo includes priority");

# special priority syntax, and context
$response = msg("tester", "--#32");
like($response, qr/Priority set to lowest on task <#32>/, "'--task' reports success");
$response = msg("tester", "priority these");
like($response, qr/Task <#32> has lowest priority/, "'--task' actually worked");

$response = msg("tester", "priority #32 #33");
like($response, qr/Task <#33> has normal priority/, "priority clumps correctly 1/3");
like($response, qr/Task <#32> has lowest priority/, "priority clumps correctly 2/3");
like($response, qr/<#33>.*<#32>/s, "priority clumps correctly (high->low) 3/3");

$response = msg("tester", "++these");
like($response, qr/Priority set to highest on tasks <#32> and <#33>/, "'++' reports success");

$response = msg("tester", "priority these");
like($response, qr/Tasks <#32> and <#33> have highest priority/, "'++' actually worked");

$response = msg("tester", "priority these normal");
like($response, qr/Priority set to normal on tasks <#32> and <#33>/, "'priority normal' reports success");
# }}}

# hide {{{
command_help_includes('hide');

$response = msg("tester", "hide #33");
like($response, qr/I don't understand/, "hide without a date gives an error");

$response = msg("tester", "hide #33 next week");
like($response, qr/I don't understand/, "hide without until gives an error");

$response = msg("tester", "hide #33 until   ");
like($response, qr/Until when\?/, "hide until without a date gives an error");

$response = msg("tester", "hide #34 until next week");
like($response, qr/Hiding task <#34> until \d\d\d\d-\d\d-\d\d/, "hide until reports success");

$response = msg("tester", "todo decline 34");
like($response, qr/No matches/, "successfully hid the task");

$response = msg("tester", "find decline 34");
like($response, qr/<#34>/, "find can still see hidden tasks");

msg("tester", "todo decline 32");
$response = msg("tester", "hide these until next month");
like($response, qr/Hiding task <#32> until \d\d\d\d-\d\d-\d\d/, "'hide until' uses context");

$response = msg("tester", "hide these until yesterday");
like($response, qr/Unhiding task <#32>/, "'hide until yesterday' reports unhiding");

$response = msg("tester", "todo decline 32");
like($response, qr/<#32>/, "successfully unhid the task");

$response = msg("tester", "hide 32 34 until yesterday");
like($response, qr/Unhiding tasks <#32> and <#34>/, "'hide tasks until' doesn't require #");

# hide for
$response = msg("tester", "hide 32 for");
like($response, qr/For how long\?/, "hide for has a special no-data error");

$response = msg("tester", "hide 32 for bananas");
like($response, qr/I don't know what you mean by 'bananas'/, "hide for doesn't append 'from now' in its 'unparseable' error");

$response = msg("tester", "hide 32 for 1 day");
like($response, qr/Hiding task <#32> until tomorrow/, "'hide task for 1 day' acts like 'hide until tomorrow");

$response = msg("tester", "unhide 32");
like($response, qr/Unhiding task <#32>/, "'unhide task' works");

$response = msg("tester", "hide 32 for 10 days");
like($response, qr/Hiding task <#32> until $in_10/, "'hide task for 10 days' also works");

$response = msg("tester", "hide 32 for 1 week");
like($response, qr/Hiding task <#32> until $in_7/, "'hide task for 1 week' also works");

$response = msg("tester", "hide for 21 weeks");
like($response, qr/Hiding task <#32> until $in_7_21/, "'hide task for 21 weeks' also works");

$response = msg("tester", "hide 32 until yesterday");
like($response, qr/Unhiding task <#32>/, "putting things back how we found them");

$response = msg("tester", "unhide /decline A");
like($response, qr/Unhiding task <#32>/, "'unhide /search' works");
# }}}

# single-task modal editing and 'show' command {{{
$response = msg("tester", "create this is my single task");
($locator) = $response =~ /(#\w+)/;

$response = msg("tester", "show");
like($response, qr/<$locator>/, "show includes the record locator in our context");

$response = msg("tester", "tag these [feature] [due friday]");
unlike($response, qr/Usage: /, "tag doesn't complain about mis-usage");
unlike($response, qr/Cannot find/, "tag doesn't complain about unfound tasks");
like($response, qr/feature/, "tag output does include new tag");
like($response, qr/<$locator>/, "tag includes record locator");

$response = msg("tester", "done these");
like($response, qr/Marking task <$locator> as done/);
unlike($response, qr/No matches/);

$response = msg("tester", "todo these $locator");
unlike($response, qr/$locator/, "'done' actually worked");

$response = msg("tester", "undone these");
like($response, qr/Marking task <$locator> as not done/);
unlike($response, qr/No matches/);

(my $sans_pound = $locator) =~ s/^#//;
$response = msg("tester", "comment this I don't think so!");
like($response, qr/Added your comment to task <$locator>/);

$task = BTDT::Model::Task->new(current_user => $gooduser);
$task->load_by_locator(substr($locator, 1));
@comments = map {$_->message} @{$task->comments->items_array_ref}; 
is(grep(/I don't think so/, @comments), 1, "comment this actually adds the comment");

msg("othertester", "r");

$response = msg("tester", "done these");
like($response, qr/Marking task <$locator> as done/, "intervening other-user input doesn't screw up gooduser's single-task commands");
unlike($response, qr/Cannot mark/);

$response = msg("tester", "show #8 #9");
like($response, qr/<#8>/, "show includes the new record locator 1/2");
like($response, qr/<#9>/, "show includes the new record locator 2/2");
unlike($response, qr/$locator/, "show doesn't include old record locator");

$response = msg("tester", "show /create part");
like($response, qr/<#8>/, "show includes the new record locator 1/2");
like($response, qr/<#9>/, "show includes the new record locator 2/2");
unlike($response, qr/$locator/, "show doesn't include old record locator");

$response = msg("tester", "done these");
like($response, qr/Marking tasks <#8> and <#9> as done/, "done can operate on multiple remembered tasks; show creates context");

$response = msg("tester", "undone these");
like($response, qr/Marking tasks <#8> and <#9> as not done/, "undone can operate on multiple remembered tasks");

$response = msg("tester", 'give these otheruser@example.com');
like($response, qr/Gave tasks <#8> and <#9> to otheruser\@example.com/, "give can operate on multiple remembered tasks");

$userim = BTDT::Model::UserIM->new(current_user => BTDT::CurrentUser->superuser);
$userim->create(user_id => $gooduser->id);

$response = msg("bug city", $userim->auth_token);
like($response, qr/Hooray/);

like(msg("bug city", "done these"), qr/Mark what as done\?/, "no context on first auth");
like(msg("bug city", "tag these with blech"), qr/Tag what\?/, "no context on first auth");
like(msg("bug city", "tag these [blech]"), qr/Tag what\?/, "no context on first auth");
like(msg("bug city", "untag blech from these"), qr/Untag what\?/, "no context on first auth");
like(msg("bug city", "untag these [blech]"), qr/Untag what\?/, "no context on first auth");
like(msg("bug city", "delete these"), qr/Delete what\?/, "no context on first auth");
like(msg("bug city", "give these otheruser\@example.com"), qr/Give what\?/, "no context on first auth");
like(msg("bug city", "move these into hiveminders feedback"), qr/Move what\?/, "no context on first auth");
like(msg("bug city", "due these"), qr/What's due\?/, "no context on first auth");
like(msg("bug city", "due these today"), qr/What's due\?/, "no context on first auth");
like(msg("bug city", "priority these"), qr/What are we prioritizing\?/, "no context on first auth");
like(msg("bug city", "priority these highest"), qr/What are we prioritizing\?/, "no context on first auth");
like(msg("bug city", "++ these"), qr/What are we prioritizing\?/, "no context on first auth");
like(msg("bug city", "hide these until today"), qr/Hide what\?/, "no context on first auth");
like(msg("bug city", "history these"), qr/Show the history of what\?/, "no context on first auth");
like(msg("bug city", "give to nobody"), qr/Abandon what\?/, "no context on first auth");
like(msg("bug city", "give up"), qr/Abandon what\?/, "no context on first auth");
like(msg("bug city", "give away"), qr/Abandon what\?/, "no context on first auth");
like(msg("bug city", "abandon"), qr/Abandon what\?/, "no context on first auth");
like(msg("bug city", "next"), qr/But I'm not showing you a list!/, "no context on first auth");
like(msg("bug city", "prev"), qr/But I'm not showing you a list!/, "no context on first auth");
like(msg("bug city", "page"), qr/But I'm not showing you a list!/, "no context on first auth");
like(msg("bug city", "rename to foo"), qr/Rename what\?/, "no context on first auth");

like(msg("bug city", "done"), qr/Mark what as done\?/, "no context on first auth");
like(msg("bug city", "tag with blech"), qr/Tag what\?/, "no context on first auth");
like(msg("bug city", "tag [blech]"), qr/Tag what\?/, "no context on first auth");
like(msg("bug city", "untag blech from"), qr/Untag what\?/, "no context on first auth");
like(msg("bug city", "untag [blech]"), qr/Untag what\?/, "no context on first auth");
like(msg("bug city", "comment"), qr/Comment on what\?/, "no context on first auth");
like(msg("bug city", "delete"), qr/Delete what\?/, "no context on first auth");
like(msg("bug city", "give otheruser\@example.com"), qr/Give what\?/, "no context on first auth");
like(msg("bug city", "move to hiveminders feedback"), qr/Move what\?/, "no context on first auth");
like(msg("bug city", "due"), qr/What's due\?/, "no context on first auth");
like(msg("bug city", "due by today"), qr/What's due\?/, "no context on first auth");
like(msg("bug city", "due today"), qr/What's due\?/, "no context on first auth");
like(msg("bug city", "priority"), qr/What are we prioritizing\?/, "no context on first auth");
like(msg("bug city", "priority highest"), qr/What are we prioritizing\?/, "no context on first auth");
like(msg("bug city", "++"), qr/What are we prioritizing\?/, "no context on first auth");
like(msg("bug city", "show"), qr/Nothing to show!/, "no context on first auth");
like(msg("bug city", "hide these until tomorrow"), qr/Hide what\?/, "no context on first auth");
like(msg("bug city", "history"), qr/Show the history of what\?/, "no context on first auth");
like(msg("bug city", "page 2"), qr/But I'm not showing you a list!/, "no context on first auth");
like(msg("bug city", "rename this to foo"), qr/Rename what\?/, "no context on first auth");
like(msg("bug city", "take"), qr/Take what\?/, "no context on first auth");
like(msg("bug city", "give me:"), qr/Take what\?/, "no context on first auth");
like(msg("bug city", "give to me"), qr/Take what\?/, "no context on first auth");
# }}}

# specific bugs {{{
for (1..8) { msg("tester", "c task $_") }
$response = msg("tester", "todo");
like($response, qr/^1\d things to do \(page 1 of 2\)/, "task count is accurate, instead of giving a memory address");

($locator) = $response =~ /(#[A-Z0-9]+)/;
$response = msg("tester", "todo $locator");
unlike($response, qr/No matches/, "smart_search with # on record locator still works");

$response = msg("tester", "show #38");
like($response, qr/You can't see task <#38>/, "tester has no access to otherteste's task 38");
unlike($response, qr/<#38>:  \[/, "no undef-looking output 1/2");
unlike($response, qr/\[priority: \]/, "no undef-looking output 2/2");

# encoding
$response = msg("tester", "create &\n    \"foo\"");
like($response, qr/Created 1 task/, "successfully created a task with &");
($locator) = $response =~ /(#[A-Z0-9]+)/;
$response = msg("tester", "show $locator");
like($response, qr/&amp;/, "& is correctly encoded");
like($response, qr/&quot;/, '" is correctly encoded');

# priority on unreadable tasks
$response = msg("tester", "priority #38");
like($response, qr/You can't see task <#38>/, "priority on unreadable tasks gives an error");

# create\nfoo was giving "Unknown command"
$response = msg("tester", "create\nthis shouldn't fail");
like($response, qr/Created 1 task/, "one created task");
# }}}

# paging {{{
$response = msg("tester", "/a");
like($response, qr{Use <b>next</b> to go to page 2}, "page 1/3 of search gives you next page");
unlike($response, qr{Use <b>prev</b> }, "page 1/3 of search doesn't give you previous page");

$response = msg("tester", "next");
like($response, qr{Use <b>prev</b> to go to page 1}, "page 2/3 of search gives you previous page");
like($response, qr{Use <b>next</b> to go to page 3}, "page 2/3 of search gives you next page");

$response = msg("tester", "next");
like($response, qr{Use <b>prev</b> to go to page 2}, "page 3/3 of search gives you previous page");
unlike($response, qr{Use <b>next</b> }, "page 3/3 of search doesn't give you next page");

$response = msg("tester", "next");
like($response, qr/You're already on the last page/, "next on last page gives an error");

$response = msg("tester", "page 1");
like($response, qr{Use <b>next</b> to go to page 2}, "'page 1' gives you next page");
unlike($response, qr{Use <b>prev</b> }, "'page 1' doesn't give you prev page");

$response = msg("tester", "page 2");
like($response, qr{Use <b>next</b> to go to page 3}, "'page 2' gives you next page");
like($response, qr{Use <b>prev</b> to go to page 1}, "'page 2' gives you prev page");

$response = msg("tester", "page 3");
unlike($response, qr{Use <b>next</b> }, "'page 3' doesn't give you next page");
like($response, qr{Use <b>prev</b> to go to page 2}, "'page 3' gives you prev page");

$response = msg("tester", "page 4");
like($response, qr{Invalid page number\. Valid numbers are 1-3\.}, "paging out of range is an error");
unlike($response, qr{Use <b>next</b> }, "'page 4' doesn't give you next page");
unlike($response, qr{Use <b>prev</b> }, "'page 4' doesn't give you prev page");

$response = msg("tester", "page 0");
like($response, qr{Invalid page number\. Valid numbers are 1-3\.}, "paging to zero is an error");
unlike($response, qr{Use <b>next</b> }, "'page 4' doesn't give you next page");
unlike($response, qr{Use <b>prev</b> }, "'page 4' doesn't give you prev page");

$response = msg("tester", "todo frob config");
unlike($response, qr{Use <b>next</b> }, "search doesn't give you next if you're on the only page");
unlike($response, qr{Use <b>prev</b> }, "search doesn't give you previous if you're on the only page");

$response = msg("tester", "page 1");
like($response, qr{frob}, "paging to 1 works");
unlike($response, qr{Use <b>next</b> }, "'page 1' doesn't give you next page");
unlike($response, qr{Use <b>prev</b> }, "'page 1' doesn't give you prev page");

$response = msg("tester", "page 2");
like($response, qr{Invalid page number\. Only page 1 is valid\.}, "paging out of range is an error");
unlike($response, qr{Use <b>next</b> }, "'page 1' doesn't give you next page");
unlike($response, qr{Use <b>prev</b> }, "'page 1' doesn't give you prev page");

$response = msg("tester", "page 0");
like($response, qr{Invalid page number\. Only page 1 is valid\.}, "paging to zero is an error");
unlike($response, qr{Use <b>next</b> }, "'page 1' doesn't give you next page");
unlike($response, qr{Use <b>prev</b> }, "'page 1' doesn't give you prev page");

$response = msg("tester", "privacy");
like($response, qr/You can find our privacy policy/, "some command other than next/prev worked");

msg("tester", "/a");
$response = msg("tester", "done these");
like($response, qr/Marking tasks .* as done\./, "can operate on all shown tasks of page 1/3");

$response = msg("tester", "next");
like($response, qr/\d+ search results/);
$response = msg("tester", "done these");
like($response, qr/Marking tasks .* as done\./, "can operate on all shown tasks of page 2/3");

$response = msg("tester", "next");
like($response, qr/\d+ search results/);
$response = msg("tester", "done these");
like($response, qr/Tasks .* are already done\./, "can operate on all shown tasks of page 3/3");

$response = msg("tester", "next");
like($response, qr/You're already on the last page/);

$response = msg("tester", "todo a");
like($response, qr/Nothing to do|No matches/, "successfully marked everything as done");

# see if accept pages correctly
msg("othertester", "create aa\nab\nac\nad\nae\naf\nag\nah\nai\naj\nak");
msg("othertester", "todo");
msg("othertester", "give these gooduser\@example.com");
msg("othertester", "next");
msg("othertester", "give these gooduser\@example.com");

$response = msg("tester", "accept");
like($response, qr{Use <b>next</b> to go to page 2\.});
unlike($response, qr{Use <b>prev</b> });

$response = msg("tester", "next");
like($response, qr{Use <b>prev</b> to go to page 1\.});
unlike($response, qr{Use <b>next</b> });
# }}}

# more show {{{
command_help_includes('show');

$response = msg("tester", "braindump foo\n    bar");
($locator) = $response =~ /(#[A-Z0-9]+)/;
$response = msg("tester", "show $locator");
like($response, qr/\bbar\b/, "explicit single-task show includes description");

$response = msg("tester", "show");
like($response, qr/\bbar\b/, "contextual single-task show includes description");

$response = msg("tester", "show *#*!(!)");
like($response, qr/Cannot find task <\Q#*#*!(!)\E>/, "show with garbage gives some kind of error");

$response = msg("tester", "show #3879389");
like($response, qr/Cannot find task <#3879389>/, "show with nonexistent task gives some kind of error");
# }}}

# review {{{
command_help_includes('review');

# review will ignore completed tasks
msg("tester", "undone #3V #3I #3F #32 #3G #3H");

$response = msg("tester", "review #3V");
like($response, qr/<#3V>/, "'review one-task' includes locator");
like($response, qr/^Shortcuts:/m, "review includes the shortcuts list");
like($response, qr/Reviewing task 1 of 1\b/, "review has a proper header");

$response = msg("tester", "q");
like($response, qr/All right\. I'll let you off easy\./, "quitting gives a special message");

$response = msg("tester", "t");
unlike($response, qr/Due date/, "q really did quit 1/2");
like($response, qr/\d+ things to do/, "q really did quit 2/2");

$response = msg("tester", "review #3V #3I");
like($response, qr/^Shortcuts:/m, "back in review");

$response = msg("tester", "c");
like($response, qr/<#3I>/, "'c' moves to the next task");

$response = msg("tester", "continue");
like($response, qr/That wasn't so bad/, "'continue' moves to the next task");

$response = msg("tester", "review #3V #3I");
like($response, qr/^Shortcuts:/m, "back in review");

my @messages = msg("tester", "d");
is(@messages, 2, "got two responses");
like($messages[0]{message}, qr/Marking task <#3V> as done/, "'d' in review mode reports success");
like($messages[1]{message}, qr/^Shortcuts:/m, "'d' automatically displays the review menu");
like($messages[1]{message}, qr/<#3I>/, "'d' automatically moves to the next page");

@messages = msg("tester", "d");
is(@messages, 2, "got two messages");

like($messages[0]{message}, qr/Marking task <#3I> as done/, "first response includes output for 'd'");
like($messages[1]{message}, qr/All done! That wasn't so bad, was it\?/, "second response includes output for review ending");

$response = msg("tester", "q");
like($response, qr/Unknown command/, "'d' left task review");

# we should definitely have five tasks at this point
# review will ignore completed tasks
msg("tester", "undone #3V #3I #3F #32 #3G #3H");

$response = msg("tester", "review");
like($response, qr/^Shortcuts:/m, 'at a review menu');

if ($response =~ /This task is awaiting your acceptance/)
{
    @messages = msg("tester", 'a');
    is(@messages, 2, "got two messages from acceptance");
    like($messages[0]{message}, qr/Accepted task <#Z>/, "accept worked");
    like($messages[1]{message}, qr/<#32>/, "moved to the next task");
}
else
{
    ok(0, "expected task to be an unaccepted one");
    ok(0, "expected task to be an unaccepted one");
    ok(0, "expected task to be an unaccepted one");
}

@messages = msg("tester", 't');
is(@messages, 2, "got two messages");

like($messages[0]{message}, qr/Unhiding task <#32>/, "first response includes output for 't'");

for my $command (qw/1 2 s m z/)
{
    if ($messages[1]{message} =~ /This task is awaiting your acceptance/)
    {
        @messages = msg("tester", 'r');
        is(@messages, 2, "got two messages from decline");
        like($messages[0]{message}, qr/Declined task <#/, "decline worked");
    }

    @messages = msg("tester", $command);
    is(@messages, 2, "got two messages");

    like($messages[0]{message}, qr/Hiding task <#\w+> until |Unhiding task <#\w+>/, "first response includes output for '$command'");
    like($messages[1]{message}, qr/^Shortcuts:/m, 'at a review menu');
}

unlike($messages[1]{message}, qr/\[priority: highest\]/, "task is not already highest priority");

@messages = msg("tester", "priority 5");
like($messages[0]{message}, qr/Priority set to highest on /, "priority reports success");
like($messages[1]{message}, qr/\[priority: highest\]/, "task is not already highest priority");

$response = msg("tester", "q");
like($response, qr/All right\. I'll let you off easy\./, "leaving task review");

$response = msg("tester", "q");
like($response, qr/Unknown command/, "definitely left task review");

$response = msg("othertester", "create this should be invisible to tester");
($locator) = $response =~ /(#[A-Z0-9]+)/;

@messages = msg("tester", "review #32 #ACK $locator");
is(@messages, 2, "two responses");
like($messages[0]{message}, qr/Cannot find task <#ACK>\./, "review nonexistent-task reports error correctly");
like($messages[0]{message}, qr/You can't review task <$locator>\./, "review otheruser's task reports error correctly");
like($messages[1]{message}, qr/^Shortcuts:/m, "even with nonexistent tasks, we still get a review menu");

@messages = msg("tester", "t");
unlike($messages[1]{message}, qr/ACK/, "'t' didn't move to the nonexistent task");
like($messages[1]{message}, qr/All done! That wasn't so bad, was it\?/, "'n' ended review");

# don't let the user do certain things in review mode {{{
# review will ignore completed tasks
msg("tester", "undone #3V #3I #3F #32 #3G #3H");

$response = msg("tester", "review #3G");
like($response, qr/^Shortcuts:/m, "back in review");

@messages = msg("tester", "review");
like($messages[0]{message}, qr/You're already reviewing tasks!/, "review within review fails");
like($messages[1]{message}, qr/^Shortcuts:/m, "error automatically displays the review menu");

@messages = msg("tester", "create");
like($messages[0]{message}, qr/Your modal task creation will have to wait until you're done reviewing tasks/, "modal create within review fails");
like($messages[1]{message}, qr/^Shortcuts:/m, "error automatically displays the review menu");

@messages = msg("tester", "feedback");
like($messages[0]{message}, qr/Your modal feedback will have to wait until you're done reviewing tasks/, "modal feedback within review fails");
like($messages[1]{message}, qr/^Shortcuts:/m, "error automatically displays the review menu");

@messages = msg("tester", "comment");
like($messages[0]{message}, qr/Your modal comment will have to wait until you're done reviewing tasks/, "modal comment within review fails");
like($messages[1]{message}, qr/^Shortcuts:/m, "error automatically displays the review menu");

$response = msg("tester", "q");
like($response, qr/All right\. I'll let you off easy\./, "left review mode");
# }}}

# only some commands move to next task; operating on other tasks {{{
# review will ignore completed tasks
msg("tester", "undone #3V #3I #3F #32 #3G #3H");

$response = msg("tester", "review #3F #32 #3G #3H");
like($response, qr/Shortcuts:/, "in task review");
like($response, qr/<#3F>/, "reviewing first task");

@messages = msg("tester", "comment this should be made easier");
like($messages[0]{message}, qr/Added your comment to task <#3F>/);
like($messages[1]{message}, qr/<#3F>/, "'comment' didn't move to the next task");

# operating on other tasks {{{
@messages = msg("tester", "comment #32 shouldn't operate on #3F");
like($messages[0]{message}, qr/Added your comment to task <#32>/);
like($messages[1]{message}, qr/<#3F>/, "'comment' didn't move to the next task");

@messages = msg("tester", "due #32 by next week");
like($messages[0]{message}, qr/Due date set to \d\d\d\d-\d\d-\d\d on task <#32>/);
like($messages[1]{message}, qr/<#3F>/, "'due' didn't move to the next task");

@messages = msg("tester", "tag #32 [argh]");
like($messages[0]{message}, qr/Updated task <#32> with tag: \[argh\]/);
like($messages[1]{message}, qr/<#3F>/, "'tag' didn't move to the next task");

@messages = msg("tester", "priority #32 low");
like($messages[0]{message}, qr/Priority set to low on task <#32>/);
like($messages[1]{message}, qr/<#3F>/, "'priority' didn't move to the next task");
# }}}

@messages = msg("tester", "tag with text-object");
like($messages[0]{message}, qr/Updated task <#3F> with tag: \[text-object]/);
like($messages[1]{message}, qr/<#3F>/, "'tag' didn't move to the next task");

@messages = msg("tester", "due on wednesday");
like($messages[0]{message}, qr/Due date set to (?:today|tomorrow|\d\d\d\d-\d\d-\d\d) on task <#3F>/);
like($messages[1]{message}, qr/<#3F>/, "'due' didn't move to the next task");

@messages = msg("tester", "priority high");
like($messages[0]{message}, qr/Priority set to high on task <#3F>/);
like($messages[1]{message}, qr/<#3F>/, "'priority' didn't move to the next task");

@messages = msg("tester", "create or fail");
like($messages[0]{message}, qr/Created 1 task/);
like($messages[1]{message}, qr/<#3F>/, "'create' didn't move to the next task");

@messages = msg("tester", "random");
like($messages[1]{message}, qr/<#3F>/, "'random' didn't move to the next task");

@messages = msg("tester", "todo");
like($messages[1]{message}, qr/<#3F>/, "'todo' didn't move to the next task");

@messages = msg("tester", "search and rescue");
like($messages[1]{message}, qr/<#3F>/, "'search' didn't move to the next task");

@messages = msg("tester", "finish");
like($messages[0]{message}, qr/Marking task <#3F> as done/, "finish affects the task given by review, not the task created last message");
like($messages[1]{message}, qr/<#32>/, "'finish' moved to the next task");

@messages = msg("tester", "give otheruser\@example.com");
like($messages[0]{message}, qr/Gave task <#32> to otheruser\@example.com/);
like($messages[1]{message}, qr/<#3G>/, "'give' moved to the next task");

@messages = msg("tester", "delete");
like($messages[0]{message}, qr/Deleted task <#3G>/);
like($messages[1]{message}, qr/<#3H>/, "'delete' moved to the next task");

@messages = msg("tester", "1");
like($messages[0]{message}, qr/Hiding task <#3H> until tomorrow/);
like($messages[1]{message}, qr/All done! That wasn't so bad, was it\?/, "'1' moved to the next test, and all done with the review");
# }}}

# "review all" {{{
msg("tester", "create hello world $_") for 1..10;
$response = msg("tester", "todo");
like($response, qr{Use <b>next</b> to go to page 2}, "this next test requires >10 items");
$response = msg("tester", "review all");
like($response, qr/Reviewing task 1 of (?!10)\d\d/, "review all gives more than ten tasks");

@messages = msg("tester", "1");
($locator) = $messages[0]{message} =~ /<#(\w+)>/;
like($messages[0]{message}, qr/Hiding task <#$1> until tomorrow/, "1 in task review gives tomorrow");
@messages = msg("tester", "hide $locator until yesterday");

my $now = DateTime->now(time_zone => "America/New_York");
my $expected = $now->clone->add(days => 2)->ymd;
@messages = msg("tester", "2");
($locator) = $messages[0]{message} =~ /<#(\w+)>/;
like($messages[0]{message}, qr/Hiding task <#\w+> until $expected/, "2 in task review gives the correct date");
@messages = msg("tester", "hide $locator until yesterday");

$expected = $now->clone->add(days => 50)->ymd;
@messages = msg("tester", "50");
($locator) = $messages[0]{message} =~ /<#(\w+)>/;
like($messages[0]{message}, qr/Hiding task <#\w+> until $expected/, "50 in task review gives the correct date");
@messages = msg("tester", "hide $locator until yesterday");

$expected = $now->clone->add(days => 365)->ymd;
@messages = msg("tester", "365");
($locator) = $messages[0]{message} =~ /<#(\w+)>/;
like($messages[0]{message}, qr/Hiding task <#\w+> until $expected/, "365 in task review gives the correct date");
@messages = msg("tester", "hide $locator until yesterday");

msg("tester", "q");
# }}}

# review declined tasks? {{{
$response = msg("tester", 'c declinedtask [owner: otheruser@example.com]');
like($response, qr/Created 1 task/, "created task for otheruser");
($locator) = $response =~ /<(#\w+)>/;

$response = msg("othertester", "decline $locator");
like($response, qr/Declined task <$locator>/, "declined task");

$response = msg("othertester", "review");

for (1..3) {
    $response = msg("othertester", "c");
    unlike($response, qr/declinedtask/, "Declined task doesn't show up in decliner's review");
}
like($response, qr/All done!/, "No longer in review");

$response = msg("tester", "delete $locator");
like($response, qr/Deleted task <#4D>/, "task gone");
# }}}
# }}}

# history {{{
command_help_includes('history');

$response = msg("tester", "history #32");
like($response, qr/<#32>/, "history includes locator");
like($response, qr/You changed priority of the task from \w+ to \w+ /, "history includes priority changing");
like($response, qr/You accepted the task/, "history includes acceptance");
like($response, qr/You created the task/, "history includes creation");
like($response, qr/Other User declined the task/, "history includes someone else's rejection");
my @datetimes = $response =~ /at \d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d\./g;
ok(@datetimes > 5, "history includes several datetimes");

$response = msg("tester", "comment #32 hello world");
like($response, qr/Added your comment to task <#32>/, "added comment for testing history");

$response = msg("tester", "history 32");
like($response, qr/<#32>/, "history works even without #");
like($response, qr/hello world/, "history includes comments made on a task");

$response = msg("tester", "history #3H #3G");
like($response, qr/<#3H>:/, "when specifying multiple tasks, the first one appears");
unlike($response, qr/<#3G>:/, "when specifying multiple tasks, the second one doesn't appear");

msg("tester", "/task");
$response = msg("tester", "history these");
@locators = $response =~ /<#\w+>/g;
is(@locators, 1, "only one locator on 'search task ; history these'");

$response = msg("tester", "history");
@locators = (@locators, $response =~ /<#\w+>/g);
is(@locators, 2, "only one locator on 'search task ; history'");
is($locators[0], $locators[1], "'history' with no args works like 'history this");

$response = msg("tester", "history /task");
@locators = $response =~ /<#\w+>/g;
is(@locators, 1, "only one locator on history /search");
is($response =~ /You created the task/g, 1, "only one instance of 'You created the task', on history /search");
# }}}

like(msg("tester", "help"), qr/The four things you'll do/, "not leaving in any kind of mode");

sub setup_groups {
    # set up HM feedback group
    my $ADMIN = BTDT::CurrentUser->superuser;

    $group1 = BTDT::Model::Group->new(current_user => $ADMIN);
    $group1->create(
	name => 'hiveminders feedback',
	description => 'dummy feedback group'
	);
    $group1->add_member($gooduser, 'organizer');
    $group1->add_member($otheruser, 'member');

    is(scalar @{$group1->members->items_array_ref}, 3,
       "Group has 3 members"); # the other one is the superuser

    $spectre = BTDT::Model::Group->new(current_user => $ADMIN);
    $spectre->create(
	name => 'SPECTRE',
	description => 'SPecial Executive for Counter-intelligence, Terrorism, Revenge and Extortion'
	);
    $spectre->add_member($otheruser, 'organizer');

    is(scalar @{$spectre->members->items_array_ref}, 2,
       "Group has 2 members"); # the other one is the superuser
}

