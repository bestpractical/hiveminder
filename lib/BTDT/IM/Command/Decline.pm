package BTDT::IM::Command::Decline;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'decline' command, which refuses to accept a task assigned by someone else.

=cut

sub run
{
    my $im = shift;
    return $im->_acceptance(@_);
}

1;
