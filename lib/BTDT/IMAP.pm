package BTDT::IMAP;

use warnings;
use strict;

use base 'Net::IMAP::Server';

use Coro;
use BTDT::IMAP::Monitor;

=head1 NAME

BTDT::IMAP - Basic IMAP server for tasks

=cut


# This should be bumped anytime there has been a change in the layout
# or content of messages.  The actual value is stored in the config.
$BTDT::IMAP::UIDVALIDITY = undef;

=head2 new PARAMHASH

Creates an IMAP server which listens on the ports as specified in the
configuration file.  The model class is L<BTDT::IMAP::Model>, the aut
class is L<BTDT::IMAP::Auth>.

=cut

sub new {
    my $class = shift;
    $BTDT::IMAP::UIDVALIDITY = Jifty->config->app('IMAP')->{uidvalidity};

    my $self = $class->SUPER::new(
        auth_class  => "BTDT::IMAP::Auth",
        model_class => "BTDT::IMAP::Model",
        connection_class => "BTDT::IMAP::Connection",
        port        => Jifty->config->app('IMAP')->{port},
        ssl_port    => Jifty->config->app('IMAP')->{ssl_port},
        user        => Jifty->config->app('IMAP')->{user},
        group       => Jifty->config->app('IMAP')->{group},
        poll_every  => Jifty->config->app('IMAP')->{poll_every},
        @_,
    );

    $self->sync_bytes;
    $self->add_command( DOCTOR => "BTDT::IMAP::Doctor" );

    return $self;
}

=head2 run

Start up the IMAP monitor, in addition to the main server.

=cut

sub run {
    my $self = shift;

    async \&BTDT::IMAP::Monitor::run, $self
        if Jifty->config->app("IMAP")->{monitor_port};

    $self->SUPER::run(@_);
}

=head2 id

Returns a custom ID string for the ID command.

=cut

sub id {
    return (
        name    => "Hiveminder IMAP",
        version => "1.0",
    );
}

=head2 bytes DIRECTION [, VALUE]

With no C<VALUE> returns the number of bytes either C<sent> or
C<received>,depending on the value of C<DIRECTION>.  If C<VALUE> is
given, increases the number of bytes by that C<VALUE>.

=cut

sub bytes {
    my $self = shift;
    my $key = "bytes_" . shift;
    if (@_) {
        $self->{$key} += $_[0];
    }
    return $self->{$key};
}

=head2 sync_bytes

If the server has no record of bytes sent and received yet, loads it
from the database.  Otherwise, updates the database with the internal
value.

=cut

sub sync_bytes {
    my $self = shift;
    for my $type (qw/sent received/) {
        if (defined $self->bytes($type)) {
            Jifty::Model::Metadata->store( "imap_bytes_$type" => $self->bytes($type));
        } else {
            $self->bytes($type => Jifty::Model::Metadata->load( "imap_bytes_$type" ) || 0);
        }
    }
}

=head2 logger

Returns the L<Log::Log4perl> logger for this class.

=cut

sub logger {
    my $self = shift;
    return Log::Log4perl->get_logger(ref($self) || $self);
}

=head2 write_to_log_hook LEVEL, MSG

Hook L<Net::Server>'s logging into L<Log::Log4perl> for all of our
logging needs.

=cut

sub write_to_log_hook {
    my $self = shift;
    my ($level, $msg) = @_;
    my @levels = qw/error warn info debug trace/;
    $level = $levels[$level];
    chomp $msg;
    $self->logger->$level($msg);
}

=head2 server_exit

When closing the server, synchronize the bytes sent, and close the
monitor port.

=cut

sub server_exit {
    my $self = shift;
    $self->{monitor}->close if $self->{monitor};
    $self->sync_bytes;
    exit;
}

1;
