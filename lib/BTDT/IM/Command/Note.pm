package BTDT::IM::Command::Note;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'note' command, which reads, adds, or clears notes on tasks.

=cut

sub run
{
    my $im = shift;
    my %args = @_;
    my $ret = '';
    my $mode = 'add';

       if ($args{message} =~ s{:\s*(.*\S.*)}{}) { }
    elsif ($args{message} =~ s{^(?:clear|del(?:ete)?|rm|remove)\b}{}i) {
        $mode = 'clear';
    }
    else {
        # strip optional command if they provided it
        $args{message} =~ s{^(?:read|see|view)\b}{}i;

        $mode = 'read';
    }

    my $note = $1;

    my $msg = $im->_msg2tasks(%args);
    $ret .= "Cannot find ".$im->_locator_list(@{ $msg->{notfound} }).".\n"
        if @{ $msg->{notfound} };

    if (@{ $msg->{tasks} } == 0) {
        return $im->no_matches(
            ($mode eq 'add'
                ? "Add a note to what?"
                : $mode eq 'clear'
                ? "Clear notes from what?"
                : "Read notes on what?"
            ),
            $msg,
            pre => $ret,
            %args);
    }

    if ($mode eq 'read') {
        return read_notes($im, $msg, \%args, $ret);
    }
    elsif ($mode eq 'add') {
        return add_note($im, $note, $msg, \%args, $ret);
    }
    elsif ($mode eq 'clear') {
        return clear_notes($im, $msg, \%args, $ret);
    }

}

=head2 read_notes

Reads the notes on a task.

=cut

sub read_notes {
    my ($im, $msg, $args, $ret) = @_;
    my $task;

    my @noaccess;
    for (@{ $msg->{tasks} })
    {
        if ($_->current_user_can('read')) { $task = $_; last }
        else                              { push @noaccess, $_ }
    }

    $ret .= "You can't see ".$im->_locator_list(@noaccess).".\n"
        if @noaccess;

    return $im->no_matches("Show the notes of what?", $msg, pre => $ret, %$args)
        if !defined($task);

    $ret .= $im->task_summary($task) . "\n";

    $im->_set_shown_tasks($args->{session}, $task);

    return $ret;
}

=head2 add_note

Add a note to tasks.

=cut

sub add_note {
    my ($im, $note, $msg, $args, $ret) = @_;

    my (@updated, @noaccess);
    for my $task (@{ $msg->{tasks} })
    {
        my $response = $im->update_task($task,
            description => $task->description =~ /\S/
                         ? $task->description . "\n" . $note
                         : $note);

        if ($response) { push @updated,  $task }
        else           { push @noaccess, $task }
    }

    $ret .= "You can't add notes to ".$im->_locator_list(@noaccess).".\n" if @noaccess;
    $ret .= "Added your note to ".$im->_locator_list(@updated) if @updated;

    $im->_set_shown_tasks($args->{session}, @updated);

    return $ret;
}

=head2 clear_notes

Clears notes from tasks.

=cut

sub clear_notes {
    my ($im, $msg, $args, $ret) = @_;

    my (@updated, @noaccess);
    for my $task (@{ $msg->{tasks} })
    {
        my $response = $im->update_task($task,
            description => '');
        if ($response) { push @updated,  $task }
        else           { push @noaccess, $task }
    }

    $ret .= "You can't clear notes from ".$im->_locator_list(@noaccess).".\n" if @noaccess;
    $ret .= "Cleared the notes from ".$im->_locator_list(@updated) if @updated;

    $im->_set_shown_tasks($args->{session}, @updated);

    return $ret;
}

1;

