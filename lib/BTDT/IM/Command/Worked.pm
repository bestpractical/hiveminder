package BTDT::IM::Command::Worked;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'worked' command, which adds time to worked and subtracts from left.

=cut

sub run
{
    my $self = shift;
    my %args = @_;
    my $ret = '';
    my $input;

    return "Sorry! This feature is for pro users only. Upgrade at http://hiveminder.com/account/upgrade" unless $self->current_user->has_feature('TimeTracking');

       if ($input = __PACKAGE__->try_colonic_args(\%args)) { }
    elsif ($args{message} =~ s/\b(?<!#)(?:for)\s*(.*)//i)   { $input = $1 }
    elsif ($args{message} =~ s/^(.*?)\s*(?<!#)(?:on)\s*//i) { $input = $1 }
    else
    {
        return "I don't understand. Use: <b>worked</b> <i>tasks</i> <b>for</b> <i>duration</i>, or <b>spent</b> <i>duration</i> <b>on</b> <i>tasks</i>.";
    }

    return "For how long?" if $input eq '';

    my ($valid) = BTDT::Model::Task->validate_time_worked($input);
    return "I don't understand the duration '$input'." if not $valid;

    my $msg = $self->_msg2tasks(%args);
    $ret .= "Cannot find ".$self->_locator_list(@{ $msg->{notfound} }).".\n"
        if @{ $msg->{notfound} };

    return $self->no_matches("Worked on what?", $msg, pre => $ret, %args)
        if @{ $msg->{tasks} } == 0;

    my (@updated, @noaccess);
    for my $task (@{ $msg->{tasks} })
    {
        my $response = $self->update_task($task,
            add_time_worked => $input,

            # UpdateTask expects time_left so it can check whether they're the
            # same. if so, it'll subtract time worked from time left
            time_left       => $task->time_left,
        );
        if ($response) { push @updated,  $task }
        else           { push @noaccess, $task }
    }

    $ret .= "You can't update ".$self->_locator_list(@noaccess).".\n" if @noaccess;
    $ret .= "Recorded time worked on ".$self->_locator_list(@updated).".\n"
        if @updated;

    $self->_set_shown_tasks($args{session}, @updated);

    return $ret;
}

1;

