package BTDT::IM;
use Data::Page;
use Module::Refresh ();
use HTML::Entities;
use Encode 'encode_utf8';
use strict;
use warnings;
use base qw( Jifty::Object Class::Accessor::Fast );

our @protocols = qw(AIM Jabber Twitter);

use constant default_to_create => 0;
use constant only_create       => 0;
use constant terse             => 0;

__PACKAGE__->mk_accessors(qw/command_table priority_table priorities
                             end_modal/);

=head2 new

Creates a new L<BTDT::IM>. Any keyword args given are used to call set
accessors of the same name. Calls C<setup> then C<login>.

=cut

sub new
{
    my $class = shift;
    my $self  = bless {}, $class;
    my %args  = @_;

    while ( my ( $arg, $value ) = each %args ) {
        if ( $self->can($arg) ) {
            $self->$arg($value);
        } else {
            $self->log->error(
                ( ref $self ) . " called with invalid argument $arg" );
        }
    }

    $self->setup;
    $self->login;

    return $self;
}

=head2 setup

This method is used to initialize your data structures. Please remember to call
C<< $self->SUPER::setup >>.

=cut

sub setup
{
    my $self = shift;

    $self->command_table(
    {
        'c'            => 'Create',
        'create'       => 'Create',
        'bd'           => 'Create',
        'braindump'    => 'Create',
        'new'          => 'Create',
        'add'          => 'Create',
        'do'           => 'Create',
        'todo:'        => 'Create',

        't'            => 'Todo',
        'ls'           => 'Todo',
        'todo'         => 'Todo',
        'tood'         => 'Todo', # someone explicitly requested this one

        'tag'          => 'Tag',

        'tags'         => 'Tags',

        'untag'        => 'Untag',
        'detag'        => 'Untag',

        'search'       => 'Search',
        'find'         => 'Search',
        '/'            => 'Search',

        'd'            => 'Done',
        'done'         => 'Done',
        'did'          => 'Done',
        'finish'       => 'Done',
        'finished'     => 'Done',
        'complete'     => 'Done',
        'completed'    => 'Done',

        'undone'       => 'Undone',
        'unfinish'     => 'Undone',
        'unfinished'   => 'Undone',
        'notdone'      => 'Undone',
        'notfinish'    => 'Undone',
        'notfinished'  => 'Undone',
        'incomplete'   => 'Undone',
        'notcomplete'  => 'Undone',
        'notcompleted' => 'Undone',

        'hideforever'  => 'HideForever',

        'comment'      => 'Comment',

        'feedback'     => 'Feedback',

        'random'       => 'Random',

        'give'         => 'Give',
        'push'         => 'Give',
        'owner'        => 'Give',
        'assign'       => 'Give',

        'accept'       => 'Accept',

        'reject'       => 'Decline',
        'decline'      => 'Decline',

        'delete'       => 'Delete',
        'del'          => 'Delete',
        'rm'           => 'Delete',
        'remove'       => 'Delete',

        'due'          => 'Due',

        'priority'     => 'Priority',
        'prio'         => 'Priority',

        'privacy'      => 'Privacy',

        'show'         => 'Show',
        'view'         => 'Show',
        'display'      => 'Show',
        'cc'           => 'Show',
        'context'      => 'Show',
        'task'         => 'Show',

        'hide'         => 'Hide',
        'starts'       => 'Hide',

        'next'         => 'Next',
        'prev'         => 'Prev',
        'previous'     => 'Prev',
        'n'            => 'Next',
        'p'            => 'Prev',
        'page'         => 'Page',

        'review'       => 'Review',
        'taskreview'   => 'Review',

        'history'      => 'History',
        'changes'      => 'History',
        'info'         => 'History',
        'information'  => 'History',
        'comments'     => 'History',

        'alias'        => 'Alias',
        'aliases'      => 'Alias',
        'expand'       => 'Alias',
        'expansion'    => 'Alias',

        'then'         => 'Then',
        'andthen'      => 'Then',

        'rename'       => 'Rename',
        'resummarize'  => 'Rename',

        'filter'       => 'Filter',
        'filters'      => 'Filter',

        'move'         => 'Move',
        'group'        => 'Move',
        'regroup'      => 'Move',

        'estimate'     => 'Estimate',
        'worked'       => 'Worked',
        'spent'        => 'Worked',

        'note'         => 'Note',
        'notes'        => 'Note',
        'describe'     => 'Note',
        'description'  => 'Note',

        'url'          => 'URL',
        'uri'          => 'URL',
        'urls'         => 'URL',
        'uris'         => 'URL',
        'link'         => 'URL',
        'links'        => 'URL',

        '?'            => 'Help',
        'help'         => 'Help',
        'man'          => 'Help',

        'date'         => 'Date',
        'time'         => 'Date',
        'datetime'     => 'Date',

        'invite'       => 'Invite',

        'upforgrabs'   => 'Unowned',
        'unowned'      => 'Unowned',

        'start'        => 'Start',
        'begin'        => 'Start',

        'stop'         => 'Stop',
        'end'          => 'Stop',

        'pause'        => 'Pause',
        'unpause'      => 'Unpause',

        'project'      => 'Project',
        'milestone'    => 'Milestone',

        'hi'           => 'Greeting',
        'hello'        => 'Greeting',
        'hey'          => 'Greeting',

        'bye'          => 'Bye',
        'goodbye'      => 'Bye',
        'good-bye'     => 'Bye',

        'thanks'       => 'Thanks',

        'whoami'       => 'Whoami',

        'version'      => 'Version',

        'unlink'       => 'Unlink',
    });

    for (values %{$self->command_table})
    {
        require "BTDT/IM/Command/$_.pm"
            unless exists $INC{"BTDT/IM/Command/$_.pm"};
    }

    $self->priority_table(
    {
        'lowest'  => 1,
        'low'     => 2,
        'normal'  => 3,
        'high'    => 4,
        'highest' => 5,

        '!!'      => 5,
        '!'       => 4,

        '--'      => 1,
        '-'       => 2,
        '+'       => 4,
        '++'      => 5,

        0         => 1,
        1         => 1,
        2         => 2,
        3         => 3,
        4         => 4,
        5         => 5,
        6         => 5,
        7         => 5,
        8         => 5,
        9         => 5,
    });

    $self->priorities(
    [
        '',
        'lowest',
        'low',
        'normal',
        'high',
        'highest',
    ]);

    # true = commit modal thing (braindump), false = abort
    $self->end_modal(
    {
        '.'        => 1,
        'done'     => 1,
        'finish'   => 1,
        'cancel'   => 0,
    });
}

