package BTDT::IM::Command::Due;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'due' command, which sets/views due dates on tasks.

=cut

sub run
{
    my $im = shift;
    my %args = @_;
    my $ret = '';
    my $date;
    my $unset = 0;
    my $rel;

       if ($date = __PACKAGE__->try_colonic_args(\%args)) { }
    elsif ($args{message} =~ s/\b(?<!#)(?:by|on)(.*)//i) { $date = $1 }
    elsif ($args{message} =~ s/\b(?<!#)(?:in)(.*)//i)    { $date = $1; $rel = 1 }

    $unset = defined($date) && $date =~ /\bnever\b/i;

    my $msg = $im->_msg2tasks(%args);
    my @tasks = @{ $msg->{tasks} };
    $ret .= "Cannot find ".$im->_locator_list(@{ $msg->{notfound} }).".\n"
        if @{ $msg->{notfound} };

    return $im->no_matches("What's due?", $msg, pre => $ret, %args)
        if @tasks == 0;

    # update due dates
    if ($date)
    {
        my $parsed;
        $date =~ s/^\s+//; $date =~ s/\s+$//;
        my $unparsed = $rel ? "in $date" : $date;
        $parsed = BTDT::DateTime->intuit_date_explicit($unparsed) if !$unset;
        return "I don't know what you mean by '$date'."
            if !defined($parsed) && !$unset;
        $parsed = $unset ? undef : $parsed->ymd;

        my (@updated, @noaccess);
        for my $task (@tasks)
        {
            my $response = $im->update_task($task, due => $parsed);
            if ($response) { push @updated,  $task }
            else           { push @noaccess, $task }
        }

        $ret .= "Cannot set the due date on "
             .  $im->_locator_list(@noaccess)
             .  ".\n"
                    if @noaccess;
        return $ret if !@updated;

        my $newdue = $updated[0]->due;

        my $set = defined($newdue)
                ? "Due date set to " . $newdue->friendly_date
                : "Unset the due date";
        $ret .= "$set on ".$im->_locator_list(@updated) .".\n";
        $im->_set_shown_tasks($args{session}, @updated);
        return $ret;
    }

    # report due dates
    my @clumps = $im->_clump_tasks(sub { $_[0]->due }, @tasks);

    my $today = BTDT::DateTime->now;
    $today = $today->ymd;

    for my $clump (@clumps)
    {
        my $due = $clump->[0]->due;
        if (!$due)
        {
            my $has = @$clump > 1 ? "have" : "has";
            $ret .= ucfirst($im->_locator_list(@$clump))
                    .  " $has no due date.\n";
        }
        else
        {
            my $past = $due->ymd lt $today;
            my $plural = @$clump > 1;
            my $is = 'is';
            $is = 'are' if $plural;
            $is = 'was' if $past;
            $is = 'were' if $past && $plural;

            $due = $due->friendly_date;

            $ret .= ucfirst($im->_locator_list(@$clump))." $is due $due.\n";
        }
    }
    $im->_set_shown_tasks($args{session}, @tasks);

    return $ret;
}

1;
