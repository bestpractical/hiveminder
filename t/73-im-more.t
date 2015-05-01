use warnings;
use strict;

use BTDT::Test tests => 798;
use BTDT::Test::IM;

# See the caveats section of Test::More
my $builder = Test::More->builder;
binmode $builder->output,         ":utf8";
binmode $builder->failure_output, ":utf8";
binmode $builder->todo_output,    ":utf8";

setup_screenname('gooduser@example.com' => 'tester');
setup_screenname('otheruser@example.com' => 'othertester');
setup_screenname('onlooker@example.com' => 'onlooker');

create_tasks(
    "foo",
    "bar",
    "baz",
    "quux",
);

# review "star commands" {{{
im_like("review", qr/Reviewing task 1 of 6/, "started review");
ims_like("2",
    qr/Hiding task <#\w+> until /,
    qr/Reviewing task 2 of 6/,
);

ims_like("*3",
    [qr/Hiding tasks( <#\w+>,){4} and <#\w+> until /,
        "star commands apply to the rest of the tasks"],
    [qr/Reviewing task 2 of 6/, "star commands don't move the iterator"],
);

ims_like("*due these by tomorrow",
    [qr/Due date set to tomorrow on tasks( <#\w+>,){4} and <#\w+>/,
        "you can star any command"],
    [qr/Reviewing task 2 of 6/, "star commands don't move the iterator"],
);

ims_like("alias foo=done",
    [qr/OK! 'foo' now expands to 'done'/],
    [qr/Reviewing task 2 of 6/, "still in task review"],
);

ims_like("*foo",
    [qr/Marking tasks( <#\w+>,){4} and <#\w+> as done/,
        "you can star aliases"],
    [qr/Reviewing task 2 of 6/, "star commands don't move the iterator"],
);

im_like("q", qr/All right. I'll let you off easy/, "ending review");
# }}}
# date command {{{
command_help_includes("date");
for (qw/date time datetime/) {
    im_like($_, qr{It is \d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d in your time zone, America/New_York});
}
# }}}
# help aliases {{{
im_like('help braindump', qr/The command to create new tasks/);
im_like('help ++', qr/Lets you see or change the priority of /);
# }}}
# url command {{{
command_help_includes('url');
im_like('link #3', qr{http://task\.hm/3\b \(01 some task\)}, "linking a locator works");
im_like('link #3 #4', qr{http://task\.hm/3\b.*http://task\.hm/4\b}s, "linking a list of locators works");
im_like('url', qr{http://task\.hm/3\b.*http://task\.hm/4\b}s, "link uses and sets context");
# }}}
# notes command {{{
command_help_includes("note");

im_like("note #3: testing 1 2 3", qr/Added your note to task <#3>/);
my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
$task->load_by_locator('3');
is($task->description, 'testing 1 2 3', "added a note");

im_like("note read #3", qr/\S\ntesting 1 2 3\Z/, "got the note out of the task");
im_like("note #3", qr/\S\ntesting 1 2 3\Z/, "got the note out of the task");
im_like("note 3", qr/\S\ntesting 1 2 3\Z/, "got the note out of the task");
im_like("note clear #3", qr/Cleared the notes from task <#3>/, "cleared notes");
im_unlike("note read #3", qr/\S\ntesting 1 2 3\Z/, "cleared notes");

im_like("note #3: foo", qr/Added your note to task <#3>/);
im_like("note #3: bar", qr/Added your note to task <#3>/);
im_like("note read #3", qr/\S\nfoo\nbar\Z/, "newlines are correct");

im_like("note this: die bart die", qr/Added your note to task <#3>/);
im_like("note read #3", qr/\S\nfoo\nbar\ndie bart die\Z/, "contextual note");

im_like("note: yum", qr/Added your note to task <#3>/);
im_like("note read #3", qr/\S\nfoo\nbar\ndie bart die\nyum\Z/, "syntax sugar");

im_like("note #3 #4: carp", qr/Added your note to tasks <#3> and <#4>/);
im_like("note read #3", qr/\S\nfoo\nbar\ndie bart die\nyum\ncarp\Z/, "note on multiple tasks");
im_like("note read #4", qr/\S\ncarp\Z/, "note on multiple tasks");

im_unlike("note read #3 #4", qr/carp.*carp/s, "note read shows only one task");
im_like("note: this is just the third task", qr/Added your note to task <#3>/, "only the one shown note is in context");
# }}}
# multiple commands {{{
# basic handling {{{
im_like("privacy ;; privacy", qr/Hold it!/, "multiple commands is restricted to pro users");
im_like("alias privpriv=privacy ;; privacy", qr/Hold it!/, "defining an alias with multiple commands is also restricted");
im_like("privpriv", qr/Unknown command/, "the alias wasn't created");

BTDT::Test->make_pro('gooduser@example.com');

ims_like("privacy ;; privacy", (qr/You can find our privacy policy at/)x2);

im_like("alias privpriv=privacy ;; privacy", qr/OK! 'privpriv' now expands to 'privacy ;; privacy'\./);
ims_like("privpriv", (qr/You can find our privacy policy at/)x2);

ims_like("privacy;;privacy", (qr/You can find our privacy policy at/)x2);
# }}}
# potential abuse {{{
im_like("alias die=privacy;;die", qr/OK! 'die' now expands to 'privacy ;; die'\./);
ims_like("die", (qr/You can find our privacy policy at/)x16, qr/You're doing too many commands in one IM/);

im_like("alias croak=privacy;;croak;;croak", qr/OK! 'croak' now expands to 'privacy ;; croak ;; croak'\./);
ims_like("croak", (qr/You can find our privacy policy at/)x16, qr/You're doing too many commands in one IM/);
# }}}
# filters {{{
im_like('alias w=filter clear;; filter tag @work;; t', qr/OK! 'w' now expands to 'filter clear ;; filter tag \@work ;; t'\./);
ims_like('w',
    qr/You have no filters to clear/,
    qr/Added your new filter\. You now have 1/,
    qr/Nothing to do!/,
);
im_like('filters', qr/You have 1 filter:.*1\. tag \@work/s);

im_like('alias h=filter clear;; filter not tag @work;; filter due before tomorrow;; t', qr/OK! 'h' now expands to 'filter clear ;; filter not tag \@work ;; filter due before tomorrow ;; t'\./);
ims_like('h',
    qr/Cleared your 1 filter\./,
    qr/Added your new filter\. You now have 1/,
    qr/Added your new filter\. You now have 2/,
    qr/Nothing to do!/,
);
im_like('filters', qr/You have 2 filters:.*1\. not tag \@work.*2\. due before tomorrow/s);

ims_like('w',
    qr/Cleared your 2 filters\./,
    qr/Added your new filter\. You now have 1/,
    qr/Nothing to do!/,
);
im_like('filters', qr/You have 1 filter:.*1\. tag \@work/s);
im_like('filter clear', qr/Cleared your 1 filter\./);
# }}}
# losing pro {{{
my $user = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
$user->load_by_cols(email => 'gooduser@example.com');
$user->__set(column => 'pro_account', value => 'f');
Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');

im_like("privacy ;; privacy", qr/Hold it!/, "multiple commands is restricted to pro users");
im_like("w", qr/Hold it!/, "multiple commands is restricted to pro users");
# }}}
# }}}
# filter owner/requestor {{{
im_like('c unobtanium [owner: otheruser@example.com]', qr/Created 1 task/);
im_like('c dilithium! [owner: onlooker@example.com]', qr/Created 1 task/);
im_like('c need a regular todo task!!', qr/Created 1 task/);

im_like('filter not owner me', qr/Added your new filter\. You now have 1/);
im_like('t', qr/2 things to do.*dilithium.*unobtanium/s);
im_like('filter clear', qr/Cleared your 1 filter\./);

im_like('filter owner otheruser@example.com', qr/Added your new filter\. You now have 1/);
im_like('t', qr/1 thing to do.*unobtanium/s);
im_like('filter clear', qr/Cleared your 1 filter\./);

im_like('filter not owner otheruser@example.com', qr/Added your new filter\. You now have 1/);
im_like('t', qr/2 things to do.*regular todo.*dilithium/s);
im_like('filter clear', qr/Cleared your 1 filter\./);

# requestor
im(othertester => 'c gooduser should never see this', qr/Created 1 task/);
im(onlooker    => 'c gooduser should never see this', qr/Created 1 task/);
im(othertester => 'c goomba [owner: gooduser@example.com]', qr/Created 1 task/);
im(onlooker    => 'c thwomp [owner: gooduser@example.com]', qr/Created 1 task/);

im_like('accept all', qr/Accepted tasks <#\w+> and <#\w+>/, "accepted two tasks");

im_like('filter not requestor me', qr/Added your new filter\. You now have 1/);
im_like('t', qr/2 things to do.*goomba.*thwomp/s);
im_like('filter clear', qr/Cleared your 1 filter\./);

im_like('filter requestor me', qr/Added your new filter\. You now have 1/);
im_like('t', qr/1 thing to do.*regular todo/s);
im_like('filter clear', qr/Cleared your 1 filter\./);

# group
BTDT::Test->setup_hmfeedback_group;

im_like('c upforgrabs [owner: nobody] [group: hiveminders feedback]', qr/Created 1 task/);

im_like('filter owner nobody', qr/Added your new filter\. You now have 1/);
im_like('t', qr/1 thing to do.*upforgrabs/s);
im_like('filter clear', qr/Cleared your 1 filter\./);

im_like('filter not owner nobody', qr/Added your new filter\. You now have 1/);
im_unlike('t', qr/upforgrabs/);
im_like('filter clear', qr/Cleared your 1 filter\./);
# }}}
# tags command {{{
command_help_includes("tags");
im_like('tags', qr/You have no tags/);

create_tasks("butterflies and hurricanes [absolution]");
im_like('tags', qr/Tags: absolution/);

create_tasks("hysteria [Absolution]");
im_unlike('tags', qr/absolution.*absolution/i, "differently-cased tag appears only once");

create_tasks("corona radiata ['The Slip']");
im_like('tags', qr/The Slip/, "case is preserved");
im_like('tags', qr/absolution, The Slip/i, "tags are sorted");
# }}}
# whoami {{{
command_help_includes("whoami");

im_like('whoami', qr/tester, you are Good Test User \(gooduser\@example\.com\) on Hiveminder\./);
im(othertester => 'whoami', qr/othertester, you are Other User \(otheruser\@example\.com\) on Hiveminder\./);
# }}}
# create an already-complete task {{{
for (
    ['[complete: 1]'       => 1],
    ['[done: 1]'           => 1],
    ['[completed: 1]'      => 1],
    ['[completed: banana]' => 1],
    ['[completed banana]'  => 1],

    ['[complete: 0]'       => 0],
    ['[done: 0]'           => 0],
    ['[completed: 0]'      => 0],
    ['[banana completed]'  => 0],
    ['[done: ]'            => 0],
    ['[done]'              => 0],
) {
    my ($attr, $complete) = @$_;

    my $response = im_like("create something I already did $attr", qr/Created 1 task/);
    my ($loc) = $response =~ /<#(\w+)>/;

    my $task = BTDT::Model::Task->new;
    $task->load_by_locator($loc);

    ok($task->id, "got a task");

    if ($complete) {
        ok($task->complete, "the task is complete ($attr)");
        ok($task->completed_at, "task has a completion time ($attr)");
    }
    else {
        ok(!$task->complete, "the task is incomplete ($attr)");
        is($task->completed_at, undef, "task has no completion time ($attr)");
    }

    is($task->summary, "something I already did", "attribute ($attr) was parsed out");
}
# }}}
# Done and Cancel in modal create {{{
im_like('create [test-modal]', qr/OK\. Let's create some tasks\./);
im_like('Task A', qr/to exit without sending/);
im_like('Cancel', qr/OK\. I've canceled "Create" mode/);
im_like('UnknownCommand', qr/Unknown command/);

im_like('cancel', qr/Unknown command/, 'make sure we canceled create');

$task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
$task->load_by_cols(summary => 'Task A');
ok(!$task->id, "no task was created");

im_like('create [test-modal]', qr/OK\. Let's create some tasks\./);
im_like('Task B', qr/to exit without sending/);
im_like('Done', qr/Created 1 task/);
im_like('UnknownCommand', qr/Unknown command/);
im_like('cancel', qr/Unknown command/, 'make sure we finished create');

$task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
$task->load_by_cols(summary => 'Task B');
ok($task->id, "task was created");
# }}}
# invite {{{
command_help_includes("invite");

im_like('invite', qr{I don't understand. Use: <b>invite</b> <i>email</i>});
im_like('invite me', qr{Believe it or not, you're using Hiveminder \*right\* \*now\*!});
im_like('invite screenname', qr{I don't understand. Use: <b>invite</b> <i>email</i>});
im_like('invite otheruser@example.com', qr{It turns out they already have an account.});
im_like('invite nonuser@example.com', qr{You've invited nonuser\@example.com to join Hiveminder. Thanks for spreading the buzz!});
# }}}
# comment with newlines {{{
my $loc = create_tasks('foo');
im_like("comment this: LINEONE\nLINETWO\nLINETHREE", qr/Added your comment to task <$loc>/);
my $comment = (comments_on_task($loc))[-1];
like($comment, qr/LINEONE/, "the first line is added to the comment");
like($comment, qr/LINETWO/);
like($comment, qr/LINETHREE/);
# }}}
# changing tasks per page {{{
# need more tasks!
create_tasks(map { "hi $_" } 1 .. 10);

im_like('t', qr/page 1 of 2/, "we have more than one page of tasks at 15 per page");

$user->set_per_page(50);
Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');

im_unlike('t', qr/page 1 of 2/, "we now have only one page of tasks at 50 per page");
# }}}
# dependency display {{{
my ($independent1, $independent2, $dependent1, $dependent2) = create_tasks(
    "independent 1",
    "independent 2",
    "dependent 1",
    "dependent 2",
);

im_like("$independent1 then $dependent1",
    qr/Task <$dependent1> now depends on task <$independent1>/
);
im_like("/$independent1", qr/\[and then: $dependent1\]/);
im_like("/$dependent1", qr/\[but first: $independent1\]/);

im_like("$independent2 and then $dependent1",
    qr/Task <$dependent1> now depends on task <$independent2>/
);
im_like("/$dependent1", qr/\[but first: $independent1 and 1 more\]/);

im_like("$independent1 andthen $dependent2",
    qr/Task <$dependent2> now depends on task <$independent1>/
);
im_like("/$independent1", qr/\[and then: $dependent1 and 1 more\]/);

im_like("done $independent1", qr/Marking task <$independent1> as done./);
im_like("/$dependent1", qr/\[but first: $independent2\]/);
# }}}
# unowned {{{
command_help_includes("unowned");

im_like("unowned", qr/List the up-for-grabs tasks of which group\?/);
im_like("upforgrabs", qr/List the up-for-grabs tasks of which group\?/);
im_like("unowned nonexistent group", qr/I don't know the 'nonexistent group' group/);
im_like("unowned alpha", qr/No unowned tasks in alpha/);

my ($locator) = create_tasks("foo [group: alpha]");
im_like("unowned alpha", qr/No unowned tasks in alpha/);

im_like("give $locator to nobody", qr/Abandoned task <$locator>/);
my $response = im_like("unowned alpha", qr/1 unowned task in alpha/);
like($response, qr/foo/, "correct task");

($locator) = create_tasks("bar [group: alpha] [owner: otheruser\@example.com]");
$response = im_like("unowned alpha", qr/1 unowned task in alpha/);
like($response, qr/foo/, "correct task");
# }}}
# bare locator shows the task {{{
($locator) = create_tasks("give-me-a-task!");
im_like($locator, qr/give-me-a-task/);

im_like("thisisntalocator", qr/Unknown command/);
# }}}
# alias that uses a builtin alias {{{
im_like('alias give-jay=give this to otheruser@example.com', qr/OK! 'give-jay' now expands to 'give this to otheruser\@example\.com'/);
im_like('c foo', qr/Created 1 task/);
im_like('give-jay', qr/Gave task <#\S+> to otheruser\@example.com/);

im_like('alias set_to_highest_priority=++', qr/OK! 'set_to_highest_priority' now expands to '\+\+'/);
im_like('set_to_highest_priority', qr/Priority set to highest on task <#\S+>/);
# }}}
# alias + unicode {{{
my $tsukutte = "\x{3064}\x{304f}\x{3063}\x{3066}";
im_like("alias $tsukutte=create", qr/OK! '$tsukutte' now expands to 'create'/);
im_like("$tsukutte test", qr/Created 1 task.*test/s);
im_like("$tsukutte $tsukutte", qr/Created 1 task.*$tsukutte/s);
# }}}
# "actually, I wanted to create a task" {{{
im_like("does not exist", qr/Unknown command\..*Use <b>\^<\/b> to create a task from that message/);
$response = im_like("^", qr/Created 1 task/);
($loc) = $response =~ /<#(\w+)>/;

$task = BTDT::Model::Task->new;
$task->load_by_locator($loc);
ok($task->id, "got a task");
is($task->summary, "does not exist", "correct task name");


$response = im_like("^", qr/Created 1 task/);
($loc) = $response =~ /<#(\w+)>/;

$task = BTDT::Model::Task->new;
$task->load_by_locator($loc);
ok($task->id, "got a task");
is($task->summary, "^", "correct task name");
# }}}

# unlink (should always be last) {{{
command_help_includes("unlink");
im_like('unlink', qr/Your IM account successfully unlinked from gooduser\@example\.com\./);

im_like('todo', qr/privacy policy/, "we're no longer an active account");

setup_screenname('otheruser@example.com' => 'tester');
im_like('todo', qr/gooduser should never see this/, "we're now linked to a different account");

im_like('whoami', qr/tester, you are Other User \(otheruser\@example\.com\) on Hiveminder\./);
# }}}
