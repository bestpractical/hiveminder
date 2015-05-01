package BTDT::RTM::Tasks;

use strict;
use warnings;

use base 'BTDT::RTM';
use DateTime::Format::ISO8601;

my %priority_hm_to_rtm = ( 1 => "N", 2 => "N", 3 => 3, 4 => 2, 5 => 1 );
my %priority_rtm_to_hm = reverse %priority_hm_to_rtm;

=head1 NAME

BTDT::RTM::Tasks - Task management

=head1 METHODS

=head2 require_task

Helper method, which aborts unless a C<task_id> is given.  Returns the
task object.

=cut

sub require_task {
    my $class = shift;
    $class->require_user;

    my $task = BTDT::Model::Task->new;
    $task->load( $class->params->{task_id} );
    $class->send_error( 340 => "task_id invalid or not provided" )
        unless $task->id;
    $task->start_transaction;
    return $task;
}

=head2 send_txn TASK [TRANSACTION]

Finishes the current transaction, if any, and sends a summary of it.

=cut

sub send_txn {
    my $class = shift;
    my $task = shift;

    my $txn = shift || $task->current_transaction || undef;
    $txn = $txn->id if ref $txn;

    $task->end_transaction if $task->current_transaction;

    $class->send_ok(
        transaction => { id => $txn, undoable => 0 },
        list => {
            id => $class->params->{'list_id'},
            taskseries => $class->task_data($task),
        },
    );
}

=head2 task_data TASK

Sends data about the given task.

=cut

sub task_data {
    my $class = shift;
    my $task = shift;

    my %times;
    for my $field (qw/created last_modified due completed_at/) {
        # We try hard here not to stringify the DateTime objects since it's slow
        # when they have formatter like these do courtesy of the JDBI filters
        my $dt = $task->$field;
        if ( defined $dt ) {
            $times{$field} = $dt;

            # We move from floating to local for floating dates
            # (like "due"), and then to UTC to get the right offset
            $times{$field}->set_current_user_timezone("UTC")
                if $times{$field}->time_zone->is_floating;

            $times{$field}->set_time_zone("UTC");
            $times{$field} = $times{$field}->ymd."T".$times{$field}->hms."Z";
        }
        else {
            $times{$field} = "";
        }
    }

    my @tags = $task->tag_array;
    my @notes = map {BTDT::RTM::Tasks::Notes->note_data($_)}
        grep {$_->transaction->type ne "create"} @{$task->comments};

    return {
        id           => $task->id,
        created      => $times{created},
        modified     => $times{last_modified},
        name         => $task->summary,
        source       => "api",
        location_id  => "",
        url          => "",
        tags         => ( @tags ? { tag => \@tags } : [] ),
        participants => [],
        notes        => ( @notes ? { note => \@notes } : [] ),
        task         => {
            id           => $task->id,
            due          => $times{due},
            has_due_time => 0,
            added        => $times{created},
            completed    => $times{completed_at},
            deleted      => "",
            priority     => $priority_hm_to_rtm{ $task->priority },
            postponed    => "0",
            estimate     => "",
        }
    };
}

=head2 method_add

Adds a task.

=cut

sub method_add {
    my $class = shift;
    $class->require_user;

    $class->send_error( 4000 => "Task name provided is invalid" )
        unless $class->params->{name};

    my $task = BTDT::Model::Task->new;

    my %defaults = ();

    if ( $class->params->{'list_id'} ) {
        my $collection = $class->load_list;
        %defaults = $collection->new_defaults;
    }

    my ($id, $msg) = $task->create(
        %defaults,
        summary => $class->params->{name},
        __parse_summary => $class->params->{parse},
    );
    $class->send_error( 105 => "Task creation failed: $msg" )
        unless $id;
    $class->send_txn( $task, $task->transactions->last );
}

=head2 method_addTags

Adds tags to a task.

=cut

sub method_addTags {
    my $class = shift;
    my $task = $class->require_task;
    $task->set_tags(
        Text::Tags::Parser->new->join_tags(
            $task->tag_collection->as_list,
            split /,/, $class->params->{tags}
        )
    );

    $class->send_txn( $task );
}

=head2 method_complete

Marks a task as complete.

=cut

sub method_complete {
    my $class = shift;
    my $task = $class->require_task;
    $task->set_complete(1);
    $class->send_txn( $task );
}

=head2 method_delete

Hides a task forever.

=cut

sub method_delete {
    my $class = shift;
    my $task = $class->require_task;
    $task->set_will_complete(0);
    $class->send_txn( $task );
}

=head2 method_getList

Returns a list of all tasks that match the given C<filter>, and were
modified after C<last_sync>.

=cut

