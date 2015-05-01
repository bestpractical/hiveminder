use strict;
use warnings;

=head1 NAME

BTDT::IM::Shell

=head1 DESCRIPTION

Class to let you interact with the IM system in your shell. You may also use
eval (by prefixing the code with a tilde: C<~1 + 1>). This is most useful for
inspecting and modifying C<$self>. You invoke this with
C<bin/im --shell=SCREENNAME>. The screenname is taken to be an AIM SN. When we
add other protocols this will be less hardcoded.

=cut

package BTDT::IM::Shell;
use base qw( BTDT::IM );

use constant protocol => "AIM"; # so we don't need another valid_value
__PACKAGE__->mk_accessors(qw/screenname/);

=head1 METHODS

=head2 setup

Autoflush the output stream.

=cut

sub setup
{
    my $self = shift;
    $| = 1;
    $self->SUPER::setup(@_);
}

=head2 send_message recipient, message

Prints the message to the screen

=cut

sub send_message
{
    my ($self, $recipient, $message) = @_;
    $message = $self->canonicalize_outgoing($message);
    print $message;
}

=head2 iteration

Read a line of input

=cut

sub iteration
{
    my $self = shift;

    print "> ";
    my $input = <>;
    exit if !defined($input);

    $self->received_message($self->screenname, $input);
}

=head2 canonicalize_outgoing message

Makes sure there's a newline on the message.

=cut

sub canonicalize_outgoing
{
    my $self = shift;
    my $message = shift;

    $message = $self->SUPER::canonicalize_outgoing($message);
    $message .= "\n";
}

=head2 linkify TASKS

Returns tasks linked in <#foo> format.

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

1;


