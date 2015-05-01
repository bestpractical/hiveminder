use warnings;
use strict;

# {{{ Setup
use BTDT::Test tests => 123;

my $server = Jifty::Test->make_server;
isa_ok( $server, 'Jifty::TestServer' );

my $URL = $server->started_ok;

my $mech = BTDT::Test->get_logged_in_mech($URL);

isa_ok( $mech, 'Jifty::Test::WWW::Mechanize' );
$mech->content_like( qr/Logout/i, "Logged in!" );

# }}}

# {{{ Verify that BTDT::Test group setup is operable

like( $mech->uri, qr{/todo}i, "Redirected to the inbox" );

ok( $mech->find_link( text => "Groups" ), "Found groups link" );
$mech->follow_link_ok( text => "Groups" );

like( $mech->uri, qr|/groups|, "Got group page" );

ok( $mech->find_link( text => "alpha" ) );
$mech->follow_link_ok( text => "alpha" );

# }}}

# {{{ make 4 new tasks in this group via braindump

my @tasks = ( 'Do thing 1', 'Do thing 2', 'Do thing 3', 'Do thing 4' );

ok( $mech->find_link( text => "Braindump" ) );
$mech->follow_link_ok( text => "Braindump" );
$mech->content_like(
    qr|See more syntax for braindump|,
    "Braindump window showed itself properly"
);
$mech->fill_in_action_ok( 'quickcreate', text => join( "\n", @tasks ) );

$mech->click_button( value => 'Create' );
$mech->html_ok;

$mech->content_unlike(
    qr|See more syntax for braindump|,
    "Braindump window hid itself properly"
);

my $new_email = 'someone@somewhere.com';

# assign tasks to the user

my $tasks_uri = $mech->uri;
foreach my $task (@tasks) {
    $mech->content_like( qr|$task</a>|,
        "Braindump into group created a task '$task'" );

    $mech->follow_link_ok( text => $task );

    my $mon = $mech->moniker_for('BTDT::Action::UpdateTask');

    $mech->fill_in_action_ok( $mon, owner_id => $new_email );
    $mech->submit_html_ok( value => 'Save' ) ;    # FYI this does not work with click_button

    is( $mech->action_field_value( $mech->moniker_for("BTDT::Action::UpdateTask"), 'owner_id'), $new_email, "Owner was reassigned properly to owner $new_email");

    $mech->content_contains( $new_email, "New task owner's email shows up on edit form" );

    # go back to the tasks page to check the next task
    $mech->get_ok($tasks_uri);
}

# did the user get mail about accepting? if so, parse it.
my @emails = BTDT::Test->messages;
is( scalar @emails, 4, "four invite messages sent" );
BTDT::Test->setup_mailbox();    # clear the mailbox

