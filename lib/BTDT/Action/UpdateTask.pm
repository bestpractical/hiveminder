use warnings;
use strict;

=head1 NAME

BTDT::Action::UpdateTask

=cut

package BTDT::Action::UpdateTask;

use base qw/BTDT::Action Jifty::Action::Record::Update/;
use base 'BTDT::Action::ArgumentCacheMixin';
use Scalar::Defer qw/lazy defer/;
use List::MoreUtils qw/uniq/;

=head2 record_class

We are talking about L<BTDT::Model::Task> objects.

=cut

sub record_class { 'BTDT::Model::Task' }


=head2 arguments

Pull the generic form fields, but set the default_value for tags to
the string variant of it.

=cut

sub arguments {
    my $self = shift;
    return $self->{__cached_arguments}
        if ( exists $self->{__cached_arguments} );

    my $weakself = $self;
    Scalar::Util::weaken $weakself;

    my $args = $self->__get_cache->{ $self->__cache_key( $self->record ) }
        ||= $self->SUPER::arguments();
    $args->{comment} = { label => 'Add a comment', render_as => 'Textarea' };

    $args->{hidden_forever} = {
        label           => 'Hide forever?',
        render_as       => 'Checkbox',
        default_value   => not $args->{will_complete}{default_value},
    };

    $args->{add_time_worked} = { label => 'Add time worked' };
    $args->{add_time_worked}{ajax_validates} = 1;

    $args->{owner_id}{ajax_validates} = 1;
    $args->{owner_id}{canonicalizer}
        = \&BTDT::Model::Task::canonicalize_owner_id;

    $args->{summary}{ajax_canonicalizes} = 1;

    $args->{requestor_id}{ajax_validates} = 1;

    # XXX TODO: the rest of this code is nearly identical to that of
    # CreateTask::arguments -- they should be refactored

    $args->{'requestor_id'}{'default_value'} = lazy {
        my $requestor = $weakself->record->requestor;
        if   ( $requestor->id ) { $requestor->email }
        else                    {undef}
    };

    $args->{'owner_id'}{'default_value'} = lazy {
        if ( $weakself->record->owner->id ) {
            $weakself->record->owner->email;
        }
    };

    $args->{'group_id'}{'valid_values'}
        = lazy { $weakself->_compute_possible_groups($weakself->record) };
    $args->{'group_id'}{canonicalizer}
        = \&BTDT::Model::Task::canonicalize_group_id;

    $args->{'group_id'}{'render_as'} = 'Select';
    $args->{'owner_id'}{'render_as'} = 'Text';

    $args->{accepted} = {
        valid_values => [
            { display => 'accepted',    value => '1' },
            { display => 'declined',    value => '0' },
            { display => '(no change)', value => '' },
        ],
        default_value => '',
        render_as     => 'Radio',
        label         => 'Accepted',
    };

    # XXX TODO ACL
    # Project and milestone - render them as selects with
    # projects/milestones for the group
    for my $type (qw(project milestone)) {
        $args->{$type}{'render_as'}    = 'Select';
        $args->{$type}{'valid_values'} = defer {
            if ( $weakself->record->group_id ) {
                my $class = "BTDT::".ucfirst($type)."Collection";

                my $collection = $class->new;
                $collection->incomplete;
                $collection->group( $weakself->record->group_id );

                my @values = (
                    { display => '(None)', value => "" }
                );

                push @values, { display => $_->summary, value => $_->id }
                    for @$collection;

                return \@values;
            }
            else {
                return [];
            }
        };
    }

    return $self->{__cached_arguments} = $args;
}


sub _compute_possible_groups {
    my $self = shift;
    my $record = shift;

    my $groups_ref = ();

    if (   $record->owner->id == BTDT::CurrentUser->nobody->id
        or $record->owner->id == $self->current_user->id ) {
        my $groups = Jifty->web->current_user->user_object->groups;
        $groups->limit(column => 'id', operator => '!=', value => $record->group->id)
          if $record->group->id;

        $groups_ref = [
            {   display => (
                    (     $record->group_id
                        ? $record->group->name
                        : "Personal"
                    )
                    . " (Unchanged)"
                ),
                value => $record->group_id,
            },
            {   display_from => 'name',
                value_from   => 'id',
                collection   => $groups,
            },
        ];
    }
    if (!$groups_ref) {

        # XXX: only load owner's that might not be readable. use
        # previous valud_values for groups of self.
        my $groups = BTDT::Model::GroupCollection->new();
        $groups->limit_contains_user( Jifty->web->current_user->user_object );
        $groups->limit_contains_user( $record->owner )
            if $record->owner->id;
        $groups->order_by( column => 'name' );
        $groups->_do_search();    # XXX don't do the count and then the search
                                  # We'll always want the full search
        if ( $groups->count ) {

            $groups_ref = [
                {   display => $record->group->name,
                    value   => $record->__value('group_id'),
                },
            ];

            while ( my $g = $groups->next ) {
                next
                    if ( $record->group_id
                    && $g->id == $record->group_id );

                push @{$groups_ref},
                    {
                    display => $g->name,
                    value   => $g->id,
                    };
            }
        }
    }

    $groups_ref ||= [
        {   display => $record->group->id
            ? $record->group->name
            : "Personal",
            value => $record->group->id,
        },
    ];

    # If we can bring the task into "Personal" depends on if it's
    # already a personal task, or if we have update permissions on the
    # group in question.
    if (    $record->group->id
        and $record->group->current_user_can("update_tasks") )
    {
        splice @$groups_ref, 1, 0,
            {
            display => "Personal",
            value   => 0,
            };
    }

    return $groups_ref;

}

=head2 validate_owner_id

Ensures the owner is a valid email address

=cut

