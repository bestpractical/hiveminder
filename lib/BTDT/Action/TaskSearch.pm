use warnings;
use strict;

=head1 NAME

BTDT::Action::TaskSearch -

=head1 DESCRIPTION

Performs a search over the set of tasks; its results are stored in the
'tasks' key of the associated L<Jifty::Result> object.

=cut

package BTDT::Action::TaskSearch;
use base qw/BTDT::Action Jifty::Action/;

__PACKAGE__->mk_accessors(qw/filters/);

use BTDT::Model::User;

=head2 arguments

TaskSearch takes a number of possible arguments:

=over

=item complete

=item summary

=item description

=item owner

=item requestor

=item group

=item tag

=item due

=item priority

=back

All of the above arguments also posess a C<_not> version of them.
Additionally, C<due_before>, C<due_after>, C<priority_above>, and
C<priority_below> also exist.

See also C<BTDT::Model::TaskCollection>

=cut

sub arguments {
    my $self = shift;

    return $self->{__cached_arguments} if ($self->{__cached_arguments});

    my $arguments = $self->_base_arguments();

    my %task_args = %{ BTDT::Action::CreateTask->new->arguments };
    for my $task_key ( keys %task_args ) {
        my $my_key = $task_key;
        $my_key =~ s/completed_at/completed/g;
        $my_key =~ s/_id//;
        $my_key =~ s/^tags/tag/;
        for my $key ( grep { $_ =~ /^$my_key(?:$|_)/ } keys %{$arguments} ) {
            $arguments->{$key} = {
                %{ $task_args{$task_key} },
                label => $arguments->{$key}{label}
            };
            for (qw(mandatory default_value validator)) {
                delete $arguments->{$key}{$_};
            }
            $arguments->{$key}{render_as} = "Text"
                if $my_key eq "description";
        }
    }
    $arguments->{unaccepted}{render_as} = "Checkbox";
    $arguments->{pending}{render_as} = "Checkbox";
    $arguments->{has_attachment}{render_as} = "Checkbox";
    $arguments->{has_no_attachments}{render_as} = "Checkbox";

    unshift @{ $arguments->{priority}{valid_values} }, '';

    $arguments->{$_}{'canonicalizer'} = sub {
        my ( $self, $value ) = @_;
        return if defined $value and $value eq '';
        return BTDT::Model::Task::canonicalize_priority( @_ );
    } for grep { /^priority/ } keys %$arguments;

    for my $field (qw/owner requestor next_action_by/) {
        $arguments->{$field}{'render_as'} = "Text";
        $arguments->{$field}{'ajax_autocompletes'} = 1;
        $arguments->{$field}{'autocompleter'} = \&BTDT::Model::Task::autocomplete_owner_id;
        $arguments->{$field . "_not"} = $arguments->{$field};
    }

    $arguments->{'tag'}{'render_as'} = "Text";
    $arguments->{'tag'}{'ajax_autocompletes'} = 1;
    $arguments->{'tag'}{'autocompleter'} = \&BTDT::Model::Task::autocomplete_tags;

    $arguments->{'tag_not'} = $arguments->{'tag'};

    my @valid_groups = @{$arguments->{'group'}{'valid_values'}};

    for (@valid_groups) {
        $_->{'value'} = 'personal' if exists $_->{'display'} && $_->{'display'} eq "Personal";
    }

    unshift @valid_groups, {value => '', display => ''};

    $arguments->{'group'}{'valid_values'} = \@valid_groups;
    $arguments->{'group_not'}{'valid_values'} = \@valid_groups;

    for (qw( project milestone )) {
        $arguments->{$_}{'render_as'} = "Text"
            if exists $arguments->{$_};
    }

    return $self->{__cached_arguments} = $arguments;

}

=head2 _base_arguments

Returns our base immutable args.

=cut

