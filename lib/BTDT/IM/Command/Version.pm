package BTDT::IM::Command::Version;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'version' command, which reports the Hiveminder git revision name.
This is reported in the web UI too, where it's useful for detecting that
services were properly restarted.

=cut

sub run {
    return 'Hiveminder revision: ' . BTDT->git_revision . '.';
}

1;

