use warnings;
use strict;

=head1 DESCRIPTION

This is a template for your own tests. Copy it and modify it.

=cut

use BTDT::Test tests => 133;

# For encoding testing
use charnames ':full';
use Encode;
use Encode::IMAPUTF7;

ok(1, "Loaded the test script");

# Create incoming email addresses for later
my $GOODUSER = BTDT::CurrentUser->new( email => 'gooduser@example.com' );
my $incoming1 = BTDT::Model::PublishedAddress->new( current_user => $GOODUSER );
$incoming1->create(user_id => $GOODUSER->id, auto_attributes => "[priority: high][some tags]");
my $incoming2 = BTDT::Model::PublishedAddress->new( current_user => $GOODUSER );
$incoming2->create(user_id => $GOODUSER->id, auto_attributes => "[other things]");

# Add a couple other users to the group
my $group = BTDT::Model::Group->new( current_user => $GOODUSER );
$group->load_by_cols( name => 'alpha' );
for my $email (qw/otheruser@example.com onlooker@example.com/) {
    my $other = BTDT::Model::User->new( current_user => BTDT::CurrentUser->superuser );
    $other->load_by_cols( email => $email );
    $group->add_member( $other, 'member' );
}

# Set us up an IMAP server
my $client = BTDT::Test->start_imap;
my $task = BTDT::Model::Task->new(current_user => $GOODUSER);
my $mime;

#################### Login

# Non-pro can't log in
ok(!$client->login('gooduser@example.com', "secret"), "Can't log in (not pro)");

BTDT::Test->make_pro('gooduser@example.com');

# Wrong password fails login
ok(!$client->login('gooduser@example.com', "wrong"), "Can't log in (wrong password)");

# Right login
ok($client->login('gooduser@example.com', "secret"), "OK login");


#################### INBOX

# Have right messages in inbox
my $messages = $client->select("INBOX");
ok(defined $messages, "Selected INBOX");
is($messages, 2, "Have right number of messages in inbox");
body_like(1, qr/01 some task/);
body_like(2, qr/02 other task/);

# Create message via other methods
$task->create(
    summary => "03 new task with and \N{LATIN SMALL LETTER U WITH DIAERESIS}mlaut",
    description => '',
);

# Poll finds new message
$client->noop;
is(scalar @{$client->untagged}, 1, "Got an untagged message");
like($client->untagged->[0], qr/3 EXISTS/, "Is an EXISTS");
ok($mime = mime_object(3), "Got a MIME object");
my $header = $mime->header_obj;
isa_ok($header, "Email::MIME::Header");
like($header->header("Subject"), qr/03 new task/, "Has right subject");
like($header->header_raw("Subject"), qr/=\?UTF-8\?/, "Subject was encoded");

# Update task directly
$task->set_tags("foo");

# Poll gets updated message
$client->noop;
is(scalar @{$client->untagged}, 2, "Got two untagged messages");
like($client->untagged->[0], qr/3 EXPUNGE/, "Is an EXPUNGE");
like($client->untagged->[1], qr/3 EXISTS/, "Is an EXISTS");
body_like(3, qr/Tags: foo/);

# Add a comment
$task->comment("Some comment on the task");

# Poll gets updated message
$client->noop;
is(scalar @{$client->untagged}, 2, "Got two untagged messages");
like($client->untagged->[0]||'', qr/3 EXPUNGE/, "Is an EXPUNGE");
like($client->untagged->[1]||'', qr/3 EXISTS/, "Is an EXISTS");

# Can append to INBOX
ok($client->put("INBOX", <<'EOT'));
To: gooduser@example.com
From: otheruser@example.com
Subject: [whee] Some new task by append

A body goes here
EOT

# Get two updates as part of that
is(scalar @{$client->untagged}, 2, "Got two untagged messages");
like($client->untagged->[0], qr/4 EXPUNGE/, "Is an EXPUNGE");
like($client->untagged->[1], qr/4 EXISTS/, "Is an EXISTS");

# Has right body
body_like(4, qr/Some new task by append/);

# Creates a task
$task->load(4);
is($task->summary, "[whee] Some new task by append", "Can create tasks by append");
is($task->requestor->email, 'gooduser@example.com', "Has current user as requestor");
is($task->owner->email, 'gooduser@example.com', "Has current user as owner");
is($task->tags, "", "Didn't get any tags");


#################### Action mailboxes

# Copy to Actions/Completed
ok($client->copy(3, "Actions/Completed"), "Copied to completed mailbox");

# Task is no longer in mailbox
is(scalar @{$client->untagged}, 1, "Got an untagged message");
like($client->untagged->[0], qr/3 EXPUNGE/, "Is an EXPUNGE");