sub method_getList {
    my $class = shift;
    $class->require_user;

    my $collection = $class->load_list;

    my $since = $class->params->{'last_sync'};
    if ($since) {
        $since =~ s/\+0000$/Z/;
        $since = DateTime::Format::ISO8601->parse_datetime($since);
        my $txns_alias = $collection->join(
            alias1  => 'main',
            column1 => 'id',
            table2  => 'task_transactions',
            column2 => 'task_id'
        );
        $collection->limit(
            alias    => $txns_alias,
            column   => 'modified_at',
            operator => '>',
            value    => $since."Z",
        );
    }

    if (my $filter = $class->params->{'filter'}) {
        while ($filter =~ /(\S+?):("(.*?)"|\S+)/g) {
            my ($type, $value) = ($1, $3 || $2);
            if ($type eq "name") {
                $collection->from_tokens( summary => $value );
            } elsif ($type eq "priority") {
                $collection->from_tokens( priority => $priority_rtm_to_hm{$value} );
            } elsif ($type eq "status") {
                $collection->from_tokens( ($value eq "completed") ? () : ("not"), "complete" );
            } elsif ($type eq "tag") {
                $collection->from_tokens( tag => $value );
            } elsif ($type eq "due") {
                $collection->from_tokens( due => $value );
            } elsif ($type eq "dueBefore") {
                $collection->from_tokens( due => before => $value );
            } elsif ($type eq "dueAfter") {
                $collection->from_tokens( due => after => $value );
            } elsif ($type eq "completed") {
                $collection->from_tokens( completed_at => $value );
            } elsif ($type eq "completedBefore") {
                $collection->from_tokens( completed_at => before => $value );
            } elsif ($type eq "completedAfter") {
                $collection->from_tokens( completed_at => after => $value );
            } elsif ($type eq "added") {
                $collection->from_tokens( created => $value );
            } elsif ($type eq "addedBefore") {
                $collection->from_tokens( created => before => $value );
            } elsif ($type eq "addedAfter") {
                $collection->from_tokens( created => after => $value );
            } elsif ($type eq "isReceived") {
                $collection->from_tokens( requestor => not => 'me' );
            } elsif ($type eq "to") {
                $collection->from_tokens( owner => not => $value );
            }
        }
    }

    $class->send_ok(
        tasks => {
            list => {
                # Give them back the list id as it was submitted
                id => $class->params->{'list_id'},
                $since ? ( current => $since."Z" ) : (),
                $collection->count
                    ? ( taskseries =>
                        [ map { $class->task_data($_) } @{$collection} ], )
                    : (),
            },
        },
    );
}

=head2 method_movePriority

Moves the priority up or down.

=cut

sub method_movePriority {
    my $class = shift;
    my $task = $class->require_task;
    $class->send_error( 105 => "Invalid or no direction supplied" )
        unless $class->params->{direction}||"" =~ /^(up|down)$/;
    my $prio = $task->priority;
    $prio++ if $class->params->{direction} eq "up" and $prio == 1; # account for RTM only having 4 prios
    $prio++ if $class->params->{direction} eq "up" and $prio < 5;
    $prio-- if $class->params->{direction} eq "down" and $prio > 2;
    $task->set_priority($prio);
    $class->send_txn( $task );
}

=head2 method_moveTo

Unimplemented, due to not implementing multiple lists.

=cut

sub method_moveTo { shift->send_unimplemented; }

=head2 method_postpone

Unimplemented, due to knowing what "postpone" means.

=cut

sub method_postpone { shift->send_unimplemented; }

=head2 method_removeTags

Removes the given tags.

=cut

sub method_removeTags {
    my $class = shift;
    my $task = $class->require_task;
    my %skip = map {+($_ => 1)} split /,/, $class->params->{tags};
    my @tags = grep {not $skip{$_}} $task->tag_collection->as_list;
    $task->set_tags( Text::Tags::Parser->new->join_tags(@tags) );
    $class->send_txn( $task );
}

=head2 method_setDueDate

Sets the due date.

=cut

sub method_setDueDate {
    my $class = shift;
    my $task = $class->require_task;
    my $dt;
    if ($class->params->{parse}) {
        $dt = BTDT::DateTime->intuit_date_explicit($class->params->{due});
    } else {
        my $due = $class->params->{due};
        $due =~ s/\+0000$/Z/;
        $dt = DateTime::Format::ISO8601->parse_datetime($due)->ymd;
    }
    $class->send_error( 360 => "Can't parse datetime" ) unless $dt;
    $task->set_due($dt);
    $class->send_txn( $task );
}

=head2 method_setEstimate

Unimplemented due to time parsing.

=cut

sub method_setEstimate { shift->send_unimplemented; }

=head2 method_setLocation

Unimplemented due to lack of location implementation.

=cut

sub method_setLocation { shift->send_unimplemented; }

=head2 method_setName

Sets the summary of the task.

=cut

sub method_setName {
    my $class = shift;
    my $task = $class->require_task;
    $class->send_error( 4000 => "Task name provided is invalid")
        unless $class->params->{name};
    $task->set_summary( $class->params->{name} );
    $class->send_txn( $task );
}

=head2 method_setPriority

Sets the priority

=cut

sub method_setPriority {
    my $class = shift;
    my $task = $class->require_task;
    my $prio = $priority_rtm_to_hm{$class->params->{priority} || "-"} || 3;
    $task->set_priority( $prio );
    $class->send_txn( $task );
}

=head2 method_setRecurrence

Unimplemented due to our recurrence model sucking.

=cut

sub method_setRecurrence { shift->send_unimplemented; }

=head2 method_setTags

Sets the tags on the task.

=cut

sub method_setTags {
    my $class = shift;
    my $task = $class->require_task;
    $task->set_tags( Text::Tags::Parser->new->join_tags( split /,/, $class->params->{tags} ) );
    $class->send_txn( $task );
}

=head2 method_setURL

Unimplemented due to us not having a specific URL field

=cut

sub method_setURL { shift->send_unimplemented; }

=head2 method_uncomplete

Marks a task as no longer done.

=cut

sub method_uncomplete {
    my $class = shift;
    my $task = $class->require_task;
    $task->set_complete(0);
    $class->send_txn( $task );
}

1;
