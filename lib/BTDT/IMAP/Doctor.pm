package BTDT::IMAP::Doctor;
use strict;
use warnings;

use base qw/Net::IMAP::Server::Command/;

use Chatbot::Eliza;

__PACKAGE__->mk_accessors(qw/doctor/);

=head1 NAME

BTDT::IMAP::Doctor - Implement an DOCTOR command in IMAP

=head1 DESCRIPTION

This adds an extra IMAP command, DOCTOR, which allows authorized users
to chat with the ELIZA program.

=head1 METHODS

=head2 validate

Acts as if the command doesn't exist unless the user is logged in.
Takes no options.

=cut

sub validate {
    my $self = shift;

    # Act as if this command doesn't exist, if they're not auth'd
    return $self->SUPER::run if $self->connection->is_unauth;

    return $self->bad_command("Too many options") if $self->parsed_options;

    return 1;
}

=head2 run

Instantiates a new L<Chatbot::Eliza> instance, and sets up the
C</continue> for later messages, using
L<Net::IMAP::Server::Connection/pending>.

=cut

sub run {
    my $self = shift;
    $self->doctor(Chatbot::Eliza->new());
    $self->connection->pending(sub {$self->continue(@_)});
    my @initial = @{$self->doctor->{initial}};
    $self->out("+ ".$initial[ rand( @initial ) ]);
}

=head2 continue

Called on each successive message from the client; calls
L<Chatbot::Eliza/transform>, and sends it to the client.

=cut

sub continue {
    my $self = shift;
    my $line = shift;
    $line =~ s/[\r\n]+$//;
    if ($self->doctor->_testquit($line)) {
        $self->connection->pending(undef);
        return $self->ok_completed;
    } else {
        $self->out("+ ".$self->doctor->transform($line));
    }
}

1;