=head2 login

This method is used to log into whatever third-party service this is a gateway
to. You don't have to override this, nor do you have to call
C<< $self->SUPER::login >>.

=cut

sub login {
}

=head2 iteration

This method is called repeatedly, you can use this to poll the IM object to see
if it has any messages incoming.

=cut

sub iteration
{
    my $self = shift;
}

=head2 _increment_stat NAME

Loads the L<Jifty::Model::Metadata> object given by NAME, increments it by one,
and stores it again. Used for statistics tracking.

=cut

sub _increment_stat {
    my $name = shift;
    my $current = Jifty::Model::Metadata->load($name) || 0;
    $current += 1;
    Jifty::Model::Metadata->store($name => $current);
}

=head2 received_message sender, message, PARAMHASH

This method should be called for any incoming message. sender and message are
canonicalized for you.

=cut

sub received_message
{
    my ($self, $sender, $message, %args) = @_;

    eval
    {
        if ( Jifty->config->framework('DevelMode') ) {
            Module::Refresh->refresh;
            Jifty::I18N->refresh;
        }

        $sender = $self->canonicalize_screenname($sender);
        $message = Jifty::I18N->promote_encoding($message);
        $message = $self->canonicalize_incoming($message);

        if (!defined $message) {
            $self->log->info("[IM] $sender on ".$self->protocol." sent a no-op message");
            return;
        }

        eval {
            $self->log->info("[IM] $sender on ".$self->protocol.": '$message'");
        };
        warn $@ if $@;

        # prevent a nice infinite loop of
        #    aolsystemmsg: hi
        #    hmtasks: hi
        #    aolsystemmsg: cannot send msg to SN you're not on buddy list of
        #    hmtasks: hi
        #    aolsystemmsg: cannot send msg to SN you're not on buddy list of
        #    hmtasks: hi
        # etc
        return if ($sender eq 'aolsystemmsg' || $sender eq 'aim')
               && $self->protocol eq 'AIM';

        my ($user, $userim);

        if ($args{user} && $args{userim})
        {
            ($user, $userim) = @args{qw/user userim/};
        }
        else
        {
            ($user, $userim) = $self->authorized_as($sender, $message, %args);
        }

        return unless $user;

        my $current_user = BTDT::CurrentUser->new(id => $user->id);
        $self->current_user($current_user);

        my $session = $self->get_session($sender);

        _increment_stat("app_im_messages");

        my $protocol = lc $self->protocol;
        _increment_stat("app_${protocol}_messages");

        $self->_parse_message(
            %args,
            screenname   => $sender,
            message      => $message,
            user         => $user,
            userim       => $userim,
            session      => $session,
        );

        # this really has to be done last otherwise the system will see
        # the current message here
        $session->set(last_message => $message);

        my $now = time;
        my $previous = $session->get('last_message_time') || 0;

        # check whether we received a message today from this user. we
        # can't just to ($now - $previous > $spd) because that's a rolling
        # stat, whereas we want a cutoff point
        my $spd = 24*60*60;
        if ($now % $spd > $previous % $spd) {
            _increment_stat("app_im_users");
            _increment_stat("app_${protocol}_users");
        }

        $session->set(last_message_time => $now);

        $session->unload();
    };

    if ($@)
    {
        my $error = $@;
        eval {
            if ($error =~ /^BTDT::IM error: (.*)\n/) {
                $self->send_message($sender,
                                    "An error has occurred: $1",
                                    $args{send_param});
                return;
            }

            $self->log->error("[IM] Exception thrown! Sender was $sender on "
                            . $self->protocol
                            . ". Message was '$message'. Exception was: $error");

            $self->send_message($sender,
                                "Ack! Some kind of error occurred. Sorry!",
                                $args{send_param});

            $self->send_message($sender, $error, $args{send_param})
                if Jifty->config->framework('DevelMode');
        };
        if ($@) {
            $self->log->error("[IM] An exception occurred when sending a message! $@");
        }
    }

    $self->log->info("[IM] Done replying to $sender on ".$self->protocol);
}

=head2 _check_modal (usual cmd args)

Internal method for checking and finishing modal commands.

=cut

sub _check_modal
{
    my $self = shift;
    my %args = @_;

    return if $args{modal_end};

    my $so_far = $args{session}->get('modal_state');

    if (defined($so_far) && $so_far ne '')
    {
        my $end_modal = $self->end_modal->{lc $args{message}};

        if (defined($end_modal))
        {
            # must come before dispatch to avoid infinite loop
            $args{message} = $so_far;
            $args{session}->set(modal_state => '');

            # if modal has no newline then it's only the initial text (such
            # as "create"), therefore we should act as if the user is
            # canceling if they end without adding anything
            if ($end_modal && $args{message} =~ /\n/)
            {
                $self->_parse_message(%args, modal_end => 1);
            }
            else
            {
                my ($command) = $args{message} =~ /^(\w+)/;
                $args{abort_message}
                    ||= "OK. I've canceled \"\u$command\" mode.";

                $self->send_message($args{screenname}, $args{abort_message}, $args{send_param});
            }

            return 1;
        }

        $args{session}->set(modal_state => "$so_far\n$args{message}");
        $self->send_message($args{screenname},
                            "OK. Type <b>done</b> to finish or type <b>cancel</b> to exit without sending.", $args{send_param});
        return 1;
    }

    return 0;
}

