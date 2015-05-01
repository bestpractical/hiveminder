package BTDT::IM::Command::Show;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'show' command, which shows tasks in the user's current context.

=cut

sub run
{
    my $im = shift;
    my %args = @_;
    my $ret = '';

    my $msg = $im->_msg2tasks(%args);
    $ret .= "Cannot find ".$im->_locator_list(@{ $msg->{notfound} }).".\n"
        if @{ $msg->{notfound} };

    my (@tasks, @noaccess);
    for (@{ $msg->{tasks} })
    {
        if ($_->current_user_can('read')) { push @tasks, $_ }
        else                              { push @noaccess, $_ }
    }

    $ret .= "You can't see ".$im->_locator_list(@noaccess).".\n"
        if @noaccess;

    if (@tasks == 0)
    {
        return $im->no_matches("Nothing to show!", $msg, pre => $ret, %args);
    }
    elsif (@tasks == 1)
    {
        $ret .= $im->task_summary($msg->{tasks}[0]);
    }
    else
    {
        $ret .= scalar(@tasks) . " tasks in your context:\n";
        for (@tasks)
        {
            $ret .= $im->short_task_summary($_) . "\n";
        }
    }

    $im->_set_shown_tasks($args{session}, @tasks);

    return $ret;
}

1;
