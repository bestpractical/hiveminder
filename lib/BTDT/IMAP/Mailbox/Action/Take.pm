package BTDT::IMAP::Mailbox::Action::Take;

use warnings;
use strict;

use base qw/BTDT::IMAP::Mailbox::Action/;

=head1 NAME

BTDT::IMAP::Mailbox::Action::Take - Claims a message

=head1 METHODS

=head2 name

The name of this mailbox is always "Take"

=cut

sub name { "Take" }

=head2 run MESSAGE

When a message is copied, set the owner to the current user.

=cut

sub run {
    my $self = shift;
    my $message = shift;

    $message->task_email->task->set_owner_id( $self->current_user->id );

    return $self->next_message;
}


=head2 append BODY

When a message is appended to this mailbox, create a task owned by the
user.

=cut

sub append {
    my $self = shift;
    my $text = shift;
    return $self->append_with( $text, "", owner_id => $self->current_user->id );
}

1;
