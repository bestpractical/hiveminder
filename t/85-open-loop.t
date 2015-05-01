use warnings;
use strict;

# setup {{{
use BTDT::Test tests => 273;
use BTDT::Test::IM;
my $gooduser  = BTDT::CurrentUser->new( email => 'gooduser@example.com');
my $otheruser = BTDT::CurrentUser->new( email => 'otheruser@example.com');
my $onlooker  = BTDT::CurrentUser->new( email => 'onlooker@example.com');

sub create_task($$)
{
    my ($screenname, $summary) = @_;
    my $current_user;

    $current_user = $gooduser  if $screenname eq 'tester';
    $current_user = $otheruser if $screenname eq 'othertester';
    die "Invalid screenname passed to create_task at line "
      . (caller)[2]
      . "; expected 'tester' or 'othertester'"
          if !defined($current_user);

    my $response = im($screenname, "c $summary", qr/Created 1 task/);
    my ($locator) = $response =~ /<#(\w+)>/;
    my $task = BTDT::Model::Task->new(current_user => $current_user);
    $task->load_by_locator($locator);
    return $task;
}

sub reload_task(\$)
{
    my $task_ref = shift;
    my $id = $$task_ref->id;

    undef $$task_ref;

    $$task_ref = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
    $$task_ref->load($id);
}

setup_screenname($gooduser->id  => 'tester');
setup_screenname($otheruser->id => 'othertester');
setup_screenname($onlooker->id  => 'onlooker');

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;

my $mech = BTDT::Test->get_logged_in_mech($URL);
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->content_like(qr/Logout/i,"Logged in to gooduser!");

my $othermech = BTDT::Test->get_logged_in_mech($URL, 'otheruser@example.com', 'something');
isa_ok($othermech, 'Jifty::Test::WWW::Mechanize');
$othermech->content_like(qr/Logout/i,"Logged in to otheruser!");
# }}}
# sanity check {{{
my $task = create_task('tester', 'this is a task for tester only');
is($task->owner_id, $gooduser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $gooduser->id, "next_action_by->id is set even if owner == requestor");
# }}}
# give a task and have it be declined {{{
$task = create_task('tester', 'trying to re-assign this to othertester, but he will decline');
my $locator = $task->record_locator;
is($task->owner_id, $gooduser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $gooduser->id, "next_action_by->id is set even if owner == requestor");

