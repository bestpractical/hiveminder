use warnings;
use strict;

=head1 DESCRIPTION

Make sure that we don't loop mail '

=cut

use Email::Reply;
use BTDT::Test tests => 48, actual_server => 1;

# setup {{{
my $server = BTDT::Test->make_server;
my $URL = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech($URL);

my $su = BTDT::CurrentUser->superuser;

# set up our problem user {{{
my $u = BTDT::Model::User->new(current_user => $su);
my ($id, $msg) = $u->create(name  => 'loop candidate',
                            email => 'candidate1@example.com' );
ok($id, $msg);

my $cu = BTDT::CurrentUser->new(email => $u->email);
# }}}
# give him a published address {{{
($id, $msg) = $u->publish_address();
ok($id, $msg);
my $personal_address = BTDT::Model::PublishedAddress->new(current_user => $su);
$personal_address->load($id);
ok($personal_address->id, $personal_address->address);

my $u_addr = $personal_address->address.'@my.hiveminder.com';
# }}}
# set up a group {{{
my $g = BTDT::Model::Group->new(current_user => $su);
($id, $msg) = $g->create(name => 'loopgroup');
ok($id, $msg);
# }}}
# set up the group's published address {{{
my $group_address = BTDT::Model::PublishedAddress->new(current_user => $su);
($id, $msg) = $group_address->create(
    group_id => $g->id,
    action   => 'CreateTask',
);
ok($id, $msg);
ok($group_address->id, $group_address->address);
# }}}

# Clean out the mailbox
BTDT::Test->setup_mailbox();
# }}}
# helper functions {{{
sub create_user_and_addy { # {{{
    my $name = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    # * set up a user
    my $user = BTDT::Model::User->new(current_user => $su);
    my ($id, $msg) = $user->load_or_create(name => $name, email => $name.'@example.com');
    ok($id, $msg);

    # * set up a personal incoming address
    my $addresses = $user->published_addresses;
    my $address = $addresses->first;;
    unless ($address) {
        ($id, $msg) = $user->publish_address();
        ok($id, $msg);
        $address = BTDT::Model::PublishedAddress->new(current_user => $su);
        $address->load($id);
    }
    ok($address->id, $address->address);
    return ($user, $address->address.'@my.hiveminder.com');
} # }}}
sub get_recipients { # {{{
    local $Test::Builder::Level = $Test::Builder::Level + 1;
} # }}}
sub get_sender { # {{{
    local $Test::Builder::Level = $Test::Builder::Level + 1;
} # }}}

sub construct_message { # {{{
    my %args = (
        to => undef,
        from => undef,
        subject => 'Test message',
        @_
    );
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $email = Email::Simple->create(
        header => [
            From    => $args{'from'},
            To      => $args{'to'},
            Subject => $args{'subject'}
        ],
        body => 'This space intentionally left blank',
    );

    return $email;
} # }}}
sub inject_message { # {{{
    my $msg = shift;
    Carp::cluck("No message provided for injection") unless ref $msg;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $val = BTDT::Test->mailgate(
        '--url'     => $URL,
        '--address' => header_addr( $msg, 'to' ),
        '--sender'  => header_addr( $msg => 'from' ),
        '--message' => $msg->as_string
    );

    return defined $val ? 1 : 0;
} # }}}
sub inject_message_ok { # {{{
    my $message = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    ok(inject_message($message), "Injected message");
} # }}}
sub header_addr { # {{{
    my $msg = shift;
    my $header = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    return undef unless ref $msg;
    my $line = $msg->header($header);
    my @addresses = Email::Address->parse($line);
    return undef unless $addresses[0];
    return $addresses[0]->address;
} # }}}

sub find_task { # {{{
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $task = BTDT::Model::Task->new(current_user => $cu);
    $task->load_by_cols(@_);

    ok($task && $task->id, "task loaded");
    return $task;
} # }}}
sub txns_of { # {{{
    my $summary = shift;
    my $task;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    if (ref($summary)) {
        $task = $summary;
    }
    else {
        $task = find_task(summary => $summary);
    }

    return $task->transactions->count;
} # }}}

sub inject_task_from { # {{{
    my $name = shift;
    my $summary = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ($user, $address) = create_user_and_addy($name);
    my $message = construct_message(from => $address, to => $u_addr, subject => $summary);
    inject_message_ok($message);
    return $address;
} # }}}

sub get_sent_messages { # {{{
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my @mail = BTDT::Test->messages;
    BTDT::Test->setup_mailbox();
    return @mail;
} # }}}
sub one_mail_ok { # {{{
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my @messages = get_sent_messages();
    is(@messages, 1, "one message sent");
    return $messages[0];
} # }}}
sub no_mail_ok { # {{{
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my @messages = get_sent_messages();
    is(@messages, 0, "no mail received");


} # }}}
sub bounced_ok { # {{{
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my @messages = get_sent_messages();
    is(@messages, 1, "got a mail");
    like($messages[0]->header('from'), qr/postmaster\@hiveminder/, "mail was from postmaster\@hiveminder");
} # }}}

