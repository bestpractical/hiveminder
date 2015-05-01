use warnings;
use strict;

use BTDT::Test tests => 38, actual_server => 1;
use Test::LongString;

use_ok('BTDT::CurrentUser');

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');
my $URL = $server->started_ok;
my $mech = Jifty::Test::WWW::Mechanize->new();
$mech->get($URL);

# with.hm
BTDT::Test->setup_mailbox();
my @messages = BTDT::Test->messages();
is(scalar @messages, 0, "Cleared out the mbox");

my $user = BTDT::Model::User->new( current_user => BTDT::CurrentUser->superuser );
$user->load_by_cols( email => 'gooduser@example.com' );
ok( $user->id, "Got a user" );
$user->set_pro_account('t');
ok( $user->pro_account, "Has pro account" );
ok( $user->email_secret, "Has an email secret" );

my $secret = $user->email_secret;

# non-pro user to self
BTDT::Test->setup_mailbox();
like(BTDT::Test->mailgate("--url" => $URL, "--address" => 'otheruser@example.com.'.$secret.'.with.hm', '--sender' => 'otheruser@example.com', "--message" => <<'END_MESSAGE'), qr/non-pro used with\.hm/i, "mailgate threw error");
From: otheruser@example.com
Subject: testfoofoofoo
Message-ID: <test@example>

body
END_MESSAGE

@messages = BTDT::Test->messages();
is( scalar @messages, 1, "Got one message" );

my $message = shift @messages;
like $message->header('Subject'), qr/Error processing email/, "Got subject";
like $message->body, qr/otheruser\@example.com.@{[$secret]}.with.hm/, "Got body email";
like $message->body, qr/\/account\/upgrade/, "Got body upgrade link";
like $message->body, qr/\/pro/, "Got body pro link";
like $message->body, qr/restricted/, "Got body text";

my $task = BTDT::Model::Task->new( current_user => BTDT::CurrentUser->superuser );
$task->load_by_cols( summary => 'testfoofoofoo' );
ok !$task->id, "Didn't get task";

# wrong secret
BTDT::Test->setup_mailbox();
like(BTDT::Test->mailgate("--url" => $URL, "--address" => 'gooduser@example.com.foobar.with.hm', '--sender' => 'otheruser@example.com', "--message" => <<'END_MESSAGE'), qr/non-pro used with\.hm/i, "mailgate threw error");
From: otheruser@example.com
Subject: testfoofoofoo2
Message-ID: <test@example>

body
END_MESSAGE

@messages = BTDT::Test->messages;
is( scalar @messages, 1, "Got one message" );

$message = shift @messages;
like $message->header('Subject'), qr/Error processing/, "Got subject";
is $message->header('To'), 'otheruser@example.com', "Got recipient";
like $message->body , qr/email has not been processed/, "Got body";
like $message->body , qr/gooduser\@example\.com\.foobar\.with\.hm/, "Got recipient echoed";

$task = BTDT::Model::Task->new( current_user => BTDT::CurrentUser->superuser );
$task->load_by_cols( summary => 'testfoofoofoo2' );
ok !$task->id, "Didn't get a task";

# pro user to non-pro user
BTDT::Test->setup_mailbox();
is(BTDT::Test->mailgate("--url" => $URL, "--address" => "otheruser\@example.com.$secret.with.hm", '--sender' => 'gooduser@example.com', "--message" => <<'END_MESSAGE'), '', "mailgate was silent");
From: gooduser@example.com
Subject: testfoofoofoo3

body
END_MESSAGE

@messages = BTDT::Test->messages;
is( scalar @messages, 1, "Got one message" );

$message = shift @messages;
like $message->header('Subject'), qr/New task: testfoofoofoo3/, "Got subject";
is $message->header('To'), 'otheruser@example.com', "Got recipient";
like $message->body , qr/gooduser\@example.com/, "Got sender email";

$task = BTDT::Model::Task->new( current_user => BTDT::CurrentUser->superuser );
$task->load_by_cols( summary => 'testfoofoofoo3' );
ok $task->id, "Got task";

# pro user to self
BTDT::Test->setup_mailbox();
is(BTDT::Test->mailgate("--url" => $URL, "--address" => 'gooduser@example.com.'.$secret.'.with.hm', '--sender' => 'gooduser@example.com', "--message" => <<'END_MESSAGE'), '', "mailgate was silent");
From: gooduser@example.com
Subject: testfoofoofoo4

body
END_MESSAGE

@messages = BTDT::Test->messages;
is( scalar @messages, 0, "Got NO message" );

$task = BTDT::Model::Task->new( current_user => BTDT::CurrentUser->superuser );
$task->load_by_cols( summary => 'testfoofoofoo4' );
ok $task->id, "Got task";

# pro user to non-existant user
BTDT::Test->setup_mailbox();
is(BTDT::Test->mailgate("--url" => $URL, "--address" => 'newuser2@example.com.'.$secret.'.with.hm', '--sender' => 'gooduser@example.com', "--message" => <<'END_MESSAGE'), '', "mailgate was silent");
From: gooduser@example.com
Subject: testfoofoofoo5

body
END_MESSAGE

@messages = BTDT::Test->messages;
is( scalar @messages, 1, "Got one message" );

$message = shift @messages;
like $message->header('Subject'), qr/New task: testfoofoofoo5/, "Got subject";
is $message->header('To'), 'newuser2@example.com', "Got recipient";
like $message->body, qr/gooduser\@example.com/, "Got sender email";
like $message->body, qr/quick and easy to activate/, "Got nonuser prose";

$task = BTDT::Model::Task->new( current_user => BTDT::CurrentUser->superuser );
$task->load_by_cols( summary => 'testfoofoofoo5' );
ok $task->id, "Got task";


