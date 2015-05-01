package BTDT::Sync;

use warnings;
use strict;

use base 'Jifty::Object';

=head1 NAME

BTDT::Sync

=head1 DESCRIPTION

Provides generic utility methods for syncing (and importing or
exporting) between BTDT tasks and outside data formats.

=cut


=head2 sync_data PARAMHASH

A helper to sync data structures extracted from some imported data
file into BTDT tasks

=over

=item ids

An array reference of task IDs that were originally sent out.
Defaults to the empty list. Any tasks with IDs that are present here,
but not in C<tasks> will be marked as complete.

=item tasks

And array reference of hash references, of the sort that
L<BTDT::Sync::TextFile/parse_tasks> would generate, namely hashes
representing tasks-to-be, with fields for columns on
C<BTDT::Model::Task>

Defaults to the empty list.

=item tokens

An array reference of tokens that should be used to find defaults for
any created tasks.  Defaults to undef, which causes no defaults to be
imposed.

=back

Returns a hash reference of array references of L<BTDT::Model::Task>
objects.  The keys of the bash reference are C<created>, C<updated>,
C<completed>, C<create_failed>, and C<update_failed>.

=cut

sub sync_data {
    my $class = shift;
    my %args = (ids => [], tasks => [], tokens => undef, @_);

    # Extract which IDs or record locators we sent out.
    # The point here is to end with %ids set, since all our update code
    # is keyed with IDs.
    my ( %ids );

    my @temp;
    push (@temp, int($_)) foreach @{$args{ids}};
    $args{ids} = \@temp;

    $ids{$_}++ for @{ $args{ids} };

    # Find out the default values, based on the search we sent out
    my %defaults;
    if ($args{tokens}) {
        my $tasks = BTDT::Model::TaskCollection->new();
        $tasks->from_tokens(@{ $args{tokens} });
        %defaults = $tasks->new_defaults;
    }

    my $ret = {
        created       => [],
        updated       => [],
        completed     => [],
        create_failed => [],
        update_failed => [],
        ids           => [],
    };

    # these keep track of the temporary IDs for tasks used in dependencies
    # when a task is created, it sees if there's an unfulfilled dependency
    # waiting on it (and if so, creates it), then it lets other tasks know
    # how it can find the task given its temporary ID
    my %unfulfilled_dependencies;
    my %ready_for_dependency;

    # Loop through each task
    for my $parsed_task (@{ $args{tasks} }) {
        my $t = {
            %defaults,
            %{ $parsed_task },
            tags => join(" ",
                        grep {$_}
                            $defaults{tags} || "",
                            $parsed_task->{tags} || ""),
        };

        my $task = BTDT::Model::Task->new();

        my ($dependency_type, $dependency_on);
        my $dependency_id = delete $t->{__dependency_id};

        if ( $t->{__dependency_type} ) {
            $dependency_type = delete $t->{__dependency_type};
            $dependency_on   = delete $t->{__dependency_on};
        }

        if ( $t->{id} and $t->{summary} and delete $ids{ $t->{id} } ) {
            # We sent the task out, so this is an update
            $task->load( $t->{id} );
            next unless $task->current_user_can("update");
            $task->start_transaction;

            $task->set_summary( $t->{summary} );
            $task->set_description( $t->{description} );
            $task->set_tags( $t->{tags} );
            $task->set_priority( $t->{priority} ) if $t->{priority};
            $task->set_due( $t->{due} ) if $t->{due};
            $task->set_group_id( $t->{group_id} ) if $t->{group_id};
            $task->set_starts( $t->{starts} ) if $t->{starts};

            # Use the current user from the task since we don't have a current
            # user for classes (like here) only instances
            if ( $task->current_user->has_feature('TimeTracking') ) {
                # Take our time worked param and ADD it to the existing time worked
                # Also subtract it from the existing time left iff the user doesn't
                # specify that explicitly (this is different logic than the Update action)
                if ( $t->{time_worked} ) {
                    my $seconds = $task->duration_in_seconds( $t->{time_worked} );

                    if ( defined $seconds ) {
                        # Time::Duration::Parse DOES handle "3h10s 5 seconds" correctly
                        my $worked = ($task->time_worked || '') . " $seconds seconds";
                        $task->set_time_worked( $worked );

                        # If we have time worked AND time left in the summary for this task,
                        # then we don't want to change time left behind the user's back
                        my $old_left = $task->time_left;

                        if ( defined $old_left and not defined $t->{time_left} ) {
                            my $left = $task->duration_in_seconds( $old_left ) - $seconds;
                            $task->set_time_left( $left >= 0 ? "$left seconds" : undef );
                        }
                    }
                }

                $task->set_time_left( $t->{time_left} ) if defined $t->{time_left}; # may be 0
            }

            # starting with 0.02, we send out due and group. if these
            # don't come back, assume the user doesn't want them any more.
            # for consistency, we do the same with priority as well
            if ($args{format_version} >= '0.02') {
                # default priority is 3, so
                $t->{priority} ||= 3;

                for my $attr (qw/due priority/) {
                    my $setter = "set_$attr";
                    $task->$setter(undef)
                        if $task->$attr && !defined $t->{$attr};
                }

                # tasks ALWAYS have a real group, even if it's just "personal"
                $task->set_group_id($t->{group_id} || 0)
                    if $task->group_id
                    && lc($t->{group_id}||'') ne lc($task->group->name||'personal');
            }

            if ($task->end_transaction) {
                push @{$ret->{updated}}, $task;
            } else {
                push @{$ret->{update_failed}}, $task;
            }
        }
        elsif ($t->{id}) {
            # this codepath usually indicates that the user gave a record
            # locator for a dependency. we don't want to update or create the
            # task
            $task->load_by_locator(delete $t->{id});
        }
        else {
            # Didn't exist before, create
            delete $t->{id};

            $task->create( %{$t} );
            if ($task->id) {
                push @{$ret->{created}}, $task;
            } else {
                push @{$ret->{create_failed}}, $task;
            }
        }

        # now work out dependencies
        if (my $dep = $dependency_id && $unfulfilled_dependencies{$dependency_id}) {
            my ($type, $other) = @$dep;

            if ($type eq 'first') {
                $task->add_depended_on_by($other);
            }
            else {
                $other->add_depended_on_by($task);
            }
        }

        if ($dependency_on) {
            if (my $other = $ready_for_dependency{$dependency_on}) {
                if ($dependency_type eq 'first') {
                    $task->add_depended_on_by($other);
                }
                else {
                    $other->add_depended_on_by($task);
                }
            }
            else {
                $unfulfilled_dependencies{$dependency_on} = [
                    $dependency_type, $task
                ];
            }
        }

        $ready_for_dependency{$dependency_id} = $task;

        push @{ $ret->{ids} }, $task->id;
    }

    for my $id ( keys %ids ) {
        # Not mentioned, complete them
        my $task = BTDT::Model::Task->new();
        $task->load($id);
        next unless $task->current_user_can("update");
        $task->set_complete(1);
        push @{$ret->{completed}}, $task;
        push @{ $ret->{ids} }, $task->id;
    }

    return $ret;
}

1;
