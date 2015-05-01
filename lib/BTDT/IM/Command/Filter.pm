package BTDT::IM::Command::Filter;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'filter' command, for filter (aka context) CRUD.

=cut

sub run
{
    my $im = shift;
    my %args = @_;

    $args{message} =~ s/^\s+//;

    if ($args{message} eq '')
    {
        return show_all($im, %args);
    }
    elsif ($args{message} =~ /^clear\s*$/)
    {
        return clear($im, %args);
    }
    elsif ($args{message} =~ /^clear\s*(-?\d+|last|latest)\s*$/)
    {
        my $number = $1;
        $number = -1 if $number =~ /last|latest/;
        return clear_one($im, %args, number => $number);
    }
    elsif ($args{message} =~ /^clear\b/)
    {
        return "I don't understand. Use <b>filter clear</b> to clear all filters, or <b>filter clear <i>number</i></b> to clear one filter.\n";
    }
    else
    {
        return create($im, %args);
    }
}

=head2 show_all PARAMHASH

Shows the user all of his filters. If he has none, then it will give a hint
about how to set one.

=cut

sub show_all
{
    my $im = shift;
    my %args = @_;

    my $filters = $args{session}->get('filters') || [];
    if (@$filters == 0)
    {
        return 'You have no filters. Example: "filter tag @work"' if $im->terse;

        return '<p>You have no filters. </p><p>You can set filters by using <b>filter <i>desired filter</i></b>. For example, <b>filter tag @work</b> will show you only tasks tagged with @work. </p><p>You can clear filters by typing <b>filter clear</b>. </p><p>See <b>help filter</b> for more information.</p>'
    }

    my $ret = "You have "
            . @$filters
            . " filter"
            . (@$filters == 1 ? "" : "s")
            . ":\n";

    my $num = 0;
    for my $filter (@$filters)
    {
        $ret .= ++$num . ". $filter\n";
    }

    return $ret;
}

=head2 clear

Clears the user's filters.

=cut

sub clear
{
    my $im = shift;
    my %args = @_;

    my $filters = $args{session}->get('filters') || [];
    $args{session}->set('filters' => []);

    return "You have no filters to clear." if @$filters == 0;

    return "Cleared your "
         . @$filters
         . " filter"
         . (@$filters == 1 ? "" : "s")
         . ".";
}

=head2 clear_one

Clears only one of the user's filters.

=cut

sub clear_one
{
    my $im = shift;
    my %args = @_;

    my $filters = $args{session}->get('filters') || [];

    if ($args{number} == 0)
    {
        return "Filter number out of range.";
    }

    if (abs($args{number}) > @$filters)
    {
        return "You have no filters to clear." if @$filters == 0;
        return "You have only "
             . @$filters
             . " filter"
             . (@$filters == 1 ? "" : "s")
             . ".";
    }

    # splice can accept a negative offset just fine. we subtract 1 only if
    # positive because we used 1-based indexes
    --$args{number} if $args{number} > 0;

    my $spliced = splice @$filters, $args{number}, 1;

    $args{session}->set('filters' => $filters);

    return "You no longer have the filter: " . $spliced . "\n";
}

=head2 create

Creates a new filter.

=cut

sub create
{
    my $im = shift;
    my %args = @_;

    my $filters = $args{session}->get('filters') || [];

    my ($ok, $msg) = parse_tokens($im, $args{message});
    $ok or return "I can't create your new filter: $msg";

    push @$filters, $args{message};

    $args{session}->set('filters' => $filters);
    return "Added your new filter. You now have " . @$filters . ".";
}

=head2 filter2fv STRING, CALLBACK

Takes a filter and transforms it into a list of (field, value) pairs. The
callback will be invoked for each field, value pair.

=cut

sub filter2fv
{
    my $im = shift;
    my $filter = shift;
    my $orig_cb = shift;
    my @attributes;

    my $cb = sub {
        my ($field, $value, $inverse) = @_;
        push @attributes, [$field, $value, $inverse];
        $orig_cb->($field, $value, $inverse);
        return 1;
    };

    my ($ok, $msg) = parse_tokens($im, $filter, $cb);
    $ok or die "BTDT::IM error: I don't understand the filter '$filter' because: $msg\n";

    return @attributes;
}

=head2 filter2tokens STRING

Takes a filter and transforms it into a list of tokens.

=cut

sub filter2tokens
{
    my $im = shift;
    my $filter = shift;
    my @attributes;

    my $cb = sub {
        my ($field, $value, $inverse) = @_;
        push @attributes, 'not' if $inverse;
        push @attributes, $field, split ' ', $value;
        return 1;
    };

    my ($ok, $msg) = parse_tokens($im, $filter, $cb);
    $ok or die "BTDT::IM error: I don't understand the filter '$filter' because: $msg\n";

    return @attributes;
}

=head2 apply_filter STRING, TASKS

Takes a filter and transforms it into something that can be used with
TaskCollection->from_tokens.

