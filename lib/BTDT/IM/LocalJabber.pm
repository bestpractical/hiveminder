package BTDT::IM::LocalJabber;
use strict;
use warnings;
use HTML::Entities;
use base qw( BTDT::IM::Jabber );

use constant protocol => "Jabber";

=head2 login

Is a no-op, because we're B<in> the server.

=cut

sub login {
    my $self = shift;
    $self->log->info("Starting up a local Jabber bot.");
}

=head2 iteration

Shouldn't get called -- server notifies us on message reception

=cut

sub iteration
{
    my $self = shift;
    die "Local jabber doesn't do iterations\n";
}

=head2 send_message

Sends a message to the specified jid. This uses the extra argument passed to
received_message to make sure the subject, thread, resource, etc are the same
as what we received.

This also sends an HTML copy of the message, with probable record locators
linkified.

=cut

sub send_message
{
    my ($self, $recipient, $body, $cb) = @_;
    $body = $self->canonicalize_outgoing($body);

    # send out an HTMLified copy of the mail, with probably record locators
    # linkified (which comprises all of the HTML users actually care about)
    my $html = encode_entities($body, '&<>');

    # avoid interpreting &#39; as a record locator
    $html =~ s{(?<!&)#(\w+)}{<a href="http://task.hm/$1">#$1</a>}g;
    $html =~ s{\n}{<br />}g;

    $cb->reply($body, $html);
}

=head2 begin_metadata

Start a C<< <small> >> tag for metadata

=cut

sub begin_metadata { '<small>' }

=head2 end_metadata

Close the C<< <small> >> tag for metadata

=cut

sub end_metadata { '</small>' }

1;
