package BTDT::IM::Command::URL;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'URL' command, which shows the URLs for tasks in the user's current context.

=cut

sub run
{
    my $im = shift;
    my %args = @_;
    my $ret = '';

    my $msg = $im->_msg2tasks(%args);
    $ret .= "Cannot find ".$im->_locator_list(@{ $msg->{notfound} }).".\n"
        if @{ $msg->{notfound} };

    if (@{ $msg->{tasks} } == 0)
    {
        return $im->no_matches("Nothing to show!", $msg, pre => $ret, %args);
    }
    else
    {
        $ret .= "Tasks in your context:\n";
        for (@{ $msg->{tasks} })
        {
            my $summary = $_->summary;
            $summary = substr($summary, 0, 20) . '..'
                if length($summary) > 22;

            $ret .= sprintf "#%s: http://task.hm/%s (%s)\n",
                        $_->record_locator,
                        $_->record_locator,
                        $summary;
        }
    }

    $im->_set_shown_tasks($args{session}, @{ $msg->{tasks} });

    return $ret;
}

1;

