use warnings;
use strict;

=head1 NAME

BTDT::Notification::EmailError -- A bounce message when there's an
                                  error processing incoming mail

=head1 DESCRIPTION

We send an EmailError notification when we receive incoming mail that
we get an error handling, for whatever reason.

=cut

package BTDT::Notification::EmailError;

use base qw(BTDT::Notification);

__PACKAGE__->mk_accessors(qw(result email address));

=head2 result

A Jifty::Result of the action that failed that caused us to send this
bounce.

=head2 email

The text of the email that we received that generated the error.

=head2 address

The address to which the user attempted to send mail.

=head2 setup

Set up our subject and sender

=cut

sub setup {
    my $self = shift;

    $self->subject('Hiveminder.com -- Error processing email');
    $self->from('Hiveminder <postmaster@hiveminder.com>');
}

=head2 preface

Return an apologetic message explaining that an error happened,
including the text of the error.

=cut

sub preface {
    my $self = shift;
    my $to = $self->address;
    my $error = $self->result->error;

    return <<"END_PREFACE";
We're sorry, but we encountered an error processing your email to us
at $to.

The error was: $error

We hope we didn't mess up your day too badly with this. Drop us a line
at support\@hiveminder.com if you need help fixing this problem, or
try again in a little while.

END_PREFACE

}

=head2 parts

Returns the body, as well as an attachment of the original message.

=cut

sub parts {
    my $self = shift;
    return [
        @{$self->SUPER::parts},
        Email::MIME->create(
            attributes => {
                content_type => 'message/rfc822',
                disposition => 'attachment',
            },
            body => Encode::encode_utf8($self->email),
           )
       ];
}




1;
