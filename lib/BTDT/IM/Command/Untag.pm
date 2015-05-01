package BTDT::IM::Command::Untag;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'untag' command, which removes tags from tasks.

=cut

sub run
{
    my $im = shift;
    my %args = @_;
    my $ret = '';
    my $tags;

       if ($tags = __PACKAGE__->try_colonic_args(\%args)) { }
    elsif ($args{message} =~ s/\[(.*\S.*)\]//)            { $tags = $1 }
    elsif ($args{message} =~ s/^(.*?)\s*from\s*//i)       { $tags = $1 }
    else
    {
        return "I don't understand. Use: <b>untag</b> <i>tags</i> <b>from</b> <i>tasks</i> or: <b>untag</b> <i>tasks</i> <i>[tags]</i>";
    }

    $tags =~ y/[]//d;
    return "Remove which tags?" if $tags =~ /^\s*$/;

    my @tags = BTDT::Model::TaskTagCollection->tags_from_string($tags);
    my $displaytags = join ' ', map {"[$_]"} @tags;
    my $s = @tags > 1 ? 's' : '';
    return "Remove which tags?" if @tags == 0;

    my %remove = map { $_ => 1 } @tags;

    my $msg = $im->_msg2tasks(%args);
    $ret .= "Cannot find ".$im->_locator_list(@{ $msg->{notfound} }).".\n"
        if @{ $msg->{notfound} };

    return $im->no_matches("Untag what?", $msg, pre => $ret, %args)
        if @{ $msg->{tasks} } == 0;

    my (@updated, @noaccess, @noremove);
    for my $task (@{ $msg->{tasks} })
    {
        my (@removed, @kept);
        for ($task->tag_array) {
            if ($remove{$_}) {
                push @removed, $_;
                next;
            }
            push @kept, $_;
        }

        if (@removed == 0) {
            push @noremove, $task;
            next;
        }

        my $response = $im->update_task($task,
            tags => Text::Tags::Parser->new->join_tags(@kept));
        if ($response) { push @updated,  $task }
        else           { push @noaccess, $task }
    }

    $ret .= "You can't untag ".$im->_locator_list(@noaccess).".\n"
        if @noaccess;

    if (@noremove) {
        my $doesnt = @noremove == 1 ? "doesn't" : "don't";
        $ret .= ucfirst($im->_locator_list(@noremove))
             .  " $doesnt have $displaytags.\n";
    }

    $ret .= "Removed $displaytags from " . $im->_locator_list(@updated)
        if @updated;

    $im->_set_shown_tasks($args{session}, @updated);

    return $ret;
}

1;

