use warnings;
use strict;

=head1 NAME

BTDT::Action::DeclineGroupInvitation - Decline a group invitation

=head1 DESCRIPTION

This is the link in a user's email when they're declining a group invitation.

=cut

package BTDT::Action::DeclineGroupInvitation;
use base qw/BTDT::Action Jifty::Action/;

use BTDT::Model::User;

=head2 arguments

invitation

=cut

sub arguments {
    return( { invitation => { mandatory => 1,
                            },
          });
}

=head2 take_action

Declines the invitation

=cut

sub take_action {
    my $self = shift;

    my $invite = BTDT::Model::GroupInvitation->new();
    $invite->load_by_cols( id => $self->argument_value('invitation'));

    unless ($invite->id and $invite->recipient->id == Jifty->web->current_user->id) {
        $self->result->error("Huh.  It seems you've received a bogus invitaiton.");
        return;
    }

    BTDT::Notification::DeclineGroupInvitation->new(
        invite => $invite,
    )->send;

    $self->result->message("You've declined the invitation to ".$invite->group->name.".  We'll break it to the organizer gently.");

    $invite->delete;

    return 1;
}

1;
