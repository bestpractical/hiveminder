package BTDT::IM::Command::HideForever;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the "hide forever" command, which marks tasks as hidden forever.

=cut

sub run
{
    my $im = shift;
    my %args = @_;
    my $ret = '';

    my $msg = $im->_msg2tasks(%args, show_hidden_forever => 1);
    $ret .= "Cannot find ".$im->_locator_list(@{ $msg->{notfound} }).".\n"
        if @{ $msg->{notfound} };

    return $im->no_matches("Mark what as hidden forever?", $msg, pre => $ret, %args)
        if @{ $msg->{tasks} } == 0;

    if ($msg->{search} && @{ $msg->{tasks} } > 1 && !$im->terse)
    {
        my $command = 'hideforever';
        my $output = "Multiple tasks match your search. Send me <b>y</b> on a line by itself to confirm you want to hide these tasks forever. Anything else will be treated as a fresh command.\n";
        for (@{ $msg->{tasks} })
        {
            $output .= "\n" . $im->short_task_summary($_);
            $command .= ' ' . $_->record_locator;
        }
        $args{session}->set(confirm => $command);
        return $output;
    }

    my (@existing, @updated, @noaccess);
    for my $task (@{ $msg->{tasks} })
    {
        if (!defined($task->will_complete)) { push @noaccess, $task; next }
        if (!$task->will_complete)          { push @existing, $task; next }

        my $response = $im->update_task($task, will_complete => 0);
        if ($response) { push @updated,  $task }
        else           { push @noaccess, $task }
    }

    $ret .= "Cannot hide "
            .  $im->_locator_list(@noaccess)
            .  " forever.\n"
                if @noaccess;

    if (@existing)
    {
        my $is = @existing == 1 ? 'is' : 'are';
        $ret .= ucfirst($im->_locator_list(@existing))
             .  " $is already hidden forever.\n";
    }

    return { response => $ret, review_next => $msg->{contextual} } if !@updated;

    $ret .= "Hiding ".$im->_locator_list(@updated) ." forever.\n";
    $im->_set_shown_tasks($args{session}, @updated);

    return { response => $ret, review_next => $msg->{contextual} };
}

1;