sub validate_owner_id {
    my ( $self, $value ) = @_;
    return BTDT->validate_user_email( action => $self, column => "owner_id", value => $value, empty => 1, group => $self->record->group_id );
}

=head2 validate_requestor_id

Ensures the requestor is a valid email address

=cut

sub validate_requestor_id {
    my ( $self, $value ) = @_;
    return BTDT->validate_user_email( action => $self, column => "requestor_id", value => $value, empty => 1, group => $self->record->group_id );
}

=head2 take_action

Most of the processing here is done in the superclass; we need to
close any expanded "edit tags" boxes too.

=cut

sub take_action {
    my $self = shift;

    $self->argument_value( owner_id =>
            BTDT::Model::User->resolve( $self->argument_value("owner_id") )
            || $self->record->owner_id );
    $self->argument_value( group_id => undef )
        if $self->has_argument("group_id")
        and not $self->argument_value("group_id");

    # If they're changing the group, and the owner was either going to
    # be or already was nobody, force it to be the current user
    $self->argument_value( owner_id => Jifty->web->current_user->id )
        if ((defined $self->argument_value("owner_id") and $self->argument_value("owner_id") == BTDT::CurrentUser->nobody->id)
            xor (defined $self->record->owner_id and $self->record->owner_id == BTDT::CurrentUser->nobody->id))
        and $self->has_argument("group_id")
        and not $self->argument_value("group_id");

    if ( my $add_time = $self->argument_value('add_time_worked') ) {
        my $seconds = $self->record->duration_in_seconds( $add_time );

        if ( defined $seconds ) {
            my $left = $self->record->time_left;
            my $arg  = $self->argument_value('time_left');

            if ( defined $left and (not defined $arg or $arg eq $left) ) {
                $left = $self->record->duration_in_seconds( $left ) - $seconds;
                $self->argument_value( 'time_left' => ($left >= 0 ? "$left seconds" : undef) )
            }

            # Time::Duration::Parse does handle "3h10s 5 seconds" correctly
            my $worked = ($self->record->time_worked || '')
                       . " $seconds seconds";
            $self->argument_value( 'time_worked' => $worked);

            $self->argument_value( 'add_time_worked' => undef );
        }
    }

    # Use hidden_forever as an inverted will_complete
    if ( not defined $self->argument_value('will_complete') ) {
        my $hidden_forever = $self->argument_value('hidden_forever');
        $self->argument_value( 'will_complete'  => not $hidden_forever );
        $self->argument_value( 'hidden_forever' => undef );
    }

    $self->record->start_transaction;
    $self->SUPER::take_action or return;
    if (defined $self->argument_value('comment') and $self->argument_value('comment') =~ /\S/) {
        $self->record->comment($self->argument_value('comment'));
        $self->report_success;
    }
    $self->record->end_transaction;

    delete $self->__get_cache->{$self->__cache_key($self->record)};

    return 1;
}

=head2 report_success

The success message links to the ticket's history page.

=cut

sub report_success {
    my $self = shift;
    my $type = ucfirst $self->record->type;
    my $summary = Jifty->web->escape($self->record->summary);
    $self->result->message(qq{<a href="/task/@{[$self->record->record_locator]}/history">$type '$summary' updated.</a>});
}

=head2 canonicalize_summary

Attempt to intuit other information about the task by parsing its summary.
Then automatically update other task attributes.

=over

=item implicit

 Defaults to 0, if 1 will use implicitly parsed data to set empty fields

=back

=cut

sub canonicalize_summary {
    my $self = shift;
    my $summary = shift;
    my %args = ( implicit => 0 , @_ );

    my $changes = BTDT::Model::Task->parse_summary($summary);
    my %updated_fields;

    foreach my $change (keys %{$changes->{explicit}}) {
        my $changed_value = $changes->{explicit}{$change};
        if ($change eq 'tags') {
            my $parser = Text::Tags::Parser->new;
            my @tags =  $parser->parse_tags($self->argument_value('tags'));
            push @tags, $parser->parse_tags($changed_value);
            @tags = uniq @tags;
            $changed_value = $parser->join_tags(@tags);
        }
        $self->argument_value($change => $changed_value);
        $updated_fields{$change} = $changed_value;
    }

    # We shouldn't consider implicit changes when we're updating
    # a task.  Otherwise we might get into a fight with the user
    # when we think their summary means something, but they're
    # trying to "unset" a value in the UI
    # for example "task for thursday" and a user setting Due to ""
    if ($args{implicit}) {
        foreach my $change (keys %{$changes->{implicit}}) {
            my $changed_value = $changes->{implicit}{$change};
            # TODO need a way to handle priority, since it defaults to 3
            # and dates can't get "unset" since we'll reparse "for thursday"
            unless ($self->argument_value($change)) {
                $self->argument_value($change => $changed_value);
                $updated_fields{$change} = $changed_value;
            }
        }
    }

    # TODO we really need a programmatic way of accessing label
    # and it has to work with Jifty::Param::Schema
    # $action->form_field is not it (it tries to print)
    my @updates;
    my %arguments = %{ $self->arguments };
    foreach my $field (keys %updated_fields) {
        unless ($field eq 'summary') {
            push @updates, "$arguments{$field}{label} to $updated_fields{$field}";
        }
    }

    if (@updates) {
        my $fields = join (", ", @updates);
        $self->canonicalization_note(summary => "Set $fields");
    }
    return $changes->{explicit}{summary};

}

=head2 validate_add_time_worked

The time worked must look like a time value (see
L<BTDT::Model::Task/_validate_time>)

=cut

sub validate_add_time_worked {
    my $self = shift;
    my ( $ok, $error ) = $self->record->_validate_time(@_);

    return $ok
        ? $self->validation_ok('add_time_worked')
        : $self->validation_error('add_time_worked' => $error );
}

1;
