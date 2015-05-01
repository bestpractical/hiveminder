package BTDT::IM::Command::Review;
use strict;
use warnings;
use base 'BTDT::IM::Command';
use Time::Duration;

=head2 run

Runs the 'review' command, which works a lot like the Task Review page on the
web. This is called only when the user explicitly types 'review'. During the
review process, C<display> and C<review> are called.

=cut

# the data structure for the tasks to review is a string of locators with a /
# which precedes the current item. if the / is at the end of string then the
# review is over.

sub run
{
    my $im = shift;
    my %args = @_;

    my @tasks;
    my $locators;
    my @ret;
    my $msg = {};

    return "You're already reviewing tasks!" if $args{in_review};

    if ($args{message} =~ /^\s*$/)
    {
        my $tasks = BTDT::Model::TaskCollection->new();
        $tasks->from_tokens(qw(owner me not complete starts before tomorrow
                               but_first nothing));
        $im->apply_filters($tasks, %args);
        @tasks = @{$tasks->items_array_ref};
    }
    else
    {
        $msg = $im->_msg2tasks(%args);

        my $warnings;
        $warnings .= "Cannot find "
                  .  $im->_locator_list(@{ $msg->{notfound} })
                  .  ".\n"
                         if @{ $msg->{notfound} };

        my (@noaccess, @complete);
        for (@{ $msg->{tasks} })
        {
            if (!$_->current_user_can('update'))
            {
                push @noaccess, $_;
            }
            elsif ($_->complete)
            {
                push @complete, $_;
            }
            else
            {
                push @tasks, $_;
            }
        }

        $warnings .= "You can't review "
                  .  $im->_locator_list(@noaccess)
                  .  ".\n"
                         if @noaccess;

        $warnings .= ucfirst($im->_locator_list(@complete))
                  .  " are already done.\n"
                         if @complete;

        push @ret, $warnings if $warnings;
    }

    $locators ||= join ' ', '/',
                            map {$_->record_locator} @tasks;

    return $im->no_matches("You have nothing to review.", $msg, pre => $ret[0], %args)
        if $locators =~ m{^/\s*$};

    $args{session}->set(review_tasks => $locators);
    $args{session}->set(review_start => time);

    push @ret, display($im, %args);
    return @ret;
}

=head2 current_task CMDARGS

Retrieves the task currently under review. If there are no tasks left, it will
exit the review and return the user-displayable error message. If there are
tasks left, it will return a three-element list with: the C<BTDT::Model::Task>,
the number of tasks already reviewed thus far, and the number of tasks left in
the review.

=cut

sub current_task
{
    my $im = shift;
    my %args = @_;

    my $locators = $args{session}->get('review_tasks');

    my ($shown, $to_show) = $locators =~ m{^(.*?)/(.*)};
    my @shown = split ' ', $shown;
    my @to_show = split ' ', $to_show;

    if (@to_show == 0)
    {
        my $ret = "All done! That wasn't so bad, was it?";

        $args{session}->set(review_tasks => '');
        if (my $start = $args{session}->get('review_start'))
        {
            $ret .= ' The review took you ' . duration(time - $start, 1) . '.';
            $args{session}->set(review_start => '');
        }

        return $ret;
    }

    my $task = BTDT::Model::Task->new();
    $task->load_by_locator($to_show[0]);

    if (!$task->id)
    {
        # couldn't load task, so let's try the next one
        next_task($im, %args);

        unshift @_, $im; # we need it on again, since goto &sub reuses @_
        goto &current_task;
    }

    $im->_set_shown_tasks($args{session}, $task);

    return ($task, scalar @shown, scalar @to_show);
}

=head2 remaining_tasks CMDARGS

Retrieves the current task under review, and every following task.

=cut

sub remaining_tasks
{
    my $im = shift;
    my %args = @_;
    my $locators = $args{session}->get('review_tasks');

    my ($to_show) = $locators =~ m{^.*?/(.*)};
    $im->_set_shown_tasks($args{session}, $to_show);

    return $to_show;
}

=head2 display

Displays the menu for a task.

=cut

