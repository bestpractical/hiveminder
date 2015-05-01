use warnings;
use strict;

package BTDT::Notification;

use base qw/Jifty::Notification/;
use URI;
use MIME::Base64;
use Text::Autoformat;
use Email::MessageID ();

__PACKAGE__->mk_accessors(qw/proxy_of reply_to/);

=head1 NAME

BTDT::Notification

=head1 DESCRIPTION

An abstract base class for any notifications Hiveminder is sending.
Sets the return address correctly.


=head2 setup

Sets the sender of this notification to C<do_not_reply@hiveminder.com>.

=cut

sub setup {
    my $self = shift;
    $self->from('Hiveminder <do_not_reply@hiveminder.com>');
}

=head2 proxy_of

A L<BTDT::Model::TaskEmail> that this notification is a proxy for --
that is, for the purposes of threading, this email takes the place of
that one.  This option takes precedence over L</reply_to>, below.

=head2 reply_to

A L<BTDT::Model::TaskEmail> that this notification is a response to,
for the purposes of threading.

=head2 set_headers MESSAGE

Takes a given L<Email::Simple> object C<MESSAGE>, and overrides the
default headers to provide proper C<Message-ID>, C<In-Reply-To>, and
C<References> headers.

=cut

sub set_headers {
    my $self = shift;
    my ($message) = @_;

    my $proxy_of = $self->proxy_of;
    my $reply_to = $self->reply_to;

    my $host = URI->new( Jifty->config->framework("Web")->{BaseURL} )->host;
    if (    $proxy_of
        and $proxy_of->sender->id == $self->to->id
        and $proxy_of->message_id !~ /\@generated\.$host>$/ )
    {

        # We're trying to proxy an email message back to the person
        # who sent it -- which will cause us to resend their own
        # message-id back to them, but with different content, which
        # is obviously wrong.  Make this message a reply instead.
        $reply_to = $proxy_of;
        $proxy_of = undef;
    }

    if ($proxy_of) {
        my $proxy = Email::Simple->new( $proxy_of->message );
        $self->proxy_headers( $message, $proxy );
    } elsif ($reply_to) {
        my $reply = Email::Simple->new( $reply_to->message );
        $self->reply_headers( $message, $reply );
    } else {
        $message->header_set( "Message-ID", $self->new_message_id );
    }

    #set a default Sender header
    $message->header_set( "Sender", Encode::encode('MIME-Header',$self->from));
    $message->header_set( "X-Hiveminder", Jifty->config->framework('Web')->{'BaseURL'});
    $message->header_set( "Auto-generated", "auto-replied" );
    $self->encode_references($message);
}

=head2 reply_headers MESSAGE REPLY

Sets the headers on the given L<Email::Simple> object MESSAGE such
that it appears to be a reply to the L<Email::Simple> object REPLY.
This can be called as a class method.  Does not have a return value;
it modifies MESSAGE in place.

=cut

sub reply_headers {
    my $class = shift;
    my ( $message, $reply ) = @_;
    $message->header_set( "Message-ID", $class->new_message_id )
        unless $message->header("Message-ID");
    $message->header_set( "In-Reply-To", $reply->header("Message-ID") );
    $message->header_set(
        "References",
        join(
            " ",
            (   $reply->header("References")    # XXX this warns in t/47
                    || $reply->header("In-Reply-To")
            ),
            $reply->header("Message-ID")
        )
    );
}

=head2 proxy_headers MESSAGE PROXY

Sets the headers on the given L<Email::Simple> object MESSAGE such
that it appears to be a proxy to the L<Email::Simple> object PROXY.
This can be called as a class method.  Does not have a return value;
it modifies MESSAGE in place.

=cut

sub proxy_headers {
    my $class = shift;
    my ( $message, $proxy ) = @_;
    $message->header_set( "Message-ID",
        $class->encode_message_id( $proxy->header("Message-ID") ) );
    $message->header_set( "In-Reply-To", $proxy->header("In-Reply-To") )
        if $proxy->header("In-Reply-To");
    $message->header_set( "References", $proxy->header("References") )
        if $proxy->header("References");
}

=head2 new_message_id

Returns a new message-id.

=cut

sub new_message_id {
    my $self = shift;
    my $host = URI->new( Jifty->config->framework("Web")->{BaseURL} )->host;
    return "<"
        . DateTime->now->strftime("%Y%m%d%H%M%S") . "."
        . Jifty->web->serial
        . '@generated.'
        . $host . ">";
}

