package BTDT::Action::CloseIMAPConnection;
use warnings;
use strict;
use base qw/BTDT::Action/;

use IO::Socket;

=head2 NAME

BTDT::Action::CloseIMAPConnection - close an IMAP connection

=cut

use Jifty::Param::Schema;
use Jifty::Action schema {
    param 'coro' =>
        label is 'Coroutine ID',
        ajax validates,
        is mandatory,
        documentation is "The Coroutine ID of the connection to close";

    param 'method' =>
        label is 'Method',
        is mandatory,
        documentation is "How rude to be when closing it down",
        valid_values are [qw/close kill/];
};

=head2 validate_coro

The C<coro> argument is required, and must be numeric.

=cut

sub validate_coro {
    my $self = shift;
    my $coro = shift;

    if ($coro =~ /\D/) {
        return $self->validation_error(coro => "That isn't numeric");
    }
}

=head2 take_action

Requires staff privileges; closes or kills the appropriate IMAP connection.

=cut

sub take_action {
    my $self = shift;
    return $self->result->error("Permission denied")
      unless $self->current_user->is_staff;

    my $socket = IO::Socket::INET->new(
        PeerHost => "localhost",
        PeerPort => Jifty->config->app("IMAP")->{monitor_port},
    );

    return $self->result->error("IMAP server down?") unless $socket;

    $socket->print($self->argument_value("method") . " " . $self->argument_value("coro")."\n");
    my $message = $socket->getline; chomp $message;
    if ($message) {
        $self->result->message($message);
    } else {
        $self->result->error("Failed -- no response from IMAP?");
    }
    $socket->close;
}

1;