=head2 authorized_as screenname, message

Used to check whether screenname is authorized by any user account. Returns a
user object and a userim object if authorized, otherwise false. If it returns
false then it will have already responded to the user, so you don't have to.

If the user is unauthorized and the message contains the authorization token,
this will still return false.

=cut

sub authorized_as
{
    my ($self, $screenname, $message, %args) = @_;

    my $userim = BTDT::Model::UserIM->new(current_user
                                          => BTDT::CurrentUser->superuser);
    $userim->load_by_cols("protocol" => $self->protocol,
                          screenname => $screenname);

    if ($userim->user_id)
    {
        my $current_user = BTDT::CurrentUser->new(id => $userim->user_id);
        $userim->current_user($current_user);

        my $user = BTDT::Model::User->new(current_user => $current_user);
        $user->load($userim->user_id);
        return ($user, $userim);
    }

    # so no users found, let's see if this is an auth token
    $message =~ s/\s+//g;

    # String::Koremutake generates only alphabetical chars. User may have
    # extra crap in his message that causes him to fail auth. Whether this
    # should be existant at all is another question altogether. If the user
    # cannot auth properly, chances are the rest of the bot is going to go
    # badly for him. On the other hand, sometimes the client sends only
    # weird chars on the first message, to probe whether the other client
    # can do encryption. So this stripping is probably worthwhile.
    $message =~ tr/a-zA-Z//cd;

    $userim->load_by_cols("auth_token" => $message, confirmed => 0);
    if ($userim->user_id)
    {
        $userim->set_confirmed(1);
        $userim->set_protocol($self->protocol);
        $userim->set_screenname($screenname);

        my $current_user = BTDT::CurrentUser->new(id => $userim->user_id);
        my $user = BTDT::Model::User->new(current_user => $current_user);
        $user->load($userim->user_id);

        if ($self->terse) {
            $self->send_message($screenname, "Your account has been activated, ".$user->name.". Hooray!", $args{send_param});
        }
        else {
            $self->send_message($screenname, "Your account has been activated, ".$user->name.". Hooray!\n\nI know most of the basic Hiveminder commands, like <b>todo</b> and <b>create</b>. Type <b>help</b> for a list of what I can do! Visit http://hiveminder.com/legal/privacy to see our privacy policy.", $args{send_param});
        }
    }
    else
    {
        if ($self->terse) {
            $self->send_message($screenname, "Hi, I'm Hiveminder. Check out http://hiveminder.com/prefs/IM to set up Hiveminder+".$self->protocol." goodness.", $args{send_param});
        }
        else {
            $self->send_message($screenname, "Hi, I'm Hiveminder. I can help you keep track of what you need to do and what you need other folks to do. Make an account at <b>http://hiveminder.com/</b> then configure IM support at http://hiveminder.com/prefs/IM so we can chat! Visit http://hiveminder.com/legal/privacy to see our privacy policy.", $args{send_param});
        }
    }

    return;
}

=head2 _parse_message currentuser, screenname, message

Called to dispatch to commands. Handles modal checks and updates.

=cut

sub _parse_message
{
    my $self = shift;
    my %args = @_;

    Jifty->web->current_user($self->current_user);
    Jifty->web->response(Jifty::Response->new);
    Jifty->web->request(Jifty::Request->new);

    # check if we need to get a 'y' from the user
    my $action = $args{session}->get('confirm');
    if (!defined($action) || $action ne '')
    {
        $args{session}->set(confirm => '');
        if ($args{message} eq 'y')
        {
            $args{message} = $action;
        }
    }

    return if $self->_check_modal(%args);

    # make sure that "a;;b" gets parsed as "a" then "b" not "command named a;;b"
    $args{message} =~ s/ ?;; ?/ ;; /g;

    $args{message} =~ s/^\s*//;

    # typing an invalid command then ^ creates that task
    my $last_message = $args{session}->get('last_message');
    if ($args{message} =~ /^\^\s*$/ && defined($last_message)) {
        $args{message} = "create $last_message";
    }

    my $review_tasks = $args{session}->get('review_tasks');
    if (defined($review_tasks) && $review_tasks ne '' && !$args{in_review})
    {
        my $package = 'BTDT::IM::Command::Review';
        for ($package->can('review')->($self, %args, command => 'review'))
        {
            $self->send_message($args{screenname}, $_, $args{send_param});
        }
        return;
    }

    my $package;

    if ($self->only_create) {
        $package = 'BTDT::IM::Command::Create';
    }
    else {
        ($package, $args{message}) = $self->package_of($args{message});

        if (!defined($package))
        {
            if ($self->default_to_create) {
                $package = 'BTDT::IM::Command::Create';
            }
            else {
                $self->send_message($args{screenname}, "Unknown command. Use <b>?</b> or <b>help</b> if you need it. Use <b>^</b> to create a task from that message. Should this work? Send <b>feedback</b>!", $args{send_param});
                $self->log->debug("[IM] Unknown command received: $args{message}");
            return;
            }
        }
    }

    (my $command = $package) =~ s/^BTDT::IM::Command:://;
    my $dispatch_to = $package->can('run');

    if (!$self->current_user->pro_account && $args{message} =~ /;;/) {
        my $message = "Hold it! You're trying to use ;; (multiple commands). This is a pro-only feature. Upgrade today! http://hiveminder.com/pro";
        $self->send_message($args{screenname}, $message, $args{send_param});
        return $message;
    }

    if ($command ne 'Alias' && $args{message} =~ s/;;(.*)//s) {
        if ($args{multicommand_recurse}++ > 15) {
            my $message = "You're doing too many commands in one IM. Cool it a bit.";
            $self->send_message($args{screenname}, $message, $args{send_param});
            return $message;
        }

        $args{rest} = $1;
    }

    $args{message} =~ s/^\s+//;
    $args{message} =~ s/\s+$//;
    $args{command} = lc $command;
    $args{package} = $package;
    my @messages = $dispatch_to->($self, %args);

    for (@messages)
    {
        my $message = ref($_) eq 'HASH' ? $_->{response} : $_;
        $self->send_message($args{screenname}, $message, $args{send_param});
    }

    if (defined($args{message} = delete $args{rest})) {
        push @messages, $self->_parse_message(%args);
    }

    return @messages;
}

