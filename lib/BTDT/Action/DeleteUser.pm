use warnings;
use strict;


=head1 NAME

BTDT::Action::DeleteUser

=cut

package BTDT::Action::DeleteUser;

use base qw/Jifty::Action::Record::Delete/;

=head2 record_class

This deletes L<BTDT::Model::User> objects.

=cut

sub record_class { 'BTDT::Model::User'  }

=head2 report_success

Sets the message to "Accont Deleted."

=cut

sub report_success {
    my $self = shift;
    $self->result->message("Account deleted.");
}

=head2 take_action

Send an email right before we delete their account

=cut

sub take_action {
    my $self = shift;

    BTDT::Notification::AccountDeleted->new( to => $self->record )->send;
    $self->SUPER::take_action or return;
    Jifty->web->current_user( undef );

    return 1;
}

1;
