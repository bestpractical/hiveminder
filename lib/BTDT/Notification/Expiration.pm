use warnings;
use strict;

package BTDT::Notification::Expiration;
use base qw/BTDT::Notification/;

=head1 NAME

BTDT::Notification::Expiration - Notification that your Pro account has expired.

=head1 ARGUMENTS

C<to>

=head2 setup

Sets up the email.

=cut

sub setup {
    my $self = shift;
    $self->SUPER::setup(@_);

    my $expired = ( $self->to->was_pro_account and not $self->to->pro_account ) ? 1 : 0;

    if ( $expired ) {
        $self->subject("Oh no!  Your Hiveminder Pro upgrade has expired.");

        $self->body(<<"        END_BODY");
Your Hiveminder Pro upgrade expired @{[$self->to->english_paid_until]}.  If you
don't want to use the Pro features anymore, then you can ignore this notification
(we won't send you anymore about the matter).
        END_BODY

        my $html = "<p>".$self->body."</p>";
        $html =~ s/(expired [\w\s]+?)\./<span style="color: red">$1<\/span>./;

        my $pro = Jifty->web->url( path => '/pro' );
        $html =~ s/(Pro features)/<a href="$pro">$1<\/a>/;

        $self->html_body( $html );
    }
    else {
        $self->subject("Your Hiveminder Pro upgrade is almost over!");

        $self->body(<<"        END_BODY");
Your Hiveminder Pro upgrade will run out @{[$self->to->english_paid_until]}.

If you want to continue using features such as task attachments, with.hm email, reports, and site-wide SSL, act fast!
        END_BODY

        my $html = "<p>".$self->body."</p>";
        $html =~ s/\n\n/<\/p><p>/;

        my $pro = Jifty->web->url( path => '/pro' );
        $html =~ s/(features)/<a href="$pro">$1<\/a>/;

        my $renew = Jifty->web->url( path => '/account/upgrade' );
        $html =~ s/(act fast)/<a href="$renew">$1<\/a>/;

        $self->html_body( $html );
    }
}

=head2 footer

Sets up the footer

=cut

sub footer {
    my $self = shift;
    return <<"    END_FOOTER";
To renew your Hiveminder Pro upgrade, go to:

@{[Jifty->web->url( path => '/account/upgrade' )]}
    END_FOOTER
}

=head2 html_footer

The HTML version of the normal footer

=cut

sub html_footer {
    my $self = shift;
    return qq(<p>Renewing your Pro upgrade is easy and only <a href="@{[Jifty->web->url( path => '/account/upgrade' )]}">a few clicks away</a>.</p>)
           . $self->SUPER::html_footer;
}

1;
