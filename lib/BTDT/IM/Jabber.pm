package BTDT::IM::Jabber;
use strict;
use warnings;
use base qw( BTDT::IM );
use Scalar::Util qw(weaken);

use constant protocol => "Jabber";
__PACKAGE__->mk_accessors(qw/jabber/);

=head2 login

Sets up a Net::Jabber object and logs into your desired Jabber server.

=cut

sub login {
    my $self = shift;

    require Net::Jabber;
    Net::Jabber->import;

    my %config  = %{ Jifty->config->app('IM') };
    my $server = $config{jabber_server}
        or Carp::croak "Please set a jabber_server in etc/site_config";
    my $screenname = $config{jabber_screenname}
        or Carp::croak "Please set a jabber_screenname in etc/site_config";
    my $password   = $config{jabber_password}
        or Carp::croak "Please set a jabber_password in etc/site_config";
    my $port = $config{jabber_port} || 5222;
    my $resource = $config{jabber_resource} || 'bot';

    $self->log->info("[IM] Signing onto $server:$port..");

    $self->jabber(Net::Jabber::Client->new);

    # connect
    $self->jabber->Connect(hostname => $server,
                           port     => $port,
                           timeout  => 30);
    if (!$self->jabber->Connected) {
        my $msg = "Unable to connect to $server:$port.";
        $self->log->fatal($msg);
        sleep 20; # daemontools reinvokes pretty quickly, which can burn up CPU
        die $msg;
    }
    $self->log->info("[IM] Connected to $server:$port..");

    # send our auth
    my ($ok, $msg) = $self->jabber->AuthSend(username => $screenname,
                                             password => $password,
                                             resource => $resource);

    if ($ok ne 'ok') {
        $msg = "Unable to get authorization: $ok - $msg.";
        $self->log->fatal($msg);
        die $msg;
    }

    $self->log->info("[IM] Signed onto $server:$port as $screenname.");

    # this needs to be a closure so it gets the right $self
    my $weaken_self = $self;
    $self->jabber->SetCallBacks(message => sub {
        my ($sid, $msg) = @_;
        my $message = $msg->GetBody;
        return if $message eq ''; # status update
        my $sender = $msg->GetFrom;

        #$message = Jifty::I18N->promote_encoding($message);
        $weaken_self->received_message($sender, $message, send_param => $msg);
    });
    Scalar::Util::weaken($weaken_self);

    # tell the world we're ready to rock
    $self->jabber->PresenceSend();
}

=head2 iteration

Does a 5s sleep for new messages. It will break early if something occurs,
so technically we could have it sleep forever.

=cut

sub iteration
{
    my $self = shift;
    my $ok = $self->jabber->Process(5);
    defined $ok or die "Net::Jabber error: " . $self->jabber->GetErrorCode;
}

=head2 send_message

Sends a message to the specified jid. This uses the extra argument passed to
received_message to make sure the subject, thread, resource, etc are the same
as what we received.

=cut

sub send_message
{
    my ($self, $recipient, $body, $msg) = @_;

    # here we check to see that the sender of the message we're replying to
    # is the same as the person who we're sending this message to.
    # this should always be the case. if it's not, then something probably
    # went wrong. we shouldn't be using the fields from the original message,
    # as they might include sensitive data.
    $body = $self->canonicalize_outgoing($body);

    my $from = $msg->GetFrom;
    my $canonicalized = $self->canonicalize_screenname($from);

    if ($recipient ne $canonicalized) {
        $self->log->error("Sending a reply to someone who didn't originally send us the message we're replying to. This usually indicates an error.");

        return $self->jabber->MessageSend(
                to => $recipient,
                type => 'chat',
                body => $body,
        );
    }

    # if the canonicalized nick is the same as the recipient, then we populate
    # the message with most of the fields we originally received, so it does
    # look like a reply
    $self->jabber->MessageSend(
            to => $msg->GetFrom, # this includes resource, unlike recipient
            type => $msg->GetType,
            thread => $msg->GetThread,
            subject => $msg->GetSubject,
            body => $body,
    );

    # 5% chance to nag the user to switch to hmtasks@hiveminder.com
    if (rand(20) < 1) {
        $self->jabber->MessageSend(
                to => $msg->GetFrom, # this includes resource, unlike recipient
                type => $msg->GetType,
                thread => $msg->GetThread,
                subject => $msg->GetSubject,
                body => 'Please switch over to using our new Jabber bot, hmtasks@hiveminder.com. My days are numbered!',
        );
    }
}

=head2 canonicalize_screenname screenname

The only canonicalizations I know about are:

=over 4

=item Strip resource

This is temporary. Resources will be useful in the future. foo/work and
foo/home should allow different auto-tag thingies.

=item Append our domain if no domain

Just so that there's B<always> a domain.

=item Lowercase everything

=back

=cut

sub canonicalize_screenname
{
    my ($self, $screenname) = @_;
    $screenname = $self->SUPER::canonicalize_screenname($screenname);
    $screenname =~ s{/.*}{};

    $screenname .= Jifty->config->app('IM')->{jabber_server}
        unless $screenname =~ /@/;

    return lc $screenname;
}

=head2 canonicalize_outgoing message

Strip all HTML. Jabber doesn't use it.

=cut

sub canonicalize_outgoing
{
    my ($self, $message) = @_;
    $message = $self->SUPER::canonicalize_outgoing($message);

    $message =~ s{<.*?>}{}g;

    return $message;
}

=head2 linkify TASKS

Returns tasks linked with no extra formatting.

=cut

sub linkify
{
    my $self = shift;
    map {
        my $copy = $_;
        $copy = $copy->record_locator if ref($copy) && $copy->can('record_locator');
        $copy =~ s{^#?(.*)$}{#$1};
        $copy;
    } @_;
}

=head2 encode STRING

Do no encoding. The default is HTML entity encoding.

=cut

sub encode
{
    return $_[1];
}

1;

