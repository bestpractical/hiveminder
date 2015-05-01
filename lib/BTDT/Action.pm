use warnings;
use strict;

package BTDT::Action;
use BTDT::DateTime;

=head1 NAME

BTDT::Action - Do Stuff in BTDT

=head1 DESCRIPTION

Provides mumble actions mumble.  Overrides Jifty::Action.

=head2 _canonicalize_date

Parses and returns the date using L<BTDT::DateTime::intuit_date_explicit>.

=cut

sub _canonicalize_date {
    my $self = shift;
    my $val = shift;
    return undef unless defined $val and $val =~ /\S/;
    return undef unless my $dt = BTDT::DateTime->intuit_date_explicit($val);
    return $dt->ymd;
}

1;
