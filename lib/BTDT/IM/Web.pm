use strict;
use warnings;

=head1 NAME

BTDT::IM::Web

=head1 DESCRIPTION

Class to make a web-based IM bot easy.

=cut

package BTDT::IM::Web;
use base qw( BTDT::IM );
use HTML::Entities;

use constant protocol => "Web";

=head1 METHODS

=head2 interp message, "rest"

Takes some text from the user and interprets it according to the usual IM
rules.

The arguments to interp are passed on to L</load_account> and
L</extra_recv_args>.

=cut

sub interp
{
    my $self  = shift;
    my $input = shift;
    my @rest  = @_;

    my ($userim, $msg) = $self->load_account($input, @rest);
    return $msg if !$userim;

    my $screenname = $userim->screenname;
    my $current_user = BTDT::CurrentUser->new(id => $userim->user_id);
    my $user = BTDT::Model::User->new(current_user => $current_user);
    $user->load($userim->user_id);

    my @output;

    {
        local *BTDT::IM::Web::send_message = sub
        {
            my ($self, $recipient, $message) = @_;
            return if $recipient ne $screenname;
            push @output, $self->canonicalize_outgoing($message);
        };

        $self->received_message($screenname, $input,
            user   => $user,
            userim => $userim,
            $self->extra_recv_args($input, @rest),
        );
    }

    return wantarray ? @output : join "\n", @output;
}

=head2 extra_recv_args message, rest

This should return any extra arguments to received_message. It receives as
arguments everything passed to L</interp>.

=cut

sub extra_recv_args { }

=head2 load_account -> (UserIM, message)

Loads (or creates!) a UserIM. If all goes well, will return the UserIM object
and an "OK" message. Otherwise, returns undef and the error.

It receives as arguments everything passed to L</interp>.

=cut

sub load_account {
    my $self = shift;

    my $user = Jifty->web->current_user->user_object;
    my $userim = BTDT::Model::UserIM->new;
    my $screenname = $user->email;

    my ($ok, $msg) = $userim->load_or_create(
        user_id    => $user->id,
        screenname => $screenname,
        protocol   => $self->protocol,
        confirmed  => 1,
        auth_token => '',
    );

    return ($userim, "OK") if $ok;
    return (undef, $msg);
}

=head2 canonicalize_incoming message

Stolen from BTDT::IM::AIM. Strips HTML from messages. It also replaces <br>
(and <br />!) with newlines so multi-line braindumps still work.

=cut

sub canonicalize_incoming
{
    my ($self, $message) = @_;
    $message = $self->SUPER::canonicalize_incoming($message);

    $message =~ s/<br.*?>/\n/gi;
    $message =~ s/<.*?>//g;

    HTML::Entities::decode_entities($message);

    return $message;
}

=head2 canonicalize_outgoing message

Currently just replaces \n with <br>

=cut

sub canonicalize_outgoing
{
    my ($self, $message) = @_;
    $message = $self->SUPER::canonicalize_outgoing($message);

    $message =~ s/\n/<br>/g;

    return $message;
}

1;
