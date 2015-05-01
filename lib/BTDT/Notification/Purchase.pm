use warnings;
use strict;

package BTDT::Notification::Purchase;
use base qw/BTDT::Notification/;

=head1 NAME

BTDT::Notification::Purchase

=head1 ARGUMENTS

C<purchase>

=cut

__PACKAGE__->mk_accessors(qw/purchase/);

=head2 setup

Sets up the email.

=cut

sub setup {
    my $self = shift;
    $self->SUPER::setup(@_);

    unless (UNIVERSAL::isa($self->purchase, "BTDT::Model::Purchase")) {
        $self->log->error((ref $self) . " called with invalid purchase argument");
        return;
    }

    $self->to( $self->purchase->owner );

    if ( $self->purchase->gift ) {
        my $tx = $self->purchase->transaction;
        $tx->current_user( BTDT::CurrentUser->superuser );
        $self->subject( $tx->user->name . " bought you " . $self->purchase->description );
    } else {
        if (    $self->purchase->description eq 'Hiveminder Pro'
            and not $self->to->was_pro_account )
        {
            $self->subject("Welcome to Hiveminder Pro!");
        }
        else {
            $self->subject("Your Hiveminder purchase: "
                           . $self->purchase->description );
        }
    }

    $self->body(<<"END_BODY");
You should be able to start using @{[$self->purchase->description]} immediately
on hiveminder.com.  Check out the exclusive features you can now use at @{[Jifty->web->url( path => '/pro' )]}.

Your Hiveminder Pro upgrade is good until @{[$self->to->paid_until]}.

If you have any questions or problems, please contact support\@hiveminder.com.

Enjoy!

END_BODY

    my $html = "<p>".$self->body."</p>";
    $html =~ s{\n\n}{</p><p>}g;
    $html =~ s/(support\@hiveminder\.com)/<a href="mailto:$1">$1<\/a>/;
    $html =~ s/(hiveminder\.com)/<a href="https:\/\/$1">$1<\/a>/;
    $html =~ s{(Check out the exclusive features you can now use) at (http://.+/pro)\.}{<a href="$2">$1</a>!};
    $self->html_body( $html );

}

1;
