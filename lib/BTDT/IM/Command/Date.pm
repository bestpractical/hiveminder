package BTDT::IM::Command::Date;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'date' command, which tells you the current date.

=cut

sub run
{
    my $now = BTDT::DateTime->now;
    return sprintf 'It is %s %s in your time zone, %s.',
        $now->ymd,
        $now->hms,
        $now->time_zone->name;
}

1;

