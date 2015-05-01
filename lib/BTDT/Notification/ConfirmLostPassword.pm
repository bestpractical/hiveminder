use warnings;
use strict;

package BTDT::Notification::ConfirmLostPassword;
use base qw/BTDT::Notification/;

=head1 NAME

BTDT::Notification::ConfirmLostPassword

=head1 ARGUMENTS

C<to>, a L<BTDT::Model::User> who wants to reset their password.

=cut

=head2 setup

Sets up the fields of the message.

=cut

sub setup {
    my $self = shift;
    $self->SUPER::setup(@_);

    unless ( UNIVERSAL::isa( $self->to, "BTDT::Model::User" ) ) {
        $self->log->error(
            ( ref $self ) . " called with invalid to argument" );
        return;
    }

    my $letme = Jifty::LetMe->new();
    $letme->email($self->to->email);
    $letme->path('reset_password');
    my $confirm_url = $letme->as_url;

    $self->subject("Hiveminder: Lost your password?");
    $self->body(<<"END_BODY");
To reset your Hiveminder password, just click:

$confirm_url

If you're not trying to reset your password, just ignore
this email.

You can read our full privacy policy on the web at:

    @{[Jifty->web->url(path => '/legal/privacy/')]}

The short version is that we'll never sell your email address and if
you ask us to stop sending you mail, we'll cut it out ASAP.
END_BODY
}

1;