sub _list
{
    my $self = shift;
    my %args = (
        tokens       => [qw(owner me)],
        post_tokens  => sub {},
        post_filter  => sub {},
        post_search  => sub {},
        apply_tokens => sub {
            my $tasks = shift;
            my $args = shift;
            $tasks->from_tokens(@_);
        },
        search => sub {
            my ($self, $tasks, $args) = @_;
            $tasks->smart_search($args->{message}) if $args->{message} ne '';
        },
        @_,
    );

    my $tasks = BTDT::Model::TaskCollection->new();
    $args{apply_tokens}->($tasks, \%args, @{ $args{tokens} });

    my $error = $args{post_tokens}->($self, $tasks);
    return $error if defined $error;

    $self->apply_filters($tasks, %args);
    $error = $args{post_filter}->($self, $tasks, ($args{session}->get('filters') || []));
    return $error if defined $error;

    $args{search}->($self, $tasks, \%args);

    $error = $args{post_search}->($self, $tasks);
    return $error if defined $error;

    my @tasks = map {$_->record_locator} @{$tasks->items_array_ref};
    if (@tasks == 1 && exists $args{header1})
    {
        $args{session}->set(query_header => '1 ' . $args{header1});
    }
    else
    {
        $args{session}->set(query_header => @tasks . ' ' . $args{header});
    }
    $args{session}->set(query_tasks => join ' ', @tasks);
    $args{session}->set(page => 1);

    my $page = $self->make_pager(scalar(@tasks), $args{user}->per_page);

    $args{session}->set(max_page => $page->last_page);

    $self->_show_tasks(%args);
}

sub _show_tasks
{
    my $self = shift;
    my %args = @_;

    my @locators = split ' ', $args{session}->get('query_tasks');
    return 'No matches.' if @locators == 0;

    my $current_page = $args{session}->get('page');

    my $page = $self->make_pager(scalar(@locators), $args{user}->per_page);

    my $first_page = $page->first_page;
    my $last_page = $page->last_page;

    # the next/prev commands don't do any checks themselves
    if ($current_page < $first_page)
    {
        $args{session}->set(page => $first_page);
        return "You're already on the first page.";
    }
    if ($current_page > $last_page)
    {
        $args{session}->set(page => $last_page);
        return "You're already on the last page.";
    }

    $page->current_page($current_page);
    my $next_page = $page->next_page;
    my $prev_page = $page->previous_page;

    my $response = $args{session}->get('query_header');

    # inform user of pagination, filters
    my @metadata;

    push @metadata, "page $current_page of $last_page"
        if $last_page > 1;

    my $filters = @{ $args{session}->get('filters') || [] };
    push @metadata, "$filters filter" . ($filters == 1 ? "" : "s")
        if $filters;

    if (@metadata) {
        $response .= " (" . join(', ', @metadata) . ")";
    }

    $response .= ':';

    my $seen;

    for ($page->first-1 .. $page->last-1)
    {
        my $task = BTDT::Model::Task->new();
        $task->load_by_locator($locators[$_]);

        if (!$task->id)
        {
            $response .= "\n#$locators[$_] not found";
            next;
        }

        if (@locators == 1)
        {
            # show the full task if only one task in the list
            $response .= "\n" . $self->task_summary($task);
        }
        else
        {
            $response .= "\n" . $self->short_task_summary($task);
        }
        $seen .= " #" . $task->record_locator;
    }

    if ($next_page || $prev_page) {
        $response .= "\n";

        if ($self->terse) {
            $response .= "("
                      .  ($next_page ? "next" : "")
                      .  ($next_page && $prev_page ? "/" : "")
                      .  ($next_page ? "prev" : "")
                      .  ")";
        }
        else {
            $response .= "\nUse <b>next</b> to go to page $next_page."
                if $next_page;
            $response .= "\nUse <b>prev</b> to go to page $prev_page."
                if $prev_page;
        }
    }

    $self->_set_shown_tasks($args{session}, $seen);

    return $response;
}

=head2 make_pager total_entries, entries_per_page

Returns a L<Data::Page> object initialized with the total entries and entries
per page. The special value of 0 entries per page will cause page one to list
all tasks. This is consistent with the values for
C<< BTDT::Model::User->per_page >>.

=cut

sub make_pager {
    my $self     = shift;
    my $total    = shift;
    my $per_page = shift;

    my $pager = Data::Page->new;
    $pager->total_entries($total);

    $pager->entries_per_page($per_page)
        if $per_page;

    return $pager;
}

=head2 no_matches DEFAULT, HASHREF, CMDARGS