=head2 encode_message_id MESSAGE_ID

Returns the given MESSAGE_ID, but encoded such that the MESSAGE_ID
either originates from the BTDT server, or from the notification's
recipient, if they originally generated the MESSAGE_ID.  Since all
comments and emails are between the notification's recipient and the
server, this guarantees that both ends of the conversation are able to
thread the mail properly -- additionally, message-ids that originated
from neither recipient nor server are encoded in such a way that their
original message-id can be extracted by the server when it comes back
in the C<References> or C<In-Reply-To> header.

=cut

sub encode_message_id {
    my $self  = shift;
    my $mid = shift || '';
    my $host  = URI->new( Jifty->config->framework("Web")->{BaseURL} )->host;

    return $mid if $mid =~ /@(generated|translation)\.$host>$/;
    return $self->new_message_id unless $mid;

    # Look it up, find out if we need to translate
    my $msg = BTDT::Model::TaskEmail->new;
    $msg->load_by_cols( message_id => $mid );
    return $mid if ($msg->sender->id||0) == ($self->to->id||0);

    # This MID needs to be translated, because they saw our proxied version
    my $encoded = MIME::Base64::encode_base64($mid);
    $encoded =~ s/\s//g;

    return "<$encoded\@translation.$host>";
}

=head2 decode_message_id MESSAGE_ID

Returns the given MESSAGE_ID, after decoding it, if necessary.  This
will return the true message-id of proxied messages.

=cut

sub decode_message_id {
    my $self  = shift;
    my ($mid) = @_;
    my $host  = URI->new( Jifty->config->framework("Web")->{BaseURL} )->host;
    return $mid unless $mid =~ /^<(.*)\@translation\.$host>$/;

    return MIME::Base64::decode_base64($1);
}

=head2 encode_references MESSAGE

Takes am L<Email::Simple> object MESSAGE, and encodes the
C<In-Reply-To> and C<References> headers (if any) using
L</encode_message_id>.

=cut

sub encode_references {
    my $self = shift;
    my ($message) = @_;

    for my $header (qw/In-Reply-To References/) {
        next unless $message->header($header);

        $message->header_set(
            $header => join( " ",
                map { $self->encode_message_id( $_->as_string ) }
                    Email::Address->parse( $message->header($header) ) )
        );
    }
}

=head2 decode_references MESSAGE

Takes an L<Email::Simple> object MESSAGE, and decodes the
C<In-Reply-To> and C<References> headers (if any) using
L</decode_message_id>.

=cut

sub decode_references {
    my $self = shift;
    my ($message) = @_;

    for my $header (qw/In-Reply-To References/) {
        next unless $message->header($header);

        $message->header_set(
            $header => join( " ",
                map { $self->decode_message_id( $_->as_string ) }
                    Email::Address->parse( $message->header($header) ) )
        );
    }
}

=head2 preface


Print a cute, slightly annoying greeting before the message

=cut

sub preface {
    my $self = shift;

    return 'Hey'.($self->to ? ", ".$self->to->name : "")."!\n\n";
}


=head2 send_one_message

Auto-format the text that will be the body of the email.

Check if $self->to has opted not to receive mail, and if not, send the
email.

=cut