sub display
{
    my $im = shift;
    my %args = @_;

    my ($task, $shown, $to_show) = current_task($im, %args);
    return $task if !defined($shown);

    my $count = $shown + $to_show;
    my $current = $shown + 1;
    my $percent = int(100 * $current / $count);
    my $menu = $im->terse
             ? "$current/$count\n"
             : "Reviewing task $current of $count ($percent%):\n";

    $menu .= $im->task_summary($task);


    my $now     = BTDT::DateTime->now;
    my $twodays = $now->intuit_date_explicit("in 2 days")->day_name;

    if ($task->accepted)
    {
        if ($im->terse) {
            $menu .= "Shortcuts: D T12SMZ NQ";
        }
        else {
            $menu .= << "MENU";

Shortcuts: [<b>D</b>]one! :: Do this [<b>T</b>]oday :: Hide until tomorrow ([<b>1</b>] day), $twodays ([<b>2</b>] days), [<b>S</b>]aturday, [<b>M</b>]onday, next month [<b>Z</b>] :: Continue to [<b>N</b>]ext task :: [<b>Q</b>]uit the review
MENU
        }
    }
    else
    {
        if ($im->terse) {
            $menu .= "Shortcuts: [A]ccept [R]eject [N]ext [Q]uit";
        }
        else {
            $menu .= << "MENU";
This task is awaiting your acceptance.

Shortcuts: [<b>A</b>]ccept :: [<b>R</b>]eject :: Continue to the [<b>N</b>]ext task :: [<b>Q</b>]uit the review
MENU
        }
    }

    return $menu;
}

=head2 review

Called from the dispatcher like a normal command, for when we're in task review
mode.

=cut

sub review
{
    my $im = shift;
    my %args = @_;
    my ($task, $tasks, @ok);
    my $star = 0;

    if ($args{message} =~ s/^\*//) {
        $star = 1;
        $tasks = remaining_tasks($im, %args);
    }
    else {
        ($task, @ok) = current_task($im, %args);
        return $task unless @ok;
    }

    my %shortcuts;
    if ($star || $task->accepted)
    {
        my $now      = BTDT::DateTime->now;
        my $monday   = $now->dow == 1 ? 'next Monday'   : 'Monday';
        my $saturday = $now->dow == 6 ? 'next Saturday' : 'Saturday';

        %shortcuts =
        (
            T => 'hide this until today',
            TODAY => 'hide this until today',

            1 => 'hide this until tomorrow',
            TOMORROW => 'hide this until tomorrow',

            # Funky wording, but consistency
            2 => 'hide this until in 2 days',
            TWODAYS => 'hide this until in 2 days',

            S => "hide this until $saturday",
            SATURDAY => "hide this until $saturday",

            M => "hide this until $monday",
            MONDAY => "hide this until $monday",

            Z => 'hide this until next month',
            MONTH => 'hide this until next month',

            D => 'done',
        );
    }
    else
    {
        %shortcuts =
        (
            A => 'accept',
            R => 'reject',
            D => 'done',
        );
    }

    # q and quit are always valid shortcuts
    $shortcuts{QUIT} = $shortcuts{Q} = sub
    {
        my $ret = "All right. I'll let you off easy. <i>This time.</i>";
        $args{session}->set(review_tasks => '');

        if (my $start = $args{session}->get('review_start'))
        {
            $ret .= ' The review lasted ' . duration(time - $start, 1) . '.';
            $args{session}->set(review_start => '');
        }

        return $ret;
    };

    # as are n, next and c and continue
    $shortcuts{CONTINUE} = $shortcuts{C} =
    $shortcuts{NEXT}     = $shortcuts{N} = sub {
        next_task($im, %args);
        return display($im, %args);
    };

    my $shortcut = $shortcuts{ uc $args{message} };

    if (ref($shortcut) eq 'CODE')
    {
        return $shortcut->();
    }
    elsif (defined $shortcut)
    {
        $args{message} = $shortcut;
    }
    elsif ($args{message} =~ /^\s*(\d+)\s*$/)
    {
        my $dt = BTDT::DateTime->now->add(days => $1)->ymd;
        $args{message} = "hide this until $dt";
    }

    my @messages = $im->_parse_message(%args, in_review => 1);
    for (@messages)
    {
        if (!$star && ref($_) eq 'HASH' && $_->{review_next})
        {
            next_task($im, %args);
            return display($im, %args);
        }
    }

    return display($im, %args);
}

=head2 next_task

Updates internal state of the review iterator.

=cut

sub next_task
{
    my $im = shift;
    my %args = @_;

    my $tasks = $args{session}->get('review_tasks');
    $tasks =~ s{/ (\S+)}{$1 /};
    $args{session}->set(review_tasks => $tasks);
}

1;

