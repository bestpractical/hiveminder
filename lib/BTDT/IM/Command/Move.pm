package BTDT::IM::Command::Move;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'move' command, which sets the group of tasks.

=head2 type

This command works with groups.

=head2 preposition

C<move foo TO bar>

=cut

sub type { 'group' }
sub preposition { 'to' }

sub run {
    my $im = shift;
    my %args = @_;
    my $ret = '';
    my $input;

    my $package     = $args{package};
    my $command     = $args{command};
    my $type        = $package->type;
    my $preposition = $package->preposition;

    # allow "group of FOO is BAR"
    $args{message} =~ s/^of\b\s*//i;

       if ($input = __PACKAGE__->try_colonic_args(\%args)) { }
    elsif ($args{message} =~ s/\b(?<!#)(?:is|to|into)\s*(.*)//i) { $input = $1 }
    else
    {
        return "I don't understand. Use: <b>$command</b> <i>tasks</i> <b>$preposition</b> <i>$type</i>";
    }

    return "Into which $type?" if $input eq '';

    my $method = "canonicalize_$type";
    my ($name, $id) = $package->$method($input);
    return "I don't know the '$input' $type."
        if !defined($id);

    my $msg = $im->_msg2tasks(%args);
    $ret .= "Cannot find ".$im->_locator_list(@{ $msg->{notfound} }).".\n"
        if @{ $msg->{notfound} };

    return $im->no_matches("Move what?", $msg, pre => $ret, %args)
        if @{ $msg->{tasks} } == 0;

    my (@updated, @noaccess, @alreadydone);
    for my $task (@{ $msg->{tasks} })
    {
        if (($task->$type->id||0) == $id) { push @alreadydone, $task; next }

        my $response = $im->update_task($task, "${type}_id" => $id);
        if ($response) { push @updated,  $task }
        else           { push @noaccess, $task }
    }

    my $is = @alreadydone == 1 ? 'is' : 'are';
    $ret .= ucfirst($im->_locator_list(@alreadydone))." $is already in $type '$name'.\n" if @alreadydone;

    $ret .= "You can't move ".$im->_locator_list(@noaccess)." into $type '$name'.\n" if @noaccess;
    $ret .= "Moved ".$im->_locator_list(@updated)." into $type '$name'.\n"
        if @updated;

    $im->_set_shown_tasks($args{session}, @updated);

    return $ret;
}

1;

