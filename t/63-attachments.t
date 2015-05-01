use warnings;
use strict;

BEGIN {
    $ENV{JIFTY_VENDOR_CONFIG} = "t/attachment_config.yml";
}

use BTDT::Test tests => 88, actual_server => 1;

my $gooduser = BTDT::CurrentUser->new( email => 'gooduser@example.com' );

{
    # Setup pro user
    my $user = BTDT::Model::User->new( current_user => BTDT::CurrentUser->superuser );
    $user->load( $gooduser->id );
    $user->set_pro_account('t');
}

my $user = BTDT::Model::User->new( current_user => BTDT::CurrentUser->superuser );
$user->load( $gooduser->id );

# Setup server
my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

# Setup mech
my $URL  = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech( $URL );
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->html_ok;
$mech->content_like(qr/Logout/i, "logged in");

# Go to attachments tab
$mech->follow_link_ok( text => '01 some task' );
$mech->follow_link_ok( text => 'Attachments' );

# Upload file
is $user->disk_quota->usage, 0, "quota usage is 0";

my $tempfile = Jifty::Test->test_file(
    Jifty::Util->absolute_path("t/text-file")
);
open my $FILE, ">", $tempfile;
print $FILE "This is some text.  And some more text.";
close $FILE;

$mech->fill_in_action_ok(
    $mech->moniker_for('BTDT::Action::CreateTaskAttachment'),
    name    => 'test1',
    content => $tempfile
);
$mech->submit_html_ok;
$mech->content_contains('text-file', 'found uploaded file');

Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
is $user->disk_quota->usage, 39, "quota usage is correct";

# Delete attachment
my $attach = BTDT::Model::TaskAttachment->new( current_user => $gooduser );
$attach->load_by_cols( filename => 'text-file' );
ok $attach->id, "Got attachment";
like $attach->__value('content'), qr/This is some text\./, "Good content";
my ( $ret, $msg) = $attach->delete;
ok $ret, "deleted attachment";

Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
is $user->disk_quota->usage, 0, "quota usage is 0";

# Attempt to upload a file that's too big
my $tempfile2 = Jifty::Test->test_file(
    Jifty::Util->absolute_path("t/text-file2")
);
open my $FILE2, ">", $tempfile2;
print $FILE2 "x" x 1050; # Push us over the 1k test limit
close $FILE2;

$mech->fill_in_action_ok(
    $mech->moniker_for('BTDT::Action::CreateTaskAttachment'),
    name    => 'test2',
    content => $tempfile2
);
$mech->submit_html_ok;
$mech->warnings_like(qr/Attachment size .*? is too large/);
$mech->content_like(qr'Attachment size .+? too large', "found error message");
#$mech->content_contains('text-file', 'found previously file');
$mech->content_lacks('text-file2', 'did NOT find big file');

Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
is $user->disk_quota->usage, 0, "quota usage is still the same";

# Attempt to upload a file that exceeds user quota
my $cap = $user->disk_quota->cap;
ok $user->disk_quota->add_usage( $cap - $user->disk_quota->usage - 50 ), "add to usage";
ok !$user->disk_quota->usage_ok( 51 ), "51 bytes not ok";
ok $user->disk_quota->usage_ok( 50 ), "50 bytes ok";
my $usage = $user->disk_quota->usage;

my $tempfile3 = Jifty::Test->test_file(
    Jifty::Util->absolute_path("t/text-file3")
);
open my $FILE3, ">", $tempfile3;
print $FILE3 "x" x 60; # Push us over the user limit
close $FILE3;

$mech->fill_in_action_ok(
    $mech->moniker_for('BTDT::Action::CreateTaskAttachment'),
    name    => 'test3',
    content => $tempfile3
);
$mech->submit_html_ok;
$mech->warnings_like(qr/Attachment size .*? exceeds user quota/);
$mech->content_like(qr'Attachment size .+? exceeds user quota', "found error message");
#$mech->content_contains('text-file', 'found previously file');
$mech->content_lacks('text-file3', 'did NOT find big file');

Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
is $user->disk_quota->usage, $usage, "quota usage is still the same";

# Mail in attachment
BTDT::Test->setup_mailbox();
my @messages = BTDT::Test->messages();
is(scalar @messages, 0, "Cleared out the mbox");

my $secret = $user->email_secret;

# pro user to someone else
is(BTDT::Test->mailgate("--url" => $URL, "--address" => "otheruser\@example.com.$secret.with.hm", '--sender' => 'gooduser@example.com', "--message" => <<'END_MESSAGE'), '', "mailgate was silent");
From: gooduser@example.com
Subject: 03 test1
Content-Type: multipart/mixed;
 boundary="------------040902000207040007010107"

