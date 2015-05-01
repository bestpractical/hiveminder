package BTDT::IM::Command::Priority;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'priority' command, which sets/views the priorities of tasks.

=cut

sub run
{
    my $im = shift;
    my %args = @_;
    my $ret = '';
    my $priority;
    my $priority_word;
    my $view = 0;

       if ($priority = __PACKAGE__->try_colonic_args(\%args)) { }
    elsif ($args{message} =~ s/\b(?<!#)(lowest|low|normal|highest|high)\b//) {
        $priority = $1
    }
    elsif ($args{message} =~ s/(--|-|\+\+|\+|!!|!)//)         { $priority = $1 }
    elsif ($args{message} =~ s/(?<!#)\b(\d)\b//)              { $priority = $1 }
    else                                                      { $view = 1 }

    if (!$view)
    {
        $priority = $im->priority_table->{lc $priority};
        return "I don't know what you mean by priority '$priority'."
            if !defined($priority);
    }

    $priority_word = $im->priorities->[$priority] if $priority;

    my $msg = $im->_msg2tasks(%args);
    my @tasks = @{ $msg->{tasks} };
    $ret .= "Cannot find ".$im->_locator_list(@{ $msg->{notfound} }).".\n"
        if @{ $msg->{notfound} };

    return $im->no_matches("What are we prioritizing?", $msg, pre => $ret, %args)
        if @tasks == 0;

    # update priorities
    if ($priority)
    {
        my (@updated, @noaccess);
        for my $task (@tasks)
        {
            my $response = $im->update_task($task, priority => $priority);
            if ($response) { push @updated,  $task }
            else           { push @noaccess, $task }
        }

        $ret .= "Cannot set the priority on "
             .  $im->_locator_list(@noaccess)
             .  ".\n"
                    if @noaccess;
        return $ret if !@updated;

        $ret .= "Priority set to $priority_word on ".$im->_locator_list(@updated) .".\n";
        $im->_set_shown_tasks($args{session}, @updated);
        return $ret;
    }

    # report priorities
    # sorting by 6 - priority so we get high to low
    my @clumps = $im->_clump_tasks(sub {6 - (shift->priority||0)}, @tasks);

    for my $clump (@clumps)
    {
        if (!defined($clump->[0]->priority))
        {
            $ret .= "You can't see " . $im->_locator_list(@$clump) . ".\n";
            next;
        }

        my $priority = $im->priorities->[$clump->[0]->priority];

        my $has = @$clump == 1 ? 'has' : 'have';

        $ret .= ucfirst($im->_locator_list(@$clump))
             .  " $has $priority priority.\n";
    }
    $im->_set_shown_tasks($args{session}, @tasks);
    return $ret;
}

1;
