
use warnings;
use strict;

=head1 DESCRIPTION

This is a template for your own tests. Copy it and modify it.

=cut

use BTDT::Test tests => 112;

# Create a graph of tasks.

use_ok('BTDT::Model::Task');
use_ok('BTDT::Model::TaskCollection');

my $a  = BTDT::Model::Task->new(current_user =>BTDT::CurrentUser->superuser);
$a->create(summary => 'A');
ok($a->id, "Created the first task ". $a->id);


my $b  = BTDT::Model::Task->new(current_user =>BTDT::CurrentUser->superuser);
$b->create(summary => 'B');
ok($b->id, "Created the first task ". $b->id);

my $c  = BTDT::Model::Task->new(current_user =>BTDT::CurrentUser->superuser);
$c->create(summary => 'C');
ok($c->id, "Created the first task ". $c->id);

$b->add_dependency_on($a->id);
$c->add_dependency_on($a->id);
#diag('Created three related tasks');

# Very basic smoke tests


is($a->depended_on_by->count(), 2, "we have on dependency");
is($b->depends_on->count(),1,"we are depended on by one task");

#diag('All tasks are undone');
test_all_tasks_undone();



# Mark task B as done

$b->set_complete(1);

is($b->complete(),1);

#diag ('Task b is done');
test_subtask_done();

# Mark task B as not done
$b->set_complete(0);

is($b->complete(),0);

#diag('Task b is once again undone');
test_all_tasks_undone();

# Mark task A as done

$a->set_complete(1);
is ($a->complete,1);

#diag('Task A is done');

test_supertask_done();

# Mark task A as not done
$a->set_complete(0);
is ($a->complete,0);
#diag('Task A is not done');
test_all_tasks_undone();


# Mark all tasks done

for ($a, $b, $c) {
        $_->set_complete(1);
        ok($_->complete, $_->summary ." Is ok");
}
#diag ('All three tasks are done');
test_all_tasks_done();

# Mark all tasks not done
for($a, $b, $c) {
        $_->set_complete(0);
        ok(!$_->complete, $_->summary ." Is ok");
}

#diag('All three tasks are not done');

test_all_tasks_undone();

$a->set_summary('Not A!');

# Reload the tasks to clear the in-memory cached (wrong) versions.
$b->load($b->id);
$c->load($c->id);

like($b->depends_on_summaries, qr/Not A\!/);
like($c->depends_on_summaries, qr/Not A\!/);

$c->set_summary('Still C');
$a->load($a->id);
like($a->depended_on_by_summaries, qr/Still C/);


# Test deleting tasks

$c->delete();
$a->load($a->id);
unlike($a->depended_on_by_summaries, qr/Still C/);

$a->delete();
$b->load($b->id);

unlike($b->depends_on_summaries, qr/Not A\!/);

sub test_all_tasks_undone {

    # Verify that A has two deps
    check_depended_on_by( $a => 2);
    is( $a->depended_on_by_summaries, "B\tC");
    # Verify that B depends on one task 
    check_depends_on($b => 1);


    # Verify that C depends on one task 
    check_depends_on($c => 1);

}

sub test_subtask_done {

    # Verify that A has one incomplete dependency, C
    check_depended_on_by( $a => 1);
    is( $a->depended_on_by_summaries, "C");


    # Verify that B depends on one task, A
    check_depends_on($b => 1);

    # Verify that C depends on one task, A
    check_depends_on($c => 1);
}

sub test_supertask_done {

    # Verify that A has two incomplete dependencies, B & C
    check_depended_on_by( $a => 2);
    is( $a->depended_on_by_summaries, "B\tC");

    # Verify that C depends on zero tasks
    check_depends_on($c => 0);
    # Verify that B depends on zero tasks
    check_depends_on($b => 0);

}


sub test_all_tasks_done {
    # Verify that A has no incomplete dependencies
    check_depended_on_by( $a => 0);
    # Verify that C depends on zero tasks
    check_depends_on($c => 0);
    # Verify that B depends on zero tasks
    check_depends_on($b => 0);

}


sub check_depends_on {
    my $task  = shift;
    my $expected = shift;

    $task->load($task->id); # We hates the caching, we do.
    my $real             = $task->incomplete_depends_on;
    my $count     = $task->depends_on_count;
    my $ids       = $task->depends_on_ids;
    my $summaries = $task->depends_on_summaries;

    is( $real->count, $expected,        "We have the right count of tasks" ) || Carp::confess;
    is( $real->count, $count, "Cached count agrees" );
    is( join( "\t", map { $_->id } @{ $real->items_array_ref } ),
        $ids, "Cached ids agree" );
    is( join( "\t", map { $_->summary } @{ $real->items_array_ref } ),
        $summaries, "Cached summaries sagree" );

}

sub check_depended_on_by {
    my $task  = shift;
    my $expected = shift;

    $task->load($task->id); # We hates the caching, we do.

    my $real             = $task->incomplete_depended_on_by;
    my $count     = $task->depended_on_by_count;
    my $ids       = $task->depended_on_by_ids;
    my $summaries = $task->depended_on_by_summaries;

    is( $real->count, $expected,        "We have the right count of tasks" ) || Carp::confess;
    is( $real->count, $count, "Cached count agrees" ) || Carp::confess;
    is( join( "\t", map { $_->id } @{ $real->items_array_ref } ),
        $ids, "Cached ids agree" );
    is( join( "\t", map { $_->summary } @{ $real->items_array_ref } ),
        $summaries, "Cached summaries sagree" );
}