sub grep_mail_to { # {{{
    my $address = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my @to;
    for my $mail (@_) {
        next if !$mail;
        my $to = $mail->header('to');
        push @to, $to;
        next unless $to =~ /$address/;
        ok(1, "Found a mail to $address");
        return $mail;
    }

    ok(0, "Couldn't find a mail to $address among @to");
    return undef;
} # }}}
sub update_task { # {{{
    my $task = shift;
    my %args = @_;

    Jifty->web->current_user($task->current_user);
    Jifty->web->response(Jifty::Response->new);
    Jifty->web->request(Jifty::Request->new);

    my $update = BTDT::Action::UpdateTask->new(
        arguments => \%args,
        record => $task,
    );

    my $success = 0;

    $update->validate
        and $update->run
        and $update->result->success
        and $success = 1;

    ok($success, "ran update action");
} # }}}
# }}}

# Someone sets their return address to their hiveminder address {{{
# have "user b" create a task by mail for $u, with their return address as $b->published_address.
my $address_b = inject_task_from(b => 'Task from B');

# hiveminder sends $u mail.
my $message = one_mail_ok();

# $u replies to the mail with "Great"
my $b_reply = Email::Reply::reply(
    to   => $message,
    from => $u->email,
    all  => 1,
    body => "Great!"
);
inject_message_ok($b_reply);

# hiveminder sends "Great" to $u->email and $b->published_address.
my @b_replies = get_sent_messages();
TODO: {
    local $TODO = "needs to be finished, then code must be fixed";
    is(@b_replies, 2, "Sent two messages");
}

# check recipients of the replies
my $to_b = grep_mail_to($address_b, @b_replies);

TODO: {
    local $TODO = "needs to be finished, then code must be fixed";
    grep_mail_to($u->email, @b_replies);
}

# Since the MTA does not exist here, we feed the second message ($address_b) to EmailDispatch
inject_message_ok($to_b);

# Hiveminder drops it on the floor with a permanent error, complaining about mail loops
bounced_ok();
# }}}



# Someone forwards a recipient address back to hiveminder {{{
# have "user c" create a task for $u
my $address_c = inject_task_from(c => 'Task from C');
my $txns = txns_of('Task from C');

# hiveminder sends $u mail.
$message = one_mail_ok();
ok($message->header('X-Hiveminder'), "outgoing mail has X-Hiveminder header");

# reinject the message _to_ $u_addr
$message->header_set(To => $u_addr);
inject_message_ok($message);

# make sure hiveminder adds a txn to the task but drops the message on the floor
my $new_txns = txns_of('Task from C') - $txns;
is($new_txns, 1, "one new transaction");

bounced_ok();
# }}}


# TODO: A recipient address bounces back into Hiveminder {{{
# have "user d" create a task for $u.
# hiveminder sends $u mail
# extract that message
# fake a bounce message from $u to the task email address
# make sure hiveminder adds a txn to the task but drops the message on the floor
# }}}

# TODO: Someone sets up an autoreply on a recipient address {{{
# have "user e" create a task for $u.
# hiveminder sends $u mail
# extract that message
# fake a vacation message from $u to the task email address. Use an outlook vacation message
# make sure hiveminder adds a txn to the task but drops the message on the floor
# }}}

# Something automated sends in a request (i.e. iwantsandy.com) {{{
# have "signup@iwantsandy" create a task for $u.
$message = Email::Simple->new(<<'EOT');
Received: (qmail 16609 invoked from network); 1 Nov 2008 19:08:38 -0000
Received: from unknown (HELO mario.valuesofn.com) (198.145.37.151) by
 bp.nmsrv.com with SMTP; 1 Nov 2008 19:08:38 -0000
Received: from iwantsandy.com (peach [10.15.25.12]) by mario.valuesofn.com
 (Postfix) with ESMTP id DEC9194658E for <dofrifoji@my.hiveminder.com>; Sat, 
 1 Nov 2008 12:08:37 -0700 (PDT)
Date: Sat, 1 Nov 2008 19:08:37 +0000
From: "Sandy [iwantsandy.com]" <signup@iwantsandy.com>
Reply-To: "Sandy [iwantsandy.com]" <signup@iwantsandy.com>
Message-ID: <bc99862e-6db5-4b9a-9928-2ae74835b7ca@iwantsandy.com>
Subject: Introduction (Re: )
Mime-Version: 1.0
Content-Type: multipart/mixed; boundary=mimepart_490ca935dccf1_4cd418b822be
X-Sandy-ID: 6280620
Precedence: bulk
Errors-To: postmaster@iwantsandy.com


