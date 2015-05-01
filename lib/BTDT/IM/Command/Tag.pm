package BTDT::IM::Command::Tag;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'tag' command, which adds tags to tasks.

=cut

sub run
{
    my $im = shift;
    my %args = @_;
    my $ret = '';
    my $tags;

       if ($tags = __PACKAGE__->try_colonic_args(\%args)) { }
    elsif ($args{message} =~ s/\b(?<!#)with\s*(.+)//i)    { $tags = $1 }
    elsif ($args{message} =~ s/\[(.*\S.*)\]//)            { $tags = $1 }
    else
    {
        return "I don't understand. Use: <b>tag</b> <i>tasks</i> <b>with</b> <i>tags</i> or: <b>tag</b> <i>tasks</i> <i>[tags]</i>";
    }

    $tags =~ y/[]//d;
    return "Tag with what?" if $tags =~ /^\s*$/;

    my @tags = BTDT::Model::TaskTagCollection->tags_from_string($tags);
    my $displaytags = join ' ', map {"[$_]"} @tags;
    my $s = @tags > 1 ? 's' : '';
    return "Tag with what?" if @tags == 0;

    my $msg = $im->_msg2tasks(%args);
    $ret .= "Cannot find ".$im->_locator_list(@{ $msg->{notfound} }).".\n"
        if @{ $msg->{notfound} };

    return $im->no_matches("Tag what?", $msg, pre => $ret, %args)
        if @{ $msg->{tasks} } == 0;

    my (@updated, @noaccess);
    for my $task (@{ $msg->{tasks} })
    {
        my $response = $im->update_task($task,
            tags => $task->tags . ' ' . $tags);
        if ($response) { push @updated,  $task }
        else           { push @noaccess, $task }
    }

    $ret .= "You can't tag ".$im->_locator_list(@noaccess).".\n" if @noaccess;
    $ret .= "Updated ".$im->_locator_list(@updated)
         .  " with tag$s: $displaytags.\n"
                if @updated;

    $im->_set_shown_tasks($args{session}, @updated);

    return $ret;
}

1;
