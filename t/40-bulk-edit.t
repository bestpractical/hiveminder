use warnings;
use strict;
use List::Util qw(first);

=head1 DESCRIPTION

Test bulk updates

=cut

use BTDT::Test tests => 89;

my $admin     = BTDT::CurrentUser->superuser;
my $gooduser  = BTDT::CurrentUser->new( email => 'gooduser@example.com'  );
my $otheruser_cu = BTDT::CurrentUser->new( email => 'otheruser@example.com'  );
my $otheruser = BTDT::Model::User->new(current_user => $admin);
$otheruser->load_by_cols(email => 'otheruser@example.com');

ok $gooduser;
Jifty->web->current_user($gooduser);

my @id_for;

for (3..25)
{
    $id_for[$_] = create_task("Task " . (sprintf "%02d", $_))->id;
}

my $server = Jifty::Test->make_server;
my $URL = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech($URL);
my $button = "Save Changes";

$mech->follow_link(text => 'Bulk Update');

$mech->content_contains($button, 'Got to the bulk edit page');

ok(remove_tasks($mech, qw(3 4 10)), "Removed tasks 3,4,10");

$mech->fill_in_action_ok('bulk_edit', add_tags => 'tag1 tag2');
$mech->click_button(value => $button);
$mech->content_lacks('Exit Bulk Edit', 'Got back to the inbox');

# Work around a persistent deleted tasks without javascript bug.
$mech->follow_link(text => 'To Do');
$mech->follow_link(text => 'Bulk Update');

ok(remove_tasks($mech, qw(4 7)), "Removed tasks 4,7");
$mech->fill_in_action_ok('bulk_edit', add_tags => 'tag3', remove_tags => 'tag1');
$mech->click_button(value => $button);

# Clear out our old record cache, because it disagrees with the server's
Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
task_tags_ok(1, [qw(tag2 tag3)], [qw(tag1)]);
task_tags_ok(3, [qw(tag3)], [qw(tag1 tag2)]);
task_tags_ok(4, [qw()], [qw(tag1 tag2 tag3)]);
task_tags_ok(7, [qw(tag1 tag2)], [qw(tag3)]);
task_tags_ok(10, [qw(tag3)], [qw(tag1 tag2)]);
# task_tags_ok(12, [qw(tag2 tag3)], [qw(tag1)]);

bulkedit([5, 8], complete => 1);

my $tasks = BTDT::Model::TaskCollection->new(current_user => BTDT::CurrentUser->new(id => $gooduser->id));
$tasks->unlimit; # yes, we really want all rows
my @tasks = grep { $_->complete } @{$tasks->items_array_ref};
ok((grep {$_->summary =~ qr/Task 05/} @tasks), 'Task 5 is here');
ok((grep {$_->summary =~ qr/Task 08/} @tasks), 'Task 8 is here');

bulkedit([20, 21, 22, 23], owner_id => $otheruser->email);

is(scalar BTDT::Test->messages, 4, "Sent 4 emails");

$tasks = BTDT::Model::TaskCollection->new(current_user => BTDT::CurrentUser->new(id => $gooduser->id));
$tasks->unlimit; # yes, we really want all rows
for (20, 21, 22, 23)
{
    ok(0 == (grep {$_->summary =~ qr/Task $_/} @{$tasks->items_array_ref}),
       "Task $_ is here");
}

bulkedit([18, 19, 24, 25], starts => "next week"); 

$tasks = BTDT::Model::TaskCollection->new(current_user => BTDT::CurrentUser->new(id => $gooduser->id));
$tasks->unlimit; # yes, we really want all rows
my $now = time;
@tasks = grep { $_->starts && $_->starts->epoch > $now } @{$tasks->items_array_ref};
ok((grep {$_->summary eq 'Task 18'} @tasks), 'Changed task 18 start date');
ok((grep {$_->summary eq 'Task 19'} @tasks), 'Changed task 19 start date');
ok((grep {$_->summary eq 'Task 24'} @tasks), 'Changed task 24 start date');
ok((grep {$_->summary eq 'Task 25'} @tasks), 'Changed task 25 start date');

$tasks = BTDT::Model::TaskCollection->new(current_user => BTDT::CurrentUser->new(id => $otheruser->id));
$tasks->unlimit; # yes, we really want all rows
@tasks = grep { $_->owner_id == $otheruser->id && $_->requestor_id == $gooduser->id && !$_->accepted} @{$tasks->items_array_ref};

for my $num (20, 21, 22, 23)
{
    ok((grep {$_->summary eq "Task $num"} @tasks), 'Task was successfully requested');
}

my $otheruser_email = 'otheruser@example.com';
$otheruser = BTDT::CurrentUser->new( email => 'otheruser@example.com'  );
Jifty->web->current_user($otheruser);
bulkedit([20, 21, 22, 23], accepted => 1);

