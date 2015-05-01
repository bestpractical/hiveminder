package BTDT::IM::Command::Then;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'then' command, which sets up a task dependency. It expects arguments
in the form (dependency, task). The dispatcher has a special rule "foo then
bar" -- translated to "then foo bar".

=cut

sub run
{
    my $im = shift;
    my %args = @_;
    my $ret = '';

    my @tasks = split ' ', $args{message};
    if (@tasks != 2)
    {
        return "I don't understand. Use: <b>task</b> then <b>task</b>.";
    }

    for (@tasks)
    {
        s/^#+//;
        my $task = BTDT::Model::Task->new();
        $task->load_by_locator($_);

        if (!$task->id) { return "Cannot find " . $im->_locator_list($_)."." }

        $_ = $task;
    }

    my ($independent, $dependent) = @tasks;

    my $dep = BTDT::Model::TaskDependency->new();
    my ($ok, $msg) = $dep->create(
        task_id    => $dependent->id,
        depends_on => $independent->id,
    );
    return $msg if !$ok;

    $im->_set_shown_tasks($args{session}, @tasks);
    for ($dependent, $independent) { $_ = $im->_locator_list($_) }
    return "\u$dependent now depends on $independent.";
}

1;

