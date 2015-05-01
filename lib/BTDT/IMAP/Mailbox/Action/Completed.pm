package BTDT::IMAP::Mailbox::Action::Completed;

use warnings;
use strict;

use base qw/BTDT::IMAP::Mailbox::Action/;

=head1 NAME

BTDT::IMAP::Mailbox::Action::Completed - Completes a message

=head1 METHODS

=head2 name

The name of this mailbox is always "Completed"

=cut

sub name { "Completed" }

=head2 run MESSAGE

When a message is copied into this mailbox, mark it as complete.
Returns a virtual message.

=cut

sub run {
    my $self = shift;
    my $message = shift;

    $message->task_email->task->set_complete( 1 );

    return $self->next_message;
}

=head2 append BODY

When a message is appended to this mailbox, create a completed task.

=cut

sub append {
    my $self = shift;
    my $text = shift;
    return $self->append_with( $text, "", complete => 1 );
}

1;
