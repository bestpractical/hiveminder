use warnings;
use strict;
use Text::Tags::Parser;

=head1 NAME

BTDT::Model::TaskCollection

=cut

package BTDT::Model::TaskCollection;
use base qw/BTDT::Collection/;

use Number::RecordLocator;
use BTDT::DateTime;

our $LOCATOR = Number::RecordLocator->new();

=head2 implicit_clauses

Set default ordering to complete-ness, most due, highest priority,
then id.  Also, only find tasks I'm the owner of, I'm the requestor of
or that are in groups I'm a member of.

=cut

sub implicit_clauses {
    my $self = shift;
    my $tasks_alias = 'main';

    $self->set_default_order( collection => $self, tasks_alias => $tasks_alias);
    $self->{tokens}    = [];
    $self->{arguments} = [];

    $self->default_limits( collection => $self, tasks_alias => $tasks_alias );
}

=head2 default_limits

Enforces ACLs and limits to type 'task'

=cut

sub default_limits {
    my $self = shift;
    $self->enforce_acls( @_ );
    $self->limit_to_type( @_ );
}

=head2 enforce_acls { collection => undef, tasks_alias => undef}

If the current user of the collection isn't the superuser, limit the collection down to tasks they can see.
(tasks_alias needs to be set to an alias to the 'tasks' table that's already part of your query.

=cut

sub enforce_acls {
    my $self = shift;
    my %args = ( collection => undef, tasks_alias => undef, @_ );

    return if $args{'collection'}->current_user->is_superuser;

    my $user = $args{'collection'}->current_user->user_object;
    my $groups = $user ? $user->cached_group_ids : [];
    $args{'collection'}->limit(
        subclause        => 'my_tasks_acl',
        alias            => $args{'tasks_alias'},
        column           => 'group_id',
        operator         => 'IN',
        case_sensitive   => 1,
        value            => $groups,
        entry_aggregator => 'or'
    ) if @{$groups};
    $args{'collection'}->limit(
        subclause        => 'my_tasks_acl',
        alias  => $args{'tasks_alias'},
        column           => 'owner_id',
        value            => $args{'collection'}->current_user->id,
        entry_aggregator => 'or'
    );
    $args{'collection'}->open_paren('my_tasks_acl');
    $args{'collection'}->limit(
        subclause        => 'my_tasks_acl',
        alias  => $args{'tasks_alias'},
        column           => 'requestor_id',
        value            => $args{'collection'}->current_user->id,
        entry_aggregator => 'or'
    );

    $args{'collection'}->limit(
        subclause        => 'my_tasks_acl',
        alias  => $args{'tasks_alias'},
        column           => 'group_id',
        operator         => 'IS',
        value            => 'NULL',
        entry_aggregator => 'and'
    );
    $args{'collection'}->close_paren('my_tasks_acl');

    # We've added a bunch of criteria but they're not real.  We should
    # stop searches from working until the user does something real.
    $args{'collection'}->_is_limited(0);

    # We don't need to acl-check anything when we go to add these records
    $args{'collection'}->results_are_readable(1);
}

=head2 limit_to_type { collection => ..., tasks_alias => ... }

Limit this collection to normal tasks (by default)

=cut

sub limit_to_type {
    my $self = shift;
    my %args = (
        collection  => undef,
        tasks_alias => undef,
        type        => 'task',
        @_
    );

    $args{'collection'}->limit(
        alias  => $args{'tasks_alias'},
        column => 'type',
        value  => $args{'type'},
        case_sensitive => 1
    );
}

=head2 set_default_order  { collection => undef, tasks_alias => undef}

Sets a default ordering for this collection: by complete, then due, then priority, then id

=cut

sub set_default_order {
        my $self = shift;
        my %args = ( collection => undef, tasks_alias => undef, @_);


    $args{'collection'}->order_by(
        { alias => $args{'tasks_alias'}, column => 'complete', order => 'ASC' },
        { alias => $args{'tasks_alias'}, column => 'due',      order => 'ASC' },
        { alias => $args{'tasks_alias'}, column => 'priority', order => 'DESC' },
        { alias => $args{'tasks_alias'}, column => 'id',       order => 'ASC' },
        )
        unless $args{'collection'}->{order_by};

}

=head2 tokens

Returns the tokens that the collection was specified with, if it was
limited using L</from_tokens>.  Note that there may be other limits
that were not imposed by tokens.

=cut

sub tokens {
    my $self = shift;
    Carp::confess("$self tokens called with args. you want from_tokens") if (@_);
    return @{ $self->{tokens} };
}

=head2 arguments

Returns the list of arguments, determined by token processing.

=cut

sub arguments {
    my $self = shift;
    return @{ $self->{arguments} };
}

=head2 group GROUP_ID

Limit tasks to group GROUP_ID

=cut

sub group {
    my $self  = shift;
    my $group = shift;
    $self->limit( column => 'group_id', operator => '=', value => $group );
}

=head2 incomplete

Show only incomplete tasks.

=cut

sub incomplete {
    my $self = shift;
    $self->limit(
        column   => 'complete',
        value    => 0
    );
}

=head2 complete

Show only complete tasks.

=cut

sub complete {
    my $self = shift;
    $self->limit( column => 'complete', value => 1 );
}

=head2 will_complete

Show only tasks that will be completed.

=cut

sub will_complete {
    my $self = shift;
    $self->limit( column => 'will_complete', value => 1 );
}

=head2 will_never_complete

Show only tasks that will never be completed.

=cut

sub will_never_complete {
    my $self = shift;
    $self->limit( column => 'will_complete', value => 0 );
}

=head2 depended_on_by ID

Limits this result set to all tasks which task ID depends on.

=cut

sub depended_on_by {
    my $self = shift;
    my $id   = shift;
    my $alias = shift;
    unless ( $self->{'depended_on_by_alias'} ) {
        $self->{'depended_on_by_alias'}
            = $self->new_alias( BTDT::Model::TaskDependency->table() );
        $self->join(
            alias1  => $alias || 'main',
            column1 => 'id',
            alias2  => $self->{'depended_on_by_alias'},
            column2 => 'depends_on'
        );
    }
    $self->limit(
        alias  => $self->{depended_on_by_alias},
        column => 'task_id',
        value  => $id
    );

    return $self;
}

=head2 depend_on ID

Limits this result set to all tasks which depend on task ID

=cut

sub depend_on {
    my $self = shift;
    my $id   = shift;
    my $alias = shift;
    unless ( $self->{'depends_on_alias'} ) {
        $self->{'depends_on_alias'}
            = $self->new_alias( BTDT::Model::TaskDependency->table );
        $self->join(
            alias1  => $alias || 'main',
            column1 => 'id',
            alias2  => $self->{'depends_on_alias'},
            column2 => 'task_id'
        );
    }
    $self->limit(
        alias  => $self->{depends_on_alias},
        column => 'depends_on',
        value  => $id
    );

    return $self;
}

=head2 for_owner ID

Limit tasks to owner ID

=cut

sub for_owner {
    my $self = shift;
    my $id   = shift;
    $self->limit( column => 'owner_id', operator => '=', value => $id );
}

=head2 for_person ID [ALIAS]

Limit tasks to those with an owner or requestor of ID

=cut

sub for_person {
    my $self  = shift;
    my $id    = shift;
    my $alias = shift || 'main';

    # Limit to owners and requestors to ID
    $self->open_paren('owner_or_requestor');
    $self->limit(
        alias       => $alias,
        column      => 'owner_id',
        value       => $id,
        subclause   => 'owner_or_requestor',
    );
    $self->limit(
        alias       => $alias,
        column      => 'requestor_id',
        value       => $id,
        subclause   => 'owner_or_requestor',
        entry_aggregator => 'OR',
    );
    $self->close_paren('owner_or_requestor');
}

=head2 sort_by ALIAS FIELDNAME [ORDER]

Sorts the collection by FIELDNAME (used by L<search>), with optional
ORDER.  Defaults to ascending, except for created, completed_at,
and priority which default to descending.

=cut

sub sort_by {
    my $self  = shift;
    my $alias = shift;
    my $field = shift;
    my $order = shift;

    if ( not $order ) {
        $order = ( $field =~ /^(?:created|completed_at|priority)$/io
                        ? 'desc' : 'asc' );
    }

    if ($field eq "owner" or $field eq "requestor") {
        my $owner = $self->join(
            alias1  => $alias,
            column1 => $field.'_id',
            table2  => 'users',
            column2 => 'id',
            is_distinct => 1,
        );
        my $nobody = BTDT::CurrentUser->nobody->id;
        $self->order_by(
            {
                function => qq{$owner.id = $nobody},
                order    => 'desc',
            },
            {
                alias   => $owner,
                column  => 'name',
                order   => 'asc',
                display => $self->sort_display($field),
            },
            @{ $self->order_by }
        );
    }
    elsif ( $field eq 'project' or $field eq 'milestone' ) {
        my $task_alias = $self->join(
            type    => 'left',
            alias1  => $alias,
            column1 => $field,
            table2  => 'tasks',
            column2 => 'id',
            is_distinct => 1,
        );
        $self->order_by(
            {
                function => qq{$alias.$field = NULL},
                order    => 'desc',
            },
            {
                alias   => $task_alias,
                column  => 'summary',
                order   => 'asc',
                display => $self->sort_display($field),
            },
            @{ $self->order_by }
        );
    }
    elsif ( $field eq 'progress' ) {
        $self->order_by(
            {
                function => qq{$alias.complete is true},
                order    => 'asc',
            },
            {
                function => qq{$alias.time_worked = 0},
                order    => 'asc',
            },
            {
                alias   => $alias,
                column  => 'time_worked',
                order   => 'desc',
                display => $self->sort_display($field),
            },
            @{ $self->order_by }
        );
    } else {
        $self->order_by(
            {
                alias   => $alias,
                column  => $field,
                order   => $order,
                display => $self->sort_display($field),
            },
            @{ $self->order_by }
        );
    }
}

=head2 sort_display FIELDNAME

For a given C<FIELDNAME>, returns an anonymous subroutine or C<undef>.
The subroutine, when passed a L<BTDT::Model::Task>, returns the
C<FIELDNAME>'s value for that task, suitable for display.  This is
meant primarily to generate the headers used when grouping tasks
during sorting.

=cut

sub sort_display {
    my $self = shift;
    my ($field) = @_;

    if ($field eq "priority") {
        return sub {shift->text_priority};
    } elsif ($field eq "due" ) {
        return sub {$_[0]->due ? $_[0]->due->ymd : "No due date"};
    } elsif ($field eq "completed_at") {
        return sub {$_[0]->complete ? $_[0]->completed_at->ymd : "Not done yet"};
    } elsif ($field eq "starts") {
        return sub {$_[0]->starts ? $_[0]->starts->ymd : "No start date"};
    } elsif ($field eq "created") {
        return sub {$_[0]->created->ymd};
    } elsif ($field eq "owner" or $field eq "requestor") {
        return sub {shift->$field->name};
    } elsif ( $field eq 'project' or $field eq 'milestone' ) {
        return sub { $_[0]->$field->id ? $_[0]->$field->summary : "No $field" };
    } elsif ( $field eq 'progress' ) {
        return sub {
            return            $_[0]->complete ? "Complete"    :
                   $_[0]->time_worked_seconds ? "In Progress" :
                                                "Unstarted"   ;
        };
    } else {
        return undef;
    }
}

=head2 search $alias_name PARAMHASH

Takes a parameter hash of possible parts of the task to search, and
applies the relevant limits, calling either L</limit> or a handcoded limit
statement.


Possible keys of the paramhash are below; any of them may have C<_not>
appended to them to negate it.  Keys may be specified multiple times
to further limit the search.

=over

=item $alias_name

The name of the table alias we want to search on. You probably want main.

=item owner

The value should be an email address, or the string C<anyone>.

=item requestor

The value should be an email address, or the string C<anyone>.

=item next_action_by

The value should be an email address, or the string C<anyone>.

=item group

The value should be the group id, or the string C<personal>.

=item summary

This value is matched as a substring match against the full summary.

=item description

This value is matched as a substring match against the full
description.

=item complete

The value is ignored; the task is required to have been completed.

=item tag

The value is required to be present on a tag on the task

=item due

The due date of the task is required to be the value provided.  The
alternate versions C<due_before> and C<due_after> also exist, and do
what you would expect.

=item starts

Works just like due

=item created

Works just like due

=item completed_at

Works just like due

=item priority

The priority of the task is required to be the value provided.  The
alternate versions C<priority_above> and C<priority_below> also exist,
and do what you would expect.

=item depends_on

The task must depend on (Have a ``but first ...'' task) with the given
ID. If ``none'' is the value, must have no dependencies.

=item depended_on_by

The task must be depended on by (Have a ``and then ...'' task) with
the given ID. If ``none'' is the value, must have no tasks depending
on it.

=item has_attachment

The task must have at least one attachment. The value is ignored. This
is a no-op if the user is not pro, since non-pro users cannot see
attachments.

=item has_attachment_not

The task must have no attachments. The value is ignored. This is a no-op
if the user is not pro, since non-pro users cannot see attachments.

=back

=cut

sub search {
    my $self = shift;

    my $table_alias = shift;

    my @args = @_;




    my %translate = (
        before => "<",
        after  => ">",
        below  => "<=",    # these 2 are used only by priority, where
        above  => ">=",    # we want an inclusive search.
        ''     => '',
        not    => "not",
        lt     => '<',
        gt     => '>',
        lte    => '<=',
        gte    => '>=',
    );

    # We can't actaully smash this into a hash because keys might be repeated
    while ( my ( $key, $value ) = splice( @args, 0, 2 ) ) {

        # XXX Cargo cult XXX
        my $property = $key;
        my $cmp      = '';

        if ( $property =~ /^sort_by$/ and $value ) {
            $self->sort_by( $table_alias, $value );
            next;
        }
        elsif ( $property =~ /^sort_by_tags$/ ) {
            my @tags = map {
                my $tag = Jifty->handle->dbh->quote($_);
                $tag =~ s/^'(.*)'$/$1/o;
                {
                    function => qq{$table_alias.tags LIKE '%"$tag"%'},
                    order    => 'desc'
                }
            } Text::Tags::Parser->new->parse_tags($value);
            $self->order_by(
                { function => $table_alias.'.tags IS NOT NULL', order => 'asc' },
                @tags, @{ $self->order_by } );
            next;
        }

        if ( $key =~ /^(.*)_(above|below|before|after|not|!=|=|>|<|lte?|gte?)$/ ) {
            $property = $1;
            $cmp      = $2;
        }

        my @extra;

        my $case_sensitive = 1;
        if ( $property eq 'q' or $property eq 'query' ) {
            $self->smart_search(
                $value,
                alias  => $table_alias,
                negate => ( $cmp eq 'not' ? 1 : 0 ),
            );
            next;
        }
        elsif ( $property eq "group" ) {
            $property = "group_id";
            if ( $value eq "personal" or $value eq '0' ) {
                $cmp = $cmp ? "IS NOT" : "IS";
                $value = "NULL";
            }
            elsif ( $value =~ /^\d+$/ ) {

                # Nothing
            }
            else {
                my $group = BTDT::Model::Group->new();
                $group->load_by_cols( name => $value );
                $value = $group->id;
                next unless $value;
            }

            # Groups should be OR'd in searches
            push @extra, entry_aggregator => 'OR';

            # XXX TODO We need to deal with the case where group_id !=
            # 42 means group_id can be null
        }
        elsif ( $property eq "owner"
             or $property eq "requestor"
             or $property eq "next_action_by" ) {

            if ($property ne 'next_action_by') {
                $property .= "_id";
            }

            if ( lc $value eq "me" ) {
                $value = $self->current_user->id;
            }
            elsif ( lc $value eq "anyone" ) {

                # not undef
                $cmp = $cmp ? "IS" : "IS NOT";
                $value = "NULL";
            }
            elsif ( lc $value eq "nobody" ) {
                $value = BTDT::CurrentUser->nobody->id;
            }
            elsif ( $value =~ /\@/ ) {
                my $user = BTDT::Model::User->new();
                $user->load_by_cols( email => $value );
                $value = $user->id;    # What if they don't exist?
            }
            else {
                next;
            }
        }
        elsif ( $property eq 'person' ) {
            if ( lc $value eq "me" ) {
                $value = $self->current_user->id;
            }
            elsif ( lc $value eq "nobody" ) {
                $value = BTDT::CurrentUser->nobody->id;
            }
            elsif ( $value =~ /\@/ ) {
                my $user = BTDT::Model::User->new();
                $user->load_by_cols( email => $value );
                $value = $user->id;    # What if they don't exist?
            }
            else {
                next;
            }

            $self->for_person( $value, $table_alias );
            next;
        }
        elsif ( $property =~ /^(summary|description)$/ ) {
            $case_sensitive = 0;
            $cmp            = $cmp ? "NOT LIKE" : "LIKE";
            $value          = '%' . $value . '%';
        }
        elsif ( $property =~ /^(complete|accepted|will_complete)$/ ) {
            push @extra, entry_aggregator => 'OR';

            # postgres complains if you have a weird boolean value. this
            # wants to be fixed at the Jifty::DBI level :(
            $value = $value ? 1 : 0;
        }
        elsif ( $self->current_user->pro_account && $property eq "has_attachment") {
            $property = "attachment_count";

            if ($cmp eq "not") {
                $cmp = '=';
            }
            else {
                $cmp = '>';
            }

            $value = 0;
            push @extra, entry_aggregator => 'OR';
        }
        elsif ($property eq "id") {
            push @extra, entry_aggregator => 'OR';
            # nothing special
        }
        elsif ( $property eq "unaccepted" ) {
            push @extra, entry_aggregator => 'OR', quote_value => 0;
            $property = "accepted";
            $cmp      = "IS";
            $value    = "NULL";
        }
        elsif ( $property eq "tag" ) {
            my $parser = Text::Tags::Parser->new;
            if ( length $value ) {
                for ( $parser->parse_tags($value) ) {
                    my $tag = $parser->join_quoted_tags($_);
                    $self->limit(
                        alias            => $table_alias,
                        column           => "tags",
                        operator         => $cmp ? "NOT LIKE" : "LIKE",
                        value            => '%' . $tag . '%',
                        entry_aggregator => "AND"
                        , # Always search for tags by union $cmp ? "AND" : "OR",
                        subclause => $cmp ? "tag_not" : "tag_is",
                    );
                }
            }
            else {
                $self->limit( alias => $table_alias, column => 'tags', operator => $cmp ? '!=' : '=', value => '')
            }
            next;
        }
        elsif ( $property =~ /^(?:starts|due|created|completed_at)$/i ) {
            $cmp = $translate{$cmp};
            push @extra,
              entry_aggregator => 'OR',
              subclause        => Jifty->web->serial;

        # Things that are due after $DATE include nondue things
        # Things that start before $DATE include tungs with no startsafter date.
            if (   ( $cmp eq '>' and $property eq 'due' )
                or ( $cmp eq '<' and $property eq 'starts' ) )
            {
                $self->limit(
                    alias          => $table_alias,
                    column         => $property,
                    operator       => 'IS',
                    value          => 'NULL',
                    case_sensitive => $case_sensitive,
                    @extra
                );
            }

            if ( $value eq "anytime" ) {
                $cmp = $cmp ? "IS" : "IS NOT";
                $value = "NULL";
            }
            else {
                my $dt = BTDT::DateTime->intuit_date_explicit($value);

                # These properties are special because they are datetimes
                # not dates. We should have a separate intuit method that
                # includes time.
                if ($property eq 'created' || $property eq 'completed_at') {
                    if ($dt) {
                        # Interpret input as user's time zone...
                        $dt->set_current_user_timezone;

                        # ... but we search based on server time
                        $dt->set_time_zone('UTC');

                        $value = $dt->datetime;
                    }
                    else {
                        $value = undef;
                    }
                }
                else {
                    $value = $dt ? $dt->ymd : undef;
                }
            }
        }
        elsif ( $property eq "priority" ) {
            $cmp = $translate{$cmp};
        }
        elsif ( $property eq 'but_first' ) {
            if ( lc $value =~ 'something' ) {
                $property = 'depends_on_count';
                $cmp      = $cmp eq 'not' ? '' : 'not';
                $value    = '0';
            } elsif ( lc $value eq 'nothing' ) {
                $property = 'depends_on_count';
                $value    = '0';
            } else {
                $value =~ s/^#//;
                $value = $LOCATOR->decode($value);
                $self->depend_on($value, $table_alias);
                next;
            }
        }
        elsif ( $property eq 'and_then' ) {
            if ( lc $value eq 'something' ) {
                $property = 'depended_on_by_count';
                $cmp      = $cmp eq 'not' ? '' : 'not';
                $value    = '0';
            } elsif ( lc $value eq 'nothing' ) {
                $property = 'depended_on_by_count';
                $value    = '0';
            } else {
                $value =~ s/^#//;
                $value = $LOCATOR->decode($value);
                $self->depended_on_by($value, $table_alias);
                next;
            }
        }
        elsif ( $property eq 'depends_on' ) {
            $self->depend_on($value, $table_alias);
            next;
        }
        elsif ( $property eq 'depended_on_by' ) {
            $self->depended_on_by($value, $table_alias);
            next;
        }
        elsif ( $property =~ /^time_(?:left|worked|estimate)$/i ) {
            next unless $self->current_user->has_feature('TimeTracking');

            $cmp = $translate{$cmp};
            push @extra,
              entry_aggregator => 'OR',
              subclause        => Jifty->web->serial;

            if ( $value =~ /^(?:none|null)/i ) {
                $cmp = $cmp ? "IS NOT" : "IS";
                $value = "NULL";

                # Treat null/none as 0 too
                $self->limit(
                    alias          => $table_alias,
                    column         => $property,
                    operator       => '=',
                    value          => '0',
                    @extra
                );
            }
            else {
                my $canonicalizer = "canonicalize_$property";
                my $validator     = "validate_$property";
                $value = BTDT::Model::Task->$canonicalizer($value);
                $value = BTDT::Model::Task->$validator($value)
                            ? BTDT::Model::Task->duration_in_seconds($value)
                            : undef;
            }

            # Times less than (or lte) $TIME where $VALUE = 0 include NULL
            # Times where $TIME = 0 include NULL
            if ( ( $cmp =~ /</ and not $value ) or
                 ( not $cmp    and not $value )    )
            {
                $self->limit(
                    alias          => $table_alias,
                    column         => $property,
                    operator       => 'IS',
                    value          => 'NULL',
                    case_sensitive => $case_sensitive,
                    @extra
                );
            }
        }
        elsif ( $property =~ /^(?:project|milestone)$/ ) {
            if ( lc $value eq 'none' ) {
                $cmp   = 'IS';
                $value = 'NULL';
            } else {
                $value =~ s/^#//;
                $value = $LOCATOR->decode( $value );
            }
        } elsif ($property eq "ever_in_milestone") {
            # We join to task_transactions to find tasks that had any
            # time worked in this project or milestone
            $value =~ s/^#//;
            $value = $LOCATOR->decode( $value );
            unless ($self->{old_txns}) {
                $self->{old_txns} = $self->join(
                    alias1 => $table_alias,
                    column1 => "id",
                    table2 => "task_transactions",
                    column2 => "task_id",
                    type => "left",
                ); # Sadly, this forces a DISTINCT
                $self->limit(
                    alias => $self->{old_txns},
                    column => "time_worked",
                    operator => ">",
                    value => "0",
                    entry_aggregator => "OR",
                    subclause => "worked_deps",
                );
            }
            $self->limit(
                leftjoin => $self->{old_txns},
                column => "milestone",
                value => $value,
                entry_aggregator => 'OR',
            );
            push @extra,
                subclause => "worked_deps",
                entry_aggregator => 'OR';
        }
        elsif ( $property !~ /^(?:depended_on_by_count|depends_on_count|repeat_period|repeat_of)$/ ) {
            # Move along if we haven't processed the property yet and its
            # not one of the above
            next;
        }
        $cmp = "!=" if defined $cmp and $cmp eq "not";
        $cmp = "=" unless $cmp;

        $self->limit(
            alias            => $table_alias,
            column           => $property,
            operator         => $cmp,
            value            => $value,
            case_sensitive   => $case_sensitive,
            entry_aggregator => 'AND',
            @extra
        );
    }
}

=head2 from_tokens [TOKEN, [TOKEN, [...]]]

Takes a list of C<TOKEN>s, and converts it into a PARAMHASH suitible for
passing to L</search>.  It calls L</search> with those arguments, in
addition to returning them.  C<TOKEN>s are parsed into phrases, as follows:

=over

=item * Any item may be preceded by C<not>

=item * The property, which is one of:

owner, requestor, group, summary, description, tag, starts, due,
complete, accepted, unaccepted, priority, depended_on_by, depends_on

=item * The C<due> and C<starts> properties are optionally followed by
either C<before> or C<after>

=item * The C<priority> property is optionally followed by either
C<above> or C<below>

=item * The C<depended_on_by> and C<depends_on> properties are followed by
the id of a task that all found results block or are blocked by
respectively.

=item * Any property which is not C<complete>, C<accepted>, or
C<unaccepted> is followed by the value that the property must have



=back

=cut

sub from_tokens {
    my $self   = shift;
    my @tokens = (@_);
    push @{ $self->{tokens} }, @tokens;

    my @args = $self->scrub_tokens(@tokens);
    $self->search('main',@args);
    $self->{arguments} = \@args;
    return @args;
}

=head2 scrub_tokens @TOKEN_LIST

Takes a list of token strings, possibly suggested by an end user, cleans and canonicalizes them
and returns the cleaned form;


=cut

sub scrub_tokens {
    my $self   = shift;
    my @tokens = (@_);

    my $pro = $self->current_user->user_object->pro_account;

    my @args;
    while (@tokens) {
        my ( $property, $cmp, $value );
        $property = lc shift @tokens;

        # anything can be prefixed with "not"
        if ( $property eq "not" ) {
            $cmp = "not";
            return unless @tokens;
            $property = lc shift @tokens;
        }

        # boolean
        # before 2006-11-28, "unaccepted" was called pending.
        if ( $property eq 'pending' ) { $property = 'unaccepted' }

        if ( $property eq 'completed' ) {
            $property = 'completed_at';
            if ( $tokens[0] eq 'at' ) { shift @tokens }
        }
        if (   $property eq 'next'
            && $tokens[0] eq 'action'
            && $tokens[1] eq 'by' )
        {
            $property = 'next_action_by';
            splice @tokens, 0, 2;
        }

        if (   $property eq 'will'
            && $tokens[0] eq 'never'
            && $tokens[1] eq 'complete' )
        {
            $property = 'will_complete';
            $cmp      = 'not';
            splice @tokens, 0, 2;
        }

        if ( $property eq 'will' && $tokens[0] eq 'complete' ) {
            $property = 'will_complete';
            splice @tokens, 0, 1;
        }

        if ( $property eq 'hidden' && $tokens[0] eq 'forever' ) {
            $property = 'will_complete';
            $cmp      = (not defined $cmp) ? 'not' : undef;
            splice @tokens, 0, 1;
        }

        if ( $property =~ /^(?:hidden|hide)$/ && $tokens[0] eq 'until' ) {
            $property = 'starts';
            splice @tokens, 0, 1;
        }

        if ( $property =~ /^(?:hidden|hide)_until$/ ) {
            $property = 'starts';
        }

        if (     $property  eq 'time'
             and $tokens[0] =~ /^(left|worked|estimated?)$/ )
        {
            my $field = $1;
               $field =~ s/estimated/estimate/;
            $property = "time_$field";
            splice @tokens, 0, 1;
        }

        if ( $property eq 'but' && $tokens[0] eq 'first' ) {
            $property = 'but_first';
            splice @tokens, 0, 1;
        }

        if ( $property eq 'and' && $tokens[0] eq 'then' ) {
            $property = 'and_then';
            splice @tokens, 0, 1;
        }

        # Options that do not really take a value
        if ( $property =~ /^(complete|accepted|unaccepted|will_complete)$/ ) {
            $value = 1;
        } elsif ( $property eq 'untagged' ) {
            $property = 'tag', $value = '';
        } elsif ($property eq 'has' && $tokens[0] eq 'attachment') {
            splice @tokens, 0, 1;
            next if !$pro;
            $property = 'has_attachment';
            $value = 1;
        } elsif ($property eq 'has' && $tokens[0] eq 'no' && $tokens[1] eq 'attachments') {
            splice @tokens, 0, 2;
            next if !$pro;
            $property = 'has_attachment';
            $cmp = "not";
            $value = 1;

        # Options that take a value
        } else {

            # Pro users get some extra tokens
            next if $property eq 'next_action_by'
                 && !$pro;

            if ($property =~ /^(id|
                                owner|requestor|next_action_by|person|
                                group|
                                summary|description|tag|
                                due|starts|created|completed_at|
                                depended_on_by|depends_on|
                                but_first|and_then|
                                priority|
                                has_attachment|
                                repeat_of|repeat_next_create|repeat_period|
                                time_(?:left|worked|estimate)|
                                sort_by|sort_by_tags|
                                project|milestone|
                                q(?:uery)?
                                )$/x) {
                return unless @tokens;
                $value = shift @tokens;
            }
            else {
                # not a valid property. assume the previous property had a
                # multi-word value. this is important for things like:
                # "due before next week not complete"
                # which without this will be incorrectly parsed as
                # "due before next / week not / complete"

                # no previous property, so skip this token
                next unless @args;

                $args[-1] .= ' ' . $property;
                next;
            }
        }

        if ( $property eq 'id' ) {

            # Decode the record locator to a numeric ID
            $value = $LOCATOR->decode($value);
        }

        if ( $property eq 'depends_on' ) {
            $property = 'but_first';
            # Encode the ID as a locator
            $value = $LOCATOR->encode($value);
        }

        if ( $property eq 'depended_on_by' ) {
            $property = 'and_then';
            # Encode the ID as a locator
            $value = $LOCATOR->encode($value);
        }

        # A couple options take optional comparison arguments
        if ((   $property
                =~ /^(?:due|starts|created|completed_at|repeat_next_create)$/
                and $value =~ /^(before|after)$/i
            )
            or ( $property eq "priority" and $value =~ /^(above|below)$/i )
            or (     $property =~ /^time_(?:left|estimate|worked)$/
                 and $value =~ /^(?:lt|gt)e?$/ )
            )
        {
            my %swap = ( above => "below", before => "after", 'lt' => 'gte', 'gt' => 'lte' );
            %swap = ( %swap, reverse %swap );
            $cmp = $cmp ? $swap{ lc $value } : lc $value;
            return unless @tokens;
            $value = shift @tokens;
        }

        # Stuff it into the arguments
        my $api_name = $property;
        $api_name .= "_$cmp" if $cmp;

        push @args, $api_name => $value;
    }

    # 'complete' and 'not complete' both imply 'will complete'
    # unless explicitly specified
    if ( grep {/complete(?:_not)?/} @args
        and not grep {/will_complete/} @args )
    {
        push @args, will_complete => 1;
    }

    return @args;
}

=head2 all_defaults

Return a hash of array references for a tasklist. Can be used to inspect, for
example, which groups are represented in a tasklist.

=cut

sub all_defaults {
    my $self = shift;

    my %task;
    my @tags;

    my @args = $self->arguments;
    while ( my ( $key, $value ) = splice( @args, 0, 2 ) ) {
        my $property = $key;
        my $cmp      = '';

# XXX TODO: hackish way to deal with properties containing _ that we don't want to split
        unless ( $property =~ /^(?:depended_on_by|depends_on|created_at|but_first|and_then)$/ ) {
            ( $property, $cmp ) = ( split( '_', $key ), '' );
        }
        if ( $property eq "tag" ) {
            $property = "tags";
        }

        # Since they can't set requestor, only set owner
        if ( $property eq 'person' ) {
            $property = 'owner';
        }
        if ( $property =~ /^(owner|requestor|next_action_by|group)$/ ) {
            $property = $property . "_id";
        }

        # Decode the locators of the project and milestone tokens
        if ( $property =~ /^(?:project|milestone)$/ ) {
            if ( lc $value ne 'none' ) {
                $value =~ s/^#//;
                $value = $LOCATOR->decode($value);
            } else {
                next;
            }
        }

        # We use depends_on and depended_on_by a lot in the code.  It easier to
        # translate but_first and and_then back to them for new defaults.
        if ( $property eq 'but_first' and $value !~ /^(?:no|some)thing$/i ) {
            $property = 'depends_on';
            $value =~ s/^#//;
            $value = $LOCATOR->decode($value);
        }

        if ( $property eq 'and_then' and $value !~ /^(?:no|some)thing$/i ) {
            $property = 'depended_on_by';
            $value =~ s/^#//;
            $value = $LOCATOR->decode($value);
        }

# Skip anything we don't recognize. Really, this should be looking at arguments on the createtask action.
        next
            unless ( $self->new_item->column($property)
            or ( $property =~ /^(?:depended_on_by|depends_on)$/ ) );

        if ( $cmp eq "not" ) {
            if ( $self->new_item->column($property)->type eq "boolean" ) {
                $value = $value ? 0 : 1;
            } else {
                next;
            }
        } elsif ( $cmp eq 'before' ) {
            my $dt = BTDT::DateTime->intuit_date_explicit($value);
            $value = $dt ? $dt->subtract( days => 1 )->ymd : undef;
        } elsif ( $cmp eq 'after' ) {
            my $dt = BTDT::DateTime->intuit_date_explicit($value);
            $value = $dt ? $dt->add( days => 1 )->ymd : undef;
        } elsif ( $cmp eq 'above' || $cmp eq 'below' ) {
            # these are inclusive, so we don't need to munge $value
        } elsif ( $cmp eq '' ) {
            if($property =~ /^(owner|requestor|next_action_by)_id$/) {
                $value = $self->current_user->user_object->email
                if $value eq "me" || $value eq "anyone";
            }
        } else {
            next;
        }

        if ($property eq 'tags') {
            push @tags, $value;
        }
        else {
            push @{ $task{$property} }, $value;
        }
    }

    $task{tags} = join(" ", @tags) if @tags;
    return %task;
}


=head2 new_defaults

Returns a list of default values for a new item, based on the search.

=cut

sub new_defaults {
    my $self = shift;
    my %defaults = $self->all_defaults(@_);

    for (values(%defaults)) {
        $_ = $_->[-1] if ref($_) eq 'ARRAY';
    }

    return %defaults;
}

=head2 create_from_defaults MONIKER

Creates and returns a new L<BTDT::Action::CreateTask> action with
defaults based on the search tokens.

=cut

sub create_from_defaults {
    my $self = shift;
    my ($moniker) = @_;

    my %defaults = $self->new_defaults;

    my $action = Jifty->web->form->add_action(
        class     => 'CreateTask',
        moniker   => $moniker,
        arguments => \%defaults,
    );

    return $action;
}

=head2 smart_search QUERY [PARAMHASH]

This method tasks a set of space-separated search terms as a single
scalar argument and looks up tasks containing any of them in the summary,
description, tags, or record locator.

The second optional argument is a paramhash of C<alias> and/or C<negate>
arguments.  Negate determines whether the matches should be negated, that is,
whether it find tasks that do NOT match the search terms.  Defaults to false
(finding the tasks the match).

=cut

sub smart_search {
    my $self  = shift;
    my $query = shift;
    my %args  = (
        negate => 0,
        alias  => 'main',
        @_
    );

    my $operator   = $args{'negate'} ? 'not matches' : 'matches';
    my $aggregator = $args{'negate'} ? 'and'         : 'or';

    # XXX TODO HACK THIS SHOULD BE URI UNESCAPED
    $query =~ s/%20/ /g;
    my @terms = split( /\s+/, $query );
    foreach my $term (@terms) {
        $self->limit(
            alias            => $args{'alias'},
            subclause        => 'smart-' . $term,
            column           => 'summary',
            entry_aggregator => $aggregator,
            value            => $term,
            operator         => $operator
        );
        $self->limit(
            alias            => $args{'alias'},
            subclause        => 'smart-' . $term,
            column           => 'description',
            entry_aggregator => $aggregator,
            value            => $term,
            operator         => $operator
        );
        $self->limit(
            alias            => $args{'alias'},
            subclause        => 'smart-' . $term,
            column           => "tags",
            entry_aggregator => $aggregator,
            value            => Text::Tags::Parser->new->join_quoted_tags($term),
            operator         => $operator
        );

        # It's not pretty, but it works for searching by record locator.
        (my $locator = $term) =~ s/^#//;
        if (length $locator <= 7) {
            my $id = $LOCATOR->decode($locator);
            # Postgres caps out 'integer's at 2**31 - 1
            if ( defined $id and "$id" !~ /\D/ and $id <= (2**31 - 1) ) {
                $self->limit(
                    alias            => $args{'alias'},
                    subclause        => 'smart-' . $term,
                    column           => "id",
                    entry_aggregator => $aggregator,
                    value            => $id,
                    operator         => ($args{'negate'} ? '!=' : '=')
                );
            }
        }
    }
}

=head2 recent

Returns recently modified tasks (within the past week)

=cut

sub recent {
    my $self = shift;

    my $txns_alias = $self->join(
        alias1  => 'main',
        column1 => 'id',
        table2  => 'task_transactions',
        column2 => 'task_id'
    );
    $self->limit(
        subclause        => 'me',
        column           => 'owner_id',
        value            => Jifty->web->current_user->id,
        entry_aggregator => 'or'
    );
    $self->limit(
        subclause        => 'me',
        column           => 'requestor_id',
        value            => Jifty->web->current_user->id,
        entry_aggregator => 'or'
    );
    $self->limit(
        alias    => $txns_alias,
        column   => 'modified_at',
        operator => '>',
        value    => BTDT::DateTime->now(time_zone => 'UTC')->subtract( days => 7 ),
    );

    $self->group_by( column => 'id', );
    $self->order_by( { column => 'id', order => 'DESC' }, );

    return $self;
}

=head2 distinct_required

Returns false, since we currently don't do any joins on task collections
that need a distinctification. Some day that will change and this will bite us.

=cut

sub distinct_required {
    return undef;

}

=head2 join_tokens TOKENS

Joins a list of tokens into a single string suitable for passing,
e.g. as an argument to a page region. Round-trips with
L</split_tokens>

=cut

sub join_tokens {
    my $self_or_class = shift;
    my @tokens = @_;

    return join(' ', map {URI::Escape::uri_escape_utf8 $_} @tokens);
}

=head2 join_tokens_url TOKENS

Joins a list of tokens into a string suitable for embedding in a URL,
for, e.g. search paths. Round-trips with L</split_tokens_url>.

We intentionally double-encode, as the webserver helpfully unencodes
once for us before we ever see it.

We also encode C<"> as C<%22> manually since L<URI::Escape> stopped doing
it for us, since doing so is technically not to the RFC 3986 spec. But
escaping C<"> makes our lives simpler when we invariably put the URL in
an HTML attribute, and escaping a little too liberally doesn't harm things.

=cut

sub join_tokens_url {
    my $self_or_class = shift;
    my @tokens = @_;

    return join('/', map {
        my $escaped = URI::Escape::uri_escape_utf8 $_;
        $escaped =~ s/"/%22/g;
        URI::Escape::uri_escape($escaped)
    } @tokens);
}

=head2 split_tokens STRING

Splits a string returned by L</join_tokens> back into a list of tokens

=cut

sub split_tokens {
    my $self_or_class = shift;
    my $tokens = shift;
    return $self_or_class->_split_tokens(' ', $tokens);
}

=head2 split_tokens_url STRING

Splits a string returned by L</join_tokens_url> back into a list of tokens

=cut

sub split_tokens_url {
    my $self_or_class = shift;
    my $tokens = shift;
    return $self_or_class->_split_tokens('/', $tokens);
}

=head2 _split_tokens

Internal helper used by C<split_tokens> and C<split_tokens_url>

=cut

sub _split_tokens {
    my $self_or_class = shift;
    my $sep = shift;
    my $tokens = shift;
    return $tokens unless defined $tokens && length $tokens;
    return grep {defined $_ and /\S/} map {Encode::decode_utf8(URI::Escape::uri_unescape($_))} split $sep, $tokens;
}

=head2 search_url

Returns a URL which will produce a tasklist based on the tokens of this collection.

=cut

sub search_url {
    my $self = shift;
    return '/list/'.$self->join_tokens_url( $self->tokens );
}

=head2 time_tracking_txns

Returns a L<BTDT::Model::TaskTransactionCollection> of transactions
that fit the search criteria, suitible for summing over for time
tracking calculations.

=cut

sub time_tracking_txns {
    my $self = shift;
    my %args = (owner_as_actor => 0, milestone => 0, @_);

    my @args = $self->arguments;
    my (@other, %txns);
    while ( my ( $key, $value ) = splice( @args, 0, 2 ) ) {
        if ($key =~ /^(owner|group|project|milestone)$/) {
            $txns{$1} = $value;
        } else {
            push @other, $key, $value;
        }
    }

    my $txns = BTDT::Model::TaskTransactionCollection->new;
    my $tasks = $txns->join(
        alias1  => 'main',
        column1 => 'task_id',
        table2  => 'tasks',
        column2 => 'id',
        is_distinct => 1,
    );
    $txns->task_search_on( $tasks => arguments => @other );

    if (exists $txns{owner}) {
        my $value = $txns{owner};
        if ( lc $value eq "me" ) {
            $value = $self->current_user->id;
        } elsif ( lc $value eq "nobody" ) {
            $value = BTDT::CurrentUser->nobody->id;
        } elsif ( $value =~ /\@/ ) {
            my $user = BTDT::Model::User->new();
            $user->load_by_cols( email => $value );
            $value = $user->id;    # What if they don't exist?
        } else {
            undef $value;
        }
        $txns->limit( column => ($args{owner_as_actor} ? "created_by" : "owner_id"), value => $value, quote_value => 0 )
            if defined $value;
    }

    if (exists $txns{group}) {
        my $value = $txns{group};
        my $cmp = "=";
        if ( $value eq "personal" or $value eq '0' ) {
            $cmp = "IS";
            $value = "NULL";
        } elsif ( $value =~ /^\d+$/ ) {
            # Nothing
        } else {
            my $group = BTDT::Model::Group->new();
            $group->load_by_cols( name => $value );
            $value = $group->id;
        }
        $txns->limit( column => "group_id", operator => $cmp, value => $value, quote_value => 0)
            if $value;
    }

    for ([before => '<='], [after => '>=']) {
        my ($type, $operator) = @$_;
        next unless exists $args{$type};

        $txns->limit(
            column           => 'modified_at',
            operator         => $operator,
            value            => $args{$type},
            entry_aggregator => 'AND',
        );
    }

    if (exists $txns{project}) {
        my $value = $txns{project};
        $value =~ s/^#//;
        $value = $LOCATOR->decode( $value );
        $txns->limit( column => "project", value => $value, quote_value => 0 )
            if $value;
    }

    $txns->limit( column => "type", value => "update", entry_aggregator => "OR", case_sensitive => 1 );
    if (exists $txns{milestone} or $args{milestone}) {
        $txns->limit( column => "type", value => "milestone", entry_aggregator => "OR", case_sensitive => 1 );
        my $value = $txns{milestone} || "";
        $value =~ s/^#//;
        $value = $LOCATOR->decode( $value );
        $txns->limit( column => "milestone", value => $value, quote_value => 0 )
            if $value;
    } else {
        $txns->limit( column => "type", value => "create", entry_aggregator => "OR", case_sensitive => 1 );
        $txns->limit( column => "type", value => "timetrack", entry_aggregator => "OR", case_sensitive => 1 );
    }

    return $txns;
}

=head2 aggregate_time_tracked

Aggregate the time tracking information of all the tasks in the collection
without bothering to break down time worked by user.

=cut

sub aggregate_time_tracked {
    my $self = shift;
    my %data;

    my %args = $self->arguments;
    if ($args{owner}) {
        # We need two queries -- one for owner as actor, another for owner as owner
        my $owner = $self->time_tracking_txns;
        $owner->column( function => "SUM", column => 'time_estimate' );
        $owner->column( function => 'SUM', column => 'time_left' );
        $owner->order_by({});
        $data{'Estimate'}     = $owner->first->time_estimate || 0;
        $data{'Time left'}    = $owner->first->time_left || 0;

        my $worked = $self->time_tracking_txns(owner_as_actor => 1);
        $worked->column( function => 'SUM', column => 'time_worked' );
        $worked->order_by({});
        $data{'Total worked'} = $worked->first->time_worked || 0;
    } else {
        my $txns = $self->time_tracking_txns;
        $txns->column( function => "SUM", column => 'time_estimate' );
        $txns->column( function => 'SUM', column => 'time_worked' );
        $txns->column( function => 'SUM', column => 'time_left' );
        $txns->order_by({});
        $data{'Estimate'}     = $txns->first->time_estimate || 0;
        $data{'Total worked'} = $txns->first->time_worked || 0;
        $data{'Time left'}    = $txns->first->time_left || 0;
    }

    # Calculate the (mostly useless) diff for compat
    $data{'Diff'} = $data{'Estimate'} - $data{'Total worked'};

    return \%data;
}

=head2 group_time_tracked PARAMHASH

Aggregate the time tracking information of all the tasks in the
collection and group it by some property.  Arguments to the paramhash
include:

=over

=item by

What to group the statistics by.  Possibilities are C<group_id>,
C<project>, C<milestone>, C<owner>, or C<modified_date>; defaults to C<owner>.

=item worked

=item estimate

=item left

Each of these flags controls if the relevant statistic is generated.
All of them default to on.

=item before

=item after

Specifying either or both of these will limit the transactions to a certain
date range.

=back

=cut

sub group_time_tracked {
    my $self = shift;
    my %args =  (
        by => "owner",
        worked => 1,
        estimate => 1,
        left => 1,
        @_,
    );

    my $txns = $self->time_tracking_txns(
        milestone => ($args{by} eq "milestone"),
        $args{before} ? (before => $args{before}) : (),
        $args{after}  ? (after  => $args{after})  : (),
    );

    if ($args{by} eq "owner") {
        $txns->column( column => "created_by" ) if $args{worked};
        $txns->column( column => "owner_id" ) if $args{left} or $args{estimate};
    } elsif ($args{by} eq "modified_date") {
        $txns->column( function => "DATE", column => "modified_at" );
    } else {
        $txns->column( column => ($args{by} eq "group" ? "group_id" : $args{by}) );
    }
    $txns->column( function => 'SUM', column => 'time_worked' ) if $args{worked};
    $txns->column( function => "SUM", column => 'time_estimate' ) if $args{estimate};
    $txns->column( function => 'SUM', column => 'time_left' ) if $args{left};
    $txns->order_by({});

    # Note that we might group by owner as, as well as created_by --
    # time worked is based on the actor (created_by), time left and
    # estimate are based on the owner.
    my @group_by;
    if ($args{by} eq "owner") {
        push @group_by, {column => "created_by"} if $args{worked};
        push @group_by, {column => "owner_id"} if $args{left} or $args{estimate};
        $txns->order_by(@group_by);
    } elsif ($args{by} eq "modified_date") {
        push @group_by, {function => "date(main.modified_at)"};
    } else {
        push @group_by, {column => ($args{by} eq "group" ? "group_id" : $args{by}) };
    }
    $txns->group_by( @group_by );
    $txns->results_are_readable(1);

    my %data;
    while ( my $row = $txns->next ) {
        if ($args{by} eq "owner") {
            $data{"owner"}->{$row->created_by->id}{'object'}   = $row->created_by if $args{worked};
            $data{"owner"}->{$row->owner_id || 0}{'object'}    = $row->owner if $args{left} or $args{estimate};
            $data{"owner"}->{$row->created_by->id}{'worked'}  += $row->time_worked || 0 if $args{worked};
            $data{"owner"}->{$row->owner_id || 0}{'estimate'} += $row->time_estimate || 0 if $args{estimate};
            $data{"owner"}->{$row->owner_id || 0}{'left'}     += $row->time_left || 0 if $args{left};
        } elsif ($args{by} eq "modified_date") {
            my $date = $row->modified_at->ymd;

            $data{"modified"}->{$date}{'worked'}   += $row->time_worked || 0 if $args{worked};
            $data{"modified"}->{$date}{'estimate'} += $row->time_estimate || 0 if $args{estimate};
            $data{"modified"}->{$date}{'left'}     += $row->time_left || 0 if $args{left};
        } else {
            my $method = $args{by};
            my $data_row = ($data{$method}->{$row->$method->id || 0} ||= {});
            $data_row->{object}  = $row->$method;
            $data_row->{worked}   += $row->time_worked || 0 if $args{worked};
            $data_row->{estimate} += $row->time_estimate || 0 if $args{estimate};
            $data_row->{left}     += $row->time_left || 0 if $args{left};
        }

        $data{'worked'}   += $row->time_worked || 0 if $args{worked};
        $data{'estimate'} += $row->time_estimate || 0 if $args{estimate};
        $data{'left'}     += $row->time_left || 0 if $args{left};
    }
    return \%data;
}

=head2 add_tag_tokens URL, TAG

Adds a given TAG to the URL's tokens, if it doesn't already exist.

=cut

sub add_tag_tokens {
    my $class = shift;
    my ($path, $tag) = @_;
    my $addtag  = "/" . $class->join_tokens_url(
        tag => Text::Tags::Parser->join_tags($tag) );
    unless ( $path =~ /\Q$addtag\E/ ) {
        $path .= $addtag;
    }
    return $path;
}

=head2 tags -> { tag => count }

Returns a hash of tag name to how many times that tag appears in the task
collection. Tags of differing case will be mapped to the first case that's seen in the collection.

The special key of the empty string indicates how many tasks have no tags at
all.

=cut

sub tags {
    my $self = shift;

    my %tag_count;
    my %display;

    # Ignore case for the sake of the count, but keep track of the first
    # tag we saw to determine how to display the tag.
    while (my $task = $self->next) {
        my $tags_in_this_task = 0;
        for my $tag ( $task->tag_array ) {
            $display{lc $tag} = $tag unless $display{lc $tag};
            $tag_count{lc $tag}++;
            ++$tags_in_this_task;
        }
        $tag_count{''}++ if $tags_in_this_task == 0;
    }

    # now adjust the keys of %tag_count to match %display
    for my $key (values %display) {
        $tag_count{$key} = delete $tag_count{lc $key};
    }

    return \%tag_count;
}

=head2 group_time_tracked_by_actor_date

Aggregate the time tracking information of all the tasks in the collection and
group it by the actor, then by transaction date.

=cut

sub group_time_tracked_by_actor_date {
    my $self = shift;
    my %args = @_;
    my %data;

    my $txns = $self->time_tracking_txns;
    $args{limit_txns}->($txns) if $args{limit_txns};

    while (my $txn = $txns->next) {
        my $date = $txn->modified_at->ymd;
        $data{$txn->owner_id}{$date}{worked}     += $txn->time_worked   || 0;
        $data{$txn->owner_id}{$date}{estimate}   += $txn->time_estimate || 0;
        $data{$txn->created_by->id}{$date}{left} += $txn->time_left     || 0;
    }

    for my $time_by_owner (values %data) {
        for (values %$time_by_owner) {
            $_->{worked}   ||= 0;
            $_->{left}     ||= 0;
            $_->{estimate} ||= 0;
        }
    }

    return \%data;
}

=head2 x_factor_by_owner

Returns a hashref of x-factor (worked / estimate) of each owner in the
tasklist. Only complete tasks are considered.

=cut

sub x_factor_by_owner {
    my $self = shift;

    my $clone = $self->clone;
    $clone->limit(
        column => 'complete',
        value  => 1,
    );
    my $data = $clone->group_time_tracked( by => "owner", left => 0, estimate => 1, worked => 1)->{"owner"};

    my %x_factor;
    for my $owner (keys %{$data}) {
        if (not defined $data->{$owner}{estimate} or $data->{$owner}{estimate} == 0) {
            $x_factor{$owner} = undef;
        }
        else {
            $x_factor{$owner} = $data->{$owner}{worked} / $data->{$owner}{estimate};
        }
    }

    return \%x_factor;
}

1;

