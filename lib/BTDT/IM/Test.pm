use strict;
use warnings;

=head1 NAME

BTDT::IM::Test

=head1 DESCRIPTION

Class for testing L<BTDT::IM>

=cut

package BTDT::IM::Test;
use base qw( BTDT::IM::AIM );

__PACKAGE__->mk_accessors(qw/sent/);

=head1 METHODS

=head2 setup

Just sets up the internal data structure for keeping messages

=cut

sub setup
{
    my $self = shift;
    $self->sent([]);

    $self->SUPER::setup(@_);
}

=head2 login

Avoid logging onto AIM

=cut

sub login {
}

=head2 send_message recipient, message

Adds the message to an internal queue.

=cut

sub send_message
{
    my ($self, $recipient, $message) = @_;
    $message = $self->canonicalize_outgoing($message);
    push @{$self->sent}, {recipient => $recipient, message => $message};
}

=head2 messages

Accessor for the message queue. Automatically clears the queue in the same go,
because that's handier than having a clear_messages method.

=cut

sub messages
{
    my $self = shift;
    return splice @{$self->sent};
}

=head2 iteration

Just avoids calling AIM's C<iteration>.

=cut

sub iteration { }

=head2 canonicalize_outgoing

Returns a message suitable for testing. We do NOT want to use the
canonicalize_outgoing of our direct superclass, AIM, because of encoding
issues.

=cut

sub canonicalize_outgoing
{
    my ($self, $message) = @_;
    $message = $self->BTDT::IM::canonicalize_outgoing($message);

    $message =~ s/<br.*?>/\n/g;

    return $message;
}

=head2 linkify

This changes locators to be surrounded in <...> so we can test that they're
properly being linked.

=cut

sub linkify
{
    my $self = shift;

    map {
        my $copy = $_;
        $copy = $copy->record_locator if ref($copy) && $copy->can('record_locator');
        $copy =~ s{^#?(.*)$}{<#$1>};
        $copy;
    } @_;
}

=head2 begin_metadata

Don't use a C<< <small> >> tag for metadata

=cut

sub begin_metadata { '' }

=head2 end_metadata

Don't use a C<< <small> >> tag for metadata

=cut

sub end_metadata { '' }

1;

