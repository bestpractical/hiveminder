use warnings;
use strict;

package BTDT::Notification::NewUserInvitation;
use base qw/BTDT::Notification/;

__PACKAGE__->mk_accessors(qw/sender/);

=head1 NAME

BTDT::Notification::NewUserInvitation

=head1 ARGUMENTS

C<from>, C<to>.

=cut



=head2 setup

Sets up the email.

=cut

sub setup {
    my $self = shift;
    $self->SUPER::setup(@_);

    unless ( UNIVERSAL::isa( $self->to, "BTDT::Model::User" ) ) {
        $self->log->error(
            ( ref $self ) . " called with invalid to argument" );
        return;
    }

    $self->from($self->sender->email);
    my $from = $self->from;

#    unless ($from->name) {$from->name("A friend of yours at " . $from->email)};

    $self->subject("Hiveminder: You're invited!");

    $self->body(<<"END_BODY");
@{[$self->sender->name]} has been using Hiveminder to keep track of
tasks and thinks that you'd enjoy using Hiveminder too.

Hiveminder is a new way to keep track of things you need to do, both
for yourself and with other people.
END_BODY

    my $html = "<p>".$self->body."</p>";
    $html =~ s{\n\n}{</p><p>};
    $html =~ s{(Hiveminder)}{<a href="@{[Jifty->web->url( path => '/' )]}">$1</a>};

    $self->html_body( $html );
}

=head2 preface

Don't pretend we know their name when we're going to be asking for it in
the next step (activation).

=cut

sub preface { return "Hi!\n" }

1;
