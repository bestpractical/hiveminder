use warnings;
use strict;

package BTDT::Notification::AccountDeleted;
use base qw/BTDT::Notification/;

=head1 NAME

BTDT::Notification::AccountDeleted

=head2 setup

Sets up the email.

=cut

sub setup {
    my $self = shift;
    $self->SUPER::setup(@_);

    $self->subject("We're sorry to see you go.");

    $self->body(<<"END_BODY");
Your Hiveminder account has been deleted.

END_BODY

    $self->html_body( $self->body );
}

=head2 preface

Don't be so cheery with our greeting since it's a parting

=cut

sub preface {
    my $self = shift;
    return _('Goodbye, %1.', $self->to->name );
}

1;
