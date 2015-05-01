use warnings;
use strict;

package BTDT::Notification::ActivateAccount;
use base qw/BTDT::Notification/;

=head1 NAME

BTDT::Notification::ActivateAccount

=head1 ARGUMENTS

C<to>, a L<BTDT::Model::User> who wants to activate their account

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

    $self->subject("Hiveminder: Activate your account");
    $self->body(<<"END_BODY");
Welcome to Hiveminder!  Click the link below to activate your account
so you can start getting busy.

@{[$self->magic_letme_token_for('activate_account')]}

If you're not trying to activate your account, just ignore this email.

END_BODY

    $self->html_body(<<"    END_HTML");
<p>
  Welcome to Hiveminder!  All it takes is just <a href="@{[$self->magic_letme_token_for('activate_account')]}">one click to activate your account</a> and you can start getting busy.
</p>

<p>If you're not trying to activate your account, just ignore this email.</p>
    END_HTML
}

=head2 preface

Don't pretend we know their name when we're going to be asking for it in
the next step (activation).

=cut

sub preface { return "Hi!"  }

=head2 go_legit

Stub out go_legit so that it doesn't get tacked on for a user obviously
trying to activate their account already.

=cut

sub go_legit { "" }

1;
