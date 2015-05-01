package BTDT::IM::Command::Start;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'start' command, which starts the time-tracking clock for a task

=cut

sub run {
    my $im = shift;
    my %args = @_;

    return "Sorry! This feature is for pro users only. Upgrade at http://hiveminder.com/account/upgrade" unless $im->current_user->has_feature('TimeTracking');

    my @tasks = split ' ', $args{message};
    @tasks = split ' ', $im->_get_shown_tasks($args{session})
        if !@tasks;

    my @already_timing = split ' ', ($args{session}->get('timed_tasks') || '');
    return "There's already a timer on "
         . $im->_locator_list(@already_timing) . "!"
            if @already_timing;

    return "Start the timer on which task?"
        if @tasks == 0;

    $args{session}->set(timed_tasks => join ' ', @tasks);
    $args{session}->set(timed_start => time);

    $im->_set_shown_tasks($args{session}, @tasks);
    return "Starting the timer on " . $im->_locator_list(@tasks) . ". (Tip: You can use 'stop' to end, or 'pause' to stop temporarily)";
}

1;

