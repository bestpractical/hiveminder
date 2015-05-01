package BTDT::IM::Command::Random;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'random' command, which gives the user a random task.

=cut

sub run
{
    my $im = shift;
    my %args = @_;

    my $tasks = BTDT::Model::TaskCollection->new();
    # stolen from html/todo/index.html
    $tasks->from_tokens(qw(owner me not complete starts before tomorrow
                           accepted but_first nothing));
    $im->apply_filters($tasks, %args);
    $tasks->smart_search($args{message}) if $args{message} ne '';

    return $im->no_matches("Nothing to do!", {search => $args{message} eq '' ? 0 : 1}, %args)
        if !$tasks->count;

    my $selected;
    my $seen = 0;

    while (my $task = $tasks->next)
    {
        # a task has "priority" chances, so highest priority tasks are
        # 5x more likely to show up than lowest
        for (1..$task->priority)
        {
            $selected = $task if rand(++$seen) < 1;
        }
    }

    $im->_set_shown_tasks($args{session}, $selected);

    return "Here's a random task:\n" . $im->task_summary($selected);
}

1;