# Task is marked as complete
$task->load(3);
ok($task->complete, "Task is marked as complete");

# Mark as not complete
$task->set_complete(0);

# We see it again
$client->noop;
is(scalar @{$client->untagged}, 1, "Got an untagged message");
like($client->untagged->[0], qr/4 EXISTS/, "Is an EXISTS");
like(mime_object(4)->header("Subject"), qr/03 new task/);

# Copy into hide until mailbox
ok($client->copy(4, "Actions/Hide for/Days../03 days"), "Copied to hide until mailbox");

# Task is no longer in mailbox
is(scalar @{$client->untagged}, 1, "Got an untagged message");
like($client->untagged->[0], qr/4 EXPUNGE/, "Is an EXPUNGE");

# Task has changed due date
ok(!$task->starts, "Task didn't use to have a start date");
$task->load($task->id);
ok($task->starts, "Task has a start date");
my $now = BTDT::DateTime->now;
$now->current_user( $GOODUSER );
$now->add(days => 3);
is($task->starts->ymd, $now->ymd, "Has right start date");


#################### Group mailboxes

# Select the mailbox
$messages = $client->select("Groups/alpha");
ok(defined $messages, "Selected 'alpha' group");
is($messages+0, 0, "Have right number of messages in mailbox");

# Appending to it creates a group task owned by us
ok($client->put("Groups/alpha", <<'EOT'));
To: gooduser@example.com
From: otheruser@example.com
Subject: [whee] Some group task by append

A body goes here
EOT

# Get two updates as part of that
is(scalar @{$client->untagged}, 2, "Got two untagged messages");
like($client->untagged->[0], qr/1 EXPUNGE/, "Is an EXPUNGE");
like($client->untagged->[1], qr/1 EXISTS/, "Is an EXISTS");

# Has right body
body_like(1, qr/Some group task by append/);
body_like(1, qr/Group: alpha/);
$mime = mime_object(1);

# Creates a task
$task->load($mime->header("X-Hiveminder-Id"));
is($task->summary, "[whee] Some group task by append", "Can create tasks by append");
is($task->requestor->email, 'gooduser@example.com', "Has current user as requestor");
is($task->owner->email, 'gooduser@example.com', "Has current user as owner");
is($task->tags, "", "Didn't get any tags");
is($task->group->name, "alpha", "In the group");

# Showed up in inbox
$messages = $client->select("INBOX");
ok(defined $messages, "Selected inbox");
is($messages, 4, "See most recent message");
body_like(4, qr/Some group task by append/);

# Copy to group/unowned marks it as unowned
ok($client->copy(4, "Groups/alpha/Owners/Up for grabs"));
is(scalar @{$client->untagged}, 1, "Got an untagged message");
like($client->untagged->[0], qr/4 EXPUNGE/, "Is an EXPUNGE");
$task->load($task->id);
is($task->owner->name, "Nobody");

# Copy to "owned by someone else"
$messages = $client->select("Groups/alpha/Owners/Up for grabs");
ok(defined $messages, "Selected up for grabs");
is($messages, 1, "Has one message");
ok($client->copy(1, 'Groups/alpha/Owners/otheruser@example.com'));
is(scalar @{$client->untagged}, 1, "Got an untagged message");
like($client->untagged->[0], qr/1 EXPUNGE/, "Is an EXPUNGE");
$task->load($task->id);
is($task->owner->email, 'otheruser@example.com');

# Check that it got there
$messages = $client->select('Groups/alpha/Owners/otheruser@example.com');
ok(defined $messages, "Selected otheruser");
is($messages, 1, "Has one message");

# Transfer it to someone else
ok($client->copy(1, 'Groups/alpha/Owners/onlooker@example.com'));
is(scalar @{$client->untagged}, 1, "Got an untagged message");
like($client->untagged->[0], qr/1 EXPUNGE/, "Is an EXPUNGE");
$task->load($task->id);
is($task->owner->email, 'onlooker@example.com');

# Adding a group makes it show up immediately
ok(not(grep {$_ =~ /Newgroup/} $client->mailboxes), "Doesn't have a Newgroup mailbox");
my $newgroup = BTDT::Model::Group->new( current_user => $GOODUSER );
$newgroup->create( name => 'Newgroup' );
ok($newgroup->id, "Created a group");
ok((grep {$_ =~ /Newgroup/} $client->mailboxes), "Now has a Newgroup mailbox");

# Changing a group name is noticed
$newgroup->set_name("New Group");
is($newgroup->name, "New Group", "Changed group name");
ok(not(grep {$_ =~ /Newgroup/} $client->mailboxes), "Don't see old mailbox name");
ok((grep {$_ =~ /New Group/} $client->mailboxes), "See changed mailbox name");