im_like("give #$locator otheruser\@example.com", qr/Gave task <#$locator> to otheruser\@example\.com/, "successfully gave the task up");

reload_task($task);

is($task->owner_id, $otheruser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $otheruser->id, "next_action_by->id now othertester, since he now has the (unaccepted) task");

im('othertester', 'decline', qr/<#$locator>/, 'othertester has the pushed task in his decline list');
im('othertester', "decline $locator", qr/Declined task <#$locator>/, 'successful rejection');

reload_task($task);

is($task->owner_id, $gooduser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $gooduser->id, "next_action_by->id now tester, since othertester has declined");
is($task->accepted, undef);

im_like('accept', qr/<#$locator>/, 'tester has the declined task in his accept lisit');
im_like("accept $locator", qr/Accepted task <#$locator>/, 'successful acceptance');

reload_task($task);

is($task->owner_id, $gooduser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $gooduser->id);
is($task->accepted, 1);
# }}}
# create a task for the otheruser, have it declined {{{
$task = create_task('tester', 'something for the other user [owner: otheruser@example.com]');
$locator = $task->record_locator;
is($task->owner_id, $otheruser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $otheruser->id, "next_action_by->id now othertester, since he now has the (unaccepted) task");
is($task->accepted, undef);

im('othertester', 'decline', qr/<#$locator>/, 'othertester has the pushed task in his decline list');
im('othertester', "decline $locator", qr/Declined task <#$locator>/, 'successful rejection');

reload_task($task);

is($task->owner_id, $gooduser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $gooduser->id, "next_action_by->id now tester, since othertester has declined");
is($task->accepted, undef);

im_like('accept', qr/<#$locator>/, 'tester has the declined task in his accept lisit');
im_like("accept $locator", qr/Accepted task <#$locator>/, 'successful acceptance');

reload_task($task);

is($task->owner_id, $gooduser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $gooduser->id);
is($task->accepted, 1);
# }}}
# give a task and have it be accepted {{{
$task = create_task('tester', 're-assigning this to othertester, he will accept');
my $misc_locator = $task->record_locator;
is($task->owner_id, $gooduser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $gooduser->id, "next_action_by->id is set even if owner == requestor");
is($task->accepted, 1);

im_like("give #$misc_locator otheruser\@example.com", qr/Gave task <#$misc_locator> to otheruser\@example\.com/, "successfully gave the task up");
reload_task($task);
is($task->owner_id, $otheruser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $otheruser->id, "next_action_by->id now othertester, since he now has the (unaccepted) task");
is($task->accepted, undef);

im('othertester', 'accept', qr/<#$misc_locator>/, 'othertester has the pushed task in his accept list');
im('othertester', "accept $misc_locator", qr/Accepted task <#$misc_locator>/, 'successful acceptance');

reload_task($task);

is($task->owner_id, $otheruser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $otheruser->id, "next_action_by->id otheruser, since the task was pushed to him");
is($task->accepted, 1);
# }}}
# gooduser creates a task for otheruser {{{
$task = create_task('tester', 'start with owner ne requestor [by: otheruser@example.com]');
$locator = $task->record_locator;
is($task->owner_id, $otheruser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $otheruser->id, "next_action_by->id starts off set to owner");
# }}}
# now start commenting and ping-ponging next_action_by {{{
msg("tester", "comment #$locator this should not affect NAB");
reload_task($task);

is($task->owner_id, $otheruser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $otheruser->id, "nab unaffected by comment from non-nab");

msg("othertester", "comment #$locator right back at ya!");
reload_task($task);

is($task->owner_id, $otheruser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $gooduser->id, "nab flipped by comment from nab");

msg("othertester", "comment #$locator should again not affect NAB");
reload_task($task);

is($task->owner_id, $otheruser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $gooduser->id, "nab unaffected by comment from non-nab");

msg("tester", "comment #$locator back at otheruser");
reload_task($task);

is($task->owner_id, $otheruser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $otheruser->id, "nab flipped by comment from nab");

msg("othertester", "done #$locator");
msg("othertester", "comment #$locator ping ponging doesn't stop even if task is complete");
reload_task($task);

is($task->owner_id, $otheruser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $gooduser->id, "nab changes even if task is done");
# }}}
# third party comments and groups {{{
msg("othertester", "undone #$locator");

im("onlooker", "comment #$locator I shouldn't be able to do this!", qr/You can't comment on task <#$locator>/);

reload_task($task);

is($task->owner_id, $otheruser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $gooduser->id, "nab unaffected by third party comment failure");

# make the group, add all three people {{{
my $group = BTDT::Model::Group->new(current_user => BTDT::CurrentUser->superuser);
$group->create(
    name => 'hooah',
    description => 'hooah',
);
$group->add_member($gooduser, 'organizer');
$group->add_member($otheruser, 'member');
$group->add_member($onlooker, 'member');
# }}}

im("onlooker", "comment #$locator I still shouldn't be able to do this since the task is not part of the group", qr/You can't comment on task <#$locator>/);

reload_task($task);

is($task->owner_id, $otheruser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $gooduser->id, "nab unaffected by third party comment failure");

$task->set_group_id($group->id);
reload_task($task);
ok($task->group_id);

im("onlooker", "comment #$locator I NOW should be able to do this since the task IS part of the group", qr/Added your comment to task <#$locator>/);

reload_task($task);

is($task->owner_id, $otheruser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $gooduser->id, "nab unaffected by third party comment success");

# make sure the task still bounces around when it's in the group
msg("othertester", "comment #$locator right back at ya!");
reload_task($task);

is($task->owner_id, $otheruser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $gooduser->id, "nab flipped by comment from nab in group");

msg("othertester", "comment #$locator should again not affect NAB");
reload_task($task);

is($task->owner_id, $otheruser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $gooduser->id, "nab unaffected by comment from non-nab in group");

msg("tester", "comment #$locator back at otheruser");
reload_task($task);

is($task->owner_id, $otheruser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $otheruser->id, "nab flipped by comment from nab in group");
# }}}

# make sure that accepted pings back to the right person {{{
{
    my $other_task = create_task("tester", "Going through a nobody phase [group: hooah]");
    is($other_task->owner_id, $gooduser->id);
    is($other_task->requestor_id, $gooduser->id);
    ok($other_task->group_id);
    is($other_task->accepted, 1);

    $locator = $other_task->record_locator;
    msg("tester", "give #$locator to nobody");
    reload_task($other_task);

    is($other_task->owner_id, BTDT::CurrentUser->nobody->id);
    is($other_task->requestor_id, $gooduser->id);
    ok($other_task->group_id);
    is($other_task->accepted, 1);

    msg("tester", "give #$locator to otheruser\@example.com");
    reload_task($other_task);

    is($other_task->owner_id, $otheruser->id);
    is($other_task->requestor_id, $gooduser->id);
    ok($other_task->group_id);
    is($other_task->accepted, undef);

    msg('othertester', "decline $locator");
    reload_task($other_task);

    is($other_task->owner_id, BTDT::CurrentUser->nobody->id);
    is($other_task->requestor_id, $gooduser->id);
    ok($other_task->group_id);
    is($other_task->accepted, 1);
}
# }}}

# Tasks owned by nobody are always accepted {{{
{
    my $other_task = create_task("tester", "Going through a nobody phase [group: hooah] [owner: nobody]");
    is($other_task->owner_id, BTDT::CurrentUser->nobody->id);
    is($other_task->requestor_id, $gooduser->id);
    ok($other_task->group_id);
    is($other_task->accepted, 1);
}
# }}}

# web UI for gooduser {{{
ok(!$gooduser->user_object->pro_account, "these tests depend on gooduser being a free account");

create_task("tester", "first sanity check!");

is($task->summary, 'start with owner ne requestor', 'making sure we have the right task');
is($task->owner_id, $otheruser->id);
is($task->requestor_id, $gooduser->id);
isnt($task->next_action_by->id, $gooduser->id);

ok($mech->find_link(text => "Due tomorrow"), "have a list nav");
ok(!$mech->find_link(text => "Waiting on"),                 "open-loop searches available only to pro accounts 1/4");
ok(!$mech->find_link(text => "Needs reply"),                "open-loop searches available only to pro accounts 2/4");
ok(!$mech->find_link(text => "Needs reply, others' tasks"), "open-loop searches available only to pro accounts 3/4");
ok(!$mech->find_link(text => "Needs reply, my tasks"),      "open-loop searches available only to pro accounts 4/4");

$mech->get_ok($URL . '/list/not/next/action/by/me/requestor/me', "Loaded search page with pro-only query");
$mech->content_like(qr/start with owner ne requestor/, "pro-only query didn't work for free account");
$mech->content_like(qr/first sanity check!/, "first sanity check");

BTDT::Test->make_pro($gooduser);

$mech->get_ok($URL . '/list/not/next/action/by/me/requestor/me', "Loaded search page with pro-only query");
$mech->content_like(qr/start with owner ne requestor/, "pro-only query did work for pro account");
$mech->content_unlike(qr/first sanity check!/, "first sanity check");

ok($mech->find_link(text => "Due tomorrow"), "have a list nav");
ok($mech->find_link(text => "Waiting on"),                 "open-loop searches are available to pro accounts 1/4");
ok($mech->find_link(text => "Needs reply"),                "open-loop searches are available to pro accounts 2/4");
ok($mech->find_link(text => "Needs reply, others' tasks"), "open-loop searches are available to pro accounts 3/4");
ok($mech->find_link(text => "Needs reply, my tasks"),      "open-loop searches are available to pro accounts 4/4");
# }}}
# web UI for otheruser {{{
ok(!$otheruser->user_object->pro_account, "these tests depend on otheruser being a free account");

is($task->summary, 'start with owner ne requestor', 'making sure we have the right task');
is($task->owner_id, $otheruser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $otheruser->id);

$task = create_task("othertester", "another sanity check!");
is($task->summary, 'another sanity check!', 'making sure we have the right task');
is($task->owner_id, $otheruser->id);
is($task->requestor_id, $otheruser->id);
is($task->next_action_by->id, $otheruser->id);

msg('othertester', "comment #$misc_locator this is now an otheruser task");
$task->load_by_locator($misc_locator);
is($task->summary, 're-assigning this to othertester, he will accept', 'making sure we have the right task');
is($task->owner_id, $otheruser->id);
is($task->requestor_id, $gooduser->id);
is($task->next_action_by->id, $gooduser->id);

ok($othermech->find_link(text => "Due tomorrow"), "have a list nav");
ok(!$othermech->find_link(text => "Waiting on"),                 "open-loop searches available only to pro accounts 1/4");
ok(!$othermech->find_link(text => "Needs reply"),                "open-loop searches available only to pro accounts 2/4");
ok(!$othermech->find_link(text => "Needs reply, others' tasks"), "open-loop searches available only to pro accounts 3/4");
ok(!$othermech->find_link(text => "Needs reply, my tasks"),      "open-loop searches available only to pro accounts 4/4");

$othermech->get_ok($URL . '/list/next/action/by/me/owner/me', "Loaded search page with pro-only query");
$othermech->content_like(qr/start with owner ne requestor/, "pro-only query didn't work for free account");
$othermech->content_like(qr/another sanity check!/, "another sanity check");
$othermech->content_like(qr/re-assigning this/);

BTDT::Test->make_pro($otheruser);

$othermech->get_ok($URL . '/list/next/action/by/me/owner/me', "Loaded search page with pro-only query");
$othermech->content_like(qr/start with owner ne requestor/, "pro-only query did work for pro account");
$othermech->content_like(qr/another sanity check!/, "another sanity check");
$othermech->content_unlike(qr/re-assigning this/, "next action by me specifically filtered out gooduser's nab");

ok($othermech->find_link(text => "Due tomorrow"), "have a list nav");
ok($othermech->find_link(text => "Waiting on"),                 "open-loop searches are available to pro accounts 1/4");
ok($othermech->find_link(text => "Needs reply"),                "open-loop searches are available to pro accounts 2/4");
ok($othermech->find_link(text => "Needs reply, others' tasks"), "open-loop searches are available to pro accounts 3/4");
ok($othermech->find_link(text => "Needs reply, my tasks"),      "open-loop searches are available to pro accounts 4/4");
# }}}