=cut

sub apply_filter
{
    my $im = shift;
    my $filter = shift;
    my $tasks = shift;
    my $calls = 0;

    my $cb = sub {
        ++$calls;
    };

    my @attributes = filter2fv($im, $filter, $cb);

    for (@attributes) {
        my ($field, $value, $inverse) = @$_;
        if ($field eq 'query') {
            $tasks->smart_search($value);
            $im->log->debug("[IM Filter] Smart searching: $value");
            $calls == 1 or die "BTDT::IM error: You can't have 'query' with other attributes in the same filter.\n";
        }
        else {
            my @tokens;
            push @tokens, "not" if $inverse;
            push @tokens, $field;
            push @tokens, split ' ', $value;

            $im->log->debug("[IM Filter] Applying tokens: @tokens");
            $tasks->from_tokens(@tokens);
        }
    }
}

=head2 canonicalize_field FIELD

Canonicalizes a field name, e.g. 'tags' becomes 'tag'

=cut

our %canonicalizations = (
    tags         => 'tag',
    hide         => 'starts',
    hide_until   => 'starts',
    'hide-until' => 'starts',
);

sub canonicalize_field
{
    my $field = shift;
    return $canonicalizations{$field} || $field;
}

=head2 valid_field FIELD

Returns a boolean of whether this is a valid field or not.

=cut

our %valid_fields = map { $_ => 1 } qw/due tag group starts priority query owner requestor/;

sub valid_field
{
    my $field = shift;
    return $valid_fields{$field} || 0;
}

=head2 parse_tokens STRING, CALLBACK

This will take a filter (or potential filter) and parse it into field, value
pairs. For each (field, value) pair it will invoke the callback with arguments
field and value. The callback is expected to return a (boolean, msg) pair. You
may pass in a false value to avoid using the callback.

It will return a (boolean, msg) pair. If the boolean is false, then an error
occurred and a message will be put into msg. If the boolean is true, then
the token string was entirely valid.

=cut

sub parse_tokens
{
    my $im = shift;
    my $filter = shift;
    my $callback = shift;

    my @tokens = split ' ', $filter;

    TOKEN: while (@tokens) {
        my $field = shift @tokens;
        my $inverse = '';
        if (lc($field) eq 'not')
        {
            $inverse = 'not ';
            $field = shift @tokens;
        }
        # you can also specify a field like "!tag bar" or "-priority = 3"
        if ($field =~ s/^[!-]//) {
            $inverse = 'not ';
        }

        # if they specify "foo:bar" then split it up to "foo", "bar"
        unshift @tokens, $1
            if $field =~ s/:+(.+)//;

        $field =~ s/:+$//;

        $field = canonicalize_field($field);

        return (0, "I don't know the field '$field'. The fields I know about are: " . join(', ', sort keys %valid_fields))
            unless valid_field($field);

        my $value;
        my $parser = __PACKAGE__->can("parse_$field");

        if ($parser) {

            my @cur_tokens;
            while (@tokens) {

                # stop when we get the next 'field: value'
                last if $tokens[0] =~ /^(\w+):/ && valid_field($1);

                # also stop when we get to the next 'not field: value'
                last if lc($tokens[0]) eq 'not'
                     && @tokens > 1
                     && $tokens[1] =~ /^(\w+):/
                     && valid_field($1);

                push @cur_tokens, shift @tokens;
            }

            ($value, my $msg) = $parser->(\@cur_tokens, $inverse);

            # if parser returns undef, then an error occurred
            return (0, $msg) unless defined $value;

            # if parser returns an array ref, then apply the callback for each
            # value
            if ($callback) {
                if (ref($value) eq 'ARRAY') {
                    for my $value (@$value) {
                        my ($ok, $msg) = $callback->($field, $value, $inverse);
                        $ok or return (0, $msg);
                    }
                    next TOKEN;
                }
            }
        }
        else {
            # boolean, truthiness is determined by $inverse
            $value = 1;
        }

        if ($callback) {
            my ($ok, $msg) = $callback->($field, $value, $inverse);
            $ok or return (0, $msg);
        }
    }

    return (1, "Valid filter.");
}

# parses a date string using intuit_date
# it will return a pair (or its first element in scalar context)

# the first element is undef if any sort of error occurred
# if everything was great, then the first element is "
# (before|after|on) (due->ymd)" which you can return directly from parse_thing

# the second element will be either an error message indicating a date parse
# error, or the empty string indicating that there was no date given, or
# a reference to an error message indicating some other kind of error occurred

# it's so convoluted because the error messages need to be sufficiently helpful

