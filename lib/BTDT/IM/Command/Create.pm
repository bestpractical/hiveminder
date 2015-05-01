package BTDT::IM::Command::Create;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'create' command, which creates new tasks.

=cut

sub run
{
    my $im = shift;
    my %args = @_;

    # if there's no summary, then go into modal create. any other fields given
    # will be added to each task when the modal create ends
    my $info = BTDT::Model::Task->parse_summary($args{message});
    if (($info->{explicit}{summary}||'') =~ /^\s*$/)
    {
        return "Your modal task creation will have to wait until you're done reviewing tasks." if $args{in_review};

        $args{session}->set(modal_state => 'create ');
        $args{session}->set(braindump_extras => $args{message});

        return "OK. Let's create some tasks, one per line. When finished, type done or cancel." if $im->terse;
        return "OK. Let's create some tasks. You can use <a href=\"http://hiveminder.com/help/reference/tasklists/braindump.html\">braindump syntax</a> to create as many tasks as you want, one per line. Type <b>done</b> to finish or type <b>cancel</b> to exit without creating any tasks.";
    }

    my $braindump = BTDT::Action::ParseTasksMagically->new(
        arguments => {
            text   => $args{message},
            tokens => $im->filter_tokens(%args),
        }
    );

    $braindump->run;
    my $result = $braindump->result;
    my ($created) = $result->message =~ /(\d+ tasks?) created/;
    my @tasks = @{$result->content->{created}};
    return $result->message if @tasks == 0;

    # this occurs during modal create. the user typed "create [foo]" so we
    # want each task created in the modal create to be tagged with [foo]
    # ideally this would be done at create time, but that requires transforming
    # braindump strings into tokens, which isn't coded yet
    my $extras = $args{session}->get('braindump_extras');
    if ($extras) {
        for (@tasks) {
            $_->update_from_braindump($extras);
        }
        $args{session}->remove('braindump_extras');
    }

    if ($im->can('new_task_filter')) {
        for my $task (@tasks) {
            $im->new_task_filter($task, %args);
        }
    }

    @tasks = map { $_->record_locator } @tasks;
    $im->_set_shown_tasks($args{session}, @tasks);

    $args{session}->set(query_header => "Created $created");
    $args{session}->set(query_tasks => join ' ', @tasks);
    $args{session}->set(page => 1);

    $im->_show_tasks(%args);
}

1;
