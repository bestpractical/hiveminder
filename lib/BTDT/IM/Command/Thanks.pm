package BTDT::IM::Command::Thanks;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'thanks' command, which gives a better response to "thanks" than
"invalid command".

=cut

sub run
{
    my $im = shift;
    my %args = @_;

    my @responses =
    (
        "You're welcome!",
        "Don't mention it!",
        "Just doing my job, %n!",
    );

    my $response = $responses[rand @responses];
    $response =~ s/%n/$args{user}->name/eg;

    return $response;
}

1;

