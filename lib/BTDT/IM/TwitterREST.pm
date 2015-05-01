package BTDT::IM::TwitterREST;
use strict;
use warnings;
use base qw( BTDT::IM );

use constant protocol          => "Twitter";
use constant terse             => 1;
use constant default_to_create => 1;

use constant SLEEP_INTERVAL    => 25;

__PACKAGE__->mk_accessors(qw/twitter at_regex/);

=head2 create_twitter_handle

Returns a new authenticated L<Net::Twitter::Lite> object.

=cut

sub create_twitter_handle {
    my $self = shift;

    require Net::Twitter::Lite;

    $self->log->info("[IM] Logging into Twitter..");

    my $get_config = sub {
        my $field = "twitter_" . shift;
        my $value = Jifty->config->app("IM")->{$field}
            or Carp::croak "Please set '$field' in etc/site_config";
        return $value;
    };

    my $twitter = Net::Twitter::Lite->new(
        username        => $get_config->('screenname'),
        consumer_key    => $get_config->('consumer_key'),
        consumer_secret => $get_config->('consumer_secret'),
    );

    # Access tokens -- or at least those that have already been issued --
    # are not going to expire, so we don't need to deal with negotiating
    # OAuth for authorization every time the bot restarts.
    $twitter->access_token($get_config->('access_token'));
    $twitter->access_token_secret($get_config->('access_secret'));

    return $twitter;
}

=head2 login

Set up the Net::Twitter::Lite object.

=cut

sub login {
    my $self = shift;

    $self->twitter($self->create_twitter_handle);

    my $username = Jifty->config->app("IM")->{twitter_screenname};

    $self->at_regex(qr/^\@\Q$username\E:?\s*/i);
}

=head2 iteration

Does two 25s sleeps for new messages. This is because Twitter rate-limits our
REST GETs.

=cut

sub iteration
{
    my $self = shift;

    $self->check_tweets;
    sleep SLEEP_INTERVAL;
    $self->check_direct_messages;
    sleep SLEEP_INTERVAL;
}

=head2 check_tweets

Check our friends' tweets. We use C<app_twitter_tweet_time>
C<app_twitter_tweet_id> to avoid looking at the same message more than once.

=cut

sub check_tweets {
    my $self = shift;

    my $now = DateTime->now;
    my $last_id = Jifty::Model::Metadata->load('app_twitter_tweet_id') || 0;
    my $next_id = $last_id;

    $self->log->debug("Checking friend feed, since $last_id");

    my $tweets = eval {
        $self->twitter->friends_timeline(
            $last_id ? {since_id => $last_id} : ()
        );
    };
    warn $@ if $@;

    my $at_regex = $self->at_regex;

    for my $msg (reverse @{ $tweets || [] }) {
        $next_id = $msg->{id}
            if $msg->{id} > $next_id;

        # right now we only look at messages with our name in it
        my $name = Jifty->config->app("IM")->{twitter_screenname};
        if ($msg->{text} =~ s/$at_regex// || $msg->{text} =~ /\Q$name\E:/io || $msg->{text} =~ /^todo:/) {
            $self->handle_incoming($msg->{user}{screen_name}, $msg->{text});
        }
        else {
            $self->log->debug("Skipping tweet '$msg->{user}{screen_name}: $msg->{text}' because I don't understand it.");
        }
    }

    Jifty::Model::Metadata->store('app_twitter_tweet_id'   => $next_id);
}

=head2 check_direct_messages

Check direct messages (sent with C<d hmtasks foo>).

=cut

sub check_direct_messages {
    my $self = shift;

    my $last_id = Jifty::Model::Metadata->load('app_twitter_dm_id') || 0;
    my $next_id = $last_id;
    $self->log->debug("Checking direct messages since message ID $last_id");

    my $messages = eval { $self->twitter->direct_messages({since_id => $last_id}) };
    warn $@ if $@;

    for my $msg (reverse @{ $messages || [] }) {
        $next_id = $msg->{id}
            if $msg->{id} > $next_id;

        $self->handle_incoming($msg->{sender_screen_name}, $msg->{text});
    }

    Jifty::Model::Metadata->store('app_twitter_dm_id' => $next_id);
}

=head2 handle_incoming screenname, message

Helper function for dispatching on incoming messages.

=cut

sub handle_incoming {
    my $self = shift;
    my $sn   = shift;
    my $msg  = shift;

    if (!defined($msg)) {
        return $self->send_message($sn, "I didn't understand that. Want some help? http://hiveminder.com/help/reference/IM");
    }

    $self->received_message($sn, $msg);
}

=head2 send_message user, msg

Send a message to the given user via Twitter's REST interface.

=cut

sub send_message {
    my $self = shift;
    my $user = shift;
    my $msg  = $self->canonicalize_outgoing(shift);

    $self->twitter->new_direct_message({user => $user, text => $msg});
}

=head2 canonicalize_screenname screenname

The only canonicalizations I know about are:

=over 4

=item Lowercase everything

=back

=cut

sub canonicalize_screenname
{
    my ($self, $screenname) = @_;
    $screenname = $self->SUPER::canonicalize_screenname($screenname);
    return lc $screenname;
}

=head2 canonicalize_outgoing message

Strip all HTML. Twitter doesn't use it. Also, turn messages into one line.

=cut

sub canonicalize_outgoing
{
    my ($self, $message) = @_;

    $message = $self->make_oneline($message);

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

