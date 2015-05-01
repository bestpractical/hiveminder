use warnings;
use strict;

use BTDT::Test tests => 219;

use_ok( 'BTDT::Model::Group' );
use_ok( 'BTDT::CurrentUser' );

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;

my $mech = BTDT::Test->get_logged_in_mech($URL);
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->content_like(qr/Logout/i,"Logged in!");
like($mech->uri, qr{/todo}i, "Redirected to the inbox"); 

ok($mech->find_link(text => "Groups"), "Found groups link");
$mech->follow_link_ok(text => "Groups");

like($mech->uri, qr|/groups|, "Got group page");
# XXX need to check that this is the only group the user belongs to
$mech->content_contains("alpha", "User belongs to alpha group");

make_and_verify_group($mech, name => 'my folks', desc => 'stuff');
make_and_verify_group($mech, name => 'blue pants', desc => 'some description');
make_and_verify_group_trimming($mech, name => '   leading and trailing spaces   ', desc => '  more spaces here  ');

# Test new group creation without description

make_and_verify_group($mech, name => 'other folks');

# Test with conflicting name

$mech->follow_link_ok(text => "New group");
$mech->fill_in_action_ok('newgroup', name => 'my folks');
$mech->submit_html_ok;
unlike($mech->uri, qr{/groups/\d+/manage}, "not on a group page");
like($mech->uri, qr{/groups/create}, "still on create page");
$mech->content_like(qr{<input .+?value="my folks"}, "got same name in form");
$mech->content_contains("Sorry, but someone else beat you to that name", "got same name error");
my $g = BTDT::Model::GroupCollection->new(current_user => BTDT::CurrentUser->superuser);
$g->limit( column => 'name', value => 'my folks' );
is($g->count, 1, "Only one group with the name 'my folks'");

# Test management of the first group
ok($mech->find_link(text => "my folks"));
$mech->follow_link_ok(text => "my folks");
$mech->follow_link_ok(text => "Manage");
like($mech->uri, qr{/groups/\d+/manage}, "on a group page");
my $GROUPS_MEMBERS_URI = $mech->uri;
$mech->content_contains("Manage group members", "got group members management");
$mech->content_contains("my folks");
$mech->content_like(qr!Good Test.*organizer!s, "the user who made the group can manage it");

# test braindump from groups page

ok($mech->find_link(text => "My tasks"));
$mech->follow_link_ok(text => "My tasks");
ok($mech->find_link(text => "Braindump"));
$mech->follow_link_ok(text => "Braindump");
$mech->content_like(qr|See more syntax for braindump|, "Braindump window showed itself properly");
$mech->fill_in_action_ok('quickcreate',
    text => 'Buy new computer [personal money]');

$mech->click_button(value => 'Create');
$mech->html_ok;

$mech->content_like(qr|Buy new computer</a>|, "Braindump into group created a task (or at least something linky looking");
$mech->content_unlike(qr|See more syntax for braindump|, "Braindump window hid itself properly");


# Test another kind of braindump that's known to be failing tests
ok($mech->follow_link(text => "my folks"));
$mech->follow_link_ok(text => 'my folks');
ok($mech->find_link(text => "My tasks"));
$mech->follow_link_ok(text => "My tasks");
ok($mech->find_link(text => "Braindump"));
$mech->follow_link_ok(text => "Braindump");
$mech->fill_in_action_ok('quickcreate',
    text => 'Pay off Mafia! [personal money]');

$mech->submit_html_ok(form_name => 'quickcreate', button => 'Create');
$mech->content_like(qr|Pay off Mafia!</a>|, "Braindump into group handled priority properly");

# XXX TODO make sure that braindumped tasks are going into the proper group
# I want a way to say "Make sure that text A and text B both appear somewhere
# inside the same <span class="task">.

# Make sure we can assign tasks to people not in the group
$mech->follow_link_ok(text => "Edit");
$mech->fill_in_action_ok($mech->moniker_for('BTDT::Action::UpdateTask'),
                         owner_id => 'otheruser@example.com');
$mech->submit_html_ok;

my $other_mech = BTDT::Test->get_logged_in_mech($URL, 'otheruser@example.com', 'something');

