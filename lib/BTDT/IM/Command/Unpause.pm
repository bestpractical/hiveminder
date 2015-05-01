package BTDT::IM::Command::Unpause;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'unpause' command, which unpauses the time-tracking clock for a task

=cut

sub run {
    my $im = shift;
    my %args = @_;

    return "Sorry! This feature is for pro users only. Upgrade at http://hiveminder.com/account/upgrade" unless $im->current_user->has_feature('TimeTracking');

    my @tasks = split ' ', ($args{session}->get('timed_tasks') || '');
    return "You're not working on any tasks."
        if @tasks == 0;

    return "The timer on " . $im->_locator_list(@tasks) . " is already running!"
        if $args{session}->get('timed_start');

    $args{session}->set(timed_start => time);

    $im->_set_shown_tasks($args{session}, @tasks);
    return "Unpausing the timer (at ". __PACKAGE__->timer_duration_readable(\%args) .") on " . $im->_locator_list(@tasks);
}

1;

