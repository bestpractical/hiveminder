package BTDT::RTM::Settings;

use strict;
use warnings;

use base 'BTDT::RTM';

=head1 NAME

BTDT::RTM::Settings - User settings

=head1 METHODS

=head2 method_getList

Returns timezone settings.

=cut

sub method_getList {
    my $class = shift;
    $class->require_user;

    $class->send_ok(
        settings => {
            timezone => $class->user->time_zone,
            dateformat => 0,
            timeformat => 0,
            defaultlist => 1,
        }
    );
}

1;
