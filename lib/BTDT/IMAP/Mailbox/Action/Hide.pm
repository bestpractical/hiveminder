package BTDT::IMAP::Mailbox::Action::Hide;

use warnings;
use strict;

use base qw/BTDT::IMAP::Mailbox::Action/;

__PACKAGE__->mk_accessors(qw(days months));

=head1 NAME

BTDT::IMAP::Mailbox::Action::Hide - Hides the task for some amount of
time

=head1 METHODS

=head2 days [DAYS]

Gets or sets the number of days that this mailbox will hide messages
for.

=head2 months [DAYS]

Gets or sets the number of months that this mailbox will hide messages
for.

=head2 name

Returns an appropriate name, based on the number of L</days> or
L</months>.

=cut

sub name {
    my $self = shift;
    if ($self->days) {
        return $self->days > 1 ? sprintf("%02d days", $self->days) : "01 day";
    } else {
        return $self->months > 1 ? sprintf("%02d months", $self->months) : "01 month";
    }
}

=head2 until

Returns, as a L<BTDT::DateTime>, the day that messages will be hidden
until.

=cut

sub until {
    my $self = shift;
    my $until = BTDT::DateTime->now;
    $until->add(days => $self->days) if $self->days;
    $until->add(months => $self->months) if $self->months;
    return $until;
}

=head2 run MESSAGE

Sets the start date of the message.  Returns a virtual message.

=cut

sub run {
    my $self = shift;
    my $message = shift;

    $message->task_email->task->set_starts( $self->until->ymd );

    return $self->next_message;
}

=head2 append BODY

When a message is appended, sets the start date.

=cut

sub append {
    my $self = shift;
    my $text = shift;

    return $self->append_with( $text, "[hide: @{[$self->until->ymd]}]" );
}

1;