This will display a "no matches" message. The default is the default message to
be shown, usually different for each command ("Tag what?", "Change priority of
what?"). The hashref is meant to be the return value of msg2tasks. It returns
a message suitable for displaying to the user.

If it looked like the command was a search, it will return "No matches." If
there were any filters applied, this will let the user know that, too.

=cut

sub no_matches
{
    my $self    = shift;
    my $default = shift;
    my $msg     = shift;
    my %args    = @_;

    my $pre     = $args{pre} || '';
    my $filters = @{ $args{session}->get('filters') || [] };
    my $post    = $args{post} || '';

    if ($filters && !$self->terse) {
        $post .= " By the way, you have "
              .  $filters
              .  ' filter'
              .  ($filters == 1 ? '' : 's')
              .  ' set. (Remember that you can clear them with <b>filter clear</b>)'
    }

    return $pre . "No matches." . $post if $msg->{search};
    return $pre . $default . $post;
}

=head2 _add_to_task (usual cmd args) update_sub

Takes the message and interprets it as "[locators] [input]". This is used to
tag tasks or comment on tasks, but can be used for anything else that fits the
pattern. C<update_sub> is called for each task given that currentuser has
write-access to. You may set C<tasks> in the hash which will force the tasks
updated to that set.

Returns C<undef> if it couldn't find any tasks to try to update. Otherwise,
returns a hashref with the following fields set:

=over

=item * updated

Tasks that appear to have been updated.

=item * notfound

Record locators that do not exist.

=item * noaccess

Tasks that the current_user passed in didn't have write access to.

=item * message

The message passed in with any locators stripped out.

=item * contextual

A boolean which will be true iff the user gave no locators in the message, so
context was used to determine which tasks to update.

=back

=cut

sub _add_to_task
{
    my $self = shift;
    my %args = @_;

    my $locators;
    my $contextual = 0;

    $args{message} =~ s/^\s*//;
    $args{message} =~ s/\s*$//;

    if (ref($args{tasks}) eq 'ARRAY' && @{$args{tasks}})
    {
        $locators = join ' ', map {UNIVERSAL::isa($_, 'BTDT::Model::Task')
                                   ? $_->record_locator
                                   : uc $_} @{$args{tasks}};
    }
    elsif ($args{message} =~ s/^((?>#\S+\s*)+)//)
    {
        $locators = $1;
    }
    elsif ($args{message} =~ s/^\s*th(?:ese|is)\b\s*// || $args{in_review})
    {
        $locators = $self->_get_shown_tasks($args{session});
        $contextual = 1;
    }

    return unless $locators;

    my @notfound;
    my @noaccess;
    my @updated;

    for my $locator (split ' ', $locators)
    {
        $locator =~ s/^#//;

        my $task = BTDT::Model::Task->new();
        $task->load_by_locator($locator);

        push @notfound, $locator and next if !$task->id;
        push @noaccess, $task and next
            if !$task->current_user_can('update');

        push @noaccess, $task and next
            if !$args{update_sub}->($task, $args{message});

        push @updated, $task;
    }

    $self->_set_shown_tasks($args{session}, @updated);

    return
    {
        updated    => \@updated,
        notfound   => \@notfound,
        noaccess   => \@noaccess,
        message    => $args{message},
        contextual => $contextual,
    };
}

=head2 locator_sort

Helper function that just sorts tasks by locator.

=cut

sub _locator_sort
{
    length($a->record_locator) <=> length($b->record_locator)
                                ||
            $a->record_locator cmp $b->record_locator;
}

=head2 _clump_tasks code, tasks

Helper function for sorting tasks. Takes a coderef and a list of tasks. The
coderef should return the relevant fields of a task in string form (such as due
date, or priority). This returns an array containing array references of tasks.
Each array reference contains tasks that have the same value according to the
coderef, sorted by record locator. The entire array is sorted by values given
by the coderef.

=cut

sub _clump_tasks
{
    my $self = shift;
    my $accessor = shift;
    my %clumps;

    for my $task (@_)
    {
        my $due = $accessor->($task) || '';
        push @{ $clumps{$due} }, $task;
    }

    my @ret;
    for (sort keys %clumps)
    {
        push @ret, [ sort _locator_sort @{$clumps{$_}} ]
    }

    return @ret;
}

=head2 _acceptance (usual cmd args) verb

Used for accepting or declining a task. The verb argument should be 'accept' or
'decline'.

=cut

sub _acceptance
{
    my $self = shift;
    my %args = @_;
    my $ret = '';

    if (!$args{in_review} && $args{message} eq '')
    {
        return $self->_list(%args,
            header1 => 'unaccepted task',
            header  => 'unaccepted tasks',
            tokens  => [qw(owner me unaccepted 1 not complete)],
            post_tokens => sub {
                my ($self, $tasks) = @_;
                return "You have no unaccepted tasks."
                    if $tasks->count == 0;
                return;
            },
        );
    }

    my $msg = $self->_msg2tasks(%args, show_unaccepted => 1);
    $ret .= "Cannot find ".$self->_locator_list(@{ $msg->{notfound} }).".\n"
        if @{ $msg->{notfound} };

    if (@{ $msg->{tasks} } == 0)
    {
        return $ret . "No matches." if $msg->{search};
        return $ret . "\u$args{command} what?";
    }

    my (@accepted, @noaccess, @alreadyowned);
    for (@{ $msg->{tasks} })
    {
        if ($_->owner->id eq $args{user}->id && $_->accepted)
        {
            push @alreadyowned, $_;
            next;
        }

        my $success = $self->update_task(
            $_,
            accepted => $args{command} eq 'accept' ? 1 : 0,
        );

        if ($success) { push @accepted, $_ }
        else          { push @noaccess, $_ }
    }

    if (@noaccess) {
        $ret .= "You can't $args{command} "
             .  $self->_locator_list(@noaccess).".";

        if ($args{command} ne 'accept') {
            my $it = @noaccess == 1 ? 'it' : 'them';
            $ret .= " It's okay, you're not responsible for $it anyway.";
        }

        $ret .= "\n";
    }

    $ret .= "You already own ".$self->_locator_list(@alreadyowned).".\n"
        if @alreadyowned;

    my $verbed = "\u$args{command}ed";
    $verbed =~ s/ee/e/; # fix "declineed"
    $ret .= "$verbed ".$self->_locator_list(@accepted) .".\n"
        if @accepted;

    $self->_set_shown_tasks($args{session}, @accepted);
    return {response => $ret, review_next => $msg->{contextual}};
}

=head2 _msg2tasks PARAMHASH

Takes some user input to find some tasks. If you have any additional data that
the command needs to keep track of (such as what tags you're adding), then
strip that off before you filter it through this. This does duplicate some
of the functionality of other methods in this class, but the hope is I can then
remove those other methods!

This will return a hash containing:

=over 4

=item tasks

A list of BTDT::Model::Task objects.

=item notfound

A list of record locators for which we could not find a BTDT::Model::Task.

=item contextual

True if and only if we used some contextual information in getting locators.
This includes receiving the empty message and receiving an explicit "this",
"these", or "all".

=item search

True if and only if a search of some kind was performed (todo /foo). You
would want to know this if no tasks were found, or for deleting (since it's
easy to make your search too wide, you want to give some kind of confirmation)

=back

=cut

sub _msg2tasks
{
    my $self = shift;
    my %args = @_;
    my $locators;
    my $contextual = 0;
    my $search = 0;

    $args{message} =~ s/\s+/ /g;

    # empty locator list gives context
    $contextual = $args{message} =~ s{^\s*$}
                                     {$self->_get_shown_tasks($args{session})}ei
                  || $contextual;

    # the 1-10 tasks shown by a page in a listing
    $contextual = $args{message} =~ s{\b(?:this|these)\b}
                                     {$self->_get_shown_tasks($args{session})}ei
                  || $contextual;

    # list the tasks shown in a listing
    $contextual = $args{message} =~ s{\blist\b}
                                     {$args{session}->get('query_tasks')}ei
                  || $contextual;

    # all todo tasks
    $contextual = $args{message} =~ s{\ball\b}
                                     {$self->_search(%args)}ei
                  || $contextual;

    # first search all /.../ delimited things
    $search = $args{message} =~ s{/([^/]*)/}
                                 {$self->_search(search => $1, %args)}gei
              || $search;

    # now /... to eol
    $search = $args{message} =~ s{/(.*)}
                                 {$self->_search(search => $1, %args)}ei
              || $search;

    my @tasks;
    my @notfound;
    my %seen;

    for (split ' ', $args{message})
    {
        s/^#+//;
        my $task = BTDT::Model::Task->new();
        $task->load_by_locator($_);

        if (!$task->id)
        {
            push @notfound, '#'.$_;
            next;
        }

        # remove duplicates
        next if $seen{$task->id}++;

        push @tasks, $task;
    }

    return
    {
        tasks      => \@tasks,
        notfound   => \@notfound,
        contextual => $contextual,
        search     => $search,
    };
}

=head2 _search PARAMHASH

Looks at the optional 'search' argument and attempts to resolve it into a list
of locators. You may pass it a true value for show_done to return completed
tasks. You can do the same for hide_undone, show_unaccepted, show_hidden, and
show_wont_complete. If a tokens argument is passed in (as an arrayref), it is
used instead of the default token list (overriding the various show_foo
options).

=cut

sub _search
{
    my $self = shift;
    my %args = @_;
    my @tokens;

    if ($args{tokens})
    {
        @tokens = @{$args{tokens}};
    }
    else
    {
        @tokens = qw(owner me);

        push @tokens, $args{show_unaccepted} ? qw(unaccepted 1) : qw(accepted);
        push @tokens, qw(complete) if $args{show_done};
        push @tokens, qw(not complete) if !$args{hide_undone};
        push @tokens, qw(starts before tomorrow) if !$args{show_hidden};
        push @tokens, qw(hidden forever) if $args{show_hidden_forever};
    }

    my $tasks = BTDT::Model::TaskCollection->new();
    $tasks->from_tokens(@tokens);
    $self->apply_filters($tasks, %args);
    $tasks->smart_search($args{search}) if defined $args{search};

    return join ' ',
           map { '#' . $_->record_locator }
           @{$tasks->items_array_ref};
}

sub _locator_list
{
    my $self = shift;
    Carp::cluck("No tasks to report") if @_ == 0;

    if ($self->terse && @_ > 1) {
        return @_ . " tasks";
    }

    # sort this way because #Z should come before #34
    my @tasks = sort { length($a) <=> length($b) || $a cmp $b }
                map {UNIVERSAL::isa($_, 'BTDT::Model::Task')
                          ? $_->record_locator
                          : uc $_} @_;

    @tasks = $self->linkify(@tasks);

    return "task $tasks[0]" if @tasks == 1;
    return "tasks $tasks[0] and $tasks[1]" if @tasks == 2;
    my $last = pop @tasks;
    return "tasks " . join(', ', @tasks) . ", and $last";
}

# call this for default tasks to operate on if the user provides none
sub _get_shown_tasks
{
    my $self = shift;
    my $session = shift;

    return $session->get('shown_tasks') || '';
}

# whenever you show a task to a user, call this so single-task edit mode Just Works
# for example, this input should all affect the task created:
#     create this is a task
#     tag for-joe
#     comment seems easier than I thought
#     done

sub _set_shown_tasks
{
    my $self = shift;
    my $session = shift;

    my @locators;

    for (@_)
    {
        if (UNIVERSAL::isa($_, 'BTDT::Model::Task'))
        {
            push @locators, '#'.$_->record_locator;
        }
        elsif (!ref($_))
        {
            for my $locator (split ' ', $_)
            {
                $locator =~ s/^#+//;
                push @locators, "#$locator";
            }
        }
        else
        {
            $self->log->debug("[IM] Tried to _set_shown_tasks object of type "
                              . ref($_));
        }
    }

    $session->set(shown_tasks => join ' ', @locators);
}

=head2 send_message recipient, message

This method is called whenever the server needs to send an outgoing message.
You won't need to canonicalize either recipient or message.

=cut

sub send_message
{
    my ($self, $recipient, $message) = @_;
    print "To $recipient: $message\n";
}

=head2 canonicalize_screenname screenname

This method is called whenever we receive a message. For example, spacing and
case are irrelevant in AIM screen names, but we still want "foobar" and "Foo
Bar" to resolve to the same name.

=cut

sub canonicalize_screenname
{
    my ($self, $screenname) = @_;
    return $screenname;
}

=head2 canonicalize_incoming message

This method is called whenever we receive a message. This is basically used to
strip out the clutter from messages, like AIM's HTML.

Please call SUPER::canonicalize_incoming in your subclass.

=cut

sub canonicalize_incoming
{
    my ($self, $message) = @_;

    # iChat seems to automatically append this crap to email addresses
    $message =~ s{ (\S+) \s+ \[ mailto: \s* \1 \] }{$1}xg;

    return $message;
}

=head2 canonicalize_outgoing message

This method should be called whenever we are sending a message.
This is basically used to, for example, translate \n to <br>

=cut

sub canonicalize_outgoing
{
    my ($self, $message) = @_;

    chomp $message;

    return $message;
}

=head2 short_task_summary task

This method will be called whenever we need to display a task alongside
other tasks, e.g. in the output of a search. Can be overridden to, say,
hyperlinkify the record locator.

=cut

sub short_task_summary
{
    my ($self, $task) = @_;

    my ($locator) = $self->linkify($task->record_locator);

    my $summary = sprintf '%s%s: %s',
        $task->complete ? '* ' : '',
        $locator,
        $self->encode($task->summary);

    if (!$self->terse) {
        my $today = BTDT::DateTime->now->ymd;
        my $owner = $task->owner->email;
        my $starts = defined($task->starts) && $task->starts->ymd gt $today;
        my $comments = grep { $_->type eq 'email' }
                       @{ $task->transactions->items_array_ref };

        my $but_first = $task->depends_on;
        my $and_then = $task->depended_on_by;

        for my $collection ($but_first, $and_then) {
            $collection->incomplete;
        }

        $summary .= $self->begin_metadata;

        $summary .= " [owner: $owner]"
            if $task->current_user->user_object->email ne $owner;
        $summary .= " [due: ".$task->due->friendly_date."]" if $task->due;
        $summary .= " [starts: ".$task->starts->friendly_date."]" if $starts;
        $summary .= " [priority: ".$self->priorities->[$task->priority]."]"
            if $task->priority != 3;
        $summary .= " [group: ".$self->encode($task->group->name)."]"
            if $task->group_id;
        $summary .= " [comments: $comments]" if $comments;

        for (["and then" => $and_then], ["but first" => $but_first]) {
            my ($type, $tasks) = @$_;
            my $count = $tasks->count;
            next if $count == 0;

            my $first = $tasks->first->record_locator;
            $summary .= " [$type: #$first";

            $summary .= " and " . ($count - 1) . " more"
                if $count > 1;

            $summary .= "]";
        }

        if ($task->current_user->has_feature('TimeTracking')) {
            my $time = $task->time_summary;
            $summary .= " [time: $time]" if $time;
        }

        $summary .= " [".$self->encode($task->tags)."]" if $task->tags ne '';

        $summary .= $self->end_metadata;
    }

    return $summary;
}

=head2 task_summary task

This method will be called whenever we need to display a task alone,
e.g. in the output of "give me a random task". Can be overridden to
do your dark bidding.

=cut

sub task_summary
{
    my $self = shift;
    my ($task) = @_;

    my $summary = $self->short_task_summary(@_) . "\n";

    if (!$self->terse) {
        my $description = $task->description;
        $description = $self->encode($description);

        $summary .= $description . "\n"
            if $description ne '';
    }

    return $summary;
}

=head2 resolve_builtin_aliases MESSAGE

Takes a MESSAGE, replaces all builtin aliases in it, and returns the
modified message.

=cut

sub resolve_builtin_aliases {
    my ($self, $message) = @_;

    $message =~ s/^\s*//;

    # "abandon" is short for "give up"
    $message =~ s#^abandon\b#give up#i;

    # "take" is short for "give me"
    $message =~ s#^take\b#give me: #i;

    # "unhide" is short for "hide until yesterday"
    $message =~ s#^unhide\b#hide yesterday: #i;

    # allow "/foo" to work as "/ foo"
    $message =~ s#^/(?=\S)#/ #;

    # syntax sugar for notes
    $message =~ s#^(notes?|descri(?:be|ption)):#$1 this:#i;

    # setting priorities - we use (?>) so it doesn't backtrace and produce
    # 'priority + +'
    $message =~ s{^((?>\+\+|\+|--|-))(.*)}{priority $1 $2};

    # "hide forever" should be condensed
    $message =~ s/^hide\s*forever\b/hideforever/i;

    # worked on -> worked
    $message =~ s/^worked\s*on\b/worked/i;

    # do foo by bar -> due foo by bar
    $message =~ s/^do\b(.*)\bby\b(.*)/due $1 by $2/i;

    # unalias foo -> alias foo=
    $message =~ s/^unalias (.*)/alias $1=/;

    # "git status" as requested by Chris Prather.. why not
    $message =~ s/^git\s+status\b/todo/i;

    return $message;
}

=head2 package_of message

This method attempts to pick off the first word of a message and interpret it
as a command. If all goes well, it will return the package name of the command
to be run, and the rest of the message with the command removed. If the command
could not be found, it will return undef and the entire message.

=cut

sub package_of
{
    my ($self, $message) = @_;
    my $copy = $self->resolve_builtin_aliases($message);

    $copy =~ s/^(\S+)\s*//;
    my $command = $1;

    if (!exists $self->command_table->{lc $command})
    {
        my $alias = BTDT::Model::CmdAlias->new();
        $alias->load_by_cols(owner => $self->current_user->id,
                             name => $command);
        if ($alias->id)
        {
            $copy = $alias->expansion . ' ' . $copy;
            $copy = $self->resolve_builtin_aliases($copy);
            $copy =~ s/^(\S+)\s*//;
            $command = $1;
        }
    }

    $command = lc $command;

    # if it's not a valid command, then it might be special syntax..
    if (!exists $self->command_table->{$command})
    {
        # "locator then locator" transforms to "then locator locator"
        if ($copy =~ /^(?:and\s*)?then\s+(\S+)\s*$/i)
        {
            $copy = "$command $1";
            $command = "then";
        }

        # a bare locator transforms to "show locator"
        if ($command =~ /^\s*#?\s*(\w{2,})\s*$/)
        {
            my $locator = $1;
            my $task = BTDT::Model::Task->new;
            eval { $task->load_by_locator($locator) };
            warn $@ if $@;
            if ($task->current_user_can('read')) {
                $copy = $task->record_locator;
                $command = 'show';
            }
        }
    }

    $command = 'thanks'
        if $command =~ /^thanks?\b/;

    return (undef, $message)
        if !exists $self->command_table->{$command};

    my $package = 'BTDT::IM::Command::' . $self->command_table->{$command};

    # every command must have a 'run'
    return (undef, $message) unless $package->can('run');

    return ($package, $copy);
}

=head2 update_task task, PARAMHASH

Runs an UpdateTask action. This is in BTDT::IM because many commands use it.
Returns C<undef> if the action was not validated. Returns 0 if the action
was unsuccessful. Returns true if the action was successful.

=cut

sub update_task
{
    my $self = shift;
    my $task = shift;
    my %args = @_;

    Jifty->web->response(Jifty::Response->new);
    Jifty->web->request(Jifty::Request->new);

    my $update = BTDT::Action::UpdateTask->new(
        arguments => \%args,
        record => $task
    );

    $update->validate or return undef;
    $update->run;
    $update->result->success or return 0;
    return 1;
}


=head2 linkify tasks

This method is used to hyperlinkify tasks. The arguments are a list of
BTDT::Model::Tasks and/or stringified record locators. Any subclass that
implements this method should be able to handle a mishmash of both types.

Should return a list of strings, mapped one-to-one on the input list.

=cut

sub linkify
{
    my $self = shift;

    map {
        my $copy = $_;
        $copy = $copy->record_locator if ref($copy) && $copy->can('record_locator');
        $copy =~ s{^#?(.*)$}{<a href="http://task.hm/$1">#$1</a>};
        $copy;
    } @_;
}

=head2 apply_filters TaskCollection, PARAHMASH

Applies the current user's filters to the TaskCollection. Operates on the
TaskCollection directly.

=cut

sub apply_filters
{
    my $self = shift;
    my $tasks = shift;
    my %args = @_;

    for (@{ $args{session}->get('filters') || [] })
    {
        BTDT::IM::Command::Filter::apply_filter($self, $_, $tasks);
    }
}

=head2 filter_tokens PARAMHASH

Gets a single string of all the tokens provided by your filters.

=cut

sub filter_tokens
{
    my $self = shift;
    my %args = @_;
    my $TC = 'BTDT::Model::TaskCollection';

    return $TC->join_tokens(
        map { BTDT::IM::Command::Filter::filter2tokens($self, $_) }
            @{ $args{session}->get('filters') || [] }
    );
}


=head2 encode STRING

Uses whatever the desired encoding method of the protocol. This will probably
be HTML entity encoding, e.g. & becoming &amp;.

Note that this is only called for text that the user has direct control over.
If you want to manipulate all text, do it in canonicalize_outgoing.

=cut

sub encode
{
    my $self = shift;
    my $string = shift;

    encode_entities($string, '<>&"');

    return $string;
}

=head2 make_oneline STRING -> STRING

Returns a one-line version of the input. Tries to be smart about punctuation.
Used by Twitter to one-line our IM output.

=cut

sub make_oneline {
    my $self    = shift;
    my $message = shift;

    # First, strip trailing newlines
    1 while chomp $message;

    # Then convert newlines to ',' unless there's already punctuation
    $message =~ s{(.)\n+}{$1 =~ y/.,!?:// ? "$1 " : "$1, "}eg;

    # Remove any newlines we missed
    $message =~ tr[\n][];

    return $message;
}

=head2 get_session screenname

Returns the L<Jifty::Web::Session> object for the given screenname on this
L<BTDT::IM>'s protocol.

=cut

sub get_session {
    my $self       = shift;
    my $screenname = shift;

    my $session = Jifty::Web::Session->new;
    $session->load_by_kv(UserIM => $self->protocol . ":" . $screenname);
    return $session;
}

=head2 begin_metadata

Returns a string of text to display before task metadata

=cut

sub begin_metadata { '' }

=head2 end_metadata

Returns a string of text to display before task metadata

=cut

sub end_metadata { '' }

1;

