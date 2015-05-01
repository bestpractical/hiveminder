package BTDT::IM::Command::Unlink;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'unlink' command, which unlinks your IM account from your Hiveminder
account.

=cut

sub run
{
    my $im = shift;
    my %args = @_;

    my ($ok, $msg) = $args{userim}->delete;
    my $email = $args{user}->email;

    if ($ok) {
        return "Your IM account successfully unlinked from $email.";
    }

    $im->log->error("Unable to unlink $args{screenname} from $email: $msg");
    return "I'm unable to unlink your IM account. Please contact us by using the 'feedback' command.";
}

1;
