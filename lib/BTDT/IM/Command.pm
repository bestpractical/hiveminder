package BTDT::IM::Command;
use strict;
use warnings;

=head2 try_colonic_args CMDARGSREF

This takes a B<reference> to the command arguments and tries to process a "colonic argument". Here are some examples of colonic args:

    due tomorrow: this  ->  "tomorrow"
    give me: #ABC       ->  "me"
    tag foo: /bar       ->  "foo"

The "message" argument will be modified in-place (because that's almost always
what we want) to strip off any colonic args. The arg (or C<undef>) will be
returned.

=cut

sub try_colonic_args {
    my $self = shift;
    my $args = shift;

    return $1 if $args->{message} =~ s{^([^/:]+?):(?:\s|$)}{};
    return undef;
}

=head2 apply_tokens IM, TaskCollection, \%args

Apply the given tokens to a task collection, taking into account the user's
filters.

Expects an C<ok_to_apply> method in your command class which (when passed the
command arguments) returns a hash of field name to array reference of tokens.
These lists of tokens will be removed if a filter already takes care of that
field.

You may define a C<apply_token_callback> method in your command class to
perform additional actions for each filter fragment.

=cut

sub apply_tokens {
    my $self  = shift;
    my $im    = shift;
    my $tasks = shift;
    my $args  = shift;

    my %ok_to_apply = $self->ok_to_apply($args);

    my $cb = sub {
        my ($field) = @_;
        my $inverted = 0;

        # saying "not owner" is as good as saying "owner"
        if ($field =~ /^not (.*)$/) {
            $inverted = 1;
            $field = $1;
        }

        $self->apply_token_callback(\%ok_to_apply, $field, $inverted)
            if $self->can('apply_token_callback');

        $ok_to_apply{$field} = [];
    };

    for my $filter (@{ $args->{session}->get('filters') || [] }) {
        BTDT::IM::Command::Filter::parse_tokens($im, $filter, $cb);
    }

    $tasks->from_tokens(map { @$_ } values %ok_to_apply);
}

=head2 canonicalize_group NAME

Parses the group name and returns its (name, id). It special-cases the special
personal group. It will return undef, undef unless the user can see the group.

=cut

sub canonicalize_group {
    my $self = shift;
    my $name = shift;

    if (lc($name) eq 'personal') {
        return ('personal', 0);
    }

    my $group = BTDT::Model::Group->new();
    $group->load_by_cols(name => $name);

    return (undef, undef) if $group->name eq "(A group you can't see)";
    return ($group->name, $group->id);
}

=head2 canonicalize_project NAME

Parses the project name and returns its (summary, id). It will return undef, undef unless the user can see the project.

=cut

sub canonicalize_project {
    my $self = shift;
    $self->_canonicalize_tasktype(project => @_);
}

=head2 canonicalize_milestone NAME

Parses the milestone name and returns its (summary, id). It will return undef,
undef unless the user can see the milestone.

=cut

sub canonicalize_milestone {
    my $self = shift;
    $self->_canonicalize_tasktype(milestone => @_);
}

sub _canonicalize_tasktype {
    my $self = shift;
    my $type = shift;
    my $name = shift;

    my $task = BTDT::TaskType->new_type($type);
    $task->load_by_cols(summary => $name);

    return ($task->summary, $task->id) if defined $task->summary;
    return (undef, undef);
}

=head2 timer_duration_seconds \%cmd_args -> seconds

Returns the current duration (in seconds) of the running timer. Returns
C<undef> if it looks like there is no timer.

=cut

sub timer_duration_seconds {
    my $self = shift;
    my $args = shift;

    my $session = $args->{session};

    # is there even a timer?
    return undef unless $session->get('timed_tasks');

    my $total_time = $session->get('timed_total') || 0;
    if (my $start = $session->get('timed_start')) {
        $total_time += time - $start;
    }

    return $total_time;
}

=head2 timer_duration_readable \%cmd_args -> duration

Same as C<timer_duration_seconds> but returns the value as a human-readable
string (or C<undef>) if there's no timer).

=cut

sub timer_duration_readable {
    my $self = shift;

    my $time = $self->timer_duration_seconds(@_);

    return undef if !defined($time);

    return BTDT::Model::Task->concise_duration($time);

}

1;

