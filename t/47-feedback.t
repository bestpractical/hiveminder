use warnings;
use strict;

# {{{ Setup
use BTDT::Test tests => 31;
use Email::Simple;

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;

my $mech = BTDT::Test->get_logged_in_mech($URL);

# }}}

# {{{ Test feedback submission without an hm-feedback group
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->content_like(qr/Logout/i,"Logged in!");

$mech->fill_in_action_ok($mech->moniker_for('BTDT::Action::SendFeedback'),
                         content => "I can't find my pants.");
$mech->submit_html_ok;
$mech->content_contains("Thanks for the feedback");


my @emails = BTDT::Test->messages;

is(scalar @emails, 1, 
"Feedback action sends mail even without a feedback group");

my $email = $emails[0] || Email::Simple->new('');
is($email->header('Subject'),
     "I can't find my pants. [HM Feedback]", 
     "Mail subject is correct");
is($email->header('To'),
   'hiveminders@bestpractical.com',
   'Non-task feedback mail went to hiveminders@bestpractical.com');

# }}}


BTDT::Test->setup_mailbox();  # clear the emails.

my $group = BTDT::Test->setup_hmfeedback_group();

# {{{ Test feedback when there's a hiveminders feedback group

$mech->fill_in_action_ok($mech->moniker_for('BTDT::Action::SendFeedback'),
                         content => "My hovercraft is full of eels!! [eels]");
$mech->submit_html_ok;
$mech->content_contains("Thanks for the feedback");

@emails = BTDT::Test->messages;

# There shouldn't be 2 mails, because if there were, then gooduser got
# a copy of hir own feedback, which isn't how we do things.
is(scalar @emails, 1, 
   'Feedback action sends mail to the right # of group members');

# We test for the sent mail, assuming that a hm-feedback task was created
# if the mail is being sent properly.
$email = $emails[0] || Email::Simple->new('');
like($email->header('Subject'),
     qr{Up for grabs: My hovercraft is full of eels!!}, 
     "Mail subject is correct");
is($email->header('To'),
   'otheruser@example.com',
   "Feedback went to other group members, not to submitter");

my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
$task->load_by_cols(summary => "My hovercraft is full of eels!!");
ok($task->id, "the feedback made a real task");
is($task->priority, 3, "the feedback didn't use the implicit priority (from the !!)");
is($task->tags, '', "the feedback didn't use the explicit [eels] tag");
is($task->group_id, $group->id, "task made it to the right group");
is($task->owner->email, 'nobody', "owned by nobody");
is($task->requestor->email, 'gooduser@example.com', "requested by submitter");
# }}}


BTDT::Test->setup_mailbox();  # clear the emails.
my $u = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
$u->create( email => 'unprivileged@example.com', name => 'unpriv');
ok($u->id);
$task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);

$task->create( summary => 'A feedback task', group_id  => $group->id, requestor => $u, owner => BTDT::CurrentUser->nobody);
ok($task->id, "Created the task");
is($task->group->id, $group->id, "Created the task group");

my @unprivemails = BTDT::Test->messages;
is(scalar @unprivemails, 2, 'On create, we notified the two group members');

BTDT::Test->setup_mailbox();  # clear the emails.
$task->comment("This is a reply from the superuser");
@unprivemails = BTDT::Test->messages;
is(scalar @unprivemails, 3, 'On resolve, we notified the two group members and the requestor');



BTDT::Test->setup_mailbox();  # clear the emails.
$task->set_complete('t');
@unprivemails = BTDT::Test->messages;
is(scalar @unprivemails, 2, 'On resolve, we notified the two group members (but not the requestor)');

1;


