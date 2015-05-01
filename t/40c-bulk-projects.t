use strict;
use warnings;
use BTDT::Test tests => 32;

# setup {{{
my $gooduser = BTDT::CurrentUser->new(email => 'gooduser@example.com');
$gooduser->user_object->__set(column => 'access_level', value => 'staff');
BTDT::Test->make_pro('gooduser@example.com');

my ($foo, $bar) = create_tasks(
    "foo",
    "bar",
);

my $bps = BTDT::Model::Group->new(current_user => $gooduser);
$bps->create(
    name        => 'Best Practical',
    description => 'the project/milestone group'
);

my $alpha_group = BTDT::Model::Group->new(current_user => $gooduser);
$alpha_group->load_by_cols(name => 'alpha');

my $server = Jifty::Test->make_server;
my $URL = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech($URL);
# }}}
# create the project {{{
$mech->get_ok("/groups/". $bps->id ."/my_tasks");
$mech->follow_link_ok({ text => "Dashboard" });
$mech->fill_in_action(
    $mech->moniker_for('BTDT::Action::CreateTask', type => 'project'),
    summary => "Baby's First Project",
);
$mech->submit;
$mech->content_contains('Your project has been created!');

my $project = BTDT::Project->new(current_user => $gooduser);
$project->load_by_cols(summary => "Baby's First Project");
ok($project->id, "loaded the project we created");
# }}}
# can't bulk update project/milestone on groupless tasks{{{
$mech->get_ok('/todo');
$mech->follow_link_ok({ text => "Bulk Update" });
$mech->action_form('bulk_edit');
my ($field) = grep { $_->name =~ /project/ } $mech->current_form->inputs;
ok(!$field, "no project field");
# }}}
# bulk update of a tasklist with one group task {{{
$foo->set_group_id($bps->id);
$mech->get_ok("/groups/". $bps->id ."/my_tasks");

$mech->follow_link_ok({ text => "Bulk Update" });
$mech->action_form('bulk_edit');
($field) = grep { $_->name =~ /project/ } $mech->current_form->inputs;
ok($field, "we have a project field");
is_deeply([$field->possible_values], [0, -1, $project->id], "possible values for project field are 'no change', 'none', and the BPS project");

$mech->fill_in_action(
    'bulk_edit',
    project => $project->id,
);
$mech->submit;

reload_tasks($foo, $bar);

is($foo->project->id, $project->id, "project correctly updated for the group task");
ok(!$bar->group_id, "no group for the personal task");
ok(!$bar->project->id, "no project for the personal task");
# }}}
# group task and personal tasks, bulk update group and project {{{
$mech->get_ok("/list/group/0/group/" . $bps->id);

$mech->follow_link_ok({ text => "Bulk Update" });
$mech->action_form('bulk_edit');
($field) = grep { $_->name =~ /project/ } $mech->current_form->inputs;
ok($field, "we have a project field");
is_deeply([$field->possible_values], [0, -1, $project->id], "possible values for project field are 'no change', 'none', and the BPS project");

$mech->fill_in_action(
    'bulk_edit',
    project => $project->id,
    group   => $bps->id,
);
$mech->submit;

reload_tasks($foo, $bar);

is($foo->project->id, $project->id);
is($bar->project->id, $project->id);

is($foo->group_id, $bps->id);
is($bar->group_id, $bps->id);
# }}}
# change group, set milestone {{{
$mech->get_ok("/list/group/0/group/" . $bps->id);

$mech->follow_link_ok({ text => "Bulk Update" });
$mech->action_form('bulk_edit');
($field) = grep { $_->name =~ /project/ } $mech->current_form->inputs;
ok($field, "we have a project field");
is_deeply([$field->possible_values], [0, -1, $project->id], "possible values for project field are 'no change', 'none', and the BPS project");

$mech->fill_in_action(
    'bulk_edit',
    project => $project->id,
    group   => $alpha_group->id,
);
$mech->submit;

reload_tasks($foo, $bar);

is($foo->project->id, $project->id, "project not updated");
is($bar->project->id, $project->id, "project not updated");

is($foo->group_id, $bps->id, "group not updated because of project validation error");
is($bar->group_id, $bps->id, "group not updated because of project validation error");
# }}}

sub create_tasks {
    my @tasks;
    for my $summ (@_) {
        my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->new(id => $gooduser->id));
        $task->create(summary => $summ);
        push @tasks, $task;
    }
    return @tasks;
}

sub reload_tasks {
    for (@_) {
        my $id = $_->id;
        my $cu = $_->current_user;
        Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
        $_ = BTDT::Model::Task->new(current_user => $cu);
        $_->load($id);
    }
}

