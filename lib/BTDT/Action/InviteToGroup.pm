use warnings;
use strict;

=head1 NAME

BTDT::Action::InviteToGroup

=cut

package BTDT::Action::InviteToGroup;
use base qw/BTDT::Action Jifty::Action/;

use BTDT::Model::User;

=head2 arguments

The fields for C<InviteToGroup> are:

=over 4

=item group: the group ID

=item email: the email address of the user we want to add

=back

=cut

sub arguments {
    return (
        {
            group => {
                mandatory   => 1,
                constructor => 1,
            },
            email => {
                mandatory       => 1,
                default_value   => "",
                ajax_validates  => 1,
                label           => "Email",
                hints           => "If this person doesn't have a Hiveminder account already, they'll be asked to sign up first to accept your invitation.",
                autocompleter   => \&BTDT::Action::InviteToGroup::autocomplete_email,
            },
            role  => {
                mandatory       => 1,
                valid_values    => [qw(member guest organizer)],
                default_value   => 'member',
                render_as       => "Select",
                label           => "Role",
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

    return BTDT->validate_user_email( action => $self, column => "email", value => $email, implicit => 0 );
}

=head2 autocomplete_email

Autocomplete the email address of people the current user knows who are
not in the current group.

=cut

sub autocomplete_email {
    my $self          = shift;
    my $current_value = shift;
    my %args          = @_;
    my @results;

    return if not Jifty->web->current_user->id;

    my $user  = Jifty->web->current_user->user_object;
    my $group = BTDT::Model::Group->new;

    $group->load( $self->argument_value('group') ); # XXX TODO FIXME check that group is sane?
    return if not $group->id;

    for my $person ( $user->people_known ) {
        next if    $group->has_member( $person )
                or $group->has_invitation( $person );

        push @results, {
            value => $person->email,
            label => $person->name,
        }
            if    $person->name  =~ /^\Q$current_value\E/
               or $person->email =~ /^\Q$current_value\E/;
    }

    # If there's only one result, and it already matches entirely, don't
    # bother showing it
    return if @results == 1 and $results[0]->{value} eq $current_value;
    return @results;
}

=head2 take_action

Send an invitation.

=cut

sub take_action {
    my $self = shift;

    my $group = BTDT::Model::Group->new();

    $group->load($self->argument_value('group')); # XXX TODO FIXME check that group is sane?
    unless ($group->id) {
        $self->result->error("Sorry, but you can't choose that group.");
        return;
    }


    my ($val, $msg ) = $group->invite( recipient => $self->argument_value('email'), role => $self->argument_value('role') );

    if (not $val) {
        $self->result->error("It looks like we messed up: ".$msg);
        return undef;
    }

    $self->result->message("You've now invited " . $self->argument_value('email') . " to join " . $group->name . ". ");

    return 1;
}



1;
