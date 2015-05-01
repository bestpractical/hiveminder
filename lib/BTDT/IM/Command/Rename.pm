package BTDT::IM::Command::Rename;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'rename' command, which lets you change the summary of a task.

=cut

sub run
{
    my $im = shift;
    my %args = @_;
    my $ret = '';
    my $summary = '';

       if ($summary = __PACKAGE__->try_colonic_args(\%args)) { }
    elsif ($args{message} =~ s/\b(?<!#)to\s*(.*)//i)         { $summary = $1 }
    else {
        return "I don't understand. Use: <b>rename</b> <i>task</i> <b>to</b> <i>summary</i>";
    }

    my $msg = $im->_msg2tasks(%args);
    my @tasks = @{ $msg->{tasks} };
    $ret .= "Cannot find ".$im->_locator_list(@{ $msg->{notfound} }).".\n"
        if @{ $msg->{notfound} };

    return $im->no_matches("Rename what?", $msg, pre => $ret, %args)
        if @tasks == 0;

    if (@tasks > 1)
    {
        return $ret . "You can only rename one task at a time. Use: <b>rename</b> <i>task</i> <b>to</b> <i>summary</i>";
    }

    if ($summary eq '')
    {
        return $ret . "Set the summary to what?";
    }

    my (@updated, @noaccess);
    for my $task (@tasks)
    {
        my $response = $im->update_task($task, summary => $summary);
        if ($response) { push @updated,  $task }
        else           { push @noaccess, $task }
    }

    $ret .= "Cannot set the summary of "
            .  $im->_locator_list(@noaccess)
            .  ".\n"
                if @noaccess;
    return $ret if !@updated;

    $im->_set_shown_tasks($args{session}, @tasks);

    for (@updated)
    {
        $ret .= ucfirst($im->_locator_list($_)) . " is now: " . $_->summary . "\n";
    }

    return $ret;
}

1;

