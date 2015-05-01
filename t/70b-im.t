use warnings;
use strict;

use BTDT::Test tests => 1245;
use BTDT::Test::IM;

# setup {{
# See the caveats section of Test::More
my $builder = Test::More->builder;
binmode $builder->output,         ":utf8";
binmode $builder->failure_output, ":utf8";
binmode $builder->todo_output,    ":utf8";

setup_screenname('gooduser@example.com' => 'tester');
setup_screenname('otheruser@example.com' => 'othertester');
setup_screenname('gooduser@example.com' => 'incognito');

my $gooduser = BTDT::CurrentUser->new(email => 'gooduser@example.com');
my $otheruser = BTDT::CurrentUser->new(email => 'otheruser@example.com');
my $ADMIN = BTDT::CurrentUser->superuser;

$gooduser->user_object->set_per_page(10);

our $group1 = BTDT::Model::Group->new(current_user => $ADMIN);
$group1->create(
    name => 'hiveminders feedback',
    description => 'dummy feedback group'
);
$group1->add_member($gooduser, 'organizer');
$group1->add_member($otheruser, 'member');

is(scalar @{$group1->members->items_array_ref}, 3,
    "Group has 3 members"); # the other one is the superuser

our $spectre = BTDT::Model::Group->new(current_user => $ADMIN);
$spectre->create(
name => 'SPECTRE',
description => 'SPecial Executive for Counter-intelligence, Terrorism, Revenge and Extortion'
);
$spectre->add_member($otheruser, 'organizer');

is(scalar @{$spectre->members->items_array_ref}, 2,
    "Group has 2 members"); # the other one is the superuser

