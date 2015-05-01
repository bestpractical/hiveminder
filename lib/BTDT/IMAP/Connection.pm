package BTDT::IMAP::Connection;

use warnings;
use strict;

use base qw/Net::IMAP::Server::Connection/;
use Coro::Debug;
use Time::HiRes qw//;

__PACKAGE__->mk_accessors( qw/connected_at compute_time/ );

=head1 NAME

BTDT::IMAP::Connection

=head1 DESCRIPTION

Overrides logging and capability handling of the standard IMAP
connection class, L<Net::IMAP::Server::Connection>.

=head1 METHODS

=head2 greeting

Give a more hiveminder-specific server greeting.

=cut

sub greeting {
    my $self = shift;
    $self->connected_at(time);
    $self->untagged_response("OK Hiveminder IMAP4rev1 server");
}

=head2 logger

Returns the L<Log::Log4perl> logger for this class.

=cut

sub logger {
    my $self = shift;
    return Log::Log4perl->get_logger(ref($self) || $self);
}

=head2 log

Logging is controlled by the BTDT.IMAP.Connection facility in the
Log::Log4perl configuration.

=cut

sub log {
    my $self = shift;
    my $level = shift;
    my @lines = map {chomp; $_} @_;
    Coro::Debug::log(5, $_) for @lines;
    $self->logger->debug($_) for @lines;
}

=head2 capability

If the connection is logged in, advertise the X-DOCTOR capability.

=cut

sub capability {
    my $self = shift;
    my $str = $self->SUPER::capability;
    $str .= " X-DOCTOR" if $self->is_auth;
    return $str;
}

=head2 bytes DIRECTION [, VALUE]

With no C<VALUE> returns the number of bytes either C<sent> or
C<received>,depending on the value of C<DIRECTION>.  If C<VALUE> is
given, increases the number of bytes by that C<VALUE>.

=cut

sub bytes {
    my $self = shift;
    my $dir = shift;
    my $key = "bytes_$dir";
    if (@_) {
        $self->{$key} += $_[0];
        $self->server->bytes($dir => @_);
    }
    return $self->{$key};
}

=head2 out CONTENT

In addition to sending content to the client, also increases the byte
count.

=cut

sub out {
    my $self = shift;
    my $content = shift;

    $self->bytes(sent => length($content));
    $self->SUPER::out($content);
}

=head2 handle_command CONTENT

Inaddition to handling the command, also increases the count of bytes
received from the client.

=cut

sub handle_command {
    my $self = shift;
    my $content = shift;

    $self->bytes(received => length($content));

    my $prefix = "!(@{[$self]},@{[$self->auth ? $self->auth->user : '???']},@{[$self->is_selected ? $self->selected->full_path : 'unselected']})";
    my $before = Time::HiRes::time();
    my $cmd = $self->SUPER::handle_command($content);
    my $duration = Time::HiRes::time() - $before;
    $self->compute_time( ($self->compute_time || 0) + $duration );

    if ($duration > 3) {
        chomp $content;
        if ($cmd and $cmd->isa("Net::IMAP::Server::Command::Login") or $cmd->isa("Net::IMAP::Server::Command::Authenticate")) {
            my ($user) = $cmd->parsed_options;
            $content = $cmd->command_id . " (login $user)";
        }
        $self->logger->info("$prefix -- $duration seconds -- $content");
    }
}

=head2 update_timer

When we update the inactivity timer, store how long it started
counting dowm from, so we can tell how long we've been idle.

=cut

sub update_timer {
    my $self = shift;
    $self->SUPER::update_timer;
    $self->timer->data( $self->is_unauth ? $self->server->unauth_idle : $self->server->auth_idle )
        if $self->timer;
}

=head2 idle_time

Returns how long, in seconds, the connection has been idle.

=cut

sub idle_time {
    my $self = shift;
    return undef unless $self->timer;
    return $self->timer->data - $self->timer->remaining;
}

=head2 close

When closing the connection, update the server's count of bytes sent.

=cut

sub close {
    my $self = shift;
    $self->server->sync_bytes;
    $self->SUPER::close;
}


1;
