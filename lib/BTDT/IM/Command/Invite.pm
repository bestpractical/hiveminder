package BTDT::IM::Command::Invite;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'invite' command, which invites users to Hiveminder.

=cut

sub run {
    my $im = shift;
    my %args = @_;
    my $invitee;

    if ($args{message} =~ m{^(\S+@\S+)}) { $invitee = $1 }
    elsif ($args{message} =~ m{^me\b}i) {
        return "Believe it or not, you're using Hiveminder *right* *now*!";
    }
    else { return "I don't understand. Use: <b>invite</b> <i>email</i>" }

    my $invite = BTDT::Action::InviteNewUser->new(
        arguments => {
            email => $invitee,
        },
    );

    $invite->validate or return $invite->result->field_error('email');
    $invite->run;

    return $invite->result->message;
}

1;

