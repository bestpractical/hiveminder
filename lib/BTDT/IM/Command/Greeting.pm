package BTDT::IM::Command::Greeting;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'greeting' command, which gives a better response to "hi" than
"invalid command".

=cut

sub run
{
    my $im = shift;
    my %args = @_;

    my @greetings =
    (
        'Hiya %n!',
        'Hullo, how may I serve you today?',
        "Hello, this is an operator. Let's have a normal, human interaction.",
    );

    my $response = $greetings[rand @greetings];
    $response =~ s/%n/$args{user}->name/eg;

    return $response;
}

1;