This is a multi-part message in MIME format.
--------------040902000207040007010107
Content-Type: text/plain; charset=ISO-8859-1; format=flowed
Content-Transfer-Encoding: 7bit

Hi, just a test task with attachments.

--------------040902000207040007010107
Content-Type: text/plain;
 name="test.txt"
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment;
 filename="test.txt"

This is a test.


--------------040902000207040007010107--
END_MESSAGE

@messages = BTDT::Test->messages;
is( scalar @messages, 1, "Got one message" );

my $message = shift @messages;
like $message->header('Subject'), qr/New task: 03 test1/, "Got subject";
is $message->header('To'), 'otheruser@example.com', "Got recipient";
like $message->body , qr/gooduser\@example.com/, "Got sender email";

my $task = BTDT::Model::Task->new( current_user => BTDT::CurrentUser->superuser );
$task->load_by_cols( summary => '03 test1' );
ok $task->id, "Got task";

# Check for attachment
my $attachment = BTDT::Model::TaskAttachment->new( current_user => $gooduser );
$attachment->load_by_cols( task_id => $task->id );
ok $attachment->id, "Got attachment";
like $attachment->content, qr/This is a test\./, "Good content";
ok !$attachment->hidden, "Attachment not hidden";

# Make sure we can get it
$mech->get_ok( $URL . '/task/' . $task->record_locator . '/attachment/' . $attachment->id );
$mech->content_contains('This is a test.', "got good content from web");

# Have non-pro otheruser reply with an attachment
my $comment_address = (Email::Address->parse( $message->header('From') ))[0]->address;

# Clear out inbox
BTDT::Test->setup_mailbox();
@messages = BTDT::Test->messages();
is(scalar @messages, 0, "Cleared out the mbox");

# reply comment
is(BTDT::Test->mailgate("--url" => $URL, "--address" => $comment_address, '--sender' => 'otheruser@example.com', "--message" => <<'END_MESSAGE'), '', "mailgate was silent");
From: otheruser@example.com
Subject: Re: New Task: 03 test1
Content-Type: multipart/mixed;
 boundary="------------040902000207040007010107"

This is a multi-part message in MIME format.
--------------040902000207040007010107
Content-Type: text/plain; charset=ISO-8859-1; format=flowed
Content-Transfer-Encoding: 7bit

Hi, just a test task with attachments.  Again.

--------------040902000207040007010107
Content-Type: text/plain;
 name="test2.txt"
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment;
 filename="test2.txt"

This is a test2.


--------------040902000207040007010107--
END_MESSAGE

# Check for attachment again (should be visible)
$attachment = BTDT::Model::TaskAttachment->new( current_user => $gooduser );
$attachment->load_by_cols( task_id => $task->id, filename => 'test2.txt' );
ok $attachment->id, "Got attachment";
like $attachment->content, qr/This is a test2\./, "Good content and can read it";
ok $attachment->hidden, "Attachment IS hidden though";

# Check for attachment (should be hidden for otheruser)
my $otheruser = BTDT::CurrentUser->new( email => 'otheruser@example.com' );
my $otheruid  = $otheruser->id;

Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');

$attachment = BTDT::Model::TaskAttachment->new( current_user => $otheruser );
$attachment->load_by_cols( task_id => $task->id, filename => 'test2.txt' );
ok $attachment->id, "Got attachment";
is $attachment->content, undef, "Can't read content";
ok $attachment->__value('hidden'), "Attachment IS hidden";

# Make sure it isn't listed
$mech->get_ok( $URL . '/task/' . $task->record_locator . '/attachments' );
$mech->content_contains('test.txt', "have first attachment");
$mech->content_contains('test2.txt', "do not have second attachment");

# Make sure we can get it
$mech->get( $URL . '/task/' . $task->record_locator . '/attachment/' . $attachment->id );
is $mech->status, 200, "Success";

# Upgrade otheruser to pro and check for unhidden attachments
{
    # Go pro
    my $user = BTDT::Model::User->new( current_user => BTDT::CurrentUser->superuser );
    $user->load( $otheruid );
    $user->set_pro_account('t');
}
$otheruser = BTDT::Model::User->new( current_user => BTDT::CurrentUser->superuser );
$otheruser->load( $otheruid );

Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
$attachment->load( $attachment->id );

ok !$attachment->__value('hidden'), "Attachment is NOT hidden";
$mech->get_ok( $URL . '/task/' . $task->record_locator . '/attachments' );
$mech->content_contains('test.txt', "have first attachment");
$mech->content_contains('test2.txt', "have second attachment");


