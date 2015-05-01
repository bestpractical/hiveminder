use warnings;
use strict;

=head1 NAME

BTDT::Notification::EmailError::Loop -- A bounce message when there's an
                                               error processing incoming mail

=head1 DESCRIPTION

We send a Loop EmailError notification when we receive email that appears to be from hiveminder.

=cut

package BTDT::Notification::EmailError::Loop;

use base qw(BTDT::Notification::EmailError);

=head2 preface

Return an apologetic message explaining that an error happened,
including the text of the error.

=cut

sub preface {
    my $self = shift;
    my $to = $self->address;

    return <<"END_PREFACE";
The message you sent appears to be part of a mail loop. If you're not sure
what happened, please contact us on the web at:
    @{[Jifty->web->url( path => '/' )]}

I'm quite sorry for any trouble this might have caused you.

Love and smooches,

Hiveminder




END_PREFACE

}


1;
