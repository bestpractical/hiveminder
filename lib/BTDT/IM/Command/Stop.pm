package BTDT::IM::Command::Stop;
use strict;
use warnings;
use base 'BTDT::IM::Command';
use Time::Duration 'duration';

=head2 run

Runs the 'stop' command, which ends the time-tracking clock for a task

=cut

sub run {
    my $im = shift;
    my %args = @_;

    return "Sorry! This feature is for pro users only. Upgrade at http://hiveminder.com/account/upgrade" unless $im->current_user->has_feature('TimeTracking');

    my @tasks = split ' ', ($args{session}->get('timed_tasks') || '');
    return "You're not working on any tasks."
        if @tasks == 0;

    my $total_time = __PACKAGE__->timer_duration_seconds(\%args);

    $args{session}->remove($_) for qw/timed_tasks timed_start/;

    my (@updated, @noaccess);
    for my $locator (@tasks) {
        my $task = BTDT::Model::Task->new(current_user => $im->current_user);
        $task->load_by_locator($locator);
        my $response = $im->update_task($task,
            add_time_worked => $total_time,

            # UpdateTask expects time_left so it can check whether they're the
            # same. if so, it'll subtract time worked from time left
            time_left       => $task->time_left,
        );
        if ($response) { push @updated,  $locator }
        else           { push @noaccess, $locator }
    }

    my $ret = '';
    $ret .= "You can't update ".$im->_locator_list(@noaccess).".\n" if @noaccess;
    $ret .= "You worked on " . $im->_locator_list(@updated) . " for " . duration($total_time) . ".\n" if @updated;

    $im->_set_shown_tasks($args{session}, @tasks);

    return $ret;
}

1;

