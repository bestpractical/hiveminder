package BTDT::IM::Command::Comment;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'comment' command, which adds a comment to a task.

=cut

sub run
{
    my $im = shift;
    my %args = @_;
    my $comment = delete $args{message};

    # protect the comment from the addition of #
    if ($args{in_review})
    {
        # by default we interpret the whole thing as a date
        $args{message} = 'these';
    }

    # if the user explicitly adds locators, use them instead
    if ($comment =~ s/^((?>#\S+\s*|\bthis\b\s*|\bthese\b\s*|\ball\b\s*)+)//)
    {
        $args{message} = $1;
    }

    return "Comment on what?" if !exists $args{message};

    $args{message} .= "$comment";

    my $a2t = $im->_add_to_task(%args,
        update_sub => sub {
            my $task = shift;

            # for modal comments, we still want all the side-effects of setting
            # context and whatnot, but we don't want to add empty comments to
            # tasks
            return 1 if $comment eq '';

            $task->comment($comment);
            return 1;
    });

    return "Comment on what?" if !defined($a2t);

    my @updated = @{$a2t->{updated}};
    my @noaccess = @{$a2t->{noaccess}};
    my @notfound = @{$a2t->{notfound}};

    my $ret = '';
    $ret .= "Cannot find ".$im->_locator_list(@notfound).".\n" if @notfound;
    $ret .= "You can't comment on "
         .  $im->_locator_list(@noaccess).".\n"
                if @noaccess;

    if ($comment =~ /^\s*$/)
    {
        if ($args{modal_end})
        {
            # avoid looping back into modal comment
            return "Comment aborted!";
        }
        return "Your modal comment will have to wait until you're done reviewing tasks"
            if $args{in_review};

        my $init = 'comment '
                 . join(' ', map {'#'.$_->record_locator} @updated)
                 . ' ';

        $args{session}->set(modal_state => $init);

        return $ret . "All text you enter now will be added as a comment on ".$im->_locator_list(@updated).". Finish with 'done' or 'cancel'." if $im->terse;
        return $ret . "Welcome to modal comment mode. Anything you send me will be interpreted as one big comment on ".$im->_locator_list(@updated).". Type <b>done</b> to finish or type <b>cancel</b> to exit without commenting.";
    }

    $ret .= "Added your comment to ".$im->_locator_list(@updated) .".\n"
        if @updated;
    return $ret;
}

1;
