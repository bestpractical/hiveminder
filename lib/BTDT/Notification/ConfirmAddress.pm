use warnings;
use strict;

package BTDT::Notification::ConfirmAddress;
use base qw/BTDT::Notification Class::Accessor::Fast/;

__PACKAGE__->mk_accessors(q(existing));

=head1 NAME

Hiveminder::Notification::ConfirmAddress

=head1 ARGUMENTS

C<to>, a L<BTDT::Model::User> whose address we are confirming.

C<existing>, if the L<BTDT::Model::User> is not a new user

=cut

=head2 setup

Sets up the fields of the message.

=cut

sub setup {
    my $self = shift;
    $self->SUPER::setup(@_);
    unless (UNIVERSAL::isa($self->to, "BTDT::Model::User")) {
        $self->log->error((ref $self) . " called with invalid user argument");
        return;
    }


    my $letme = Jifty::LetMe->new();
    $letme->email($self->to->email);
    $letme->path('confirm_email');
    my $confirm_url = $letme->as_url;


    if ( $self->existing ) {
        $self->subject( 'Hiveminder: Confirm your address' );

        $self->body(<<"END_BODY");
Click the link below to confirm your new email address.

$confirm_url

END_BODY

        $self->html_body(<<"END_HTML");
<p>All it takes is <a href="$confirm_url">one click to confirm your new email address</a>.</p>

END_HTML
    }
    else {
        $self->subject( "Welcome to Hiveminder!" );

        $self->body(<<"END_BODY");
Welcome to Hiveminder.  Click the link below to confirm your email
address so you can start getting busy!

$confirm_url

END_BODY

        $self->html_body(<<"END_HTML_BODY");
<p>Welcome to Hiveminder.  All it takes is <a href="$confirm_url">one click to confirm your email address</a>,
and you can start getting busy!</p>

END_HTML_BODY
    }
}

1;
