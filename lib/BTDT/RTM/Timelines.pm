package BTDT::RTM::Timelines;

use strict;
use warnings;

use base 'BTDT::RTM';

=head1 NAME

BTDT::RTM::Timelines - Stub of timeline support

=head1 METHODS

=head2 method_create

Simply returns a per-second ascending integer.

=cut

sub method_create {
    my $class = shift;
    $class->require_user;
    $class->send_ok(
        timeline => scalar time,
    );
}

1;
