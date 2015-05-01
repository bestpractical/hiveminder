no encoding;
use warnings;
use strict;
use Encode qw(encode_utf8 decode_utf8);
use charnames ':full';

use BTDT::Test tests => 32, actual_server => 1;

# {{{ Setup
my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech($URL);
my $system_user = BTDT::CurrentUser->superuser;

my $gooduser = BTDT::Model::User->new( current_user => $system_user );
$gooduser->load_by_cols(email => 'gooduser@example.com');
$gooduser->set_notification_email_frequency('daily');

# }}}

isa_ok($mech, 'BTDT::Test::WWW::Mechanize');
$mech->content_like(qr/Logout/i,"Logged in!");

# Create a task
my $hotspring   = "Remember to have \x{2668}";
my $hotspring_b = encode_utf8($hotspring);
$mech->fill_in_action_ok('tasklist-new_item_create', 
			 summary => $hotspring,
			 group_id => 1,
			 description => "With a description about \x{2668}");
$mech->submit;
# Comment on it.
ok($mech->find_link( text => $hotspring ), "Task view link exists");
$mech->follow_link( text => $hotspring ) or die;
$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 3),
			 comment => 'commenty fresh');
$mech->submit;
$mech->content_contains('commenty fresh');

my @emails = BTDT::Test->messages;
is(scalar @emails, 1, "Comment email");
# XXX: reminder order? otheruser got sent as well.
ok( index($emails[0]->body, $hotspring_b) != -1, "mmm hotspring");
is(Encode::decode('MIME-Header', $emails[0]->header('Subject')),
   qq{Comment: $hotspring (#5)}, "Subject is correct");
like(  $emails[0]->header('Content-Type'), qr'charset="UTF-8"', 'utf-8');

BTDT::Test->teardown_mailbox;
BTDT::Test->trigger_reminders();
@emails = BTDT::Test->messages;
is(scalar @emails, 1, "Daily reminder mail");
like($emails[0]->body, qr{Here's your daily}, "Got a reminder email");
like($emails[0]->header('Subject'), qr{What's new}, "Subject is correct");
like($emails[0]->header('Content-Type'), qr'charset="UTF-8"', 'utf-8');
like($emails[0]->body, qr{$URL/todo}, "Email contains a link to your todo list");

# mail body are in byte strings.
ok( index($emails[0]->body, $hotspring_b) != -1, "mmm hotsprings");

# test for comment with latin1-char
BTDT::Test->teardown_mailbox;

$mech->get("$URL/todo");

ok($mech->find_link( text => "01 some task" ), "Task view link exists");
$mech->follow_link( text => "01 some task" ) or die;
$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 1),
			 group_id => 1);
$mech->submit;

BTDT::Test->teardown_mailbox;

    my $request = HTTP::Request->new(
        POST => "$URL/todo",
        [ 'Content-Type' => 'text/x-json',
	  'Accept' => 'text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5',
	],
qq{{"path":"/__jifty/webservices/xml","actions":{"add-comment-S7741576":{"moniker":"add-comment-S7741576","class":"BTDT::Action::UpdateTask","fields":{"id":{"fallback":"1"},"comment":{"value":"All L\x{c3}\x{a9}on's fault "}}}},"fragments":{},"variables":{"region-tasklist-item-1-S6811576":"/fragments/tasklist/comment"}}});

my $result = $mech->request( $request );

$mech->get("$URL/todo");
ok($mech->find_link( text => "01 some task" ), "Task view link exists");
$mech->follow_link( text => "01 some task" ) or die;

$mech->content_contains("All L\N{LATIN SMALL LETTER E WITH ACUTE}on's fault");

@emails = BTDT::Test->messages;
is(scalar @emails, 1, "Comment email");

ok( index($emails[0]->body, "All L\x{c3}\x{a9}on's fault") != -1, "mmm Leon");
is(Encode::decode('MIME-Header', $emails[0]->header('Subject')),
   qq{Comment: 01 some task (#3)}, "Subject is correct");
like(  $emails[0]->header('Content-Type'), qr'charset="UTF-8"', 'utf-8');

# XXX: test for adding new task with latin1 description, which gets recorded as . 


# incoming 

my ($id, $msg) = $gooduser->publish_address;
ok($id, "Created published address");
my $address = BTDT::Model::PublishedAddress->new( current_user => $system_user );
$address->load( $id );
ok($address->id, "Loaded correctly");


my $message = <<"MESSAGE";
From: gooduser\@example.com
Subject: =?ISO-8859-1?Q?L=E9on?=
Message-ID: <something\@localhost>
Content-type: text/plain; charset="ISO-8859-1"
Content-Transfer-Encoding: 8bit

All L\x{e9}on's fault!

MESSAGE


is(BTDT::Test->mailgate("--url" => $URL, "--address" => $address->address, "--message" => $message, '--sender' => 'gooduser@example.com'), '', "mailgate was silent");


$mech->get("$URL/todo");
ok($mech->find_link( text => "L\N{LATIN SMALL LETTER E WITH ACUTE}on" ), "Task view link exists");
$mech->follow_link( text => "L\N{LATIN SMALL LETTER E WITH ACUTE}on" ) or die;

$mech->content_contains("All L\N{LATIN SMALL LETTER E WITH ACUTE}on's fault");
$mech->content_contains("Subject: L\N{LATIN SMALL LETTER E WITH ACUTE}on");

