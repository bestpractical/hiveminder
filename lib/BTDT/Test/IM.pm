package BTDT::Test::IM;
use strict;
use warnings;
use BTDT::IM::Test;
use DateTime;
use Email::Simple;
use base 'Exporter';

=head1 NAME

BTDT::Test::IM - helper functions for testing IM

=head1 SYNOPSIS

    use BTDT::Test tests => 12;
    use BTDT::Test::IM;

    setup_screenname('gooduser@example.com' => 'tester');
    command_help_includes('todo');
    im_like(todo => qr/2 things to do/);

=cut

our $screenname;
our $im = BTDT::IM::Test->new();

our @EXPORT = qw(setup_screenname msg split_task_list comments_on_task is_command_help command_help_includes im_like im_unlike im ims_like ims in_days create_tasks session_for session $im);

=head2 setup_screenname id||name, screenname -> UserIM

This will set up the given screenname for the user. Returns the UserIM object.
Also runs some tests to make sure the auth token is OK.

The first call to setup_screenname is taken to be the primary test user. This
will set C<$BTDT::Test::IM::screenname> which is used for C<im_like> and
C<command_help_includes>.

=cut

sub setup_screenname {
    my $id     = shift;
    my $new_sn = shift;
    $screenname ||= $new_sn;

    # did they pass in the email instead?
    if ($id =~ /\D/) {
        my $user = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
        $user->load_by_cols(email => $id);
        $user->id
            or ::BAIL_OUT("Unable to load a user with email '$id'");
        $id = $user->id;
    }

    my $userim = BTDT::Model::UserIM->new(current_user => BTDT::CurrentUser->superuser);
    my ($val, $msg) = $userim->create(user_id => $id);
    ::ok($val, $msg);
    my $auth_token = $userim->auth_token;

    ::ok(length($auth_token) > 3, "auth token '$auth_token'  greater than 3 chars long (very low standards!)");

    {
        local $screenname = $new_sn;
        im_like($auth_token, qr/Hooray!/, "$new_sn for $id successfully authed");
    }

    return $userim;
}

=head2 im_like message, re[, testname] -> response

This will send a message and test that the response matches
the given regular expression. An optional test name may be given.

The screenname used to send the message is C<$BTDT::Test::IM::screenname>
(default: first screenname for C<setup_screenname>).

This should be used for most of your IM tests.

=cut

sub im_like {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    im($screenname, @_);
}

=head2 im_unlike message, re[, testname] -> response

See C<im_like>.

=cut

sub im_unlike {
    my $msg  = shift;
    my $re   = shift;
    my $name = shift || "Got expected response for $msg";
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $response = msg($screenname, $msg);
    ::unlike($response, $re, $name);

    return $response;
}

=head2 im screenname, message, re[, testname] -> response

Same as C<im_like> except you must pass in a screenname.

The default regex is C<qr/(?!)/> so that if you don't know the exact form
of the output, you can just use C<im(screenname, message)> and get a failure
with the response.

=cut

sub im {
    my $sn   = shift;
    my $msg  = shift;
    my $re   = shift || qr/(?!)/;
    my $name = shift || "Got expected response for $msg";
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $response = msg($sn, $msg);
    ::like($response, $re, $name);

    return $response;
}

=head2 ims_like message, re1, re2, ... -> responses

Same as C<im_like> except that multiple responses are expected. See C<ims> for
more information.

=cut

sub ims_like {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    ims($screenname, @_);
}

=head2 ims screenname, message, re1, re2, ... -> responses

Same as C<im> except that multiple responses are expected.

You must provide a regex for each response. Any disparity between number
of regexes and responses will result in test failures.

If any regex argument is an array reference, it will be interpreted as
C<[re, test name]>.

=cut

sub ims {
    my $sn   = shift;
    my $msg  = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my @responses = msg($sn, $msg);
    my @ret = @responses; # we modify @responses

    while (@responses && @_) {
        my $response    = shift @responses;

        my ($re, $name) = ref($_[0]) eq 'ARRAY'
                        ? (@{ shift @_ })
                        : (shift, undef);

        ::is($response->{recipient}, $sn);
        ::like($response->{message}, $re, $name || "Got expected response for $msg");
    }

    if (@responses) {
        ::fail;
        ::diag("Got ".@responses." more response(s) than expected for input '$msg':");
        ::diag("    got: $_->{message}") for @responses;
    }

    if (@_) {
        ::fail;
        ::diag("Got ".@_." fewer response(s) than expected for input '$msg':");
        ::diag("    expected: $_")
            for map { ref eq 'ARRAY' ? $_->[0] : $_ } @_;
    }

    return @ret;
}

=head2 msg screenname, message -> response

Send a message to the IM interface and receive message(s) back.

In scalar context, this will expect exactly one outgoing IM, to the screenname
who sent it. These two will be tested.

