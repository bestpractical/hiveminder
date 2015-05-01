use warnings;
use strict;

=head1 NAME

BTDT::Notification::EmailError::WrongSecret -- A bounce message when there's an
                                               error processing incoming mail

=head1 DESCRIPTION

We send a WrongSecret EmailError notification when we receive incoming mail
for with.hm that has the wrong secret.

=cut

package BTDT::Notification::EmailError::WrongSecret;

use base qw(BTDT::Notification::EmailError);

=head2 preface

Return an apologetic message explaining that an error happened,
including the text of the error.

=cut

sub preface {
    my $self = shift;
    my $to = $self->address;

    return <<"END_PREFACE";
You didn't provide the correct secret as part of the with.hm address $to.

Your email has not been processed and is included as an attachment with
this message.  Please double check or change your secret at

    @{[Jifty->web->url( path => '/prefs/addresses' )]}

END_PREFACE

}


1;
