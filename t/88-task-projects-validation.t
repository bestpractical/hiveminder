use strict;
use warnings;
use BTDT::Test 'no_plan';

# setup
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

# create the project
$mech->get_ok("/groups/". $bps->id ."/dashboard");
$mech->fill_in_action(
    $mech->moniker_for('BTDT::Action::CreateTask'),
    summary => "Baby's First Project",
);
$mech->submit;
$mech->content_contains('Your project has been created!');

my $project = BTDT::Project->new(current_user => $gooduser);
$project->load_by_cols(summary => "Baby's First Project");
ok($project->id, "loaded the project we createD");

# set the project use set_project
$foo->set_project( $project->id );
isnt( $foo->project->id, $project->id, "Didn't set the project" );

$foo->set_project( 42 );
isnt( $foo->project->id, $project->id, "Didn't set the project" );

$foo->set_group_id( $bps->id );
is( $foo->group_id, $bps->id, "Set group" );
$foo->set_project( $project->id );
is( $foo->project->id, $project->id, "Set the project" );

$foo->set_project( undef );
isnt( $foo->project->id, $project->id, "No longer have the project" );
is( $foo->project->id, undef, "Set the project to undef" );

# test create
my $task = BTDT::Model::Task->new( current_user => $gooduser );
my ( $id, $msg ) = $task->create(
    summary  => 'baz',
    group_id => $bps->id,
    project  => $project->id,
);
is( $task->id, $id, "Created a task" );

my $task2 = BTDT::Model::Task->new( current_user => $gooduser );
( $id, $msg ) = $task2->create(
    summary  => 'boo',
    project  => $project->id,
);
is( $task2->id, $id, "Created the task" );
is( $task2->project->id, undef, "But has no project" );

# test update

Jifty->web->request( Jifty::Request->new );
Jifty->web->response( Jifty::Response->new );

my $update = Jifty->web->new_action(
    class     => 'UpdateTask',
    arguments => { project => 13 },
    record    => $task
);
$update->validate;
$update->run;
ok( $update->result->failure, "Action failed" );
isnt( $task->project->id, 13, "didn't update" );
is( $task->project->id, $project->id, "still the same" );

# Subs!
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

