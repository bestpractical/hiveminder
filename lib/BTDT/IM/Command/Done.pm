package BTDT::IM::Command::Done;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'done' command, which marks tasks as done.

=cut

sub run
{
    my $im = shift;
    my %args = @_;
    my $ret = '';

    my $msg = $im->_msg2tasks(%args);
    $ret .= "Cannot find ".$im->_locator_list(@{ $msg->{notfound} }).".\n"
        if @{ $msg->{notfound} };

    return $im->no_matches("Mark what as done?", $msg, pre => $ret, %args)
        if @{ $msg->{tasks} } == 0;

    if ($msg->{search} && @{ $msg->{tasks} } > 1 && !$im->terse)
    {
        my $command = 'done';
        my $output = "Multiple tasks match your search. Send me <b>y</b> on a line by itself to confirm completion of these tasks. Anything else will be treated as a fresh command.\n";
        for (@{ $msg->{tasks} })
        {
            $output .= "\n" . $im->short_task_summary($_);
            $command .= ' ' . $_->record_locator;
        }
        $args{session}->set(confirm => $command);
        return $output;
    }

    my (@complete, @updated, @noaccess);
    for my $task (@{ $msg->{tasks} })
    {
        if (!defined($task->complete)) { push @noaccess, $task; next }
        if ($task->complete)           { push @complete, $task; next }

        my $response = $im->update_task($task, complete => 1);
        if ($response) { push @updated,  $task }
        else           { push @noaccess, $task }
    }

    $ret .= "Cannot mark "
            .  $im->_locator_list(@noaccess)
            .  " as done.\n"
                if @noaccess;

    if (@complete)
    {
        my $is = @complete == 1 ? 'is' : 'are';
        $ret .= ucfirst($im->_locator_list(@complete))
             .  " $is already done.\n";
    }

    return { response => $ret, review_next => $msg->{contextual} } if !@updated;

    $ret .= "Marking ".$im->_locator_list(@updated) ." as done."
         .  ($im->terse
            ? ''
            : " (Tip: You can use 'undone' if this was a mistake)")
         .  "\n";
    $im->_set_shown_tasks($args{session}, @updated);

    return { response => $ret, review_next => $msg->{contextual} };
}

1;
