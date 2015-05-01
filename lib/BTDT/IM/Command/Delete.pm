package BTDT::IM::Command::Delete;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'delete' command, which deletes tasks wholesale.

=cut

sub run
{
    my $im = shift;
    my %args = @_;
    my $ret = '';

    my $msg = $im->_msg2tasks(%args);
    $ret .= "Cannot find ".$im->_locator_list(@{ $msg->{notfound} }).".\n"
        if @{ $msg->{notfound} };

    return $im->no_matches("Delete what?", $msg, pre => $ret, %args)
        if @{ $msg->{tasks} } == 0;

    if ($msg->{search} && @{ $msg->{tasks} } > 1)
    {
        my $command = 'delete';
        my $output = $im->terse
                   ? "Send me 'y' to delete these tasks."
                   : "Multiple tasks match your search. Send me <b>y</b> on a line by itself to confirm deletion of these tasks. Anything else will be treated as a fresh command.\n";
        for (@{ $msg->{tasks} })
        {
            $output .= "\n" . $im->short_task_summary($_);
            $command .= ' ' . $_->record_locator;
        }
        $args{session}->set(confirm => $command);
        return $output;
    }

    my (@deleted, @noaccess);
    for (@{ $msg->{tasks} })
    {
        if (!$_->current_user_can('delete')) { push @noaccess, $_; next }

        my $delete = BTDT::Action::DeleteTask->new(record => $_);
        $delete->run;
        if ($delete->result->success) { push @deleted, $_ }
        else                          { push @noaccess, $_ }
    }

    $ret .= "Cannot delete "
            .  $im->_locator_list(@noaccess)
            .  ".\n"
                if @noaccess;

    return { response => $ret, review_next => $msg->{contextual} } if !@deleted;

    $ret .= "Deleted ".$im->_locator_list(@deleted) .".\n";
    $im->_set_shown_tasks($args{session});

    return { response => $ret, review_next => $msg->{contextual} };
}

1;
