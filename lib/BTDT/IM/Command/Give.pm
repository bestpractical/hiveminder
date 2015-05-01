package BTDT::IM::Command::Give;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'give' command, which assigns tasks to other people.

=cut

sub run
{
    my $im = shift;
    my %args = @_;
    my $ret = '';
    my $owner;

       if ($owner = __PACKAGE__->try_colonic_args(\%args)) { }
    elsif ($args{message} =~ s/\b(?<!#)to\s*(.+)//i)   { $owner = $1 }
    elsif ($args{message} =~ s/(\S+@\S+)//i)           { $owner = $1 }
    elsif ($args{message} =~ s/\b(up|away|nobody)\b//) { $owner = $1 }
    else
    {
        return "I don't understand. Use: <b>give</b> <i>tasks</i> <i>email</i>";
    }

    my $no_owner = $owner eq 'nobody' || $owner eq 'up' || $owner eq 'away';
    $owner = 'nobody' if $no_owner;

    my $verb = $no_owner ? "Abandon" : "Give";
    $verb = "Take" if $owner eq 'me';

    my $msg = $im->_msg2tasks(%args);
    $ret .= "Cannot find ".$im->_locator_list(@{ $msg->{notfound} }).".\n"
        if @{ $msg->{notfound} };

    return $im->no_matches("$verb what?", $msg, pre => $ret, %args)
        if @{ $msg->{tasks} } == 0;

    my (@selfowner, @updated, @took, @noaccess);
    for my $task (@{ $msg->{tasks} })
    {
        my $selfowner = $task->owner_id == $args{user}->id;

        my $result = $im->update_task($task, owner_id => $owner);
           if (!$result)                           { push @noaccess,  $task }

        elsif ($task->owner_id == $args{user}->id && $selfowner)
                                                   { push @selfowner, $task }

        elsif ($task->owner_id == $args{user}->id) { push @took,      $task }
        else                                       { push @updated,   $task }
    }

    $ret .= "Giving "
         .  $im->_locator_list(@selfowner)
         .  " to yourself? That's curious.\n"
                if @selfowner;

    $ret .= "Cannot give away ".$im->_locator_list(@noaccess).".\n"
        if @noaccess;

    if (@took) {
        $ret .= "Took ".$im->_locator_list(@took).".\n";
        $im->_set_shown_tasks($args{session}, @took);
    }

    if (@updated)
    {
        if ($no_owner)
        {
            $ret .= "Abandoned ".$im->_locator_list(@updated) .".\n";
        }
        else
        {
            $owner = $updated[0]->owner->email;
            $ret .= "Gave ".$im->_locator_list(@updated) ." to $owner.\n";
        }
        $im->_set_shown_tasks($args{session}, @updated);
    }

    return {response => $ret, review_next => $msg->{contextual}};
}

1;
