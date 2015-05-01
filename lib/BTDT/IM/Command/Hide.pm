package BTDT::IM::Command::Hide;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'hide' command, which sets/shows the 'starts' date of tasks.

=cut

sub run
{
    my $im = shift;
    my %args = @_;
    my $ret = '';
    my $rel;
    my $starts;

       if ($starts = __PACKAGE__->try_colonic_args(\%args)) { }
    elsif ($args{message} =~ s/\b(?<!#)(?:for[ -]?ever)\b//i) {
        my $run = BTDT::IM::Command::HideForever->can('run');
        return $run->($im, %args);
    }
    elsif ($args{message} =~ s/\b(?<!#)(?:until|til|till)\s*(.*)//i) {
        $starts = $1;
    }
    elsif ($args{message} =~ s/\b(?<!#)(?:for)\s*(.*)//i) {
        $starts = $1;
        $rel = 1;
    }
    else {
        return "I don't understand. Use: <b>hide</b> <i>tasks</i> <b>until</b> <i>date</i>";
    }

    return "For how long?" if $starts eq '' && $rel;
    return "Until when?" if $starts eq '';

    my $today = BTDT::DateTime->now;

    my $unparsed = $rel ? "in $starts" : $starts;
    my $parsed = BTDT::DateTime->intuit_date_explicit($unparsed);
    return "I don't know what you mean by '$starts'."
        if !defined($parsed);
    $parsed = $parsed->ymd;
    undef $parsed unless $parsed gt $today->ymd;

    my $msg = $im->_msg2tasks(%args);
    $ret .= "Cannot find ".$im->_locator_list(@{ $msg->{notfound} }).".\n"
        if @{ $msg->{notfound} };

    return $im->no_matches("Hide what?", $msg, pre => $ret, %args)
        if @{ $msg->{tasks} } == 0;

    my (@updated, @noaccess);
    for my $task (@{ $msg->{tasks} })
    {
        my $response = $im->update_task($task, starts => $parsed);
        if ($response) { push @updated,  $task }
        else           { push @noaccess, $task }
    }

    if (defined($parsed))
    {
        if (@updated)
        {
            $parsed = $updated[0]->starts->friendly_date;
        }

        $ret .= "You can't hide ".$im->_locator_list(@noaccess).".\n" if @noaccess;
        $ret .= "Hiding ".$im->_locator_list(@updated)." until $parsed.\n"
            if @updated;
    }
    else
    {
        $ret .= "You can't unhide ".$im->_locator_list(@noaccess).".\n" if @noaccess;
        $ret .= "Unhiding ".$im->_locator_list(@updated).".\n" if @updated;
    }

    $im->_set_shown_tasks($args{session}, @updated);

    return {response => $ret, review_next => $msg->{contextual}};
}

1;
