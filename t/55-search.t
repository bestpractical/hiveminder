use warnings;
use strict;

use BTDT::Test tests => 35;

=head1 DESCRIPTION

Test searching and sorting of tasks.

=cut

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;

my $good_user = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
$good_user->load_by_cols(email => 'gooduser@example.com');

my $mech = BTDT::Test->get_logged_in_mech($URL);
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->content_like(qr/Logout/i, "logged in");
ok($mech->find_link(url => '/search'));
$mech->follow_link_ok( url => '/search', "Found the search page");

# test 'completed before/after' queries {{{
create_task("Breakfast for 2005-08-$_", 3, "2005-08-$_ 13:00:00" ) for 15 .. 24;

$mech->fill_in_action_ok("search", owner => $good_user->email,
             completed_before => "2005-08-20", complete => 1, complete_not => '');
$mech->submit_html_ok();

isnt(count_tasks($mech->content), 0, "There are tasks on a search result page completed before 2005-08-20");

for (15..19) {
    my $tasktitle = "Breakfast for 2005-08-$_";
    $mech->content_contains($tasktitle, "Task $tasktitle shows in search");
}

for (20..24) {
    my $tasktitle = "Breakfast for 2005-08-$_";
    $mech->content_lacks($tasktitle, "Task $tasktitle does not show up in search");
}
# }}}

# Add some tasks with priorities

create_task("Task " . (sprintf "%02d", $_), $_%5+1 ) for (3 .. 25);

# Find the search page
$mech->follow_link_ok( url => '/search', "Found the search page");
$mech->fill_in_action_ok("search", owner => $good_user->email, 
			 priority_above => 4, priority_below => 5);
$mech->submit_html_ok();

isnt(count_tasks($mech->content), 0, "There are tasks on a search result page, priority between 4 and 5");

for (3..13) {  # 10 tasks per page
    my $tasktitle = "Task " . (sprintf "%02d", $_);
    if ($_%5+1 >= 4) {
	$mech->content_contains($tasktitle, "Task $tasktitle with priority $_ shows in search");
    } else {
	$mech->content_lacks($tasktitle, "Task $tasktitle with priority $_ does not show in search");
    }
}
$mech->follow_link_ok( url => '/search', "Found the search page");

sub create_task {
    my $summ = shift;
    my $priority = shift;
    my $completed = shift;
    
    my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->new(id => $good_user->id));
    $task->create(summary => $summ, priority => $priority);
    $task->set_complete(1, $completed) if defined $completed; # create won't let you set task->completed_at

    return $task;
}

sub count_tasks {
    my $text = shift;
    my @matches = $text =~ m/<span class="task_summary">/g;
    return scalar @matches;
}

