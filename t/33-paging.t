use warnings;
use strict;

use constant PER_PAGE => 20;

use BTDT::Test tests => 26 + PER_PAGE*4;
use BTDT::Model::Task;

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech($URL);
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->html_ok;
$mech->content_like(qr/Logout/i, "logged in");

# Paging
add_task(sprintf("%02d yet another task",$_)) for (3..(PER_PAGE - 1));
$mech->reload;
$mech->content_contains(sprintf("%02d yet another task",$_), "Found task $_ on page 1") for (3..(PER_PAGE-1));

$mech->content_lacks(PER_PAGE." yet another task", "Don't have a task ".PER_PAGE." yet");
$mech->content_lacks("desc this time", "Don't have task ".PER_PAGE."'s description yet");
add_task(PER_PAGE." yet another task", "desc this time");
$mech->reload;
$mech->content_contains(PER_PAGE." yet another task", PER_PAGE."th task is on page 1");
$mech->content_contains("desc this time", PER_PAGE."th task's desc is on page 1");
ok(! $mech->find_link(text => "Next"), "No pagination with ".PER_PAGE." tasks");

$mech->content_lacks((PER_PAGE+1)." this one will show up on the next page", "No task ".(PER_PAGE+1)." yet");
add_task((PER_PAGE+1)." this one will show up on the next page");
$mech->reload;
$mech->content_lacks((PER_PAGE+1)." this one will show up on the next page", "Still no ".(PER_PAGE+1)." after create");
ok(!$mech->find_link(text => "Back"), "Pagination - we don't have a prev page link");
ok($mech->find_link(text => "Next"), "Pagination we DO have a next page link");

$mech->follow_link_ok(text => "Next", "We went to the next page");
ok($mech->find_link(text => "Back"), "Pagination - on page 2, we do have a prev page now" );
ok(!$mech->find_link(text => "Next"), "Pagination on page two, we don't have a 'next' page link");
$mech->content_lacks(PER_PAGE." yet another task", "On page 2, no task ".PER_PAGE);
$mech->content_contains((PER_PAGE+1)." this one will show up on the next page", "on page 2, we do have task ".(PER_PAGE+1));
# We had a bug where creating a task and then hitting Next would create another
# task, since the action declarations were embedded in the Next links.
# (fixed once we moved view helper into Jifty::Request)
# With task tooltips, summaries do repeat twice, so check that it's not
# repeated a third time
$mech->content_unlike(qr!this one will show up on the next page.*this one will show up on the next page.*this one will show up on the next page!s);

# POST and GET parameters shouldn't interfere
add_task("$_ yet another task") for ((PER_PAGE+2)..(PER_PAGE*2));
$mech->reload;
$mech->content_contains("$_ yet another task", "Have task $_ on page 2") for ((PER_PAGE+2)..(PER_PAGE*2));

add_task((PER_PAGE*2+1)." Third page");
$mech->reload;
$mech->content_lacks((PER_PAGE*2+1)." Third page");
ok($mech->find_link(url => '/todo'));
$mech->follow_link_ok( url => '/todo', "Refresh to first page");
ok($mech->find_link(text => "Next"), "Pagination");
$mech->follow_link_ok(text => "Next");
$mech->content_lacks((PER_PAGE*2+1)." Third page");

# Updating from the second page keeps you there
$mech->content_contains((PER_PAGE+2)." yet another task");
$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => (PER_PAGE+2)),
                         complete => undef);
ok($mech->click_button(value => 'Create'));
$mech->content_lacks((PER_PAGE*2+1)." Third page");
$mech->content_contains((PER_PAGE+2)." yet another task");

sub add_task {
    # Create the task using the direct API instead of through the
    # server, for speed; you may need to call $mech->reload after.
    my $summ = shift;
    my $desc = shift;
    
    my $task = BTDT::Model::Task->new( current_user => $mech->current_user );
    my ($ok, $msg) = $task->create(
	summary => $summ,
	defined $desc ? (description => $desc) : ()
    );

    ok($ok, "Created task $summ");
} 

