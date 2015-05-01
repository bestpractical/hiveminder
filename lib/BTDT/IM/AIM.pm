package BTDT::IM::AIM;
use strict;
use warnings;
use base qw( BTDT::IM );
use HTML::Entities;
use Scalar::Util qw(weaken);

use constant protocol => "AIM";

__PACKAGE__->mk_accessors(qw/oscar/);

=head2 login

Sets up an OSCAR object and logs into AIM.

=cut

sub login
{
    my $self = shift;

    require Net::OSCAR;
    Net::OSCAR->import;

    $self->log->info("[IM] Signing onto AIM..");
    my %config  = %{ Jifty->config->app('IM') };
    my $screenname = $config{aim_screenname}
        or Carp::croak "Please set an aim_screenname in etc/site_config";
    my $password   = $config{aim_password}
        or Carp::croak "Please set an aim_password in etc/site_config";

    $self->oscar(Net::OSCAR->new(capabilities => [qw(buddy_icons)],
                                rate_manage => Net::OSCAR::Common::OSCAR_RATE_MANAGE_NONE()));

    $self->oscar->set_callback_error(sub {
        my ($oscar, $connecton, $error, $description, $fatal) = @_;
        my $log = sprintf '[IM] Got a %s Net::OSCAR error: %s',
                        $fatal ? 'fatal' : 'nonfatal',
                        $description;

        $self->log->error($log);
        if ($fatal) {
            # daemontools reinvokes pretty quickly, which can burn up CPU
            sleep 20;
            die $log;
        }
    });

    # these need to be a closure so it gets the right $self
    my $weaken_self = $self;

    $self->oscar->set_callback_signon_done(
        sub { $weaken_self->_on_signon(shift, $screenname) } );

    $self->oscar->set_callback_log(sub {
        my ($oscar, $level, $message) = @_;
        $weaken_self->log->warn("Net::OSCAR: $message");
    });

    $self->oscar->set_callback_im_in(sub {
        my ($oscar, $sender, $message, $is_away) = @_;
        $weaken_self->received_message($sender, $message);
    });

    Scalar::Util::weaken($weaken_self);

    $self->oscar->signon(screenname => $screenname,
                         password   => $password);
}

=head2 iteration

Does a 10ms select for checking for new messages. The docs for Net::OSCAR
explain how to properly do a sleepless poll should that become a requirement.

=cut

sub iteration
{
    my $self = shift;
    $self->oscar->do_one_loop();
}

=head2 send_message recipient, message

Wrapper around oscar->send_im required by BTDT::IM's interface.

We limit to exactly two messages, split off at 1800 characters.

=cut

sub send_message
{
    my ($self, $recipient, $message) = @_;

    $message = $self->canonicalize_outgoing($message);

    my $second;
    my $MAX = 1800;

    if (length($message) > $MAX) {
        my $leftover = substr($message, $MAX, length($message) - $MAX, '');

        # send another message, appending ... if necessary
        if (length($leftover) > $MAX) {
            $second = substr($leftover, 0, $MAX) . '...';
        }
        else {
            $second = $leftover;
        }
    }

    $self->oscar->send_im($recipient, $_)
        for grep { defined } $message, $second;
}

=head2 canonicalize_screenname screenname

Strips spacing from and lowercases the screenname so we have a canonical
representation.

=cut

sub canonicalize_screenname
{
    my ($self, $screenname) = @_;

    $screenname =~ y/ //d;      # spacing doesn't matter
    $screenname =~ y/A-Z/a-z/;  # nor does case

    return $screenname;
}

=head2 canonicalize_incoming message

Strips HTML from messages. This is so we don't have messages like

    <font size="3">authtoken</font>

It also replaces <br> (and <br />!) with newlines so multi-line braindumps
still work.

=cut

sub canonicalize_incoming
{
    my ($self, $message) = @_;
    $message = $self->SUPER::canonicalize_incoming($message);

    $message =~ s/<br.*?>/\n/gi;
    $message =~ s/<.*?>//g;

    HTML::Entities::decode_entities($message);

    # strip out as many "no-op" messages as we can find
    my $stripped = 0;

    for (qr/\[\s*sent from my mobile phone using www\.gizmo5\.com\s*\]/,
         qr/\[\s*I received your IM on my mobile phone. I will respond as soon as I can\. Want to IM from your phone\? www\.gizmo5\.com\s*\]/,
         qr/\[Offline IM sent .*? ago\]/)
    {
        $message =~ s/$_//
            and $stripped = 1;
    }

    # if we've stripped out the entire message, then abort the IM
    return undef if $stripped && $message =~ /^\s*$/;

    return $message;
}

=head2 canonicalize_outgoing message

Returns a message suitable for sending to AIM people.

=cut

sub canonicalize_outgoing
{
    my ($self, $message) = @_;
    $message = $self->SUPER::canonicalize_outgoing($message);

    $message =~ s/\n/<br>/g;

    # Oscar expects octets not characters
    utf8::encode($message);

    return $message;
}

sub _on_signon
{
    my ($self, $oscar, $screenname) = @_;

    my $profile = << "EOP";
You're busy. And you're constantly on the go.  Sometimes Hiveminder's full
web UI (or even the <a href="hiveminder.com/mini">mobile interface</a>) isn't
quite what you need. Hiveminder IM lets you add tasks, search for tasks and
even update tasks from within your IM client.

Setting up Hiveminder IM is quick and easy. Just send me an IM password from
<b>http://hiveminder.com/prefs/IM</b> and start beeing more productive!
EOP

    # don't get rid of the paragraph breaks
    $profile =~ s/(?<!\n)\n(?!\n)/ /g;

    $oscar->set_info($profile);

    # set buddy icon {{{
    my $iconname = 'static/images/bee.buddy.icon.gif';
    if (open(my $iconhandle, '<', $iconname))
    {
        local $/;
        binmode $iconhandle;
        my $icondata = join '', <$iconhandle>;

        # ugly dirty hack to work around Net::OSCAR forgetting about our
        # capabilities
        $oscar->{capabilities}->{buddy_icons} = 1;

        $oscar->set_icon($icondata);
    }
    else
    {
       $self->log->debug("[IM] Unable to open AIM buddy icon '$iconname' for reading: $!");
    } # }}}

    $oscar->commit_buddylist;

    $self->log->info("[IM] Signed onto $screenname.\n");
}

1;

