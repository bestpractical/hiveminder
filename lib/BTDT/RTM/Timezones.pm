package BTDT::RTM::Timezones;

use strict;
use warnings;

use base 'BTDT::RTM';

=head1 NAME

BTDT::RTM::Timezones - Lists timezones

=head1 METHODS

=head2 method_getList

Lists all possible timezones.

=cut

sub method_getList {
    my $class = shift;

    my @timezones;
    my $now = DateTime->now;
    for my $tzname (DateTime::TimeZone->all_names) {
        my $tz = DateTime::TimeZone->new( name => $tzname );
        push @timezones, {
            id => @timezones+1,
            name => $tzname,
            dst => 0,  # lie
            offset => $tz->offset_for_datetime( $now ),
            current_offset => $tz->offset_for_datetime( $now ),
        };
    }

    $class->send_ok( timezones => { timezone => \@timezones } );
}

1;