# Check UTF-7 encoding of mailbox names
$newgroup->set_name("New Gro\N{LATIN SMALL LETTER U WITH DIAERESIS}p");
my ($name) = grep {$_ =~ /New Gro/} $client->mailboxes;
is($name, Encode::encode('IMAP-UTF-7', 'Groups/'.$newgroup->name));
is(Encode::decode('IMAP-UTF-7', $name), 'Groups/'.$newgroup->name);

# Can create a simple group
ok($client->create_mailbox("Groups/Moose"), "Created group on server");
$newgroup->load_by_cols( name => "Moose");
ok($newgroup->id, "Found group in database");

# Can create a UTF-7 named mailbox
$name = "Das Go\N{LATIN SMALL LETTER U WITH DIAERESIS}pen";
ok($client->create_mailbox(Encode::encode("IMAP-UTF-7","Groups/$name")), "Created group on server");
$newgroup->load_by_cols( name => $name);
ok($newgroup->id, "Found group in database, with correct UTF8 name");

# Can't create a mailbox with bad UTF-7
ok(not(grep {$_ =~ /Foo/} $client->mailboxes), "Don't see a mailbox for it before");
ok(not($client->create_mailbox("Groups/Foo&!!!")), "Bogus UTF-7 is bogus");
like($client->errstr, qr/Invalid UTF-7 encoding/);
my @groups = grep {$_->name =~ /Foo/} @{$GOODUSER->user_object->groups->items_array_ref};
is(scalar @groups, 0, "No groups created");
ok(not(grep {$_ =~ /Foo/} $client->mailboxes), "Don't see a mailbox for it after");


#################### Braindump mailboxes

# Select the mailbox
$messages = $client->select("Braindump mailboxes/[priority: high][some tags]");
ok(defined $messages, "Selected '[priority: high][some tags]' braindump");
is($messages, 1, "Have right number of messages in mailbox");

# Check email has right from: and subject:
$mime = mime_object(1);
is($mime->header("Subject"),$incoming1->address);
is($mime->header("From"),$incoming1->address . '@my.hiveminder.com');

# Copy into braindump should tag and change priority
$messages = $client->select("INBOX");
ok(defined $messages, "Selected inbox");
is($messages, 3, "Have right number of messages in inbox");
$mime = mime_object(1);
$task->load($mime->header("X-Hiveminder-Id"));
is($task->tags, "", "Has no tags");
is($task->priority, 3, "Has right priority");
ok($client->copy(1, "Braindump mailboxes/[priority: high][some tags]"));
is(scalar @{$client->untagged}, 2, "Got two untagged messages");
like($client->untagged->[0], qr/1 EXPUNGE/, "Is an EXPUNGE");
like($client->untagged->[1], qr/3 EXISTS/, "Is an EXISTS");
body_like(3, qr/Tags: some tags/);
$task->load($task->id);
is($task->tags, "some tags", "Has new tags");
is($task->priority, 4, "Has new priority");

# Copy into other braindump should add tags, not replace
ok($client->copy(3, "Braindump mailboxes/[other things]"));
is(scalar @{$client->untagged}, 2, "Got two untagged messages");
like($client->untagged->[0], qr/3 EXPUNGE/, "Is an EXPUNGE");
like($client->untagged->[1], qr/3 EXISTS/, "Is an EXISTS");
body_like(3, qr/Tags: other some tags things/);
$task->load($task->id);
is($task->tags, "other some tags things", "Has new tags");

# Append into braindump makes new task with those as defalts
ok($client->put("Braindump mailboxes/[priority: high][some tags]", <<'EOT'));
To: gooduser@example.com
From: otheruser@example.com
Subject: [whee] Some new task by braindump

A body goes here
EOT

# Get an update as part of that
is(scalar @{$client->untagged}, 1, "Got an untagged message");
like($client->untagged->[0], qr/4 EXISTS/, "Is an EXISTS");

# Has right body
body_like(4, qr/Some new task by braindump/);
body_like(4, qr/Tags: some tags/);
$mime = mime_object(4);

# Created a task
$task->load($mime->header("X-Hiveminder-Id"));
is($task->summary, "[whee] Some new task by braindump");
is($task->tags, "some tags");
is($task->priority, 4);


sub body_like {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my($n, $regex) = @_;
    my $lines = $client->get( $n );
    ok(defined $lines, "Got body all right");
    my $str = join("", @{$lines || []});
    like($str, $regex, "Body matches");
}

sub mime_object {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my($n) = @_;
    my $lines = $client->get( $n );
    my $str = join("", @{$lines || []});
    return Email::MIME->new( $str );
}

1;
