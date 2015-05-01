use warnings;
use strict;

=head1 NAME

BTDT::Action::SessionAuth

=head1 DESCRIPTION

=cut

package BTDT::Action::SessionAuth;
use base qw/BTDT::Action Jifty::Action/;

=head1 METHODS

=head2 arguments

Takes C<frob> and optional C<api_key> arguments.

=cut

sub arguments {
    return ( { frob => { mandatory => 1, render_as => 'hidden' }, api_key => { render_as => 'hidden' } } );
}

=head2 take_action

Creates a new session with the same C<current_user>, and puts its
identification into the C<frob>'s session contents.

=cut

sub take_action {
    my $self = shift;

    my $frob = $self->argument_value('frob');

    # Make a new session token
    my $token_sess = Jifty::Web::Session->new;
    $token_sess->create;
    $token_sess->set( user_id => Jifty->web->current_user->id );

    # Look up the frob's session, set its token to what we just made
    my $frob_sess = Jifty::Web::Session->new;
    $frob_sess->load($frob);
    return $self->result->error("Wrong frob?") unless $frob_sess->id eq $frob;
    return $self->result->error("Frob wasn't created through proper API") unless $frob_sess->get("rtm");
    $frob_sess->set( api_token => $token_sess->id );

    # Redirect to the "api key" if given
    my $api_key = $self->argument_value('api_key');
    Jifty->web->redirect("$api_key?frob=$frob") if $api_key and $api_key =~ m{^https?://};
}

1;
