use warnings;
use strict;

package BTDT::Notification::DailyReminder;
use base qw/BTDT::Notification::PeriodicReminder/;

=head1 NAME

BTDT::Notification::DailyReminder

=head2 starting

Takes a DateTime and returns the starting date of "one day before"

=cut

sub starting
{
    my $self  = shift;
    my $now   = shift;
    my $clone = $now->clone;
    $clone->subtract(days => 1);
    return $clone;
}

=head2 subject_period

Mon, Tue, etc. in the subject

=cut

sub subject_period
{
    my $self = shift;
    my $now = shift;

    return $now->day_name;
}

=head2 intro

Returns the introductory text.

=cut

sub intro {

return <<EOM;
Good morning!  Here's your daily Hiveminder update:

EOM

}

=head2 youdid_title

Returns a short title for "What you did yesterday"

=cut

sub youdid_title { "What you did yesterday" }

=head2 othersdid_title

Returns a short title for "What other people did for you yesterday"

=cut

sub othersdid_title { "What other people did for you yesterday" }

1;
