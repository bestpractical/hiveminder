use strict;
use warnings;

package BTDT::DateTime;
use base qw/Jifty::DateTime/;

use DateTime;
use DateTime::Format::Natural;
use Date::Extract;
use Date::Manip;

=head2 intuit_date_explicit String -> BTDT::DateTime

Interpret VALUE as a date. There is no guesswork involved as to whether
there's a date in here, the user assures us that there is. Thus, we can use
our big guns (L<DateTime::Format::Natural> and L<Date::Manip>).

The result of this extraction is memoized for the duration of the request.

=cut

sub intuit_date_explicit {
    my $self = shift;
    my $c = shift;

    my $key = join(" ", datetime => $c);
    my $stash = Jifty->handler->stash || {};
    return $stash->{$key}->clone if $stash->{$key};

    $c = $self->preprocess($c, explicit => 1);

    my $dt = $self->parse_dtfn($c)
          || $self->parse_date_manip($c)
          || $self->parse_date_extract($c)
          || return;

    return $stash->{$key} = $self->upgrade($dt);
}

=head2 intuit_date String -> BTDT::DateTime

Attempt to interpret VALUE as a date. Since we're not sure if there is a date,
we use the conservative L<Date::Extract> module. This is used, for example, to
pull obvious dates out of task summaries.

=cut

sub intuit_date {
    my $self = shift;
    my $c = $self->preprocess(shift);

    my $dt = $self->parse_date_extract($c)
          || return;

    return $self->upgrade($dt);
}

=head2 preprocess String -> String

Preprocesses VALUE before handing it to the date parsing libraries.

=cut

sub preprocess {
    my $self = shift;
    my $c    = lc(shift);
    my %args = ( explicit => 0, @_ );

    $c =~ s/[.,!?]/ /g;
    $c =~ s/ +/ /g;

    # specific request. *shrug*
    $c =~ s{\bday after next\b}{2 days from now}gi;

    $c =~ s{tonight}{today}gi;
    $c =~ s{tonite}{today}gi;
    $c =~ s{\bthurs\b}{thursday}gi;

    # replace one through ten with their numeric equivalents.
    # in the future we may look at something like Lingua::EN::Words2Nums
    # to catch all numbers in word form, BUT it currently returns nothing
    # for "two days"
    $c =~ s{\bone\b}  {1}gi;
    $c =~ s{\btwo\b}  {2}gi;
    $c =~ s{\bthree\b}{3}gi;
    $c =~ s{\bfour\b} {4}gi;
    $c =~ s{\bfive\b} {5}gi;
    $c =~ s{\bsix\b}  {6}gi;
    $c =~ s{\bseven\b}{7}gi;
    $c =~ s{\beight\b}{8}gi;
    $c =~ s{\bnine\b} {9}gi;
    $c =~ s{\bten\b}  {10}gi;

    return $c;
}

=head2 upgrade DateTime -> BTDT::DateTime

Upgrades a DateTime date/time to BTDT::DateTime date.

=cut

sub upgrade {
    my $self = shift;
    my $dt   = shift;

    return BTDT::DateTime->new(time_zone => 'floating',
                               year      => $dt->year,
                               month     => $dt->month,
                               day       => $dt->day);
}

=head2 parse_dtfn String -> Maybe DateTime

Parses VALUE with L<DateTime::Format::Natural>.

=cut

sub parse_dtfn {
    my $self = shift;
    my $c    = shift;

    my $tz = $self->current_user_has_timezone || 'UTC';

    my $parser = DateTime::Format::Natural->new(
        prefer_future => 1,
        time_zone     => $tz,
    );

    # not doing this causes mason to spend a lot of effort on a stacktrace for
    # an exception
    local $SIG{__DIE__} = 'IGNORE';

    # eval is necessary because if DT:F:N screws up, it screws up bad
    my ($dt) = eval { $parser->parse_datetime($c) };

    if ($@ || !$parser->success || !$dt) {
        return;
    }

    # if today is 2007-12-01, and you say "30 november", DTFN will give 2008.
    # that is clearly not the expected behavior, so we work around it by
    # subtracting a year if the input matches "mon day" or "day mon" and the
    # parsed date came out to over six months from now. suggestions for
    # improvement welcome..
    # if ($c =~ /^\d+\s*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*$/i
    #  || $c =~ /^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*\s*\d+$/i)
    # {
    #     my $d = $dt - BTDT::DateTime->now;
    #     $dt->subtract(years => 1)
    #         if $d->delta_months >= 6;
    # }

    return $dt;
}

=head2 parse_date_manip String -> Maybe DateTime

Parses VALUE with L<Date::Manip>.

=cut

sub parse_date_manip {
    my $self = shift;
    my $c = shift;

    my $offset = $self->get_tz_offset;
    my $dt_now = BTDT::DateTime->now();
    my $now = sprintf '%s-%s', $dt_now->ymd, $dt_now->hms;

    # TZ sets the timezone for parsing
    # ConvTZ sets the output timezone
    # ForceDate forces the current date to be now in the user's timezone,
    #    if we don't set it then DM uses the machine's timezone
    Date::Manip::Date_Init("TZ=$offset", "ConvTZ=$offset", "ForceDate=$now");

    my $datestr = Date::Manip::ParseDate($c) or return;
    my ($y, $m, $d) = $datestr =~ /^(\d\d\d\d)(\d\d)(\d\d)/ or return;

    return DateTime->new(
        year      => $y,
        month     => $m,
        day       => $d,
        time_zone => 'floating',
    );
}

=head2 parse_date_extract String -> Maybe DateTime

Parses VALUE with L<Date::Extract>.

=cut

sub parse_date_extract {
    my $self = shift;
    my $c = shift;

    my $tz = $self->current_user_has_timezone || 'UTC';

    my $parser = Date::Extract->new(
        prefers   => 'future',
        returns   => 'latest',
        time_zone => $tz,
    );

    return $parser->extract($c);
}


1;
