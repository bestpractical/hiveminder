package BTDT::IM::Command::History;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'history' command, which summarizes a task's history

=cut

sub run
{
    my $im = shift;
    my %args = @_;
    my $ret = '';

    my $msg = $im->_msg2tasks(%args);
    $ret .= "Cannot find ".$im->_locator_list(@{ $msg->{notfound} }).".\n"
        if @{ $msg->{notfound} };

    my ($task, @noaccess);
    for (@{ $msg->{tasks} })
    {
        if ($_->current_user_can('read')) { $task = $_; last }
        else                              { push @noaccess, $_ }
    }

    $ret .= "You can't see ".$im->_locator_list(@noaccess).".\n"
        if @noaccess;

    return $im->no_matches("Show the history of what?", $msg, pre => $ret, %args)
        if !defined($task);

    $ret .= $im->task_summary($task) . "\n";
    my $transactions = $task->transactions;

    while (my $t = $transactions->next)
    {
        next unless $t->summary;
        $ret .= $t->summary . ' at ' . $t->modified_at . ".\n";
        my $comments = $t->comments;
        while (my $email = $comments->next) {
            if (my $sub = $email->header('Subject')) {
                $ret .= "Subject: $sub\n";
            }
            my $email = $email->formatted_body;
            $ret .= $email;
        }
    }

    $im->_set_shown_tasks($args{session}, $task);

    return $ret;
}

1;

