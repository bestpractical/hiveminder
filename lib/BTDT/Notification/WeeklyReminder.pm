use warnings;
use strict;

package BTDT::Notification::WeeklyReminder;
use base qw/BTDT::Notification::PeriodicReminder/;

=head1 NAME

BTDT::Notification::WeeklyReminder

=head2 starting

Takes a DateTime and returns the starting date of "one week before"

=cut

sub starting
{
    my $self  = shift;
    my $now   = shift;
    my $clone = $now->clone;
    $clone->subtract(weeks => 1);
    return $clone;
}

=head2 subject_period

"week of Aug 12"

=cut

sub subject_period
{
    my $self = shift;
    my $now = shift;

    return sprintf 'week of %s %d', $now->month_abbr, $now->day;
}

=head2 intro

Returns the introductory text.

=cut

sub intro {

return <<EOM;
Good morning!  Here's your weekly Hiveminder update:

EOM

}

=head2 youdid_title

Returns a short title for "What you did this week"

=cut

sub youdid_title { "What you did this week" }

=head2 othersdid_title

Returns a short title for "What other people did for you this week"

=cut

sub othersdid_title { "What other people did for you this week" }

1;
