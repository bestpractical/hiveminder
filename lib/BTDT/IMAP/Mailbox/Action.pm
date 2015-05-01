package BTDT::IMAP::Mailbox::Action;

use warnings;
use strict;

use base qw/BTDT::IMAP::Mailbox/;

=head1 NAME

BTDT::IMAP::Mailbox::Action - Represents a virtual mailbox, where
copying or appending messages into it causes actions.

=head1 METHODS

=head2 run

By default, does nothing and returns the next virtual message, using
L</next_message>.

=cut

sub run {
    my $self = shift;
    return $self->next_message;
}

=head2 next_message

Returns a virtual message, which only has a uid set.  It does B<not>
show up in the message list of the mailbox, merely gets assigned a
unique UID, and advances the UIDNEXT of the mailbox accordingly.

=cut

sub next_message {
    my $self = shift;
    my $message = BTDT::IMAP::Message->new;
    $message->uid( $self->uidnext );
    $self->uidnext( $self->uidnext + 1 );
    $Net::IMAP::Server::Server->connection->force_poll;
    return $message;
}

=head2 append_with BODY, AUTO_ATTRIBUTES, PARAMHASH

Creates a new task.  The body of the task is extracted from the
C<BODY>, as if it were an incoming email.  C<AUTO_ATTRIBUTES> is as if
it had those braindump properties applied to it.  Any other values in
the PARAMHASH are used as fallback properties for the call to
L<BTDT::Model::Task/create>.

The exception to this is if the APPEND'ed task is from OfflineIMAP,
which APPENDs instead of COPYing messages between folders.  We detect
this and re-dispatch to L</run> on the proper task.

=cut

sub append_with {
    my $self = shift;

    my ($text, $braindump, %defaults) = @_;
    local $Email::MIME::ContentType::STRICT_PARAMS = 0;
    my $email = Email::MIME->new( $text );

    return $self->handle_offlineimap($email) if $self->is_offlineimap($email);

    $defaults{requestor_id}  = $self->current_user->user_object->id;
    $defaults{summary}       = $email->header("Subject");
    $defaults{parse}         = $braindump;
    $defaults{email_content} = $text;

    my $t = BTDT::Model::Task->new( current_user => $self->current_user );
    $t->create( %defaults );
    return unless $t->id;

    return $self->next_message;
}

=head2 copy_allowed

Action mailboxes allow messages to be copied out of them.

=cut

sub copy_allowed { 1 }

1;