sub _base_arguments {
    my $self = shift;
    my $arguments = {
        'sort_by' => {
          render_as    => 'Select',
          label        => 'Sort by',
          default_value       => '',
          valid_values => [
            { display => 'Default',    value => '' },
            { display => 'Name',       value => 'summary' },
            { display => 'Priority',   value => 'priority' },
            { display => 'Due',        value => 'due' },
            { display => 'Completed',  value => 'completed_at' },
            { display => 'Hide until', value => 'starts' },
            { display => 'Age',        value => 'created' },
            { display => 'Owner',      value => 'owner' },
            { display => 'Requestor',  value => 'requestor' },
          ]
        },
        sort_by_tags    => { label => 'Sort by tags' },
        'q'             => { label => 'Quick search' },
        query           => { label => 'Task, notes, or tags' },
        query_not       => {},
        complete        => { label => 'Done' },
        complete_not    => { label => 'Not done' },
        accepted        => { label => 'Accepted' },
        accepted_not    => { label => 'Declined' },
        unaccepted         => { label => 'Unaccepted' },
        pending         => { label => 'Unaccepted' },
        summary         => { label => 'Task' },
        summary_not     => { label => q{Task isn't} },
        description     => { label => 'Notes' },
        description_not => { label => q{Notes isn't} },
        owner           => { label => 'Owner' },
        owner_not       => {},
        requestor       => { label => 'Requestor' },
        requestor_not   => {},
        group           => { label => 'Group' },
        group_not       => {},
        tag             => { label => 'Tags' },
        tag_not         => {},
        due             => {},
        due_not         => {},
        due_before      => {},
        due_after       => {},
        starts          => {},
        starts_not      => {},
        starts_before   => {},
        starts_after    => {},
        completed       => {},
        completed_not   => {},
        completed_before=> { render_as => 'Date'},
        completed_after => { render_as => 'Date'},
        priority        => {},
        priority_not    => {},
        priority_above  => {},
        priority_below  => {},
        will_complete     => { label => 'Will do' },
        will_complete_not => { label => 'Will never do' },
        next_action_by      => { label => 'Next action by' },
        next_action_by_not  => { label => 'Next action not by' },
        but_first       => { label => 'But first' },
        and_then        => { label => 'And then' },
        has_attachment     => { label => 'Has attachment(s)' },
        has_no_attachments => { label => 'Has no attachments' },
        per_page           => { render_as => 'Hidden' },
        page               => { render_as => 'Hidden' },

        # XXX TODO ACL
        project         => { label => 'Project' },
        milestone       => { label => 'Milestone' },
    };
    for my $field (qw(left worked estimate)) {
        for my $cmp (('', qw(_lt _gt _lte _gte))) {
            $arguments->{"time_$field$cmp"} = {};
        }
    }

    # XXX TODO ACL
    if ( $self->current_user->has_group_with_feature('Projects') ) {
        push @{ $arguments->{'sort_by'}{'valid_values'} },
                { display => 'Project',   value => 'project' },
                { display => 'Milestone', value => 'milestone' };
    }

    if ( $self->current_user->has_feature('TimeTracking') ) {
        push @{ $arguments->{'sort_by'}{'valid_values'} },
                { display => 'Progress',  value => 'progress' },
                { display => 'Time left', value => 'time_left' };
    }

    return $arguments;
}

=head2 arguments_to_tokens

This is a class method, not an instance method.  It does the oppossite
of L<BTDT::Model::TaskCollection/from_tokens>, returning a list of
tokens from a hash of arguments.

=cut

sub arguments_to_tokens {
    my $self = shift;
    $self = $self->new unless ref $self;
    my (%arguments) = @_;
    my @tokens;
    for my $key ( sort keys %arguments ) {
        my $value = ( defined $arguments{$key} ? $arguments{$key} : '' );
        my $base_key = $key; $base_key =~ s/_not$//;
        my $binary = ( $self->arguments->{$base_key}{render_as} || "" ) eq "Checkbox" ? 1 : 0;

        next if $key =~ /^(?:tokens)$/oi or $value !~ /\S/;
        next if $binary and not $value;

        $key = "but_first/nothing" if $key eq "no_dependencies";
        $key =~ s/^starts(_(?:after|before))?$/hidden_until$1/;

        $key = 'hidden_forever'     if $key eq 'will_complete_not';
        $key = 'hidden_forever_not' if $key eq 'will_complete';

        if ( $key !~ /^sort_by/ ) {
            $key =~ s!(.*)_not!not/$1!g;
            $key =~ s!_!/!g;
        }
        push @tokens, (split '/', $key);
        push @tokens, $value if not $binary;
    }
    @tokens = grep { defined $_ and length $_ } @tokens;
    return @tokens;
}

=head2 take_action

Performs the search.  If there are any parameters that are not in the
tokens, it performs a refirect such that all of the state is in the
tokens.

=cut

sub take_action {
    my $self   = shift;

    my @tokens;
    my $tokens = $self->argument_value("tokens");
    if (ref $tokens eq 'ARRAY') {
        push @tokens, @{ $self->argument_value("tokens")  };
    } elsif (defined $tokens) {
        push @tokens, split ' ', $tokens;
    }

    my %arguments = %{ $self->argument_values };

    $self->maybe_swap_priority(\%arguments);

    push @tokens, $self->arguments_to_tokens(%arguments);
    $self->argument_value( tokens => [@tokens] );

    my $tasks = BTDT::Model::TaskCollection->new();
    my @args  = $tasks->from_tokens(@tokens);

    if ($arguments{per_page}) {
        $tasks->set_page_info(
            current_page => ($arguments{page} || 1),
            per_page     => $arguments{per_page},
        );
    }

    $self->result->content( tasks => $tasks );
    $self->result->content( tokens => $tasks->join_tokens( @tokens ) );
    $self->result->content( tokens_string => join( ' ', @tokens ) );

    while ( my $token = shift @tokens ) {
        if ( $token eq 'group' ) {
            my $next = shift @tokens;
            if ( $next =~ /^\d+$/ ) {
                $self->result->content( group => $next );
                last;
            }
        }
    }

    my %defaults = @args;
    if (my $action = Jifty->web->request->action( $self->moniker)) {
        $action->argument( $_ => $defaults{$_} )
            for keys %defaults;
    }
    else {
        # XXX: the REST interface needs to have its defaults set somehow
    }
    return 1;
}

=head2 record

Returns an empty C<BTDT::Model::Task>

XXX TODO This is a horrible hack to deal with the fact that we are
pulling arguments from C<CreateTask>, which generates canonicalizers
that expect $self->record to work.

=cut

sub record {
    my $self = shift;
    return BTDT::Model::Task->new;
}

=head2 maybe_swap_priority args

If both a "priority above" and "priority below" are specified, but reversed,
then fix it.

=cut

sub maybe_swap_priority {
    my $self = shift;
    my $args = shift;

    return unless defined($args->{priority_above})
               && defined($args->{priority_below});

    # priority above 2, priority below 4 is valid
    return if $args->{priority_above} < $args->{priority_below};

    ($args->{priority_above}, $args->{priority_below}) =
        ($args->{priority_below}, $args->{priority_above});

    return;
}

1;
