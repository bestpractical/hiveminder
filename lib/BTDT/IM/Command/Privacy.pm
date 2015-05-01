package BTDT::IM::Command::Privacy;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'privacy' command, which links to our privacy policy.

=cut

sub run
{
    return '<p>You can find our privacy policy at: <a href="http://hiveminder.com/legal/privacy">http://hiveminder.com/legal/privacy</a>.</p>'
}

1;
