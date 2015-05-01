package BTDT::IMAP::Mailbox::Action::Braindump;

use warnings;
use strict;

use base qw/BTDT::IMAP::Mailbox::Action/;

__PACKAGE__->mk_accessors( qw/published_address/ );

=head1 NAME

BTDT::IMAP::Mailbox::Action::Braindump - Incoming email address

=head1 METHODS

=head2 new HASHREF

The name of the mailbox is the set of auto_attributes from the
L</published_address>, or C<[]>.

=head2 published_address [ADDRESS]

Gets or sets the L<BTDT::Model::PublishedAddress> associated with this
mailbox.

=cut

sub new {
    my $class = shift;
    my $args = shift;
    $args->{name} = $args->{published_address}->auto_attributes || "[]";
    my $self = $class->SUPER::new($args);
    return $self;
}

=head2 load_data

When initialized, adds a single mail message, whose C<From> is the
email address associated with this L</published_address>.

=cut

sub load_data {
    my $self = shift;

    my $email = Email::Simple->new("");
    $email->header_set( "Subject"  => $self->published_address->address );
    $email->header_set( "From"     => $self->published_address->address . '@my.hiveminder.com' );

    $self->messages([]);
    my $message = BTDT::IMAP::Message->new($email->as_string);
    $self->add_message($message);
}

=head2 uidvalidity

The UIDVALIDITY of this mailbox is based on both the
L</published_address>'s id, as well as the global UIDVALIDITY.

=cut

sub uidvalidity {
    my $self = shift;
    return $BTDT::IMAP::UIDVALIDITY + $self->published_address->id;
}

=head2 delete

Removing this mailbox removes the published address, as well.

=cut

sub delete {
    my $self = shift;

    $self->published_address->delete;

    Net::IMAP::Server::Mailbox::delete($self);
}

=head2 run BODY

Copying an existing message into this mailbox updates the task with
the auto attributes, using L<BTDT::Model::Task/update_from_braindump>.
It then returns a virtual message.

=cut

sub run {
    my $self = shift;
    my $message = shift;

    $message->task_email->task->update_from_braindump( $self->published_address->auto_attributes );

    return $self->next_message;
}

=head2 append

Appending to this mailbox is the same as sending email to the
published address.

=cut

sub append {
    my $self = shift;
    my $text = shift;
    return $self->append_with( $text, $self->name );
}

1;
