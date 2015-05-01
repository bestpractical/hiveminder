package BTDT::IM::Command::Pause;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'pause' command, which pauses the time-tracking clock for a task

=cut

sub run {
    my $im = shift;
    my %args = @_;

    return "Sorry! This feature is for pro users only. Upgrade at http://hiveminder.com/account/upgrade" unless $im->current_user->has_feature('TimeTracking');

    my @tasks = split ' ', ($args{session}->get('timed_tasks') || '');
    return "You're not working on any tasks."
        if @tasks == 0;

    my $start = $args{session}->get('timed_start');
    return "The timer on " . $im->_locator_list(@tasks) . " is already paused!"
        if !$start;

    my $total = $args{session}->get('timed_total') || 0;
    if ($start) {
        $total += time - $start;
    }

    $args{session}->set(timed_total => $total);
    $args{session}->remove('timed_start');

    $im->_set_shown_tasks($args{session}, @tasks);
    return "Pausing the timer (at ". __PACKAGE__->timer_duration_readable(\%args) .") on " . $im->_locator_list(@tasks) . ". (Tip: You can use 'unpause' when you resume work)";
}

1;