$other_mech->follow_link_ok(text_regex => qr/unaccepted/);
$other_mech->content_contains('Pay off Mafia', "The other user's been assigned the task");
$other_mech->follow_link_ok(text_regex => qr/Pay off Mafia/);
$other_mech->form_number(2);
$other_mech->click_button(value => 'Accept');
$other_mech->content_contains('accepted', "I accepted the task");
$other_mech->content_lacks('denied', "I don't get a permission error");

# Make sure we can move tasks between groups
ok($mech->find_link(text_regex => qr'new computer'));
$mech->follow_link(text_regex => qr'new computer');
$mech->fill_in_action_ok($mech->moniker_for('BTDT::Action::UpdateTask'),
                         group_id => 'blue pants');
$mech->submit_html_ok();
$mech->content_lacks('There was an error', 'There was an error while updating');
$mech->content_contains('updated', 'Moved task into another group');
$mech->follow_link(text => 'blue pants');
$mech->content_contains('Buy new computer', 'The task is in the other group');

# and that group-moves with notification also work
ok($mech->find_link(text_regex => qr'new computer'));
$mech->follow_link(text_regex => qr'new computer');
$mech->fill_in_action_ok($mech->moniker_for('BTDT::Action::UpdateTask'),
                         group_id => 'my folks',
                         comment => "I'll get you my pretty");
$mech->submit_html_ok();
$mech->content_lacks('There was an error', 'There was an error while updating');
$mech->content_contains('updated', 'Moved task into another group');
$mech->content_contains("I'll get you my pretty", 'The task picked up a comment');
$mech->follow_link(text => 'my folks');
$mech->content_contains('Buy new computer', 'The task is in the other group');
ok($mech->find_link(text_regex => qr'new computer'));
$mech->follow_link(text_regex => qr'new computer');
$mech->content_contains("I'll get you my pretty", 'The task picked up a comment');

# Test invitations.
$mech->get_ok($GROUPS_MEMBERS_URI, "Loaded group members page again before invite tests"); # XXX hack to cause above test failures not to break everything below 
my @emails = BTDT::Test->messages;
my $email_count = scalar @emails;

#Invite otheruser@example.com to group 1
$mech->fill_in_action_ok('invite',
    email => 'otheruser@example.com',
    role  => 'member',
);
$mech->submit_html_ok;
$mech->content_contains('otheruser@example.com to join my folks');

#Invite otheruser@example.com to 'other folks'
$mech->follow_link_ok(text => "Groups");
$mech->follow_link_ok(text => 'other folks');
$mech->follow_link_ok(text => 'Manage');
$mech->fill_in_action_ok('invite',
    email => 'otheruser@example.com',
    role  => 'member',
);
$mech->submit_html_ok;

# Cancel the second invitation (to 'other folks')
$mech->fill_in_action_ok('invite2');
$mech->submit_html_ok();

# Re-create it as a watcher
$mech->fill_in_action_ok('invite',
    email => 'otheruser@example.com',
    role  => 'guest',
);
$mech->submit_html_ok;

#Invite otheruser@example.com to 'blue pants'
$mech->follow_link_ok(text => "Groups");
$mech->follow_link_ok(text => 'blue pants');
$mech->follow_link_ok(text => 'Manage');
$mech->fill_in_action_ok('invite',
    email => 'otheruser@example.com',
    role  => 'member',
);
$mech->submit_html_ok;


#==== TAKE ACTION ON INVITATIONS ===================

@emails = BTDT::Test->messages;
is(scalar @emails, $email_count + 4, "four messages sent");


my $confirm_mail = $emails[-4];
ok($confirm_mail, "Sent an invite email");
is($confirm_mail->header('To'), 'otheruser@example.com', 'invite went to the right place');

