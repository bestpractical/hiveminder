use warnings;
use strict;

=head1 NAME

BTDT::Action::SendLostPasswordConfirmation

=cut

package BTDT::Action::SendLostPasswordConfirmation;
use base qw/BTDT::Action Jifty::Action/;

use BTDT::Model::User;

=head2 arguments

The field for C<SendLostPasswordConfirmation> is:

=over 4

=item address: the email address

=back

=cut

sub arguments {
    return (
        {
            address => {
                label     => 'Email address',
                mandatory => 1,
                ajax_validates => 1,
            },
        }
    );

}

=head2 validate_address

Make sure there's actually an account by that name.

=cut

sub validate_address {
    my $self  = shift;
    my $email = shift;

    return BTDT->validate_user_email( action => $self, column => "address", value => $email, existing => 1, implicit => 0 );
}

=head2 take_action

Send out a confirmation email giving a link to a password-reset form.

=cut

sub take_action {
    my $self = shift;

    my $user = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
    $user->load_by_cols( email => $self->argument_value('address') );

    BTDT::Notification::ConfirmLostPassword->new( to => $user )->send;
    $self->result->message("We have sent a link to your email account for re-setting your password.");

    return 1;
}

1;
