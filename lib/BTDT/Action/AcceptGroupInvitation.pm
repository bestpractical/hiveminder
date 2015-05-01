use warnings;
use strict;

=head1 NAME

BTDT::Action::AcceptGroupInvitation - Accept a group invitation

=head1 DESCRIPTION

This is the link in a user's email when they're accepting a group invitation.

=cut

package BTDT::Action::AcceptGroupInvitation;
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

Accepts the invitation

=cut

sub take_action {
    my $self = shift;

    my $invite = BTDT::Model::GroupInvitation->new();
    $invite->load_by_cols( id => $self->argument_value('invitation'));
    unless ($invite->id and $invite->recipient->id == Jifty->web->current_user->id) {
        $self->result->error("Huh.  That invitation doesn't seem to work.  Please check it and try again.");
        return;
    }

    if ($invite->cancelled) {
        $self->result->error("Huh.  It looks like someone cancelled this invitation.");
        $invite->delete;
        return;
        }

    my $group = $invite->group;
    # XXX TODO is this the right way to set up the rights?
    $group->current_user(BTDT::CurrentUser->superuser);
    # XXX TODO, this code should be in invitation->accept
    if ($group->has_member(Jifty->web->current_user)) {
        $self->result->error("Don't you already belong to ".$group->name."?");
        $self->result->success(1);
    } else {
        $group->add_member(Jifty->web->current_user, $invite->role);
        $self->result->message("Welcome to ".$group->name);
    }
    $invite->delete;


    return 1;
}

1;
