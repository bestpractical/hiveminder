use strict;
use warnings;

=head1 NAME

BTDT::Action::RemoveGiftRecipient

=cut

package BTDT::Action::RemoveGiftRecipient;
use base qw/BTDT::Action Jifty::Action/;

use Jifty::Param::Schema;
use Jifty::Action schema {
    param 'user_id' =>
        is mandatory;
};

=head2 take_action

Removes the user_id from the session's gift users

=cut

sub take_action {
    my $self = shift;
    $self->report_success if not $self->result->failure;
    return 1;
}

=head2 report_success

Removes the user_id from the session's gift users

=cut

sub report_success {
    my $self = shift;
    my $id   = $self->argument_value('user_id');

    my $saved = Jifty->web->session->get('giftusers') || [];

    $saved = [ grep { $_ ne $id } @$saved ];

    Jifty->web->session->set( giftusers => $saved );
}

1;