--mimepart_490ca935dccf1_4cd418b822be
Content-Type: text/plain; charset=utf-8
Content-Disposition: inline

Hi there,

I'm Sandy, Foo's (foo@example.com) personal email assistant.

Foo had me share the following detail with you:

*  Sat, 11/1/2008 5:00pm B. Bar Baz
  - sms reminder at 4:45pm

I've gone ahead and attached calendar invitations for any appointments or to-dos and virtual business cards for any contacts associated with the enclosed details. Double-click any of the attachments to add them to your calendar, to-do list, or contacts.

Sincerely,

Sandy

Everyone deserves an assistant! Sign up for free in just seconds: click http://iwantsandy.com/[redacted]

On Saturday, November 1 at 3:08 PM, Greg wrote:

 > Remember: B. Bar Baz 5 O'Clock Club


--
If you'd rather I didn't contact you again, click here: http://iwantsandy.com/stop/[redacted]


--mimepart_490ca935dccf1_4cd418b822be
Content-Type: application/ics; name="B Bar Baz.ics"
Content-Transfer-Encoding: Base64
Content-Disposition: attachment; filename="B Bar Baz.ics"

[redacted]

--mimepart_490ca935dccf1_4cd418b822be--
EOT
$message->header_set( To => $u_addr );
inject_message_ok($message);
# hiveminder sends $u mail
my $task = find_task(summary => "Introduction (Re: )");
$message = one_mail_ok();
ok($message->header('X-Hiveminder'), "outgoing mail has X-Hiveminder header");
ok($message->header("Subject"), "");
# user completes the task
$task->set_complete(1);
# Doesn't send mail to requetor, because it was Precedence: bulk
no_mail_ok();
# }}}

# TODO: Hiveminder task address as a task owner/requestor {{{
# have "user f" create a task for himself.
inject_task_from(candidate => 'Task from self');
# grab that task`s comment address as $taskaddr
# have $taskaddr create a task for $u by mail
# hiveminder sends $u mail
# $u comments on the task
# hiveminder sends mail to $u
# hiveminder adds a note to the task that it decided not to send mail to $taskaddr so as to not start a mail loop
# }}}

# Task comment address the owner of the task {{{
# That is, someone tries to go back in time and become his own fater
my $task_recurse = BTDT::Model::Task->new(current_user => $cu);
$task_recurse->create(summary => "Hi, me");

# $u sets the task owner to $task_recurse->comment_address
update_task($task_recurse, owner_id => $task_recurse->comment_address);
is($task_recurse->owner->email, $task_recurse->comment_address, "set the owner to the comment address");
BTDT::Test->setup_mailbox(); # get rid of "do you accept this task?" message

# $u adds a comment on the task
$task_recurse->comment("This is so messed up!");
$txns = txns_of($task_recurse);

# hiveminder sends mail to $task_recurse->owner
my @recurse_mail = get_sent_messages();
my $to_recurse = grep_mail_to($task_recurse->comment_address, @recurse_mail);

# reinject
inject_message_ok($to_recurse);

# hiveminder adds a note to the task that it decided not to send mail to $task_recurse->owner so as to not start a mail loop
bounced_ok();
$new_txns = txns_of($task_recurse) - $txns;
is($new_txns, 1, "got the note about mail loop");
# }}}

# TODO: Published address as a task owner/requestor {{{
# user f creates a personal address, $f_addr
# $u creates a task, $task_f with owner $f_addr
# WHAT SHOULD REALLY HAPPEN:
#     hiveminder resolves $f_addr to "user f" and adds the task as a request for f and everything is fine
# What happens right now:
# hiveminder sends mail from $task_f->comment_address to $f_addr assigning the task
# hiveminder gets mail from itself destined to $f_addr and creates a new task in $f_addr, $task_f_prime
# hiveminder sends a reply to $task_f->comment_address
# reinject the message back to ourselves
# hiveminder gets a comment to $task_f->comment_address FROM $task_f_prime->comment_address
# Hiveminder adds a non-mailed note to $task_f and drops the mail on the floor
# }}}

# TODO: Group published address as a task owner/requestor {{{
# group h creates a group address, $h_addr
# $u creates a task, $task_h with owner $h_addr
# WHAT SHOULD REALLY HAPPEN:
#     hiveminder resolves $h_addr to "group h" and adds the task as an unowned task in group h
# 
#What happens right now:
# hiveminder sends mail from $task_h->comment_address to $h_addr assigning the task
# hiveminder gets mail from itself destined to $h_addr and creates a new task in group $h, $task_h_prime
# hiveminder sends a reply to $task_h->comment_address
# reinject the message back to ourselves
# hiveminder gets a comment to $task_h->comment_address FROM $task_h_prime->comment_address
# Hiveminder adds a non-mailed note to $task_h and drops the mail on the floor
# }}}

# TODO: Someone cross-forwards RT and hiveminder {{{
#   todo
# }}}
