use warnings;
use strict;

=head1 NAME

BTDT::Notification::EmailError::ProOnly -- A bounce message when there's an
                                           error processing incoming mail

=head1 DESCRIPTION

We send a ProOnly EmailError notification when we receive incoming mail that
only pro users should be able have handled.

=cut

package BTDT::Notification::EmailError::ProOnly;

use base qw(BTDT::Notification::EmailError);

=head2 preface

Return an apologetic message explaining that an error happened,
including the text of the error.  Also pitch Hiveminder Pro to
them.

=cut

sub preface {
    my $self = shift;
    my $to = $self->address;

    return <<"END_PREFACE";
We're sorry, but the email address $to is restricted
to Hiveminder Pro users.  Your email has not been processed and is
included as an attachment with this message.

If you'd like to be able to send mail to $to,
please upgrade to Hiveminder Pro at

    @{[Jifty->web->url( path => '/account/upgrade', scheme => 'https' )]}

To find out more about Hiveminder Pro, see

    @{[Jifty->web->url( path => '/pro/' )]}

END_PREFACE

}


1;