# Mail in attachment that's too large
BTDT::Test->setup_mailbox();
@messages = BTDT::Test->messages();
is(scalar @messages, 0, "Cleared out the mbox");

# pro user to self
is(BTDT::Test->mailgate("--url" => $URL, "--address" => "gooduser\@example.com.$secret.with.hm", '--sender' => 'gooduser@example.com', "--message" => <<'END_MESSAGE'), '', "mailgate was silent");
From: gooduser@example.com
Subject: 13 moose
Content-Type: multipart/mixed;
 boundary="------------040902000207040007010107"

This is a multi-part message in MIME format.
--------------040902000207040007010107
Content-Type: text/plain; charset=ISO-8859-1; format=flowed
Content-Transfer-Encoding: 7bit

Hi, just a test task with attachments... that are too big!

--------------040902000207040007010107
Content-Type: text/plain;
 name="test3.txt"
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment;
 filename="test3.txt"

fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff


--------------040902000207040007010107--
END_MESSAGE

@messages = BTDT::Test->messages;
is( scalar @messages, 1, "Got one message" );

$message = shift @messages;
like $message->header('Subject'), qr/Error processing email/, "Got subject";
is $message->header('To'), 'gooduser@example.com', "Got recipient";
like $message->body , qr/unable to process an attachment/, "Got description";
like $message->body , qr/Attachment size .+? exceeds user quota/, "Got error message";
like $message->body , qr/\(test3.txt\)/, "Got filename";

$mech->warnings_like(qr/Attachment size .*? exceeds user quota/);

$task = BTDT::Model::Task->new( current_user => BTDT::CurrentUser->superuser );
$task->load_by_cols( summary => '13 moose' );
ok $task->id, "Got task";

# Check for attachment
$attachment = BTDT::Model::TaskAttachment->new( current_user => $gooduser );
$attachment->load_by_cols( task_id => $task->id );
ok !$attachment->id, "No attachment";
$attachment->load_by_cols( filename => "test3.txt" );
ok !$attachment->id, "No attachment";

# delete the attachments
my $attachments = BTDT::Model::TaskAttachmentCollection->new(current_user => $gooduser);
$attachments->unlimit;
$_->delete for @$attachments;

# forwarded attachment {{{
my $published_address = $mech->create_address_ok;

BTDT::Test->setup_mailbox();
@messages = BTDT::Test->messages();
is(scalar @messages, 0, "Cleared out the mbox");

is(BTDT::Test->mailgate("--url" => $URL, "--address" => $published_address, '--sender' => 'otheruser@example.com', "--message" => <<'END_MESSAGE'), '', "mailgate was silent");
From: otheruser@example.com
Subject: Fwd: This is a banana
MIME-Version: 1.0
Content-Type: multipart/mixed; 
	boundary="----=_Part_347_2143023.1212112482563"

------=_Part_347_2143023.1212112482563
Content-Type: text/plain; charset=ISO-8859-1
Content-Transfer-Encoding: 7bit
Content-Disposition: inline

---------- Forwarded message ----------
From: Sartak <sartak@gmail.com>
Date: May 29, 2008 9:53 PM
Subject: This is a banana
To: sartak@bestpractical.com, sartak@gmail.com


Peel it before you enjoy.

------=_Part_347_2143023.1212112482563
Content-Type: application/octet-stream; name=banana.pl
Content-Transfer-Encoding: base64
X-Attachment-Id: f_fgu4erjf
Content-Disposition: attachment; filename=banana.pl

IyEvdXNyL2Jpbi9lbnYgcGVybAp1c2Ugc3RyaWN0Owp1c2Ugd2FybmluZ3M7CgpkaWUgImJhbmFu
YVxuIjsKCg==
------=_Part_347_2143023.1212112482563--

END_MESSAGE

@messages = BTDT::Test->messages;
is( scalar @messages, 1, "Got one message" );

my ($locator) = $messages[0]->header('Subject') =~ /#(\w+)/;
ok($locator, "got a locator #$locator");

$task = BTDT::Model::Task->new( current_user => $gooduser );
$task->load_by_locator($locator);
ok($task->id, "loaded the task");
is($task->attachments->count, 1, "we have an attachment");
# }}}

# searching for attachments {{{
my $tasks = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$tasks->from_tokens(qw(has attachment));
is($tasks->count, 1, "one task has an attachment");
ok($_->attachment_count, "has attachments") for @$tasks;

$tasks = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$tasks->from_tokens(qw(has no attachments));
is($tasks->count, 4, "four tasks have an attachment");
is($_->attachment_count, 0, "no attachment") for @$tasks;
# }}}