$tasks = BTDT::Model::TaskCollection->new(current_user => BTDT::CurrentUser->new(id => $otheruser->id));
$tasks->unlimit; # yes, we really want all rows
@tasks = grep { $_->owner_id == $otheruser->id && $_->accepted} @{$tasks->items_array_ref};
for my $num (20, 21, 22, 23)
{
    ok((grep {$_->summary eq "Task $num"} @tasks), 'Task was successfully accepted');
}

$mech = BTDT::Test->get_logged_in_mech($URL, $otheruser_email, 'something');
ok($mech, "Logged in again");

$mech->follow_link(text => 'Bulk Update');
$mech->follow_link(text => 'all');
$mech->content_contains('Delete Tasks', 'Found the delete tasks button');
$mech->fill_in_action_ok("bulk_edit");
$mech->click_button(value => 'Delete Tasks');
$mech->content_contains('must have something you need to get done', 'Deleted all tasks');

# no tasks, create some
$mech->fill_in_action_ok('quickcreate', text => <<'END');
get the book [due yesterday]
get the candelabrum [due today]
get the bell [due tomorrow]
get the amulet
ascend [win]
END
$mech->submit;

my $get_task = sub {
    my $summary = shift;
    my $task = BTDT::Model::Task->new(current_user => $otheruser_cu);
    $task->load_by_cols(summary => $summary);
    ok($task->id, "Loaded task '$summary'");
    return $task;
};

my $book        = $get_task->("get the book");
my $bell        = $get_task->("get the bell");
my $candelabrum = $get_task->("get the candelabrum");
my $amulet      = $get_task->("get the amulet");
my $ascend      = $get_task->("ascend");

edit_dependencies($ascend, add_dependency_on => $amulet);
is(eval { $ascend->depends_on->first->summary }, 'get the amulet', 'correctly set up a dependency');
warn $@ if $@;

edit_dependencies($ascend, remove_dependency_on => $amulet);
is($ascend->depends_on->count, 0, 'correctly removed a dependency');

edit_dependencies([$book, $bell, $candelabrum], add_depended_on_by => $amulet);
is($amulet->depends_on->count, 3, 'correctly added the three items as prerequisites');

edit_dependencies([$book, $bell, $candelabrum], remove_depended_on_by => $amulet);
is($amulet->depends_on->count, 0, 'correctly removed the three items as prerequisites');

edit_dependencies($amulet, add_dependency_on => [$book, $bell, $candelabrum]);
is($amulet->depends_on->count, 3, 'correctly added three tasks');

edit_dependencies($amulet, remove_dependency_on => [$book, $bell, $candelabrum]);
is($amulet->depends_on->count, 0, 'correctly removed again the three tasks');

sub task_tags_ok {
    my $id = shift;
    my $has = shift;
    my $lacks = shift || [];

    my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->new(id => $gooduser->id));
    $task->load($id);
    ok($task->id, "got task $id");
    like($task->tags, qr/\Q$_\E/, "task $id has tag $_") for @$has;
    unlike($task->tags, qr/\Q$_\E/, "task $id lacks tag $_") for @$lacks;
}

sub create_task {
    my $summ = shift;
    my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->new(id => $gooduser->id));
    $task->create(summary => $summ);
    return $task;
}

sub remove_tasks {
    my $mech = shift;
    my @tasks = @_;
    my $moniker;
    for my $id (@tasks) {
        my @links = $mech->find_all_links(text => '[not this]');
        my $link = first {$_->url =~ /item-$id/} @links;
        return unless $link;
        $mech->get($link->url);
    }
    return 1;
}

sub bulkedit {
    my $ids = shift;

    Jifty->web->response(Jifty::Response->new);
    Jifty->web->request(Jifty::Request->new);

    @$ids = map { $id_for[ sprintf '%02d', $_ ] } @$ids;

    my $bulkedit = BTDT::Action::BulkUpdateTasks->new(
        arguments => {ids => $ids, @_},
    );

    ok $bulkedit->validate, "bulk edit input validated";
    $bulkedit->run;
    my $result = $bulkedit->result;
    ok $result->success, "bulk edit ran successfully";
}

sub edit_dependencies {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $tasks = shift;
    my $type = shift;
    my $others = shift;

    $tasks = [$tasks] if ref($tasks) ne 'ARRAY';
    $others = [$others] if ref($others) ne 'ARRAY';

    my $url = "/list" . join('', map { "/id/" . $_->record_locator } @$tasks);
    my $input = join ' ', map { "#" . $_->record_locator } @$others;

    $mech->get_ok($url);
    $mech->follow_link_ok(text => 'Bulk Update');
    $mech->fill_in_action_ok('bulk_edit', $type => $input);
    $mech->submit;
    Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
}

1;
