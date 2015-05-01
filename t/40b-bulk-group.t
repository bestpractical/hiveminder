use warnings;
use strict;
use List::Util qw(first);
use BTDT::Test tests => 16;

my $gooduser = BTDT::CurrentUser->new(email => 'gooduser@example.com');
my $otheruser = BTDT::CurrentUser->new(email => 'otheruser@example.com');

my $server = Jifty::Test->make_server;
my $URL = $server->started_ok;

# make sure that you can bulk-give-away tasks {{{
create_tasks("personal task", "group task");

my $mech = BTDT::Test->get_logged_in_mech($URL);
my $button = "Save Changes";

# first update the group of the tasks (except the personal task)
$mech->follow_link(text => 'Bulk Update');
$mech->content_contains($button, 'Got to the bulk edit page');
ok(remove_tasks($mech, 3), "Removed task 3");
$mech->fill_in_action_ok('bulk_edit', group => 1);
$mech->click_button(value => $button);
$mech->content_lacks('Exit Bulk Edit', 'Got back to the inbox');

my $personal = BTDT::Model::Task->new(current_user => $gooduser);
$personal->load_by_cols(summary => "personal task");
is($personal->group_id, undef, "no group for personal");
is($personal->owner_id, $gooduser->id, "personal task owned by gooduser");

my $group = BTDT::Model::Task->new(current_user => $gooduser);
$group->load_by_cols(summary => "group task");
is($group->group_id, 1, "group task got moved");
is($group->owner_id, $gooduser->id, "group task owned by gooduser");

# change owner to nobody
$mech->follow_link(text => 'Bulk Update');
$mech->content_contains($button, 'Got to the bulk edit page');
$mech->fill_in_action_ok('bulk_edit', owner_id => 'nobody');
$mech->click_button(value => $button);
$mech->content_lacks('Exit Bulk Edit', 'Got back to the inbox');

Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');

$personal = BTDT::Model::Task->new(current_user => $gooduser);
$personal->load_by_cols(summary => "personal task");
is($personal->group_id, undef, "no group for personal");
is($personal->owner_id, $gooduser->id, "personal task owned by gooduser");

$group = BTDT::Model::Task->new(current_user => $gooduser);
$group->load_by_cols(summary => "group task");
is($group->group_id, 1, "group task still in group");
is($group->owner_id, BTDT::CurrentUser->nobody->id, "group task owned by nobody");
# }}}

sub create_tasks {
    for my $summ (@_) {
        my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->new(id => $gooduser->id));
        $task->create(summary => $summ);
    }
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

