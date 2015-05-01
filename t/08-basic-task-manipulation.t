use warnings;
use strict;

use BTDT::Test tests => 78;
use Test::LongString;

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech($URL);
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->html_ok;
$mech->content_like(qr/Logout/i, "logged in");

# We should be at the To Do list.
$mech->content_contains('To Do');

$mech->content_contains('Tasks');

$mech->content_contains('01 some task');
$mech->content_contains('02 other task');
$mech->content_contains('with a description');

# We shold be able to add a task and have it show up
$mech->fill_in_action_ok("tasklist-new_item_create",
                         summary => "03 some new task [tag]",
                         description => "Description of some new task");
$mech->submit_html_ok();
like($mech->uri, qr|/todo|, "Back at inbox");
$mech->content_contains('03 some new task');
$mech->content_contains('Set Tags to tag','Was notified that [tag] was parsed');

# Updating nothing shouldn't update anything!
ok($mech->find_link( text => "03 some new task" ), "Task edit link exists");
$mech->follow_link_ok( text => "03 some new task" );
$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 3));
$mech->submit_html_ok();
$mech->content_lacks("Updated");
$mech->back;
$mech->back;

# Creating bogus tasks
TODO: {
    local $TODO = "No group_id entry box, so Mech doesn't cut it";
    ok(0, "Creating a task with a bogus group_id should fail");
    ok(0, "Creating a task with an undef group_id should succeed");
}

# Test tag editing
ok($mech->find_link(text => "Edit"), "Link to edit exists");
$mech->follow_link_ok(text => "Edit");
$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 1),
                         tags => "foo bar baz");
$mech->submit_html_ok();
like($mech->uri, qr|/todo|, "Back at inbox");
ok($mech->form_number(2), "Second form selected");
ok(scalar(grep {$_->value eq "Save"} $mech->current_form->find_input(undef, "submit")), "It has a Save button");
ok($mech->click_button(value => "Save"), "We can click it");
$mech->html_ok;
$mech->content_like(qr|<span class="tag">\s*<a [^>]*href="[^"]+">foo</a>\s*</span>|, "Added tag is there");
$mech->content_like(qr|<span class="tag">\s*<a [^>]*href="[^"]+">bar</a>\s*</span>|, "Added tag is there");
$mech->content_like(qr|<span class="tag">\s*<a [^>]*href="[^"]+">baz</a>\s*</span>|, "Added tag is there");

# Removing task tags
ok($mech->find_link(text => "Edit"), "Link to edit exists");
$mech->follow_link_ok(text => "Edit");
$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 1),
                         tags => "troz");
$mech->submit_html_ok();
like($mech->uri, qr|/todo|, "Back at inbox");
ok($mech->form_number(2), "Second form selected");

ok(scalar(grep {$_->value eq "Save"} $mech->current_form->find_input(undef, "submit")), "It has a Save button");
ok($mech->click_button(value => "Save"), "We can click it");
$mech->html_ok;

$mech->content_unlike(qr|<span class="tag">\s*<a [^>]*href="[^"]+">foo</a>\s*</span>|, "Removed tag isn't there");
$mech->content_unlike(qr|<span class="tag">\s*<a [^>]*href="[^"]+">bar</a>\s*</span>|, "Removed tag isn't there");
$mech->content_unlike(qr|<span class="tag">\s*<a [^>]*href="[^"]+">baz</a>\s*</span>|, "Removed tag isn't there");
$mech->content_like(  qr|<span class="tag">\s*<a [^>]*href="[^"]+">troz</a>\s*</span>|, "Added tag is there");

# preventing multiple task ownership
$mech->get_ok($URL);
$mech->follow_link_ok(text => "01 some task");
$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 1),
			 owner_id => 'otheruser@example.com,thirduser@example.com'
    );

$mech->submit_html_ok();

TODO: {
    # see t/05-login.t for cases where field_error_text works with Mech.
    local $TODO = "field_error_text is behaving badly";
    contains_string($mech->field_error_text($mech->moniker_for("BTDT::Action::UpdateTask"),
			      'owner_id'),
		    "Only one owner",
		    "Trying to assign multiple owners returns an error.");
};

is($mech->action_field_value($mech->moniker_for("BTDT::Action::UpdateTask"),
   			      'owner_id'),
			      'gooduser@example.com',
			      "trying to assign multiple owners: validation results in owner not being changed"); 
$mech->get_ok($URL);

# Checking off tasks
$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 1),
                         complete => 1);
$mech->submit_html_ok();
# XXX TODO remove duplicate test after we're sure that URL refactoring works right
$mech->content_lacks('<a href="/tasks/1">', "Task 1 is checked off, and disappeared");
$mech->content_lacks('<a href="/task/3">', "Task 1 with record locator 3 is checked off, and disappeared");

ok($mech->find_link(url => '/search'));
$mech->follow_link_ok( url => '/search', "Deleted tasks aren't on the front page. get others");
$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::TaskSearch"), group => "personal", summary => "Some Task");
$mech->submit_html_ok();
$mech->form_number(2);
ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 1), "We found a form that lets us update task 1");
ok($mech->value("J:A:F-complete-".$mech->moniker_for("BTDT::Action::UpdateTask", id => 1)), "Task 1 is checked off");
ok(!$mech->find_link(text => "Edit"), "Completed task lacks an edit link");
# Un-checking tasks
$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 1),
                         complete => undef);
$mech->submit_html_ok();
$mech->form_number(2);
ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 1), "We found a form that lets us update task 1");
ok(not($mech->value("J:A:F-complete-".$mech->moniker_for("BTDT::Action::UpdateTask", id => 1))), "Task 1 is unchecked");

# Using the done button
$mech->follow_link_ok( text => '01 some task' );
$mech->title_like( qr/01 some task/ );
$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 1));
ok($mech->click_button( value => "Save and Complete" ), "click save and complete" );
like($mech->content, qr/Save and Mark incomplete/, "not done button found");

$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 1), summary => '01 some task now with more');
ok($mech->click_button( value => "Save and Mark incomplete" ), "click not done button");
like($mech->content, qr/Save and Complete/, "done button found");
$mech->title_like( qr/01 some task now with more/ );