my $confirm_URL_RE = qr!(http://.+groups/invitation/accept/\d+)!;
like($confirm_mail->body, $confirm_URL_RE, "the email has a confirm URL");
$confirm_mail->body =~ $confirm_URL_RE;
my $confirm_URL = $1;
$confirm_URL =~ s!http://hiveminder.com!$URL!;

my $decline_URL_RE = qr!(http://.+groups/invitation/decline/\d+)!;
like($confirm_mail->body, $decline_URL_RE, "the email has a decline URL");
$confirm_mail->body =~ $decline_URL_RE;
my $decline_URL = $1;
$decline_URL =~ s!http://hiveminder.com!$URL!;

# invites should not work for the wrong user!
$mech->get_html_ok($confirm_URL);
$mech->content_contains("That invitation doesn't seem to work", "invite only works for the right user");
# decline the group invitation with the correct user
my $other_user = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
$other_user->load_by_cols(email => 'otheruser@example.com');
ok($other_user->id);
$other_user->set_beta_features('t');


$mech = BTDT::Test->get_logged_in_mech($URL, 'otheruser@example.com', 'something');
$mech->content_like(qr/Logout/i,"Logged in!");
like($mech->uri, qr{/todo}i, "Redirected to the inbox"); 

$mech->get_html_ok($decline_URL);
$mech->content_like(qr{declined the invitation to my folks.}, 
                    "Decline page text is correct");
$mech->follow_link_ok(text => "Logout");

#-------------------------
# log in as inviting user; send another invitation
$mech = BTDT::Test->get_logged_in_mech($URL);
$mech->get_ok($GROUPS_MEMBERS_URI, "Loaded group members page again before invite tests"); # This is a hack to cause above test failures not to break everything below 

#Invite otheruser@example.com to group 1
$mech->fill_in_action_ok('invite',
    email => 'otheruser@example.com',
    role  => 'member',
);
$mech->submit_html_ok;
$mech->content_contains('otheruser@example.com to join my folks');

# Create an unowned task in the group
$mech->get_ok("/groups", "Got groups page");
ok($mech->follow_link(text => "my folks"));
$mech->follow_link_ok(text => 'my folks');
ok($mech->find_link(text => "Up for grabs"));
$mech->follow_link_ok(text => "Up for grabs");
ok($mech->find_link(text => "Braindump"));
$mech->follow_link_ok(text => "Braindump");
$mech->fill_in_action_ok('quickcreate',
    text => 'A task owned by nobody [owner: nobody]');
$mech->submit_html_ok(form_name => 'quickcreate', button => 'Create');
$mech->content_like(qr|A task owned by nobody</a>|, "Braindump into group worked");


# accept the group re-invitation with the correct user.
$mech->follow_link_ok(text => "Logout");
$mech = BTDT::Test->get_logged_in_mech($URL, 'otheruser@example.com', 'something');
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->content_like(qr/Logout/i,"Logged in!");
like($mech->uri, qr{/todo}i, "Redirected to the inbox"); 

@emails = BTDT::Test->messages;

is(scalar @emails, $email_count + 6, "six messages sent");

$confirm_mail = $emails[-1];
ok($confirm_mail, "Sent an re-invite email");
is($confirm_mail->header('To'), 'otheruser@example.com', 're-invite went to the right place');

like($confirm_mail->body, $confirm_URL_RE, "the email has a confirm URL");
$confirm_mail->body =~ $confirm_URL_RE;
$confirm_URL = $1;
$confirm_URL =~ s!http://hiveminder.com!$URL!;

like($confirm_mail->body, $decline_URL_RE, "the email has a decline URL");


$mech->get_html_ok($confirm_URL);
like($mech->uri, qr{groups/\d+}, "redirected to the group page");
$mech->content_contains("Welcome", "contains welcome message");
$mech->content_contains("my folks", "contains the name of the group");
$mech->follow_link_ok(text => "Members");

$mech->content_like(qr!Good Test.*organizer!s, "the user who made the group can manage it");
$mech->content_like(qr!Other User.*member!s, "the user who joined the group can see it");

# Test that the new user can see unowned tasks
ok($mech->find_link(text => "Up for grabs"));
$mech->follow_link_ok(text => "Up for grabs");
$mech->content_like(qr|A task owned by nobody</a>|, "Found task owned by nobody");

# XXX TODO declined mail tests 
my $declined_mail = $emails[-2];
like($declined_mail->body, 
    qr{"?Other User"? <otheruser\@example.com> isn't going to join my folks.},
    "Declined-to-join-group mail has proper body text");
like($declined_mail->header("Subject"), 
   qr!Hiveminder: "?Other User"? declined invitation to my folks!,
   "Subject of declined-to-join-group mail is correct");
is($declined_mail->header("To"), 'gooduser@example.com',
   "To address of declined-to-join-group mail is correct");
like($declined_mail->header("From"), qr!"?Other User"? <otheruser\@example.com>!,
   "From address of declined-to-join-group mail is correct");


# invites should only work once
$mech->get_html_ok($confirm_URL);
$mech->content_contains("Sorry", "invite only works once");

# Test the cancelled invitation
my $cancelled_invite_mail = $emails[-5];
$cancelled_invite_mail->body =~ $confirm_URL_RE;
my $other_confirm_URL = $1;
$mech->get($other_confirm_URL);
$mech->content_contains("cancelled", "Cancelled invitations tell the user about it");

# Log out and try direct-access to the third invite
my $last_invite_mail = $emails[-4];
$last_invite_mail->body =~ $confirm_URL_RE;
my $last_confirm_URL = $1;
$mech->follow_link_ok(text => "Logout");
$mech->get_html_ok($last_confirm_URL);
like($mech->uri, qr{/splash}, "Redirected to login");
$mech->fill_in_action('loginbox', address => 'otheruser@example.com', password => 'something');
$mech->submit_html_ok;

like($mech->uri, qr{groups/\d+}, "redirected to the group page");
$mech->content_contains("Welcome", "contains welcome message");
$mech->content_contains("other folks", "contains the name of the group");


# Try joining the 'blue pants' group through the UI,
# if for some reason you've lost your invitation.

$mech->get_html_ok($URL);

like($mech->uri, qr{/todo}, "Redirected to todo page");
$mech->content_contains("awaiting your answer", "there's an invitation notification on the todo page");
$mech->follow_link_ok(text_regex => qr{invitation(s)?});

# this is annoying because it doesn't test that there's a *specific*
# invitation to blue pants; we just have to click the Accept link
# and hope that it works. 
$mech->content_contains("has invited you to become a", "There's a group invitation on the invitation page");
$mech->follow_link_ok(text => 'Accept');
$mech->content_contains("Welcome to blue pants", "Successfully joined a group through the web UI without an invitation URL");

# Test that I can leave a group
$mech->follow_link_ok(text => 'Members');
$mech->form_number(2);
$mech->click_button(value => 'Leave the group blue pants');
$mech->content_contains("Left the group 'blue pants'");
$mech->content_lacks('Permission denied');


# Test group deletion
$mech = BTDT::Test->get_logged_in_mech($URL);

make_and_verify_group($mech, name => 'one fish', desc => 'red fish, blue fish');
make_and_verify_group($mech, name => 'two fish', desc => 'red fish, silly fish');

$mech->follow_link_ok(text => "Groups");
$mech->follow_link_ok(text => 'one fish');
$mech->follow_link_ok(text => 'Manage');
$mech->action_form('deletegroup');
$mech->click_button(value => 'Delete the group one fish');
$mech->content_contains('Deleted');
$mech->content_lacks('Permission denied');

my $group = BTDT::Model::Group->new( current_user => BTDT::CurrentUser->superuser );
$group->load_by_cols( name => 'one fish' );
ok( ! defined $group->id, "Group doesn't exist" );

$mech->follow_link_ok(text => "Groups");
$mech->follow_link_ok(text => 'two fish');
$mech->follow_link_ok(text => 'Manage');

$mech->fill_in_action_ok('invite',
    email => 'otheruser@example.com',
    role  => 'member',
);
$mech->submit_html_ok;

$mech->follow_link_ok(text => "Manage");
$mech->content_contains("You cannot delete this group");
$mech->content_contains("outstanding group invitations");
$mech->content_lacks("Delete the group two fish");

$mech = BTDT::Test->get_logged_in_mech($URL, 'otheruser@example.com', "something");
$mech->content_contains("awaiting your answer", "there's an invitation notification on the todo page");

$mech->follow_link_ok(text_regex => qr{invitation(s)?});

# this is annoying because it doesn't test that there's a *specific*
# invitation to two fish; we just have to click the Accept link
# and hope that it works. 
$mech->content_contains("has invited you to become a", "There's a group invitation on the invitation page");
$mech->follow_link_ok(text => 'Accept');
$mech->content_contains("Welcome to two fish", "Successfully joined a group through the web UI");

$mech = BTDT::Test->get_logged_in_mech($URL);

$mech->follow_link_ok(text => "Groups");
$mech->follow_link_ok(text => 'two fish');
$mech->follow_link_ok(text => "Manage");

$mech->content_contains("You cannot delete this group");
$mech->content_contains("not the only member");
$mech->content_lacks("oustanding group invitations");
$mech->content_lacks("Delete the group two fish");

# Move task to group
$mech->follow_link_ok( text => "To Do" );
ok($mech->find_link(text_regex => qr'new computer'));
$mech->follow_link(text_regex => qr'new computer');
$mech->fill_in_action_ok($mech->moniker_for('BTDT::Action::UpdateTask'),
                         group_id => 'two fish' );
$mech->submit_html_ok();
$mech->content_lacks('There was an error', 'There was an error while updating');
$mech->content_contains('updated', 'Moved task into another group');

$mech->follow_link_ok(text => "Groups");
$mech->follow_link_ok(text => 'two fish');
$mech->follow_link_ok(text => "Manage", "We're on the manage page");

$mech->content_contains("You cannot delete this group");
$mech->content_contains("still tasks in this group");
$mech->content_lacks("Delete the group two fish", "you can't delete a group with tasks");
$mech->action_form('createaddr');
$mech->click_button(value => "Add a new address");

$mech->content_contains("You cannot delete this group");
$mech->content_contains("still incoming email addresses");
$mech->content_lacks("Delete the group two fish");


###


# Reducing annoying duplication above.
sub make_and_verify_group {
    my $m = shift;

    _make_group_api(@_);
}


sub make_and_verify_group_trimming {
    my $m = shift;
    my %args = @_;  # name, desc

    _make_group($m, @_);

    my $name = $args{'name'};
    $m->content_unlike(qr{$name}, "The $name group (without spaces trimmed) doesn't exist");
    #warn $m->content();
    $name = trim($name);
    $m->content_like(qr{$name}, "The $name group exists with a trimmed name and I can see it");
    $m->get_ok("$URL/groups");  # Group descriptions are on lists, not on edit pages

    my $desc = $args{'desc'};
    $m->content_unlike(qr{$desc}, "Description '$desc' (without spaces trimmed) doesn't show up on the edit page");
    $desc = trim($desc);
    $m->content_like(qr{$desc}, 
                     "Description '$desc' (properly trimmed) shows up on edit page");
    
}

sub _make_group {
    my $m = shift;
    my %args = @_;  # name, desc


    $m->get_ok("$URL/groups");

    $m->content_lacks($args{'name'});
    $m->content_lacks($args{'desc'}) if (exists $args{'desc'});
    $m->follow_link_ok(text => 'New group');
    $m->content_contains("Create", "got group page");

    if ( exists($args{'desc'}) ) {
        $m->fill_in_action_ok('newgroup',
                              name => $args{'name'},
                              description => $args{'desc'},
                             );
    } else {
        $m->fill_in_action_ok('newgroup',
                              name => $args{'name'},
                             );
    }
    $m->submit_html_ok;
    like($m->uri, qr{/groups/\d+/manage}, "on a group page");
    $m->content_contains("Invite somebody", "got group invite");
    $m->content_contains("Manage group members", 
                         "got group members management");
    ok($m->find_link(text => "Manage"), "Found manage link");
    $m->follow_link_ok(text => "Manage");
    like($m->uri, qr{/groups/\d+/manage}, "on a group page");
    $m->content_contains("Edit this group", "got group edit");
    $m->content_contains("Incoming addresses", "got group incoming addresses");
    ok($m->find_link(text => "Groups"), "Found groups link");
    $m->follow_link_ok(text => "Groups");
}

sub _make_group_api {
    my %args = @_; # name, desc

    my $group = BTDT::Model::Group->new();
    $group->create(name => $args{name}, description => $args{desc});
}
                    
# removes leading and trailing spaces
sub trim {
        my $string = shift;
        $string =~ s/^\s+//;
        $string =~ s/\s+$//;
        return $string;
}
