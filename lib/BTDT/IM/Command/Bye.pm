package BTDT::IM::Command::Bye;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'bye' command, which a better response to "bye" than "invalid command".

=cut

sub run
{
    my $im = shift;
    my %args = @_;

    my @byes =
    (
        'Bye for now, %n!',
        'See ya!',
    );

    my $response = $byes[rand @byes];
    $response =~ s/%n/$args{user}->name/eg;

    return $response;
}

1;
