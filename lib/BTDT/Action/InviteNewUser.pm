use warnings;
use strict;

=head1 NAME

BTDT::Action::InviteNewUser

=cut

package BTDT::Action::InviteNewUser;
use base qw/BTDT::Action Jifty::Action/;

use BTDT::Model::User;

=head2 arguments

The fields for C<InviteNewUser> are:

=over 4

=item email: the email address of the user we want to add

=back

=cut

sub arguments {

    return (
        {
            email => {
                mandatory       => 1,
                default_value   => "",
                ajax_validates  => 1,
                label           => " ",
                hints           => _("Just type their email address"),
            },
        }
    );

}

=head2 validate_email

Make sure their email address looks sane.

=cut

sub validate_email {
    my $self  = shift;
    my $email = shift;

    return unless BTDT->validate_user_email( action => $self, column => "email", value => $email, implicit => 0 );

    # Make a blank user object
    my $user = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
    $user->load_by_cols(email => $email);

    return $self->validation_ok('email') unless $user->id;

    if ( $user->access_level eq 'nonuser' ) {
        return $self->validation_error( email => "Someone has already sent that person an invitation." );
    }

    return $self->validation_error( email => "It turns out they already have an account." );
}


sub _invite {
    my $self = shift;
    my ( $email ) = @_;

    my $recipient = BTDT::Model::User->new( current_user => BTDT::CurrentUser->superuser );

    my ( $id, $msg ) = $recipient->create(
        email           => $email,
        email_confirmed => 1,  # we assume that these are good email addresses
        beta_features   => 0,
        access_level    => 'nonuser',
        invited_by      => Jifty->web->current_user->user_object->id,
    );

    return ( undef, $msg ) unless $id;

    my $invitation = BTDT::Notification::NewUserInvitation->new(
                        sender => Jifty->web->current_user->user_object,
                        to     => $recipient,
                     );

    $invitation->send();

    Jifty->web->current_user->user_object->add_to_invites_sent( 1 );

    return ( $id, "" );
}


=head2 take_action

Send an invitation.

=cut

sub take_action {
    my $self = shift;

    my ( $val, $msg ) = $self->_invite( $self->argument_value('email') );

    if ( not $val ) {
        $self->result->error("It looks like we messed up: ".$msg);
        return;
    }

    $self->result->message("You've invited " . $self->argument_value('email') . " to join Hiveminder. Thanks for spreading the buzz!");

    return 1;
}


1;