my $confirm_URL_RE
    = qr!(http://.+let/[^//]+/update_task/id/[0-9A-Za-z]+/[0-9A-Za-z]+)!;
my $golegit_URL_RE = qr!(http://.+let/[^//]+/activate_account/.*)!;
my $optout_URL_RE  = qr!(http://.+let/[^//]+/opt_out/.*)!;

# make the user accept task 1
my $confirm_mail = $emails[-4] || Email::Simple->new('');
ok( $confirm_mail, "Sent an invite email" );
is( $confirm_mail->header('To'),
    $new_email, 'invite 1 went to the right place' );

#local $TODO = "See TaskNotification::comment_address and permissions for non-legit users";
like(
    $confirm_mail->header('From'),
    qr{Good Test User / alpha with Hiveminder},
    'invite 1 had the right from address'
);

like( $confirm_mail->body, $confirm_URL_RE, "the email has a confirm URL" );
like( $confirm_mail->body(), $golegit_URL_RE,
    'the email has a go-legit url' );
$confirm_mail->body() =~ $golegit_URL_RE;
my $GO_LEGIT_URL = $1 || '';
like( $confirm_mail->body(), $optout_URL_RE, 'the email has an opt-out url' );

my $confirm_URL_shouldntbe_RE
    = qr!(http://.+let/[^//]+/update_task/id/[0-9A-Za-z]+/[0-9A-Za-z]+-$)!;

unlike( $confirm_mail->body, $confirm_URL_shouldntbe_RE,
    "confirm URL isn't getting hyphenated by mistake" );

like(
    $confirm_mail->body,
    qr{will notify the other members},
    "Text about group reply handling is included"
);
$confirm_mail->body =~ /$confirm_URL_RE/;
my $confirm_URL = $1;

# Now we are doing a letme as "somebody", not running actions as Good Test User

$mech->get_ok($confirm_URL);
$mech->content_contains( "If you're up for taking this on",
    "Text for an accept-this-task form page shows properly" );

$mech->click_button( value => 'Accept' );
$mech->content_contains( "Notes", "User successfully accepted task" );

my @notes = BTDT::Test->messages;

is( scalar @notes, 1, "Accepted notification sent" );
my $note_mail = $notes[0] || Email::Simple->new('');
is( $note_mail->header('To'), 'gooduser@example.com', 'accepted notice went to task owner' );
like( $note_mail->header('From'), qr{someone / alpha with Hiveminder}, 'accepted note had the right from address');

like( $note_mail->body(), qr{has accepted a task}, 'accepted note had the right text');

BTDT::Test->setup_mailbox();    # clear the mailbox

# make the user reject task 2
$confirm_mail = $emails[-3] || Email::Simple->new('');
ok( $confirm_mail, "Sent an invite email" );
is( $confirm_mail->header('To'), $new_email, 'invite 2 went to the right place' );
like( $confirm_mail->header('From'), qr{Good Test User / alpha with Hiveminder}, 'invite 2 had the right from address');
like( $confirm_mail->body, $confirm_URL_RE, "the email has a confirm URL" );
$confirm_mail->body =~ /$confirm_URL_RE/;
$confirm_URL = $1;
$mech->get_ok($confirm_URL);
$mech->content_contains( $tasks[1], "task 2 shows up on the confirm URL page" );

$mech->content_contains( "If you're up for taking this on", "Text for an accept-this-task form page shows properly" );
$mech->click_button(value => 'Decline');

$mech->content_lacks("Notes", "User successfully declined task" );
$mech->content_contains("already declined", "User successfully declined task" );
my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
$task->load_by_cols(summary => $tasks[1]);
is($task->owner_id, 3, "Declined task was assigned back to gooduser, who assigned it originally");
is($task->accepted, undef, "Declined task had its accepted status set to undef");
# for more detailed tests of declined tasks, see 15-task-notification.t near the end

# check notification of task 2
{
    @notes = BTDT::Test->messages;

#local $TODO = "Permissions for nonusers are causing this mail not to get sent";

    is( scalar @notes, 1, "Declined notification sent" );
    my $note_mail = $notes[0] || Email::Simple->new('');
    is( $note_mail->header('To'), 'gooduser@example.com', 'declined notice went to task owner' );
    like( $note_mail->header('From'), qr{someone / alpha with Hiveminder}, 'declined note had the right from address');
    like( $note_mail->body(), qr{has declined a task}, 'declined note had the right text');
    like( $note_mail->body(), qr{Do thing 2}, 'declined note had info about the task' );
    BTDT::Test->setup_mailbox();    # clear the mailbox


    # Make the user go legit
    $mech->get_ok($GO_LEGIT_URL);
    my $newpw = 'foo_bar_baz';
    $mech->fill_in_action_ok(
        $mech->moniker_for('BTDT::Action::GoLegit'),
        'name'              => 'someone',
        'password'         => $newpw,
        'password_confirm' => $newpw,
    );
    $mech->submit_html_ok( value => "Let's go!" );

    $mech->fill_in_action_ok( $mech->moniker_for('BTDT::Action::AcceptEULA') );
    $mech->submit_html_ok( value => "Accept these terms and make our lawyers happy" );
    $mech->content_contains( "Thanks for accepting the agreement", "We accepted the agreement successfully");
    $mech->content_contains( "To Do",      "Arrived at the inbox" );
    $mech->content_contains( "You have 2", "2 Unaccepted tasks" );
    $mech->content_lacks( "You have 4", "Todo list doesn't have 4 unaccepted tasks" );
    $mech->content_lacks( "You have 3", "Todo list doesn't have 3 unaccepted tasks" );

}
    $mech->get_ok($URL);
    $mech->content_lacks( "Do thing 2", "declined task 2 doesn't show up on inbox" );

    $mech->content_contains( "Do thing 1", "accepted task 1 shows up on inbox" );
    $mech->follow_link_ok( text => "Do thing 1", "Completing task 1" );

    $mech->fill_in_action_ok( $mech->moniker_for("BTDT::Action::UpdateTask"), complete => '1' );
    $mech->submit_html_ok();

    $mech->get_ok($URL);
    $mech->content_lacks( "Do thing 1", "completed task 1 not in inbox" );

# check notification of task 1 completion
{
    @notes = BTDT::Test->messages;
    is( scalar @notes, 1, "Completed notification sent" );
    my $note_mail = $notes[0] || Email::Simple->new('');
    is( $note_mail->header('To'), 'gooduser@example.com', 'completed notice went to task owner' );
    like( $note_mail->header('From'), qr{someone / alpha with Hiveminder}, 'completed note had the right from address');
    like( $note_mail->body(), qr{has completed a task}, 'completed note had the right text');
    like( $note_mail->body(), qr{Do thing 1}, 'completed note had info about the task' );
    BTDT::Test->setup_mailbox();    # clear the mailbox


}
# make the user accept task 3 via the web UI, because the letmes in invitations
# no longer work after the password change.

# XXX we should be testing for user-friendly handling of those letmes,
# in case the user clicks on the link after they have gone legit.

$mech->follow_link_ok( text => 'unaccepted tasks' );
$mech->content_contains( "Do thing 3", "Task 3 is on unaccepted-tasks page" );
$mech->follow_link_ok( text => 'Do thing 3' );
$mech->form_number(2);
$mech->click_button(value=> 'Accept');

# make the user accept task 3
$confirm_mail = $emails[-2] || Email::Simple->new("");
ok( $confirm_mail, "Sent an invite email" );
is( $confirm_mail->header('To'), $new_email, 'invite 3 went to the right place' );
like( $confirm_mail->header('From'), qr{Good Test User / alpha with Hiveminder}, 'invite 3 had the right from address');
like( $confirm_mail->body, $confirm_URL_RE, "the email has a confirm URL" );
like( $confirm_mail->body, qr/would like you to/, "the email contains 'would like you to'");

$mech->get_ok($URL);
$mech->content_contains( 'Do thing 3', 'Task 3 shows up in inbox' );
$mech->follow_link_ok( text => 'Do thing 3', 'Task 3 is a link I can follow');

BTDT::Test->setup_mailbox();    # clear the mailbox

# make the user reject task 4
$confirm_mail = $emails[-1] || Email::Simple->new('');
ok( $confirm_mail, "Sent an invite email" );
is( $confirm_mail->header('To'), $new_email, 'invite 4 went to the right place' );
like( $confirm_mail->header('From'), qr{Good Test User / alpha with Hiveminder}, 'invite 4 had the right from address');
like( $confirm_mail->body, $confirm_URL_RE, "the email has a confirm URL" );

$mech->get_ok($URL);
$mech->follow_link_ok( text => 'unaccepted task' );
$mech->content_contains( 'Do thing 4', 'Task 4 shows up in inbox' );
$mech->follow_link_ok( text => 'Do thing 4', 'Task 4 is a link I can follow');

$mech->form_number(2);
$mech->click_button(value => 'Decline');

# XXX check ownership of task 4: is it to new user or assigning user?

# check notification of task 4
{
    @notes = BTDT::Test->messages;

    is( scalar @notes, 1, "Declined notification sent" );
    $note_mail = $notes[0] || Email::Simple->new('');

    is( $note_mail->header('To'), 'gooduser@example.com', 'declined notice went to task owner' );

    like( $note_mail->header('From'), qr{someone / alpha with Hiveminder}, 'declined note had the right from address');
    like( $note_mail->body(), qr{has declined a task}, 'declined note had the right text');
    like( $note_mail->body(), qr{Do thing 4}, 'declined note had info about the task' );
    BTDT::Test->setup_mailbox();    # clear the mailbox

}

# XXX make sure that the group organizer gets notified of completion

# XXX make sure that display of the uncompleted tasks works properly