In list context, no testing will be done. You'll receive a list of messages,
each a hashref with keys C<recipient> and C<message> set.

=cut

sub msg($$)
{
    local $::TODO;

    my ($from, $content) = @_;
    $im->received_message($from, $content);

    # we would use canonicalize_screenname but we're testing
    # canonicalize_screenname itself
    $from =~ s/\s*//g;
    $from =~ y/A-Z/a-z/;

    my @messages = $im->messages;
    return @messages if wantarray;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    ::is(@messages, 1, "received some kind of response");
    ::is($messages[0]{recipient}, $from, "response sent to the correct person");
    return $messages[0]{message};
}

=head2 split_task_list message -> (lines)

This splits a task list up into its component tasks. No parsing is done on
the tasks.

=cut

sub split_task_list
{
    my $list = shift;

    my @tasks = grep {$_ ne ''}
                map  {chomp; $_}
                split /\n+/, $list;
    shift @tasks; # header line

    return @tasks;
}

=head2 comments_on_task locator -> (comments)

Returns the list of the comments (just their messages) on a task.

=cut

sub comments_on_task {
    my $locator = shift;

    my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
    $task->load_by_locator($locator);
    return unless $task->id;

    return map {$_->message} @{$task->comments->items_array_ref};
}

=head2 is_command_help sender, message -> responses

This will send a message to the IM interface and test that it's essentially
the same as the 'help' command. Shouldn't really be used.

=cut

sub is_command_help {
    my ($sender, $message) = @_;
    my @messages = msg($sender, $message);

    ::is(@messages, 3, "received three messages");
    for (@messages) {
        ::is($_->{recipient}, $sender, "response sent to the correct person");
    }
    ::like($messages[0]{message}, qr/Creating tasks:/);
    ::like($messages[1]{message}, qr/Working with tasks:/);
    ::like($messages[2]{message}, qr/Working with Hiveminder by IM:/);

    return @messages;
}

=head2 command_help_includes command -> help string

This will test that the given command has its own help file, and that it has
an entry in 'help commands'.

The screenname used to send the help commands is C<$BTDT::Test::IM::screenname>
(default: first screenname for C<setup_screenname>).

=cut

sub command_help_includes {
    my $command = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $im->received_message($screenname, "help commands");
    my @messages = $im->messages;

    my $help = join '', map { $_->{message} } @messages;

    ::like($help, qr/(?:^|>)$command\b/m, "'help commands' includes $command");
    ::unlike(msg($screenname, "help $command"), qr/I don't have a help file for /, "help $command exists");

    # check terse help
    local *BTDT::IM::Test::terse = sub { 1 };
    my $cmd_help = msg($screenname, "help $command");
    ::unlike($cmd_help, qr/I don't have a help file for /, "help $command exists");
    ::like($cmd_help, qr/tinyurl/, "terse help for '$command' contains a tinyurl (sadly)") unless $command eq 'privacy';
    ::cmp_ok(length($cmd_help), '<', 200, "terse help for '$command' is less than 200 characters");

    return $help;
}

=head2 in_days int -> friendly_date

Takes some day offset. Returns the "friendly date". For example, C<in_days(1)>
will return C<tomorrow>.

=cut

sub in_days {
    my $delta = shift;

    BTDT::DateTime->now(time_zone => "America/New_York")
                  ->add(days => $delta)
                  ->friendly_date;
}

=head2 create_tasks tasks

Creates the given list of tasks. These will test that task creation worked.
Note that you should not be in any kind of when this is performed, such as
modal create.

In list context, returns the locators of the created tasks. If any task
creations fail, then there will be an C<undef> in the slot where the locator
would be. In scalar context, returns the number of tasks successfully created.
As a special case, if you pass in only one task to create, it will DWIM and
return that task's locator (or C<undef>).

The screenname used to send the message is C<$BTDT::Test::IM::screenname>
(default: first screenname for C<setup_screenname>).

=cut

sub create_tasks {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my @loc;

    for (@_) {
        my $response = im_like("create $_", qr/Created 1 task/);
        if (::ok($response =~ /<(#\w+)>/, "got a locator")) {
            push @loc, $1;
        }
        else {
            push @loc, undef;
        }
    }

    # if they ask for one task, just give them that one locator. this is for
    # scalar context
    return $loc[0] if @_ == 1;

    # in scalar context, return the number of tasks actually created
    return grep { defined } @loc if !wantarray;

    # in list context, return the result of each task to be created
    return @loc;
}

=head2 session_for screenname

Returns the L<Jifty::Web::Session> object for the given screenname (or the
default).

=cut

sub session_for {
    my $self = shift;
    my $name = shift || $screenname;

    $im->get_session($name);
}

=head2 session

Alias for C<session_for>.

=cut

*session = \&session_for;

1;