sub send_one_message {
    my $self    = shift;
    my $to_user = $self->to;
    return unless $to_user;
    if ( !$to_user->isa('BTDT::Model::User') ) {
        $to_user = BTDT::Model::User->new(
            current_user => BTDT::CurrentUser->superuser );
        $to_user->load_by_cols( email => $self->to );
    }
    if ( $to_user->never_email ) {
        return;
    }

    # Never respond to bulk or junk email
    my $related = $self->proxy_of || $self->reply_to;
    return if $related and $related->sender->id == $to_user->id and $related->is_autogenerated;

    $self->current_user(BTDT::CurrentUser->new(id => $to_user->id));

    foreach my $part (qw(body preface footer)) {
        next unless ($self->$part && $self->$part =~ /\w/);
        $self->$part(eval { autoformat $self->$part, {squeeze => 0, renumber => 0}});
        my $err = $@;
       warn  $err if ( $err && $err !~ /Can't call method "signature"/);
    }

    $self->SUPER::send_one_message;
}

=head2 footer

Print a footer for the message. Implore non-users to go legit.

=cut

sub footer {
    my $self   = shift;
    my $footer = '';
    $footer .= $self->go_legit() if ( $self->nonuser_recipient );
    $footer .= $self->_privacy_policy();
    return $footer;
}

sub _privacy_policy {
    my $self = shift;
    my $msg  = <<"EOMESSAGE";
-- 
You can read our full privacy policy on the web at
@{[Jifty->web->url(path => '/legal/privacy/')]}

(Basically, we'll never sell your email address and if you ask us
to stop sending you mail, we'll cut it out as quickly as we can.)

EOMESSAGE

    return $msg;
}

=head2 nonuser_recipient

If the message's recipient isn't already a user, returns true.
Otherwise, returns false. This is useful for sending special messages
to nonusers.

=cut

sub nonuser_recipient {
    my $self = shift;

    if ($self->to and $self->to->current_user_can('read', column => "access_level")) {
        if ( $self->to->access_level eq 'nonuser' ) {
            return 1;
        } else {
            return undef;
        }
    } else {
        # Most likely, current_user is a nonuser, if they don't have read
        # permissions on the user they're sending to.
        # In which case, the recipient is always going to be not-a-nonuser.
        return undef;
    }
}

=head2 go_legit

Returns a paragraph imploring the user to click an activate_account link.

=cut

sub go_legit {
    my $self = shift;

    my $msg = <<"EOMESSAGE";

-----------------------------------------------------------------------

@{[$self->_go_legit_pitch]}
It's quick and easy to activate your FREE Hiveminder account, just
click this link and choose a password:

@{[$self->magic_letme_token_for('activate_account')]}

If you'd rather that we buzz off (and never email you again), peace
is just a few clicks away:

@{[$self->magic_letme_token_for('opt_out')]}

EOMESSAGE

    return ($msg);
}

sub _go_legit_pitch { <<END; }
Hiveminder helps you keep track of things that need doing (and get
more of them done) with email notifications, reminders, groups and
the ability to assign tasks to anybody with an email address, right
from your web browser.
END

=head2 full_html

(TEMPORARY) Override Jifty::Notification's full_html for now

=cut

sub full_html {
    my $self = shift;
    return join( "\n", grep { defined } $self->html_header, $self->html_body, $self->html_footer );
}

=head2 html_header

HTML equivalent of preface

=cut

sub html_header {
    my $self = shift;
    return <<"    END";
<div style="margin: 0.5em; font-family: verdana, sans-serif;">
  <p style="font-weight: bold">@{[Jifty->web->escape($self->preface)]}</p>
    END
}

=head2 html_footer

HTML equivalent of footer

=cut

sub html_footer {
    my $self = shift;
    my $footer;

    $footer .= <<"    END" if $self->nonuser_recipient;
  <div style="margin-top: 1.5em; padding: 0.8em; border: 1px solid #E48511; background-color: #F8F1D3;">
    <p style="padding-top: 0;margin-top: 0;">@{[Jifty->web->escape($self->_go_legit_pitch)]}</p>
    <p>
      It's <b>quick and easy</b> to <a href="@{[$self->magic_letme_token_for('activate_account')]}">activate your FREE Hiveminder account</a>.
    </p>
    <p style="padding-bottom: 0;margin-bottom: 0;">
      If you'd rather that we buzz off (and never email you again),
      <a href="@{[$self->magic_letme_token_for('opt_out')]}">peace is just a few clicks away</a>.
    </p>
  </div>
    END

    $footer .= <<"    END";
  <p style="margin-top: 2em;">
    <a href="@{[Jifty->web->url( path => '/' )]}"><img src="@{[Jifty->web->url( path => '/static/images/hmlogo/default.email.png' )]}" alt="Hiveminder" border="0" /></a>
  </p>

  <p style="color: #777;"><small>
    <img src="@{[Jifty->web->url( path => '/static/images/bp_logo_small.png' )]}" alt="Best Practical" align="right" />

    You can read our full <a href="@{[Jifty->web->url(path => '/legal/privacy/')]}">privacy policy</a>.  (Basically, we'll never sell your email address and if you ask us to stop sending you mail, we'll cut it out as quickly as we can.)
  </small></p>

  <p>
  </p>
</div>
    END
    return $footer;
}

1;

