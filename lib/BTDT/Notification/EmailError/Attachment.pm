use warnings;
use strict;

=head1 NAME

BTDT::Notification::EmailError::Attachment -- A bounce message when there's an
error processing an attachment in incoming mail

=head1 DESCRIPTION

We send an Attachment EmailError notification when we receive incoming mail with
attachments which we are unable to process.

=cut

package BTDT::Notification::EmailError::Attachment;

use base qw(BTDT::Notification::EmailError);

__PACKAGE__->mk_accessors(qw(filename error));

=head2 preface

Return an apologetic message explaining that an error happened,
including the text of the error.

=cut

sub preface {
    my $self     = shift;
    my $filename = ( defined $self->filename and length $self->filename )
                      ? $self->filename
                      : "[unnamed]";

    return <<"END_PREFACE";
We're sorry, but we were unable to process an attachment ($filename) in
your email (see attached).

The error was: @{[$self->error]}

However, your email itself HAS been processed successfully and there
is no need to resend it.

END_PREFACE

}


1;