sub _parse_date
{
    my $date = join ' ', @{ shift @_ };
    my $inverse = shift;

    my $pre = 'on ';
    $pre = lc("$1 ")
        if $date =~ s/^(before|after|on)\b\s*//i;

    my $dt = BTDT::DateTime->intuit_date_explicit($date);

    return wantarray ? (undef, $date) : undef if !$dt;

    if ($pre eq 'on ' && $inverse) {
        wantarray or return undef;

        my $command = (caller(1))[3];
        if ($command =~ /::parse_(\w+)$/) {
            $date = "'not $1 on $date' does not work yet.";
        }
        else {
            $date = "'not ... on $date' does not work yet.";
        }

        return (undef, \$date);
    }

    # shortcut: "on today" (or just "today") means:
    # "before tomorrow" AND "after yesterday"
    if ($pre eq 'on ' && !$inverse) {
        $dt = ["before " . $dt->clone->add(days => 1)->ymd,
               "after "  . $dt->clone->subtract(days => 1)->ymd];
    }
    else {
        $dt = $pre . $dt->ymd;
    }

    return wantarray ? ($dt, $date) : $dt;
}

=head2 parse_group \TOKENS

Tries to parse out the group name.

=cut

sub parse_group
{
    my $tokens = shift;
    return (undef, "No group specified.") if @$tokens == 0;

    my $name = join ' ', @$tokens;

    return 0
        if lc($name) eq 'personal';

    return $name
        if $name =~ /^\d+$/;

    my $group = BTDT::Model::Group->new;
    $group->load_by_cols(name => $name);
    return $group->id if $group->id;
    return (undef, "No group with the name '$name' found.");
}

=head2 parse_tag \TOKENS

Tries to parse out the tags.

=cut

sub parse_tag
{
    my $tokens = shift;
    return (undef, "No tags specified.") if @$tokens == 0;

    return $tokens;
}

=head2 parse_due \TOKENS

Tries to parse the due date given with intuit_date

=cut

sub parse_due
{
    my $tokens = shift;
    my $inverse = shift;
    return (undef, "No due date specified.") if @$tokens == 0;

    my ($due, $date) = _parse_date($tokens, $inverse);
    return $due if $due;
    return (undef, $$date) if ref $date;
    return (undef, "No due date specified.") if $date eq '';
    return (undef, "I don't understand what you mean by '$date'.");
}

=head2 parse_starts \TOKENS

Tries to parse the starts date given with intuit_date

=cut

sub parse_starts
{
    my $tokens = shift;
    my $inverse = shift;
    return (undef, "No starting date specified.") if @$tokens == 0;

    my ($starts, $date) = _parse_date($tokens, $inverse);
    return $starts if $starts;
    return (undef, $$date) if ref $date;
    return (undef, "No starting date specified.") if $date eq '';
    return (undef, "I don't understand what you mean by '$date'.");
}

=head2 parse_priority \TOKENS

Tries to parse the priority

=cut

sub parse_priority
{
    my $tokens = shift;
    return (undef, "No priority specified.") if @$tokens == 0;

    my $in = join ' ', @$tokens;
    my $priority = $in;

    # first, replace the priority words with their numeric equivalents
    for ([lowest => 1], [highest => 5], [low => 2], [high => 4], [normal => 3])
    {
        $priority =~ s/\b$_->[0]\b/$_->[1]/ig;
    }

    # above 3 is priority >= 3, we want it to mean priority > 3
    # these are the four valid priority forms
    $priority =~ s{^(?:>|above)\s+(\d)\s*$}{"above " . ($1+1)}ie or
    $priority =~ s{^(?:<|below)\s+(\d)\s*$}{"below " . ($1-1)}ie or
    $priority =~ s{^<=\s+(\d)\s*$}{below $1} or
    $priority =~ s{^>=\s+(\d)\s*$}{above $1} or
    $priority =~ s{^(?:(?:=|is)\s+)?(\d)\s*$}{$1}i or
        return (undef, "I don't understand what you mean by '$in'.");

    return (undef, "Cannot have a priority greater than five.")
        if $priority =~ /[6789]|10/;

    return (undef, "Cannot have a priority lower than one.")
        if $priority =~ /0|-/;

    return $priority;
}

=head2 parse_query \TOKENS, INVERSE

Takes the tokens to form a query, aka a smart_search. The inverse argument
is required because we cannot do inverse queries.

=cut

sub parse_query
{
    my $tokens = shift;
    return (undef, "No query specified.") if @$tokens == 0;
    my $inverse = shift;
    return (undef, "You cannot use 'not query'.") if $inverse;

    return join ' ', @$tokens;
}

=head2 parse_owner \TOKENS

Tries to parse out the owner name. Since this is always a single word, and the
rest of the system copes with the various special cases, we just pass it
through.

=head2 parse_requestor \TOKENS

Tries to parse out the requestor name. Since this is always a single word, and
the rest of the system copes with the various special cases, we just pass it
through.

=cut

sub parse_owner     { _parse_user("owner", @_) }
sub parse_requestor { _parse_user("requestor", @_) }
sub _parse_user
{
    my $type = shift;
    my $tokens = shift;
    return (undef, "No $type specified.") if @$tokens == 0;

    my $name = join ' ', @$tokens;
    return $name;
}

1;

