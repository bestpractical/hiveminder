package BTDT::IMAP::Monitor;

use warnings;
use strict;

use Coro;
use Coro::Socket;
use Coro::State;
use Coro::Debug;
use Socket;

=head1 NAME

BTDT::IMAP::Monitor - Local socket for reporting IMAP status

=head1 DESCRIPTION

Creates a Coro-driven server which listens to one-line commands on a
local port.

=head1 METHODS

=head2 run SERVER

Starts listening on the given C<< application -> IMAP -> monitor_port
>> port on localhost, and reports on the stats of connections on the
given L<Net::IMAP::Server> C<SERVER>.  This function does not return,
and should be run in its own L<Coro> thread.

=cut

sub run {
    my $server = shift;

    my $listen = IO::Socket::INET->new(
        LocalHost => "localhost",
        LocalPort => Jifty->config->app("IMAP")->{monitor_port},
        Listen    => Socket::SOMAXCONN(),
        Reuse     => 1,
        Proto     => 'tcp',
    );
    die $@ unless $listen;
    $listen = Coro::Socket->new_from_fh($listen);
    die $@ unless $listen;
    $server->{monitor} = $listen;
    while (1) {
        my $socket = $listen->accept;
        next unless $socket;

        async {
            eval { connection($server, $socket) };
            my $err = $@;
            $server->logger->warn($err) if $err;
        };
    }
}

=head2 connection

Reads one line from the client and dispatches based on it.

=cut

sub connection {
    my ($server, $socket) = @_;

    my $command = lc $socket->readline;
    chomp $command;
    if ( $command eq "list" ) {
        list($server, $socket);
    } elsif ($command =~ /^close (\d+)/i) {
        close_conn($server, $socket => $1);
    } elsif ($command =~ /^kill (\d+)/i) {
        kill_conn($server, $socket => $1)
    } elsif ($command eq "memory") {
        memory($server, $socket);
    } elsif ($command =~ m{^debug (/.*)}) {
        $server->{debug} = Coro::Debug->new_unix_server($1);
    } elsif ($command eq "stop-debug") {
        undef $server->{debug};
    }
    $socket->close;
}

=head2 list

Lists the active connections, one per line.

=cut

sub list {
    my ($server, $socket) = @_;

    for my $conn (
        map { $_->[1] } sort {
                   $a->[0] <=> $b->[0]
                or $a->[1]->commands <=> $b->[1]->commands
        } map {
            [ $_->auth ? $_->auth->current_user->id : 0, $_ ]
        } @{ $server->connections }
        )
    {
        $socket->print(
            join( "\t",
                eval { $conn->io_handle->peerhost } || 'disconnected?',
                $conn->auth     ? $conn->auth->current_user->id : '',
                $conn->selected ? $conn->selected->full_path    : '',
                $conn->commands          || 0,
                $conn->bytes("sent")     || 0,
                $conn->bytes("received") || 0,
                $conn->coro + 0,
                $conn->idle_time         || 0,
                $conn->compute_time      || 0,
                $conn->connected_at,
                )
                . "\n"
        );
    }
}

=head2 close_conn

Closes an active connection.

=cut

sub close_conn {
    my ($server, $socket, $id) = @_;
    for my $c (grep {$_->coro + 0 == $id} @{ $server->connections }) {
        $c->coro->throw("Forcibly closed\n");
        $c->coro->ready;
    }
    $socket->print("Connection closed");
}

=head2 kill_conn

Kills the connection and coro thread.

=cut

sub kill_conn {
    my ($server, $socket, $id) = @_;
    for my $c (grep {$_->coro + 0 == $1} @{ $server->connections }) {
        $c->close;
        $c->coro->cancel;
    }
    $socket->print("Connection killed");
}

=head2 memory

Prints a (long) summary of memory usage.

=cut

sub memory {
    my ($server, $socket) = @_;

    require Devel::Size::Report;
    $socket->print(Devel::Size::Report::report_size(BTDT::IMAP::Model->roots));
}

1;
