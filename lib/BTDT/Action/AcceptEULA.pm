use warnings;
use strict;

=head1 NAME

BTDT::Action::AcceptEULA

=cut

package BTDT::Action::AcceptEULA;
use base qw/BTDT::Action Jifty::Action/;

__PACKAGE__->mk_accessors(qw(user_object));

use BTDT::Model::User;

=head2 arguments

The field for C<AcceptEULA> is:

=over 4

=item eula_version: the version of the eula the current user is accepting

=back

=cut

sub arguments {
    return (
        {
            eula_version => {
                mandatory => 1,
            },
        }
    );
}

=head2 validate_eula_version

Make sure that the EULA version they're accepting is the current version.

=cut

sub validate_eula_version {
    my $self    = shift;
    my $version = shift;

    return $version == BTDT->current_eula_version
                ? $self->validation_ok('eula_version')
                : $self->validation_error( 'eula_version' => "The license agreement you accepted wasn't a current version.  Check out the new version." );
}

=head2 take_action

Walk around ACLs and update the user's accepted_eula_version

=cut

sub take_action {
    my $self = shift;
    my $user = Jifty->web->current_user->user_object;

    if ( not $user->id ) {
        $self->result->error("Sorry, you've got to have an account before you can accept the license agreement.");
        return;
    }

    my ( $ret, $msg )
        = $user->__set( column => 'accepted_eula_version',
                        value  => $self->argument_value('eula_version') );

    if ( not $ret ) {
        $self->result->error("There was a problem accepting the license agreement.  We'll fix this ASAP, so please try again later.");
        return;
    }

    $self->result->message("Thanks for accepting the agreement.");
    return 1;
}

1;
