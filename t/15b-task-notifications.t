use warnings;
use strict;

# {{{ Setup
use BTDT::Test tests => 51;
use Email::Simple;

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;

my $mech = BTDT::Test->get_logged_in_mech($URL);

# }}}

isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->content_like(qr/Logout/i,"Logged in!");
#===========================================================


# Create a group
# XXX refactor into BTDT::Test::WWW::Mechanize
my $group_user = BTDT::CurrentUser->new( email => 'gooduser@example.com');
my $other_user = BTDT::CurrentUser->new( email => 'otheruser@example.com');
my $onlooking_user = BTDT::CurrentUser->new( email => 'onlooker@example.com');

ok($group_user->id, "Loaded user ".$group_user->id);
my $group = BTDT::Model::Group->new( current_user  => $group_user);
my $groupname = 'testgroup';
$group->create(name => $groupname);
ok($group->id, "Created group ".$group->id);
$group->add_member( $other_user->user_object => 'member');
$group->add_member( $onlooking_user->user_object => 'member');


# Make sure that task-deleted group mails look right
$mech->follow_link_ok(text => "Groups");
$mech->follow_link_ok(text => "$groupname");

ok($mech->find_link(text => "Braindump"));
$mech->follow_link_ok(text => "Braindump");
$mech->content_like(qr|See more syntax for braindump|, "Braindump window showed itself properly");
$mech->fill_in_action_ok('quickcreate',
    text => "Delete me [personal money]");

$mech->click_button(value => 'Create');
$mech->html_ok;

my @emails;
BTDT::Test->setup_mailbox();
ok($mech->find_link(text => "Delete me"));
$mech->follow_link_ok(text => "Delete me");
ok($mech->find_link(text => "Delete"));
$mech->follow_link_ok(text => "Delete");

# We find the form and input manually here because using click_button with a "value"
# parameter fails to actually find the button. HTML::Form's find_input, which
# Mech's click_button relies on, isn't too bright.
# (Note that action_form has a side effect of setting Mech's current form, which
# is important for Delete to work properly.)

# XXX why does this moniker_for call fail intermittently?
my $action_form = $mech->action_form($mech->moniker_for("BTDT::Action::DeleteTask"));
my $input = $action_form->find_input(undef, 'submit');
$mech->click_button(input => $input);
$mech->content_contains("Deleted task", "clicking 'delete this task' deletes a task");
$mech->content_lacks("Delete me", "Deleted task doesn't show up in tasks");

TODO: {
    local $TODO = "We're not sending mail on deletion of unfinished group tasks.";

    @emails = BTDT::Test->messages;
    is(scalar @emails, 1, "Task deleted mail");
    my $deleted_email = $emails[0] || Email::Simple->new("");
    is($deleted_email->header('To'), 'otheruser@example.com', "To address is correct");
    like(($deleted_email->header('Subject')||""), qr{Deleted}, "Subject is correct");
}




# Check a permission error in group emails, which causes Assigned mails to have empty
# strings in their From fields. 
$mech->get_ok($URL);
my $tasktitle = "Assign this task to nobody";
$mech->create_task_ok($tasktitle, $group->id);
BTDT::Test->setup_mailbox();
$mech->follow_link_ok( text => $tasktitle );
$mech->assign_task_ok($tasktitle, 'nobody');
@emails = BTDT::Test->messages;
is(scalar @emails, 2, "Task assignment mail sent for a nobody task reassigned to me");
my $email = $emails[0] || Email::Simple->new('');
like($email->header('Subject'), qr{Abandoned}, "Subject for Abandoned email correct");

# Log out and back in as otheruser
ok($mech->find_link( text => "Logout" ), "Found logout link");
$mech->follow_link_ok( text => "Logout" );
$mech = BTDT::Test->get_logged_in_mech($URL, 'otheruser@example.com', 'something');

# grab the task and check the mail that comes back
BTDT::Test->setup_mailbox();
$mech->follow_link_ok(text => "Groups");
$mech->follow_link_ok(text => "$groupname");
$mech->follow_link_ok(text => "Up for grabs");

$mech->assign_task_ok( $tasktitle, 'otheruser@example.com');
@emails = BTDT::Test->messages;
is(scalar @emails, 2, "Task assignment mail sent for a nobody task reassigned to me");
$email = $emails[0] || Email::Simple->new('');
like($email->header('Subject'), qr{Taken}, "Subject for Taken email correct");
like($email->header('From'), qr{\w / testgroup with Hiveminder}, "from for Taken mail is correct");
unlike($email->body, qr{<> has taken a task\.}, 
       "No permission bug hiding the task acceptor's name in email");
like($email->body, qr{Other User <otheruser\@example.com> has taken a task\.}, 
       "Task taker correct");

$email = $emails[1] || Email::Simple->new('');
like($email->header('Subject'), qr{Taken}, "Subject for Taken email correct");
like($email->header('From'), qr{\w / testgroup with Hiveminder}, "from for Taken mail is correct");
unlike($email->body, qr{<> has taken a task\.}, 
       "No permission bug hiding the task acceptor's name in email");
like($email->body, qr{Other User <otheruser\@example.com> has taken a task\.}, 
       "Task taker correct");



1;
