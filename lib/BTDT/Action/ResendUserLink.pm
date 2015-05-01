use warnings;
use strict;

=head1 NAME

BTDT::Action::SendActivationLink

=cut

package BTDT::Action::ResendUserLink;
use base qw/BTDT::Action Jifty::Action/;

__PACKAGE__->mk_accessors(qw(user_object));

use BTDT::Model::User;

=head2 arguments

The field for C<SendActivationLink> is:

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

=head2 setup

Create an empty user object to work with

=cut

sub setup {
    my $self = shift;

    # Make a blank user object
    $self->user_object(BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser));
}

=head2 validate_address

Make sure there's actually an account by that name and that it is
unactivated, or activated but unconfirmed.

=cut

sub validate_address {
    my $self  = shift;
    my $email = shift;

    return unless BTDT->validate_user_email( action => $self, column => "address", value => $email, existing => 1, implicit => 0 );

    $self->user_object(BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser));
    $self->user_object->load_by_cols( email => $email );

    if ( $self->user_object->access_level eq 'nonuser' ) {
        return $self->validation_ok('address');
    } elsif (not $self->user_object->email_confirmed) {
        return $self->validation_ok('address');
    } else {
        return $self->validation_error( address => "It looks like your account is already confirmed!" );
    }
}

=head2 take_action

Send out an email containing a link to the activation or email
confirmation letme.

=cut

sub take_action {
    my $self = shift;
    my $user = $self->user_object();

    if ($user->access_level eq 'nonuser') {
        BTDT::Notification::ActivateAccount->new( to => $user )->send;
        $self->result->message("We sent a link to activate your account to your email address.");
    } else {
        BTDT::Notification::ConfirmAddress->new( to => $user )->send;
        $self->result->message("We've re-sent your confirmation.");
        $self->result->content("address_confirm" => 1)
    }

    return 1;
}

1;