# a bunch of tasks to play with
im_like("c " . join("\n", split ' ', << "TASKS"), qr/Created 36 tasks/);
hydrogen helium lithium beryllium boron carbon nitrogen oxygen fluorine
neon sodium magnesium aluminum silicon phosphorus sulfur chlorine argon
potassium calcium scandium titanium vanadium chromium manganese iron
cobalt nickel copper zinc gallium germanium arsenic selenium bromine
krypton
TASKS
# }}}
# help {{{
my $response = msg("tester", "help context");
unlike($response, qr/I don't have a help file for /, "help context has its own help page");

$response = msg("tester", "help help");
like($response, qr/The four things you'll do/, "help help gives same output as help");

$response = msg("tester", "help hi");
like($response, qr/I don't have a help file for /, "hi is a secret command, so feign ignorance on 'help hi'");

$response = msg("tester", "help thanks");
like($response, qr/I don't have a help file for /, "thanks is a secret command, so feign ignorance on 'help thanks'");
# }}}
# basic group stuff {{{
my $task = BTDT::Model::Task->new(current_user => $gooduser);
my ($val, $msg) = $task->create(
    summary => 'this is a GROUP task',
    group_id => $group1->id,
);
ok($val, "Created group task with API");

$response = msg("tester", "todo GROUP task");
like($response, qr/this is a GROUP task/, "task shows up in tester's todo");
like($response, qr/hiveminders feedback/, "task includes group name");
# }}}
# paging + delete {{{
$response = msg("tester", "search e");
my ($locator, $summary) = $response =~ /<#(\w+)>: (.*)/;

$response = msg("tester", "delete #$locator");
like($response, qr/Deleted task <#$locator>/, "successfully deleted");

msg("tester", "next");
$response = msg("tester", "prev");
like($response, qr/#$locator/, "deleted locator still appears on page");
unlike($response, qr/<#$locator>/, "deleted locator not linked");
unlike($response, qr/: \Q$summary\E/, "deleted locator's summary missing");
like($response, qr/#$locator not found/, "deleted locator gives an error");
# }}}
# rename {{{
command_help_includes('rename');

im_like("rename #Z holy moly", qr/I don't understand/);

$response = msg("tester", "rename #Z to holy moly");
like($response, qr/Task <#Z> is now: holy moly/);

im_like("rename #33 to decline this", qr/Task <#33> is now: decline this/);
im_like("rename #35 to decline that", qr/Task <#35> is now: decline that/);

$response = msg("tester", "todo #Z");
like($response, qr/holy moly/, "new summary comes through");
unlike($response, qr/decline meee/, "old summary gone");

$response = msg("tester", "rename #Z #X to error!!");
unlike($response, qr/Task <#Z> is now: error!!/);
unlike($response, qr/Task <#X> is now: error!!/);
like($response, qr/You can only rename one task at a time/);

$response = msg("tester", "todo #Z #X");
unlike($response, qr/error!!/, "tasks aren't updated if in error");

$response = msg("tester", "rename /#Z to searching works");
like($response, qr/Task <#Z> is now: searching works/);

$response = msg("tester", "todo #Z");
like($response, qr/searching works/, "new summary comes through");
unlike($response, qr/holy moly/, "old summary gone");

$response = msg("tester", "rename");
like($response, qr/I don't understand/, "refusing to set the summary to the empty string");

$response = msg("tester", "rename #Z");
like($response, qr/I don't understand/, "refusing to set the summary to the empty string");

$response = msg("tester", "rename #Z to");
like($response, qr/Set the summary to what\?/, "refusing to set the summary to the empty string");

$response = msg("tester", "rename #Z to      \n   ");
like($response, qr/Set the summary to what\?/, "refusing to set the summary to the empty string");

$response = msg("tester", "rename #Z to decline [due 2001-01-01]");
like($response, qr/Task <#Z> is now: decline(?! \[)/, "braindump syntax is parsed out");

$response = msg("tester", "todo #Z");
like($response, qr/decline/, "new summary comes through");
like($response, qr/\[due: 2001-01-01]/, "due date shows up properly");
unlike($response, qr/searching works/, "old summary gone");
# }}}
# supercharged commands {{{
msg("tester", "hide #7 #Z #9 #35 #33 until yesterday");
# due {{{
$response = msg("tester", "due /thisnotfound by next month");
like($response, qr/No matches\./);

$response = msg("tester", "due /decline by next month");
like($response, qr/Due date set to \d\d\d\d-\d\d-\d\d on tasks <#Z>, <#33>, and <#35>\./);

$response = msg("tester", "due");
like($response, qr/Tasks <#Z>, <#33>, and <#35> are due \d\d\d\d-\d\d-\d\d/);

$response = msg("tester", "due /decline");
like($response, qr/Tasks <#Z>, <#33>, and <#35> are due \d\d\d\d-\d\d-\d\d/);

$response = msg("tester", "due /decline/ #7 /foo/");
like($response, qr/Task <#7> has no due date\./);
like($response, qr/Tasks <#Z>, <#33>, and <#35> are due \d\d\d\d-\d\d-\d\d/);

$response = msg("tester", "due /decline/ 7 /foo/ by never");
like($response, qr/Unset the due date on tasks <#7>, <#Z>, <#33>, and <#35>\./);

$response = msg("tester", "due tomorrow: /decline/ 7 /foo");
like($response, qr/Due date set to tomorrow on tasks <#7>, <#Z>, <#33>, and <#35>\./);
# }}}
# review {{{
$response = msg("tester", "review /thisnotfound");
like($response, qr/No matches\./);

my @messages;
$messages[1]{message} = msg("tester", "review /decline");
for (qw/Z 33 35/)
{
    like($messages[1]{message}, qr/<#$_>/);
    @messages = msg("tester", "m");
    like($messages[0]{message}, qr/Hiding task <#$_> until /);
}
msg("tester", "hide #7 #Z #9 #35 #33 until yesterday");

$messages[1]{message} = msg("tester", "review /decline/ 7 /foo");
for (qw/Z 33 35 7/)
{
    like($messages[1]{message}, qr/<#$_>/);
    @messages = msg("tester", "m");
    like($messages[0]{message}, qr/Hiding task <#$_> until /);
}
# }}}
# hide {{{
msg("tester", "hide #7 #Z #9 #35 #33 until yesterday");
$response = msg("tester", "hide /thisnotfound until next month");
like($response, qr/No matches\./);

$response = msg("tester", "hide /decline until next month");
like($response, qr/Hiding tasks <#Z>, <#33>, and <#35> until \d\d\d\d-\d\d-\d\d\./);

$response = msg("tester", "hide until next week");
like($response, qr/Hiding tasks <#Z>, <#33>, and <#35> until \d\d\d\d-\d\d-\d\d\./);

$response = msg("tester", "hide /decline til next month");
like($response, qr/No matches/);

$response = msg("tester", "hide /decline/ #7 /foo/ until next week");
like($response, qr/Hiding task <#7> until \d\d\d\d-\d\d-\d\d\./);

$response = msg("tester", "hide #7 #Z #9 #35 #33 until next week");
like($response, qr/Hiding tasks <#7>, <#9>, <#Z>, <#33>, and <#35> until \d\d\d\d-\d\d-\d\d\./);

$response = msg("tester", "starts tomorrow: /decline/ 7 /foo");
like($response, qr/Hiding task <#7> until tomorrow\./);

$response = msg("tester", "hide /decline/ 7 /foo/ until yesterday");
like($response, qr/Unhiding task <#7>\./);

$response = msg("tester", "hide #7 #Z #9 #35 #33 until yesterday");
like($response, qr/Unhiding tasks <#7>, <#9>, <#Z>, <#33>, and <#35>\./);
# }}}
# tag {{{
$response = msg("tester", "tag /thisnotfound with foo bar");
like($response, qr/No matches\./);

$response = msg("tester", "tag /decline with foo bar");
like($response, qr/Updated tasks <#Z>, <#33>, and <#35> with tags: \[foo\] \[bar\]/);

$response = msg("tester", "tag with foo bar");
like($response, qr/Updated tasks <#Z>, <#33>, and <#35> with tags: \[foo\] \[bar\]/);

$response = msg("tester", "tag /decline [baz quux]");
like($response, qr/Updated tasks <#Z>, <#33>, and <#35> with tags: \[baz\] \[quux\]/);

$response = msg("tester", "tag /decline/ #7 /foo/ [quuux quuuux]");
like($response, qr/Updated tasks <#7>, <#Z>, <#33>, and <#35> with tags: \[quuux\] \[quuuux\]/);

$response = msg("tester", "tag /decline/ 7 /foo/ [quuuuux quuuuuux]");
like($response, qr/Updated tasks <#7>, <#Z>, <#33>, and <#35> with tags: \[quuuuux\] \[quuuuuux\]/);
# }}}
# done {{{
$response = msg("tester", "done /thisnotfound");
like($response, qr/No matches\./);

$response = msg("tester", "done /decline");
like($response, qr/Multiple tasks match your search/);
like($response, qr/<#Z>/);
like($response, qr/<#33>/);
like($response, qr/<#35>/);

$response = msg("tester", "y");
like($response, qr/Marking tasks <#Z>, <#33>, and <#35> as done/);

$response = msg("tester", "done");
like($response, qr/Tasks <#Z>, <#33>, and <#35> are already done/);

$response = msg("tester", "done /decline");
like($response, qr/No matches\./);

$response = msg("tester", "done /decline/ #7 /boron/");
like($response, qr/Multiple tasks match your search/);
like($response, qr/<#7>/);
like($response, qr/<#9>/);

$response = msg("tester", "y");
like($response, qr/Marking tasks <#7> and <#9> as done/);

$response = msg("tester", "done /decline/ 7 /boron/");
like($response, qr/Task <#7> is already done/);
# }}}
# undone {{{
$response = msg("tester", "undone /thisnotfound");
like($response, qr/No matches\./);

$response = msg("tester", "undone /decline");
like($response, qr/Multiple tasks match your search/);
like($response, qr/<#Z>/);
like($response, qr/<#33>/);
like($response, qr/<#35>/);

$response = msg("tester", "y");
like($response, qr/Marking tasks <#Z>, <#33>, and <#35> as not done/);

$response = msg("tester", "undone");
like($response, qr/Tasks <#Z>, <#33>, and <#35> are not done/);

$response = msg("tester", "undone /decline");
like($response, qr/No matches\./);

$response = msg("tester", "undone /decline/ #7 /boron/");
like($response, qr/Multiple tasks match your search/);
like($response, qr/<#9>/);
like($response, qr/<#7>/);

$response = msg("tester", "y");
like($response, qr/Marking tasks <#7> and <#9> as not done/);

$response = msg("tester", "undone /decline/ 7 /boron/");
like($response, qr/Task <#7> is not done/);
# }}}
# priority {{{
$response = msg("tester", "priority /thisnotfound highest");
like($response, qr/No matches\./);

$response = msg("tester", "priority /decline 9");
like($response, qr/Priority set to highest on tasks <#Z>, <#33>, and <#35>/);

$response = msg("tester", "priority /decline/ 33");
like($response, qr/Tasks <#Z>, <#33>, and <#35> have highest priority\./);

$response = msg("tester", "priority");
like($response, qr/Tasks <#Z>, <#33>, and <#35> have highest priority/);

$response = msg("tester", "priority high");
like($response, qr/Priority set to high on tasks <#Z>, <#33>, and <#35>/);

$response = msg("tester", "priority /decline/ #7 /foo/");
like($response, qr/Tasks <#Z>, <#33>, and <#35> have high priority\./);
like($response, qr/Task <#7> has normal priority\./);

$response = msg("tester", "--/decline/ #7 /foo/");
like($response, qr/Priority set to lowest on tasks <#7>, <#Z>, <#33>, and <#35>/);

$response = msg("tester", "priority normal: /decline/ #7 /foo");
like($response, qr/Priority set to normal on tasks <#7>, <#Z>, <#33>, and <#35>/);
# }}}
# show {{{
$response = msg("tester", "show /thisnotfound");
like($response, qr/No matches\./);

$response = msg("tester", "show /decline");
for (qw/Z 33 35/) { like($response, qr/<#$_>/) }

$response = msg("tester", "show");
for (qw/Z 33 35/) { like($response, qr/<#$_>/) }

$response = msg("tester", "show /decline/ #7 /foo/");
for (qw/Z 33 35 7/) { like($response, qr/<#$_>/) }

$response = msg("tester", "show");
for (qw/Z 33 35 7/) { like($response, qr/<#$_>/) }
# }}}
# history {{{
$response = msg("tester", "history /thisnotfound");
like($response, qr/No matches\./);

$response = msg("tester", "history /decline");
like($response, qr/<#Z>:/);

$response = msg("tester", "history");
like($response, qr/<#Z>:/);

$response = msg("tester", "history /decline/ #7 /foo/");
like($response, qr/<#Z>:/);

$response = msg("tester", "history #7 /foo/ /decline");
like($response, qr/<#7>:/, "history doesn't sort its input");
# }}}

# give {{{
$response = msg("tester", 'give /thisnotfound to foo@bar.com');
like($response, qr/No matches\./);

$response = msg("tester", 'give /decline to OtherUser@Example.Com');
like($response, qr/Gave tasks <#Z>, <#33>, and <#35> to otheruser\@example.com/);

$response = msg("tester", 'give otheruser@example.com');
TODO:
{
    local $TODO = "this needs a better response than 'Gave tasks..'";
    like($response, qr/Cannot give away tasks <#Z>, <#33>, and <#35>/);
}

$response = msg("tester", 'give otheruser@example.com: /decline/ #7 /boron');
like($response, qr/Gave tasks <#7> and <#9> to otheruser\@example.com/);
# }}}
# accept/decline {{{
$response = msg("othertester", 'accept /thisnotfound');
like($response, qr/No matches\./);

$response = msg("othertester", 'accept /decline');
like($response, qr/Accepted tasks <#Z>, <#33>, and <#35>/);

$response = msg("othertester", 'accept these');
like($response, qr/You already own tasks <#Z>, <#33>, and <#35>/);

$response = msg("othertester", 'accept /decline/ #7 /boron');
like($response, qr/Accepted tasks <#7> and <#9>/);
# }}}
# delete {{{
$response = msg("othertester", "delete /thisnotfound");
like($response, qr/No matches\./);

$response = msg("othertester", "delete /decline");
like($response, qr/Multiple tasks match your search/);
like($response, qr/<#Z>/);
like($response, qr/<#33>/);
like($response, qr/<#35>/);

$response = msg("othertester", "y");
like($response, qr/Deleted tasks <#Z>, <#33>, and <#35>/);

$response = msg("othertester", "delete");
like($response, qr/Delete what\?/);

$response = msg("othertester", "delete /decline");
like($response, qr/No matches\./);

$response = msg("othertester", "delete /decline/ #7 /boron/");
like($response, qr/Multiple tasks match your search/);
like($response, qr/<#9>/);
like($response, qr/<#7>/);

$response = msg("othertester", "y");
like($response, qr/Deleted tasks <#7> and <#9>/);

$response = msg("othertester", "delete /decline/ 7 /foo/");
like($response, qr/Cannot find task <#7>/);
# }}}
# }}}
# aliases {{{
# simple usage {{{
$response = msg("tester", "alias");
like($response, qr/You currently have no aliases/);
like($response, qr/Here's an example of how to create one/);
like($response, qr/alias w=todo \@work/);

$response = msg("tester", "w");
like($response, qr/Unknown command/);

$response = msg("tester", 'alias w=todo @work');
like($response, qr/OK! 'w' now expands to 'todo \@work'/);

$response = msg("tester", "w");
like($response, qr/No matches/);

$response = msg("tester", "create coversheet for tps report [\@work tps]\nhawaiian shirt day! [\@work] [due friday]");
like($response, qr/Created 2 tasks/);

$response = msg("tester", "w");
like($response, qr/coversheet for tps report/);
like($response, qr/hawaiian shirt day!/);

$response = msg("tester", 'w @work');
like($response, qr/coversheet for tps report/);
like($response, qr/hawaiian shirt day!/);

$response = msg("tester", "w tps");
like($response, qr/coversheet for tps report/);
unlike($response, qr/hawaiian shirt day!/);

$response = msg("tester", "w hawaiian");
unlike($response, qr/coversheet for tps report/);
like($response, qr/hawaiian shirt day!/);

$response = msg("tester", "w panic!!");
unlike($response, qr/coversheet for tps report/);
unlike($response, qr/hawaiian shirt day!/);
like($response, qr/No matches/);
# }}}
# alias commands {{{
$response = msg("tester", "alias");
like($response, qr/You have 1 alias:/);
like($response, qr/w=todo \@work/);

$response = msg("tester", "alias baz");
like($response, qr/You have no alias 'baz'/);
like($response, qr/If you'd like to create one, use/);
like($response, qr{alias baz=<i>expansion</i>});

$response = msg("tester", "alias foo=create hee hee, that tickles");
like($response, qr/OK! 'foo' now expands to 'create hee hee, that tickles'/);

$response = msg("tester", "foo");
like($response, qr/Created 1 task/);

$response = msg("tester", "alias");
like($response, qr/You have 2 aliases:/);
like($response, qr/w=todo \@work/);
like($response, qr/foo=create hee hee, that tickles/);
like($response, qr/foo=.*\bw=/s, "aliases are sorted");

$response = msg("tester", "alias w");
like($response, qr/w=todo \@work/);
like($response, qr/If you'd like to remove this alias, use/);
like($response, qr/alias w=/);
 
$response = msg("tester", "alias w=");
like($response, qr/OK\. 'w' is no longer an alias for 'todo \@work'/);
 
$response = msg("tester", "alias");
like($response, qr/You have 1 alias:/);
unlike($response, qr/w=todo \@work/);
like($response, qr/foo=create hee hee, that tickles/);

$response = msg("tester", "alias w");
like($response, qr/You have no alias 'w'/);
like($response, qr/If you'd like to create one, use/);
like($response, qr{alias w=<i>expansion</i>});

$response = msg("tester", "alias w=");
like($response, qr/You have no alias 'w'/);
like($response, qr/If you'd like to create one, use/);
like($response, qr{alias w=<i>expansion</i>});
# }}}
# miscellaneous {{{
# infinitely recursive aliases
$response = msg("tester", "alias aaa=bbb");
like($response, qr/OK! 'aaa' now expands to 'bbb'/);

$response = msg("tester", "aaa");
like($response, qr/Unknown command/);

$response = msg("tester", "alias bbb=aaa");
like($response, qr/OK! 'bbb' now expands to 'aaa'/);

$response = msg("tester", "aaa");
like($response, qr/Unknown command/);

$response = msg("tester", "bbb");
like($response, qr/Unknown command/);

# defining an alias over an existing one
$response = msg("tester", "alias bbb=ccc");
like($response, qr/'bbb' already expands to 'aaa'/);
like($response, qr/If you want to change this alias, delete it first with/);
like($response, qr/alias bbb=/);

$response = msg("tester", "alias bbb=aaa");
like($response, qr/'bbb' already expands to 'aaa'/);
like($response, qr/If you want to change this alias, delete it first with/);
like($response, qr/alias bbb=/);

# aliases are shared across all accounts of a user
$response = msg("incognito", "foo");
like($response, qr/Created 1 task/, "aliases are shared across all of a user's accounts");
like($response, qr/hee hee, that tickles/, "aliases are shared across all of a user's accounts");

# but not across all accounts ever
$response = msg("othertester", "foo");
unlike($response, qr/Created 1 task/, "aliases are not shared across all user accounts");
like($response, qr/Unknown command/, "aliases are not shared across all user accounts");

$response = msg("tester", "alias todo=blech");
like($response, qr/We already have a 'todo' command./);
# }}}
# example aliases from help {{{
$response = msg("tester", 'alias ez=tag easy:');
like($response, qr/OK! 'ez' now expands to 'tag easy:'/);

$response = msg("tester", "ez /tickles");
like($response, qr/Updated tasks <#.*?> and <#.*?> with tag: \[easy\]/);
# }}}
# bugs {{{
# "aliases like 'OSCON08' seem to fail -- Zak
my $smiley = "\x{263a}";
for my $alias (qw/CAPS OSCON08 weird-chars?/, $smiley)
{
    $response = msg("tester", "alias $alias=create [aliases-work]");
    like($response, qr/OK! '\Q$alias\E' now expands to 'create \[aliases-work\]'/);

    $response = msg("tester", "$alias bring cookies");
    like($response, qr/Created 1 task/);
    like($response, qr/bring cookies/);
    like($response, qr/aliases-work/);

    $response = msg("tester", "alias");
    like($response, qr/\Q$alias\E=create \[aliases-work\]/);

    $response = msg("tester", "alias $alias");
    like($response, qr/\Q$alias\E=create \[aliases-work\]/);
    like($response, qr/If you'd like to remove this alias, use/);

    $response = msg("tester", "alias $alias=foo");
    like($response, qr/'\Q$alias\E' already expands to 'create \[aliases-work\]'/);

    $response = msg("tester", "alias $alias=");
    like($response, qr/'\Q$alias\E' is no longer an alias for 'create \[aliases-work\]/);

    $response = msg("tester", "alias $alias=");
    like($response, qr/You have no alias '\Q$alias\E'/);

    $response = msg("tester", "$alias");
    like($response, qr/Unknown command/);
}
# }}}
# }}}
# then {{{
command_help_includes('then');

$response = msg("tester", "c this is a dependent task\nthis is an independent task");
my ($dependent, $independent) = $response =~ /<(#.*?)>/g;

$response = msg("tester", "then $independent $dependent");
like($response, qr/Task <$dependent> now depends on task <$independent>/);

$response = msg("tester", "todo $dependent");
like($response, qr/No matches/);

$response = msg("tester", "todo $independent");
like($response, qr/this is an independent task/);

$response = msg("tester", "done $independent");
like($response, qr/as done/);

$response = msg("tester", "todo $dependent");
like($response, qr/this is a dependent task/);

$response = msg("tester", "c this is also a dependent task\nthis is also an independent task");
($dependent, $independent) = $response =~ /<#(.*?)>/g;

$response = msg("tester", "$independent then $dependent");
like($response, qr/Task <#$dependent> now depends on task <#$independent>/);

$response = msg("tester", "todo #$dependent");
like($response, qr/No matches/);

$response = msg("tester", "todo #$independent");
like($response, qr/this is also an independent task/);

$response = msg("tester", "done #$independent");
like($response, qr/as done/);

$response = msg("tester", "todo #$dependent");
like($response, qr/this is also a dependent task/);

# make sure that "command then task" is still parsed as command
$response = msg("tester", "todo then #$dependent");
like($response, qr/No matches/);

# ...even if it's a valid locator
$response = msg("tester", "c then #$dependent");
like($response, qr/Created 1 task/);

# test for a task depending on itself
$response = msg("tester", "#$dependent then #$dependent");
TODO: { local $TODO = "needs Model::TaskDep to check for A -> A";
unlike($response, qr/Task <#$dependent> now depends on task <#$dependent>/);
like($response, qr/You cannot have a task depend upon itself/);
}

# test for A -> B -> A
$response = msg("tester", "c this is A co-dependent task\nthis is B co-dependent task");
my ($A, $B) = $response =~ /<(#.*?)>/g;

$response = msg("tester", "$A then $B");
like($response, qr/Task <$B> now depends on task <$A>/);

$response = msg("tester", "$B then $A");

TODO: { local $TODO = "needs Model::TaskDep to check for A -> B -> A";
unlike($response, qr/Task <$A> now depends on task <$B>/);
like($response, qr/You cannot have a task depend upon tasks that depend on it/);
}
# }}}
# filter {{{
command_help_includes('filter');

# CRUD {{{
$response = msg("tester", "filter");
like($response, qr/You have no filters/);

$response = msg("tester", "filter clear");
like($response, qr/You have no filters to clear/);

$response = msg("tester", "filter clear 1");
like($response, qr/You have no filters to clear/);

$response = msg("tester", "filter clear -1");
like($response, qr/You have no filters to clear/);

$response = msg("tester", "filter clear 0");
like($response, qr/Filter number out of range/);

$response = msg("tester", "filter clear ZOMG!");
like($response, qr/I don't understand/);
like($response, qr/to clear all filters/);

$response = msg("tester", "filter tag work");
like($response, qr/Added your new filter\. You now have 1/);

$response = msg("tester", "filter");
like($response, qr/You have 1 filter:/);
like($response, qr/tag work/);

$response = msg("tester", "filter clear 2");
like($response, qr/You have only 1 filter\./);

$response = msg("tester", "filter clear");
like($response, qr/Cleared your 1 filter\./);

$response = msg("tester", "filters tag work");
like($response, qr/Added your new filter\. You now have 1/);

$response = msg("tester", "filter tag work");
like($response, qr/Added your new filter\. You now have 2/);

$response = msg("tester", "filter");
like($response, qr/You have 2 filters:/);
like($response, qr/tag work.*tag work/s);

$response = msg("tester", "filter clear");
like($response, qr/Cleared your 2 filters\./);

$response = msg("tester", "filter tag foo");
like($response, qr/Added your new filter\. You now have 1/);

$response = msg("tester", "filter tag bar");
like($response, qr/Added your new filter\. You now have 2/);

$response = msg("tester", "filters");
like($response, qr/You have 2 filters:/);
like($response, qr/tag foo.*tag bar/s);

$response = msg("tester", "filter clear 3");
like($response, qr/You have only 2 filters\./);

$response = msg("tester", "filter clear -3");
like($response, qr/You have only 2 filters\./);

$response = msg("tester", "filter clear 2");
like($response, qr/You no longer have the filter: tag bar/);

$response = msg("tester", "filter clear 2");
like($response, qr/You have only 1 filter\./);

$response = msg("tester", "filter clear -2");
like($response, qr/You have only 1 filter\./);

$response = msg("tester", "filter clear 1");
like($response, qr/You no longer have the filter: tag foo/);

$response = msg("tester", "filter clear 1");
like($response, qr/You have no filters to clear/);

$response = msg("tester", "filter clear -1");
like($response, qr/You have no filters to clear/);

$response = msg("tester", "filter tag foo");
like($response, qr/Added your new filter\. You now have 1/);

$response = msg("tester", "filter tag bar");
like($response, qr/Added your new filter\. You now have 2/);

$response = msg("tester", "filter tag baz");
like($response, qr/Added your new filter\. You now have 3/);

$response = msg("tester", "filter clear -2");
like($response, qr/You no longer have the filter: tag bar/);

$response = msg("tester", "filter clear -2");
like($response, qr/You no longer have the filter: tag foo/);

$response = msg("tester", "filter clear -1");
like($response, qr/You no longer have the filter: tag baz/);
# }}}
# filters for tags {{{
$response = msg("tester", 'filter tag @work');
like($response, qr/Added your new filter\. You now have 1/, "first filter");

$response = msg("tester", "t");
like($response, qr/2 things to do \(1 filter\):/, 'filtered out non-@work tasks');
like($response, qr/hawaiian shirt day!/, '1st non-@work task shows up');
like($response, qr/coversheet for tps report/, '2nd non-@work task shows up');

$response = msg("tester", "create this is a new task using filter");
like($response, qr/\@work/, "filtered tag shows up in create");

$response = msg("tester", "t");
like($response, qr/3 things to do \(1 filter\):/, 'new @work task shows up');
like($response, qr/this is a new task using filter/, 'new @work task shows up');

$response = msg("tester", 'filter tag tps');
like($response, qr/Added your new filter\. You now have 2/, "second filter");

$response = msg("tester", "t");
like($response, qr/1 thing to do \(2 filters\):/, 'filtered out non-@work non-tps tasks');
like($response, qr/coversheet for tps report/, 'only [@work tps] task shows up');

$response = msg("tester", "filter clear 2");
like($response, qr/You no longer have the filter/, "bye tps reports");

$response = msg("tester", 'filter not tag tps');
like($response, qr/Added your new filter\. You now have 2/, "second filter");

$response = msg("tester", "c this shouldn't inherit the tag");
like($response, qr/Created 1 task/);
like($response, qr/inherit the tag/, "got the task summary in the response");
unlike($response, qr/\[.*tps.*\]/, "didn't get the tps tag");

$response = msg("tester", "t");
unlike($response, qr/\[.*tps.*\]/, "didn't get the tps tag");
like($response, qr/hawaiian shirt day!/, '@work non-tps task shows up');
like($response, qr/this is a new task/, '@work non-tps task shows up');
like($response, qr/inherit the tag/, '@work non-tps task shows up');

$response = msg("tester", "filter clear");
like($response, qr/Cleared your 2 filters/, "bye filters");

$response = msg("tester", 'filter tag non-existent');
like($response, qr/Added your new filter\. You now have 1/, "first filter");

$response = msg("tester", "t");
like($response, qr/No matches/, 'filtered out ALL tasks, oops');

$response = msg("tester", "create this other new task using filter");
like($response, qr/non-existent/, "filtered tag shows up in create");

$response = msg("tester", "t");
like($response, qr/1 thing to do/, 'new "non-existent" tagged task shows up');
like($response, qr/this other new task using filter/, 'new non-existent task shows up');

$response = msg("tester", 'filter tag tps');
like($response, qr/Added your new filter\. You now have 2/, "second filter");

$response = msg("tester", "t");
unlike($response, qr/coversheet for tps report/, 'filters only remove, never add');

$response = msg("tester", "filter clear");
like($response, qr/Cleared your 2 filters/, "bye filters");
# }}}
# filters for query {{{
$response = msg("tester", 'filter query ium');
like($response, qr/Added your new filter\. You now have 1/, "first filter");

$response = msg("tester", "t");
like($response, qr/12 things to do/, "ten *ium tasks");

$response = msg("tester", 'filter query vanadium');
like($response, qr/Added your new filter\. You now have 2/, "second filter");

$response = msg("tester", "t");
like($response, qr/1 thing to do/, "one vanadium task");
like($response, qr/vanadium/, "the actual task shows up");

$response = msg("tester", "filter clear");
like($response, qr/Cleared your 2 filters/, "bye filters");
# }}}
# filters for due {{{
# due before {{{
$response = msg("tester", "filter due before in 1 month");
like($response, qr/Added your new filter\. You now have 1/, "first filter");

$response = msg("tester", "todo");
like($response, qr/1 thing to do/);
like($response, qr/hawaiian shirt day!/);

$response = msg("tester", "filter not due before in 1 month");
like($response, qr/Added your new filter\. You now have 2/, "second filter");

$response = msg("tester", "todo");
like($response, qr/No matches/);

$response = msg("tester", "filter query hawaiian");
like($response, qr/Added your new filter\. You now have 3/, "third filter");

$response = msg("tester", "todo");
like($response, qr/No matches/);

$response = msg("tester", "filter clear 1");
like($response, qr/You no longer have the filter: due before in 1 month/, "bye filter");

$response = msg("tester", "todo");
like($response, qr/No matches/, "'filter not due before in 1 month' works");

$response = msg("tester", "filter clear 2");
like($response, qr/You no longer have the filter: query hawaiian/, "bye filter");

$response = msg("tester", "todo");
unlike($response, qr/hawaiian/, "'filter not due before in 1 month' works");

$response = msg("tester", "next");
unlike($response, qr/hawaiian/, "'filter not due before in 1 month' works");

$response = msg("tester", "next");
unlike($response, qr/hawaiian/, "'filter not due before in 1 month' works");

$response = msg("tester", "filter clear");
like($response, qr/Cleared your 1 filter/, "bye filters");
# }}}
# due after {{{
$response = msg("tester", "filter due after in 1 month");
like($response, qr/Added your new filter\. You now have 1/, "first filter");

$response = msg("tester", "todo");
unlike($response, qr/hawaiian shirt day!/);

$response = msg("tester", "next");
unlike($response, qr/hawaiian shirt day!/);

$response = msg("tester", "next");
unlike($response, qr/hawaiian shirt day!/);

$response = msg("tester", "filter not due after in 1 month");
like($response, qr/Added your new filter\. You now have 2/, "second filter");

$response = msg("tester", "todo");
like($response, qr/No matches/);

$response = msg("tester", "filter clear 1");
like($response, qr/You no longer have the filter: due after in 1 month/, "bye filter");

$response = msg("tester", "todo");
like($response, qr/1 thing to do/);
like($response, qr/hawaiian shirt day!/);

$response = msg("tester", "filter clear");
like($response, qr/Cleared your 1 filter/, "bye filters");
# }}}
# due on {{{
$response = msg("tester", "filter due friday");
like($response, qr/Added your new filter\. You now have 1/, "first filter");

$response = msg("tester", "todo");
like($response, qr/hawaiian shirt day!/);
like($response, qr/1 thing to do/);

$response = msg("tester", "filter clear");
like($response, qr/Cleared your 1 filter/, "bye filters");
# }}}
# }}}
# filters for priority {{{
# have a task for each priority {{{
$response = msg("tester", "--#3I");
like($response, qr/Priority set to lowest on task <#3I>/, "lowest priority task");

$response = msg("tester", "-#39");
like($response, qr/Priority set to low on task <#39>/, "low priority task");

$response = msg("tester", "++#3A");
like($response, qr/Priority set to highest on task <#3A>/, "highest priority task");
# }}}
# high/highest {{{
$response = msg("tester", "filter priority above 4");
like($response, qr/Added your new filter\. You now have 1/, "first filter");

$response = msg("tester", "todo");
like($response, qr/1 thing to do/, "1 task > high priority");

like($response, qr/coversheet/, "highest priority task shows up");
unlike($response, qr/hawaiian/, "high priority task gone");

$response = msg("tester", "filter clear");
like($response, qr/Cleared your 1 filter/, "bye filters");

$response = msg("tester", "filter priority above high");
like($response, qr/Added your new filter\. You now have 1/, "first filter");

$response = msg("tester", "todo");
like($response, qr/1 thing to do/, "1 task > high priority");

like($response, qr/coversheet/, "highest priority task shows up");
unlike($response, qr/hawaiian/, "high priority task gone");

$response = msg("tester", "filter clear");
like($response, qr/Cleared your 1 filter/, "bye filters");
# }}}
# low/lowest {{{
$response = msg("tester", "filter priority below 2");
like($response, qr/Added your new filter\. You now have 1/, "first filter");

$response = msg("tester", "todo");
like($response, qr/1 thing to do/, "1 task < low priority");

like($response, qr/bring cookies/, "lowest priority task shows up");
unlike($response, qr/GROUP task/, "low priority task gone");

$response = msg("tester", "filter clear");
like($response, qr/Cleared your 1 filter/, "bye filters");

$response = msg("tester", "filter priority below low");
like($response, qr/Added your new filter\. You now have 1/, "first filter");

$response = msg("tester", "t");
like($response, qr/1 thing to do/, "1 task < low priority");

like($response, qr/bring cookies/, "lowest priority task shows up");
unlike($response, qr/GROUP task/, "low priority task gone");

$response = msg("tester", "filter clear");
like($response, qr/Cleared your 1 filter/, "bye filters");
# }}}
# }}}
# filters for group {{{
$response = msg("tester", 'filter group hiveminders feedback');
like($response, qr/Added your new filter\. You now have 1/, "first filter");

$response = msg("tester", "t");
like($response, qr/1 thing to do \(1 filter\):/, 'filtered out non-feedback tasks');
like($response, qr/GROUP task/, 'feedback task shows up');

$response = msg("tester", "create this is a new group task using filter");
like($response, qr/hiveminders feedback/, "filtered group shows up in create");

$response = msg("tester", "t");
like($response, qr/2 things to do \(1 filter\):/, 'new feedback task shows up');
like($response, qr/new group task using filter/, 'new feedback task shows up');

$response = msg("tester", "filter clear");
like($response, qr/Cleared your 1 filter/, "bye filters");
# }}}
# filters work in the various commands {{{
$response = msg("tester", 'filter group hiveminders feedback');
like($response, qr/Added your new filter\. You now have 1/, "first filter");

$response = msg("tester", "t");
like($response, qr/2 things to do \(1 filter\):/, 'filtered out non-feedback tasks in todo');
like($response, qr/GROUP task/, 'feedback task shows up');
like($response, qr/new group task/, 'filter-created task shows up');

$response = msg("tester", "review");
like($response, qr/Reviewing task 1 of 2/, 'filtered out non-feedback tasks in review');

msg("tester", "q");

$response = msg("tester", "/hawaiian");
like($response, qr/No matches/, 'filtered out non-feedback tasks');

$response = msg("tester", "due /a by tomorrow");
like($response, qr/Due date set to tomorrow on tasks <#39> and <#3U>/, 'searched only feedback tasks');

$response = msg("tester", "due #3A by tomorrow");
like($response, qr/Due date set to tomorrow on task <#3A>/, 'using actual locators ignores filters though');

$response = msg("tester", "filter clear");
like($response, qr/Cleared your 1 filter/, "bye filters");
# }}}
# filter with colons {{{
$response = msg("tester", 'filter tag foo:bar');
like($response, qr/Added your new filter\. You now have 1/, "first filter");

$response = msg("tester", 'c x');
like($response, qr/\[foo:bar\]/, "included the tag with colons");

$response = msg("tester", "filter clear");
like($response, qr/Cleared your 1 filter/, "all filters gone");

$response = msg("tester", 'filter tag a tag:b');
like($response, qr/Added your new filter\. You now have 1/, "first filter");

$response = msg("tester", 'c x');
like($response, qr/\[(a b|b a)\]/, "included the *two* tags");

$response = msg("tester", "filter clear");
like($response, qr/Cleared your 1 filter/, "all filters gone");
# }}}

$response = msg("tester", "filter clear");
like($response, qr/You have no filters to clear/, "all filters gone");
# }}}
# modal create with braindump {{{
# test that the basic feature works
$response = msg("tester", "c [foo] [due: tomorrow]");
unlike($response, qr/Created 1 task/, "create with only braindump syntax opens modal create");
like($response, qr/to finish or type/, "response tells us how to stop the modal create");

$response = msg("tester", "alpha");
like($response, qr/to finish or type/, "response tells us how to stop the modal create");

$response = msg("tester", "beta");
like($response, qr/to finish or type/, "response tells us how to stop the modal create");

$response = msg("tester", ".");
like($response, qr/Created 2 tasks/, "braindump over");
like($response, qr/alpha/, "first task shows up in response");
like($response, qr/beta/, "second task shows up in response");
like($response, qr/\[foo\].*\[foo\]/s, "tag shows up twice");
like($response, qr/\[due: tomorrow\].*\[due: tomorrow\]/s, "due shows up twice");

$response = msg("tester", "todo alpha");
like($response, qr/alpha/, "first task shows up in response");
like($response, qr/\[foo\]/, "tag shows up");
like($response, qr/\[due: tomorrow\]/s, "due shows up");

# make sure that the braindump fields are properly cleared when creating modal
# then normal
$response = msg("tester", "c maaan [priority: high]");
like($response, qr/maaan/, "task shows up in response");
like($response, qr/\[priority: high\]/, "priority shows up in response");
unlike($response, qr/\[foo\]/, "tag NOT in response");
unlike($response, qr/\[due: tomorrow\]/, "due NOT in response");

# make sure that the braindump fields are properly cleared when creating modal
# then more modal, AND normal then modal
$response = msg("tester", "c [bar] [starts: tomorrow]");
unlike($response, qr/Created 1 task/, "create with only braindump syntax opens modal create");
like($response, qr/to finish or type/, "response tells us how to stop the modal create");

$response = msg("tester", "oi oi");
like($response, qr/to finish or type/, "response tells us how to stop the modal create");

$response = msg("tester", ".");
like($response, qr/Created 1 task/, "braindump over");
like($response, qr/oi oi/, "task shows up in response");
like($response, qr/\[bar\]/, "tag shows up in response");
like($response, qr/\[starts: tomorrow\]/, "starts shows up in response");
unlike($response, qr/foo/, "old tag does not show up");
unlike($response, qr/\[due: tomorrow\]/, "due does not show up");
unlike($response, qr/\[priority: high\]/, "priority does not show up");

# make sure that the braindump fields are properly cleared when creating modal
# then modal directly
$response = msg("tester", "c [baz] [group: hiveminders feedback]");
unlike($response, qr/Created 1 task/, "create with only braindump syntax opens modal create");
like($response, qr/to finish or type/, "response tells us how to stop the modal create");

$response = msg("tester", "feechur");
like($response, qr/to finish or type/, "response tells us how to stop the modal create");

$response = msg("tester", ".");
like($response, qr/Created 1 task/, "braindump over");
like($response, qr/feechur/, "task shows up in response");
like($response, qr/\[baz\]/, "tag shows up");
like($response, qr/\[group: hiveminders feedback\]/, "group shows up");

unlike($response, qr/bar/, "tag does not show up");
unlike($response, qr/foo/, "old tag does not show up");
unlike($response, qr/\[starts: tomorrow\]/, "starts does not show up");
unlike($response, qr/\[due: tomorrow\]/, "due does not show up");
unlike($response, qr/\[priority: high\]/, "priority does not show up");
# }}}
# move {{{
command_help_includes('move');

im_like("move #3N into hiveminders feedback", qr/Moved task <#3N> into group 'hiveminders feedback'/);
im_like("move #3N into personal", qr/Moved task <#3N> into group 'personal'/);
im_like("move #3N into PERSONAL", qr/Task <#3N> is already in group 'personal'/);
im_like("move #3N into HIVEMINDERS FEEDBACK", qr/Moved task <#3N> into group 'hiveminders feedback'/);
im_like("move #3N into Hiveminders Feedback", qr/Task <#3N> is already in group 'hiveminders feedback'/);

im_like("move /foo into personal", qr/Tasks <#3X> and <#3Y> are already in group 'personal'/);

im_like("move /nonexistent into personal", qr/No matches/);
im_like("move #ZZZ into personal", qr/Cannot find task <#ZZZ>/);

im_like("move #3N into NONEXISTENT GROUP!!!!", qr/I don't know the 'NONEXISTENT GROUP!!!!' group/);
im_like("move #3N into spectre", qr/I don't know the 'spectre' group/, "cannot see (or move tasks into) a group you're not in");

im_like("move #3N into hiveminders feedback", qr/Task <#3N> is already in group 'hiveminders feedback'/);
im_like("show #3N", qr/group: hiveminders feedback/, "move (group) actually works");
im_unlike("show #3O", qr/group: hiveminders feedback/, "move (personal) actually works");
# }}}
# hi, bye, thanks {{{
my $thanks_re = qr/^(You're welcome!|Don't mention it!|Just doing my job, Good Test User!)$/;
for (1..5) {
    im_like("hi", qr/^(Hiya Good Test User!|Hullo, how may I serve you today\?|Hello, this is an operator.*)$/);
    im_like("bye", qr/^(Bye for now, Good Test User!|See ya!)$/);
    im_like("thanks", $thanks_re);
    im_like("thank! you!", $thanks_re);
}
# }}}
# pseudo-locators "these", "list", "all" {{{
im_like("filter query e", qr/Added your new filter\. You now have 1\./);
im_like("todo g", qr/[^2-9]\d things to do \(page 1 of 2, 1 filter\):/, "plenty of tasks to work with");
im_like("done these", qr/Marking tasks(?: <#\w+>,){9} and <#\w+> as done/, "these uses a page");
im_like("done list", qr/Marking tasks .*? as done/, "list gets even more");
im_like("done all", qr/Marking tasks .*? as done/, "all gets even more");
im_like("filter clear", qr/Cleared your 1 filter/);
# }}}

like(msg("tester", "help"), qr/The four things you'll do/, "not leaving in any kind of mode");

