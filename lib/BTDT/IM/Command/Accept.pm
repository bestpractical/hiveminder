package BTDT::IM::Command::Accept;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'accept' command, for accepting re-assigned tasks.

=cut

sub run
{
    my $im = shift;
    return $im->_acceptance(@_);
}

1;
