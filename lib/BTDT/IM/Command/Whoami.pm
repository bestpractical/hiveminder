package BTDT::IM::Command::Whoami;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'whoami' command, which tells you about your Hiveminder account.

=cut

sub run
{
    my $im = shift;
    my %args = @_;

    my $email = $args{user}->email;
    my $name = $args{user}->name;
    my $screenname = $args{screenname};

    return "$screenname, you are $name ($email) on Hiveminder.";
}

1;
