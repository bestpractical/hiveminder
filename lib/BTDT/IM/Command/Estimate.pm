package BTDT::IM::Command::Estimate;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'estimate' command, which sets the estimated time_left for a task.

=cut

sub run
{
    my $self = shift;
    my %args = @_;
    my $ret = '';
    my $input;

    return "Sorry! This feature is for pro users only. Upgrade at http://hiveminder.com/account/upgrade" unless $self->current_user->has_feature('TimeTracking');

       if ($input = __PACKAGE__->try_colonic_args(\%args)) { }
    elsif ($args{message} =~ s/\b(?<!#)(?:takes?|is)\s*(.*)//i) { $input = $1 }
    else
    {
        return "I don't understand. Use: <b>estimate</b> <i>tasks</i> <b>take</b> <i>duration</i>";
    }

    return "How long?" if $input eq '';

    my ($valid) = BTDT::Model::Task->validate_time_left($input);
    return "I don't understand the duration '$input'." if not $valid;

    my $msg = $self->_msg2tasks(%args);
    $ret .= "Cannot find ".$self->_locator_list(@{ $msg->{notfound} }).".\n"
        if @{ $msg->{notfound} };

    return $self->no_matches("Estimate for what?", $msg, pre => $ret, %args)
        if @{ $msg->{tasks} } == 0;

    my (@updated, @noaccess);
    for my $task (@{ $msg->{tasks} })
    {
        my $response = $self->update_task($task, time_left => $input);
        if ($response) { push @updated,  $task }
        else           { push @noaccess, $task }
    }

    $ret .= "You can't update ".$self->_locator_list(@noaccess).".\n" if @noaccess;
    $ret .= "Recorded estimate for ".$self->_locator_list(@updated).".\n"
        if @updated;

    $self->_set_shown_tasks($args{session}, @updated);

    return $ret;
}

1;

