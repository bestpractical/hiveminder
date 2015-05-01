use warnings;
use strict;

=head1 NAME

BTDT::View::Review

=cut

package BTDT::View::Review;
use Jifty::View::Declare -base;
__PACKAGE__->use_mason_wrapper;

sub review_dates {
    my $self = shift;
    my $dt = BTDT::DateTime->today;

    my $tomorrow = $dt->intuit_date_explicit("tomorrow");
    my $two_days = $dt->intuit_date_explicit("in 2 days");
    my $month    = $dt->intuit_date_explicit("in 1 month");
    my $saturday = $dt->intuit_date_explicit("saturday");
    my $monday   = $dt->intuit_date_explicit("monday");

    for ($saturday, $monday) {
        $_ = $_->add( weeks => 1 )
            if $two_days >= $_;
    }

    return sort { $a->{date} <=> $b->{date} } (
        {
            date              => $tomorrow,
            label             => 'Tomorrow',
            key_binding       => 1,
            key_binding_label => 'Tomorrow',
        },
        {
            date              => $two_days,
            label             => $two_days->day_name . " - 2 days",
            key_binding       => 2,
            key_binding_label => 'Two days',
        },
        {
            date              => $saturday,
            label             => 'Saturday - ' . $self->delta_days($saturday - $dt),
            key_binding       => 'S',
            key_binding_label => 'Saturday',
        },
        {
            date              => $monday,
            label             => 'Monday - ' . $self->delta_days($monday - $dt),
            key_binding       => 'M',
            key_binding_label => 'Monday',
        },
        {
            date              => $month,
            label             => 'Next month - ' . $month->day . ' ' . $month->month_abbr,
            key_binding       => 'Z',
            key_binding_label => 'A month',
        },
    );
}

sub delta_days {
    my $self  = shift;
    my $delta = shift->delta_days;
    return $delta." day".( $delta > 1 ? "s" : "" );
}

1;

