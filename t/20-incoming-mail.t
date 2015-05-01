use warnings;
use strict;

use BTDT::Test tests => 92, actual_server => 1;
use Test::LongString;

use_ok('BTDT::CurrentUser');
my $system_user = BTDT::CurrentUser->superuser;

# Making TaskEmails by hand
# work around for the fact that markdown mistakenly escapes ampersands in URLs.
#   'http://www.amazon.com/gp/product/1569715025/<br>ref=pd_cp_b_title/102-3852617-5264112?%5Fencoding=UTF8&v=glance&n=283155';
my $LONG_URL = 'http://www.amazon.com/gp/product/1569715025/ref=pd_cp_b_title/102-3852617-5264112?%5Fencoding=UTF8&amp;v=glance&amp;n=283155';
my $LONG_URL_LINKIFIED_SHOULDBE = 'http://www.amazon.com/gp/product/1569715025/ref=pd_cp_b_title/102-3852617-526411 2?%5Fencoding=UTF8&amp;v=glance&amp;n=283155';


my $message = Email::Simple->new(<<'MESSAGE' . "\n\n$LONG_URL\n\n");
From: gooduser@example.com
Subject: Some new task
X-My-Header: moose

Testing the body
more test

http://some.big.url.com/with.html#anchors

http://some.big.url.com/with_basic_underscores.html

MESSAGE

ok ($message, "We've defined our message");
use_ok('BTDT::Model::TaskEmail');
can_ok('BTDT::Model::TaskEmail', 'new');
my $mail = BTDT::Model::TaskEmail->new(current_user => BTDT::CurrentUser->superuser);
isa_ok($mail, 'BTDT::Model::TaskEmail');
can_ok($mail, 'create');
$message->header_set("Message-ID" => "<".__LINE__ . '@localhost>');
my ($id,$msg) = $mail->create( message => $message->as_string);
ok(!$id,$msg);

($id) = $mail->create( message => $message->as_string, task_id => 1 );
ok($id,"ya. created one message");


# Feeding them into the mailgate
ok(-e "bin/mailgate", "bin/mailgate exists");
ok(-x "bin/mailgate", "bin/mailgate is executable");


my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');
my $URL = $server->started_ok;

# Test basic failure cases of the mailgate
like(BTDT::Test->mailgate(), qr/Usage/, "Mailgate by itself returns");
like(BTDT::Test->mailgate("--url" => $URL), qr/No --address/, "Mailgate needs an address");
like(BTDT::Test->mailgate("--url" => $URL, "--address" => "moose"), qr/No --sender/, "Mailgate needs a sender");
like(BTDT::Test->mailgate("--url" => $URL, "--address" => "moose", '--sender' => 'meese'), qr/No message passed on STDIN/, "Mailgate needs a message");

# Make a published address
my $user = BTDT::Model::User->new( current_user => $system_user );
$user->load_by_cols( email => 'gooduser@example.com' );
ok($user->id, "Got a user");
($id, $msg) = $user->publish_address;
ok($id, "Created published address");

# Make them pro, while we're at it, so we can see attachments
BTDT::Test->make_pro($user);

# Load it up
my $address = BTDT::Model::PublishedAddress->new( current_user => $system_user );
$address->load( $id );
ok($address->id, "Loaded correctly");

# Try loading the next task (shouldn't exist)
my $task = BTDT::Model::Task->new( current_user => $system_user );
$task->load( 3 );
ok( ! $task->id, "Task 3 doesn't exist yet" );

# Send in a message to a bogus url
$message->header_set("Message-ID" => "<".__LINE__ . '@localhost>');
like(BTDT::Test->mailgate("--url" => $URL, "--address" => "bogus", "--message" => $message->as_string, '--sender' => 'gooduser@example.com'), qr/Address 'bogus' didn't match a published address/, "mailgate returned error");
$task->load( 3 );
ok( ! $task->id, "Task 3 still non-existent" );

# Send to a correct url
is(BTDT::Test->mailgate("--url" => $URL, "--address" => $address->address, "--message" => $message->as_string, '--sender' => 'gooduser@example.com'), '', "mailgate was silent 2");
$task->load( 3 );
ok( $task->id, "Task 3 exists now" );
is( $task->summary, "Some new task", "Has subject we sent");
like( $task->description, qr/Testing the body/, "Has body text we sent");
like( $task->formatted_description, qr/<p>Testing the body<br class="automatic">\nmore test<\/p>\n\n<p>/, "Converted the newlines to <br>s and <p>s");
like( $task->formatted_description, 
qr|<a href="http://some.big.url.com/with.html#anchors" target="_blank">http://some.big.url.com/with.html#anchors</a>|, "formatted_description linkifies URLs with anchors properly");
like( $task->formatted_description, 
qr|<a href="http://some.big.url.com/with_basic_underscores.html" target="_blank">http://some.big.url.com/with_basic_underscores.html</a>|, "formatted_description linkifies URLs without anchors and with double underscores properly");

like( $task->formatted_description, 
  qr|<a href="\Q$LONG_URL\E" target="_blank">\Q$LONG_URL_LINKIFIED_SHOULDBE\E</a>|, 
  "formatted_description linkifies very long URLs without italicizing underscores and with spaces for wrapping",
);

# Drill down to the message
my $txns = $task->transactions;
isa_ok($txns, "BTDT::Model::TaskTransactionCollection");
is($txns->count, 1);
my $txn = $txns->next;
isa_ok($txn, "BTDT::Model::TaskTransaction");
is($txn->type, "create");
my $comments = $txn->comments;
isa_ok($comments, "BTDT::Model::TaskEmailCollection");
is($comments->count, 1);
my $email = $comments->next;
isa_ok($email, "BTDT::Model::TaskEmail");

# Check sender and body
is($email->sender_id, $user->id, "Got right sender");
$message->header_set("X-Hiveminder-delivered-to" => $address->address);
is($email->message,   $message->as_string,  "Got right email message");

# We can extract the email's various parts
is($email->header("X-My-Header"), "moose", "Can do header extraction");


# Sanity check for next email
$task->load( 4 );
ok( ! $task->id, "Task 4 doesn't exist yet");
$user->load_by_cols( email => 'new@example.com' );
ok( ! $user->id, "new\@example.com address doesn't exist yet");

# Email from a unknown address
is(BTDT::Test->mailgate("--url" => $URL, "--address" => $address->address, "--sender", 'new@example.com', "--message" => <<'EOT'), '', "mailgate was silent 3");
From: new@example.com
Subject: Some new thing

A body we don't really care about
EOT

# Should have created both a task and a user
$task->load( 4 );
ok( $task->id, "Task 4 exists now" );
$user->load_by_cols( email => 'new@example.com' );
ok( $user->id, "new\@example.com created");


# Make a group with Good Test User in it, and a published address for it
my $group = BTDT::Model::Group->new( current_user => BTDT::CurrentUser->new( email => 'gooduser@example.com' ));
($id, $msg) = $group->create(name => "Test group");
ok($id, "Created a group");
$address = BTDT::Model::PublishedAddress->new( current_user => $group->current_user );
($id, $msg) = $address->create(
    group_id => $group->id,
    action   => 'CreateTask',
);
ok($id, "Created published address");

# Email from a member of the group should get through and create a task
$task->load( 5 );
ok( ! $task->id, "Task 5 doesn't exist yet");
is(BTDT::Test->mailgate("--url" => $URL, "--address" => $address->address,  '--sender' => 'gooduser@example.com', "--message" => <<'EOT'), '', "mailgate was silent 4");
From: gooduser@example.com
Subject: Some group-like thing

A body we don't really care about
EOT
$task->load( 5 );
ok( $task->id, "Task 5 exists now" );
is( $task->group->id, $group->id, "In the group");
is( $task->summary, "Some group-like thing");

# Email from non-member should also get through
$task->load( 6 );
ok( ! $task->id, "Task 6 doesn't exist yet");
is(BTDT::Test->mailgate("--url" => $URL, "--address" => $address->address,  '--sender' => 'randomperson@example.com', "--message" => <<'EOT',), '', "mailgate was silent 5");
From: randomperson@example.com
Subject: Some other group-like thing

A body we don't really care about
EOT
$task->load( 6 );
ok( $task->id, "Task 6 exists now" );
is( $task->group->id, $group->id, "In the group");
is( $task->summary, "Some other group-like thing", "Got the right task summary");

# UTF-8 mail

use charnames qw(:full);

BTDT::Test->setup_mailbox();
is(scalar BTDT::Test->messages(), 0, "Cleared out the mbox");

is(BTDT::Test->mailgate("--url" => $URL, "--address" => $address->address,  '--sender' => 'randomperson@example.com', "--message" => <<"EOT"), '', "mailgate was silent 6");
From: randomperson\@example.com
Subject: To the group

\N{GREEK SMALL LETTER ALPHA}
EOT

my @messages =  BTDT::Test->messages();

is (scalar @messages, 1, "Got one message");

$task->load(7);
ok( $task->id, "No error posting UTF-8 mail" );
like( $task->description, qr/\N{GREEK SMALL LETTER ALPHA}/, "UTF-8 roundtripped fine" );

my $mech = BTDT::Test->get_logged_in_mech($URL);

$mech->get($URL . "/task/9");
# This test tested for a case when the on-user acls stopped one of the parties to a task from seeing it.
# It would read "Task created at" instead of "Task created by ... at"
unlike($mech->content, qr/Task created at/, "ACLS let group members see non-member users who have created the tasks");
contains_string($mech->content, "\N{GREEK SMALL LETTER ALPHA}", "got a greek alpha");

# Test MIME-encoded non-utf8 high-byte characters
use utf8;

is(BTDT::Test->mailgate("--url" => $URL, "--address" => $address->address, '--sender' => 'gooduser@example.com', "--message" => <<'END_MESSAGE'), '', "mailgate was silent 7");
From: gooduser@example.com
Subject: Funny character
Mime-Version: 1.0
Content-Type: text/plain; charset=iso-8859-1
Content-Disposition: inline
Content-Transfer-Encoding: quoted-printable

M=F6=F6se

END_MESSAGE

$task->load(8);
ok( $task->id, "No error posting mail" );
like( $task->description, qr/Mööse/, "Roundtripped fine" );

# Attempt to view the task from the web
$mech->get_ok($URL . "/task/A");  # id 8 == record locator A

contains_string($mech->content, 'Mööse');


# Test comment emails
$task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
$task->load(1);
my $addr = $task->comment_address;

# Try a comment mail from the task owner
is(BTDT::Test->mailgate("--url" => $URL, "--address" => $addr, '--sender' => 'gooduser@example.com', "--message" => <<'END_MESSAGE'), '', "mailgate was silent 8");
From: gooduser@example.com
Subject: This is a comment.

I've got something important to say, or something.

END_MESSAGE

$mech->get_ok($URL);
$mech->follow_link_ok(text => '01 some task');

Jifty::Test->test_file("test.html");
$mech->save_content('test.html');

$mech->content_contains('something important to say', 'Got the comment');


# Try a comment mail from someone random
is(BTDT::Test->mailgate("--url" => $URL, "--address" => $addr, '--sender' => 'someonerandom@nowhere.com', "--message" => <<'END_MESSAGE'), '', "mailgate was silent 9");
From: someonerandom@nowhere.com
Subject: This is a comment.

I am absolutely no one important!

END_MESSAGE

$mech->reload;
$mech->content_contains('I am absolutely no one important!', 'Got the comment');


# Try nested multipart emails
is(BTDT::Test->mailgate("--url" => $URL, "--address" => $addr, '--sender' => 'gooduser@example.com', "--message" => <<'END_MESSAGE'), '', "mailgate was silent 10");
From: gooduser@example.com
Subject: Some comment
Content-Type: multipart/mixed; boundary="0-1964129831-1166203469=:61243"
Content-Transfer-Encoding: 8bit

--0-1964129831-1166203469=:61243
Content-Type: multipart/alternative; boundary="0-1621201831-1166203469=:61243"

--0-1621201831-1166203469=:61243
Content-Type: text/plain; charset=iso-8859-1
Content-Transfer-Encoding: 8bit

Some body

--0-1621201831-1166203469=:61243
Content-Type: text/html; charset=iso-8859-1
Content-Transfer-Encoding: 8bit

<div>Some html body with <b>tags</b></div>
--0-1621201831-1166203469=:61243--
--0-1964129831-1166203469=:61243
Content-Type: application/msword; name="Hiveminder screen shots.doc"
Content-Transfer-Encoding: base64
Content-Description: 3046539478-Hiveminder screen shots.doc
Content-Disposition: attachment; filename="Hiveminder screen shots.doc"

SNIPPED

--0-1964129831-1166203469=:61243--
END_MESSAGE

$mech->reload;
$mech->content_contains("Some body");


# Multipart email with an empty multipart/mixed
is(BTDT::Test->mailgate("--url" => $URL, "--address" => $addr, '--sender' => 'gooduser@example.com', "--message" => <<'END_MESSAGE'), '', "mailgate was silent 11");
From 9198174576@message.alltel.com Mon Feb 19 03:09:06 2007
Received: (qmail 27048 invoked from network); 19 Feb 2007 03:09:06 -0000
Received: from unknown (HELO gwa11.webcontrolcenter.com) (63.134.207.55)
  by bp.nmsrv.com with SMTP; 19 Feb 2007 03:09:06 -0000
Received: from maila49.webcontrolcenter.com [216.119.106.58] by gwa11.webcontrolcenter.com with SMTP;
   Sun, 18 Feb 2007 20:07:20 -0700
Received: from ispmxmta07-srv.alltel.net [166.102.165.168] by maila49.webcontrolcenter.com with SMTP;
   Sun, 18 Feb 2007 20:07:47 -0700
Received: from md-00 ([162.40.135.16]) by ispmxmta07-srv.windstream.net
          with ESMTP
          id <20070219030746.BJKS5199.ispmxmta07-srv.windstream.net@md-00>
          for <hiveholly@freezingcode.com>; Sun, 18 Feb 2007 21:07:46 -0600
Received: from null ([162.40.135.2])
          by MD2 SMTP SERVER (Message Director SMTP Server v2.33) with SMTP ID 352
          for <hiveholly@freezingcode.com>;
          Sun, 18 Feb 2007 21:00:09 -0600 (CST)
Return-Path: <19198174576@message.alltel.com>
Message-ID: <27231855.1171854009442.JavaMail.root@md-00>
Date: Sun, 18 Feb 2007 21:06:57 -0600 (CST)
From: 9198174576@message.alltel.com
To: hiveholly@freezingcode.com
Subject: ++buy disposal adapter
Mime-Version: 1.0
Content-Type: multipart/mixed; 
	boundary="----=_Part_4628170_27280973.1171854009438"
X-Mms-Delivery-Report: yes
X-Mms-Delivery-Time: Sun, 18 Feb 07 21:06:57 CST 
X-Mms-MMS-Version: 1.0
X-Mms-Message-Class: Personal
X-Mms-Message-Type: m-send-req
X-Mms-Message-Size: 497
X-Mms-Read-Reply: no
X-Mms-Transaction-ID: 1171836409
X-Mms-Message-ID: 192078738@mms.alltel.com
X-Priority: 3
X-HostedBy: Ericsson
X-Original-From: 9198174576@mms.alltel.com
X-Original-Return-Path: <19198174576@mms.alltel.com>

------=_Part_4628170_27280973.1171854009438
Content-Type: multipart/related; type="application/smil"; 
	boundary="----=_Part_72462_7850714.1171854420676"; start="<mmmm>"

------=_Part_72462_7850714.1171854420676
Content-Type: multipart/alternative; name=mms; 
	boundary="----=_Part_4628169_7011148.1171854009435"
Content-Disposition: attachment; filename=mms

------=_Part_4628169_7011148.1171854009435
Content-Type: text/plain; charset=us-ascii
Content-Transfer-Encoding: 7bit

Evil multipart message
------=_Part_4628169_7011148.1171854009435
Content-Type: text/html; charset=iso-8859-1
Content-Transfer-Encoding: 7bit

<html>[ SNIPPED ]</html>
------=_Part_4628169_7011148.1171854009435--

------=_Part_72462_7850714.1171854420676
Content-Type: image/gif; name=divider.gif
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename=divider.gif
Content-ID: <divider.gif>

R0lGODlhTAIBAIAAAL7E2QAAACH5BAAAAAAALAAAAABMAgEAAAIWhI+py+0Po5y02ouz3rz7D4bi
SJZfAQA7
------=_Part_72462_7850714.1171854420676
Content-Type: image/gif; name=spacer.gif
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename=spacer.gif
Content-ID: <spacer.gif>

R0lGODlhAQABAIAAAAAAAAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==
------=_Part_72462_7850714.1171854420676
Content-Type: image/gif; name=bluebar.gif
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename=bluebar.gif
Content-ID: <bluebar.gif>

R0lGODlhegIGAIAAAABJqgAAACH5BAAAAAAALAAAAAB6AgYAAAJBhI+py+0Po5y02ouz3rz7D4bi
SJbmiabqyrbuC8fyTNf2jef6zvf+DwwKh8Si8YhMKpfMpvMJjUqn1Kr1is1qhwUAOw==
------=_Part_72462_7850714.1171854420676
Content-Type: image/gif; name=header.gif
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename=header.gif
Content-ID: <header.gif>

SNIPPED
------=_Part_72462_7850714.1171854420676
Content-Type: image/gif; name=greenbar.gif
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename=greenbar.gif
Content-ID: <greenbar.gif>

R0lGODlheQIEAIAAAMreXAAAACH5BAAAAAAALAAAAAB5AgQAAAIzhI+py+0Po5y02ouz3rz7D4bi
SJbmiabqyrbuC8fyTNf2jef6zvf+DwwKh8Si8YhMKmcFADs=
------=_Part_72462_7850714.1171854420676
Content-Type: image/jpeg; name=alltel_logo.jpg
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename=alltel_logo.jpg
Content-ID: <alltel_logo.jpg>

SNIPPED
------=_Part_72462_7850714.1171854420676--

------=_Part_4628170_27280973.1171854009438
Content-Type: multipart/mixed; 
	boundary="----=_Part_4628168_7522443.1171854009427"

------=_Part_4628168_7522443.1171854009427--

------=_Part_4628170_27280973.1171854009438--



END_MESSAGE
$mech->reload;
$mech->content_contains("Evil multipart message");

is(BTDT::Test->mailgate("--url" => $URL, "--address" => $addr, '--sender' => 'gooduser@example.com', "--message" => <<'END_MESSAGE'), '', "mailgate was silent 11");
Received: (qmail 27625 invoked from network); 10 Jan 2008 23:21:14 -0000
Received: from unknown (HELO iserv1.seatimes.com) (192.251.219.16) by
 bp.nmsrv.com with SMTP; 10 Jan 2008 23:21:14 -0000
Received: from pexchconn.seatimes.com (pexchconn [192.251.220.55]) by
 iserv1.seatimes.com (8.13.4/8.13.4) with ESMTP id m0ANL4xL008865 for
 <prutetepi@my.hiveminder.com>; Thu, 10 Jan 2008 15:21:08 -0800 (PST)
Received: from PEXCHVD.seatimes.com ([10.80.10.152]) by
 pexchconn.seatimes.com with Microsoft SMTPSVC(6.0.3790.3959); Thu, 10 Jan
 2008 15:21:05 -0800
X-MimeOLE: Produced By Microsoft Exchange V6.5
MIME-Version: 1.0
Content-Type: application/x-pkcs7-mime;smime-type=signed-data;name=smime.p7m; smime-type=signed-data; name="smime.p7m"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename="smime.p7m"
Content-class: urn:content-classes:message
Subject: Sitescope image retrieval on VIP's
Date: Thu, 10 Jan 2008 15:21:04 -0800
Message-ID: <89ECDF0F8AE50C458A342C4C4F8CB84202266A5E@PEXCHVD.seatimes.com>
X-MS-Has-Attach: yes
X-MS-TNEF-Correlator: 
Thread-Topic: Sitescope image retrieval on VIP's
Thread-Index: AchI78OLEkNQm9mpR42LFTPjp79beAC5SpFAAgKd/0A=
From: gooduser@example.com
To: profrusyga@my.hiveminder.com
X-OriginalArrivalTime: 10 Jan 2008 23:21:05.0064 (UTC)
 FILETIME=[78DD4A80:01C853DF]

MIAGCSqGSIb3DQEHAqCAMIACAQExCzAJBgUrDgMCGgUAMIAGCSqGSIb3DQEHAaCAJIAEggeeQ29u
dGVudC1UeXBlOiBtdWx0aXBhcnQvYWx0ZXJuYXRpdmU7DQoJYm91bmRhcnk9Ii0tLS09X05leHRQ
YXJ0XzAwMF8wMTc3XzAxQzg1MzlDLjZCOTFGM0YwIg0KDQpUaGlzIGlzIGEgbXVsdGktcGFydCBt
ZXNzYWdlIGluIE1JTUUgZm9ybWF0Lg0KDQotLS0tLS09X05leHRQYXJ0XzAwMF8wMTc3XzAxQzg1
MzlDLjZCOTFGM0YwDQpDb250ZW50LVR5cGU6IHRleHQvcGxhaW47DQoJY2hhcnNldD0iVVMtQVND
SUkiDQpDb250ZW50LVRyYW5zZmVyLUVuY29kaW5nOiA3Yml0DQoNCkZyb206IE5vamFuIE1vc2hp
cmkgDQpTZW50OiBNb25kYXksIERlY2VtYmVyIDMxLCAyMDA3IDk6NDcgQU0NClRvOiBFcmljIEdv
ZXR6DQpTdWJqZWN0OiBSRTogU2l0ZXNjb3BlIGltYWdlIHJldHJpZXZhbA0KDQogDQoNCkkgdGhp
bmsgdGhpcyB3b3VsZCBiZSB3b3J0aHdoaWxlIHRvIGRvIG9uIHRoZSBWSVBzLCB0aGUgQWthbWFp
IG1vbml0b3JzIHRoYXQNCmlzLg0KDQogDQoNCk9uIGEgcmVsYXRlZCBub3RlLCBpdCBsb29rcyBs
aWtlIHRoZSBhbGVydHMgaW4gdGhlIG5ldyBTaXRlY29wZSBuZWVkIGZ1cnRoZXINCm1vZGlmaWNh
dGlvbi4gIENvdWxkIEkgZW5saXN0IHlvdXIgaGVscCBvbiB0aGlzIG92ZXIgdGhlIG5leHQgd2Vl
ayBvciBzbz8NCg0KIA0KDQpJIHdpbGwgYWxzbyBzZXR1cCBhIGJyaWVmIFNpdGVzY29wZSB0cmFp
bmluZyBmb3IgTWlsZXMgYW5kIHlvdXJzZWxmLg0KDQogDQoNCk5vag0KDQogDQoNCiAgX19fX18g
IA0KDQpGcm9tOiBFcmljIEdvZXR6IA0KU2VudDogVGh1cnNkYXksIERlY2VtYmVyIDI3LCAyMDA3
IDU6MjAgUE0NClRvOiBOb2phbiBNb3NoaXJpDQpTdWJqZWN0OiBTaXRlc2NvcGUgaW1hZ2UgcmV0
cmlldmFsDQoNCkhleSwgSSBqdXN0IG5vdGljZWQgdGhpcyBpbiB0aGUgU2l0ZVNjb3BlIG9ubGlu
ZSBoZWxwOg0KDQogDQoNCi0tLS0NCg0KIA0KDQpXaGVuIHRoZSBVUkwgTW9uaXRvciByZXRyaWV2
ZXMgYSBXZWIgcGFnZSwgaXQgcmV0cmlldmVzIHRoZSBwYWdlJ3MgY29udGVudHMuDQpBIHN1Y2Nl
c3NmdWwgcGFnZSByZXRyaWV2YWwgYXNzdXJlcyB5b3UgdGhhdCB5b3VyIFdlYiBzZXJ2ZXIgaXMg
ZnVuY3Rpb25pbmcNCnByb3Blcmx5LiBUaGUgVVJMIE1vbml0b3IgZG9lcyBub3QgYXV0b21hdGlj
YWxseSByZXRyaWV2ZSBhbnkgb2JqZWN0cyBsaW5rZWQNCmZyb20gdGhlIHBhZ2UsIHN1Y2ggYXMg
aW1hZ2VzIG9yIGZyYW1lcy4gWW91IGNhbiwgaG93ZXZlciwgaW5zdHJ1Y3QNClNpdGVTY29wZSB0
byByZXRyaWV2ZSB0aGUgaW1hZ2VzIG9uIHRoZSBwYWdlIGJ5IHNlbGVjdGluZyB0aGUgUmV0cmll
dmUNCkltYWdlcyBvciBSZXRyaWV2ZSBGcmFtZXMgYm94IGxvY2F0ZWQgaW4gdGhlIEFkdmFuY2Vk
IE9wdGlvbnMgc2VjdGlvbiBvZiB0aGUNCkFkZCBVcmwgTW9uaXRvciBGb3JtLg0KDQogDQoNCi0t
LS0NCg0KIA0KDQpXb3VsZCBpdCBiZSB3b3J0aCBpdCB0byB0dXJuIG9uIHJldHJpZXZhbCBvZiBv
YmplY3RzIGZyb20gc29tZSBvZiBvdXIgcGFnZXM/DQpMZXQgbWUga25vdyBpZiB5b3UgdGhpbmsg
aXQncyBhIGdvb2QgaWRlYSBmb3IgbWUgdG8gbG9vayBpbnRvIHRoaXMuDQoNCiANCg0KRXJpYw0K
DQogDQoNCi0tDQoNCkVyaWMgR29ldHoNCg0KU2VuaW9yIEludGVybmV0IEVuZ2luZWVyL05ldyBN
ZWRpYQ0KVGhlIFNlYXR0bGUgVGltZXMgQ29tcGFueQ0KUmVwcmVzZW50aW5nIHRoZSBTZWF0dGxl
IFBvc3QtSW50ZWxsaWdlbmNlcg0KcDogMjA2LzQ2NC0zMzA2DQoNCm53c291cmNlLmNvbSB8IHNl
YXR0bGV0aW1lcy5jb20gfCBzZWF0dGxlcGkuY29tDQoNCiANCg0KDQotLS0tLS09X05leHRQYXJ0
XzAwMF8wMTc3XzAxQzg1MzlDLjZCOTFGM0YwDQpDb250ZW50LVR5cGU6IHRleHQvaHRtbDsNCglj
aGFyc2V0PSJVUy1BU0NJSSINCkNvbnRlbnQtVHJhbnNmZXItRW5jb2Rpbmc6IHF1b3RlZC1wcmlu
dGFibGUNCg0KBIIgXjxodG1sIHhtbG5zOnY9M0QidXJuOnNjaGVtYXMtbWljcm9zb2Z0LWNvbTp2
bWwiID0NCnhtbG5zOm89M0QidXJuOnNjaGVtYXMtbWljcm9zb2Z0LWNvbTpvZmZpY2U6b2ZmaWNl
IiA9DQp4bWxuczp3PTNEInVybjpzY2hlbWFzLW1pY3Jvc29mdC1jb206b2ZmaWNlOndvcmQiID0N
CnhtbG5zOnN0MT0zRCJ1cm46c2NoZW1hcy1taWNyb3NvZnQtY29tOm9mZmljZTpzbWFydHRhZ3Mi
ID0NCnhtbG5zPTNEImh0dHA6Ly93d3cudzMub3JnL1RSL1JFQy1odG1sNDAiPg0KDQo8aGVhZD4N
CjxtZXRhIGh0dHAtZXF1aXY9M0RDb250ZW50LVR5cGUgY29udGVudD0zRCJ0ZXh0L2h0bWw7ID0N
CmNoYXJzZXQ9M0R1cy1hc2NpaSI+DQo8bWV0YSBuYW1lPTNER2VuZXJhdG9yIGNvbnRlbnQ9M0Qi
TWljcm9zb2Z0IFdvcmQgMTEgKGZpbHRlcmVkIG1lZGl1bSkiPg0KPCEtLVtpZiAhbXNvXT4NCjxz
dHlsZT4NCnZcOioge2JlaGF2aW9yOnVybCgjZGVmYXVsdCNWTUwpO30NCm9cOioge2JlaGF2aW9y
OnVybCgjZGVmYXVsdCNWTUwpO30NCndcOioge2JlaGF2aW9yOnVybCgjZGVmYXVsdCNWTUwpO30N
Ci5zaGFwZSB7YmVoYXZpb3I6dXJsKCNkZWZhdWx0I1ZNTCk7fQ0KPC9zdHlsZT4NCjwhW2VuZGlm
XS0tPjxvOlNtYXJ0VGFnVHlwZQ0KIG5hbWVzcGFjZXVyaT0zRCJ1cm46c2NoZW1hcy1taWNyb3Nv
ZnQtY29tOm9mZmljZTpzbWFydHRhZ3MiID0NCm5hbWU9M0QiQ2l0eSIvPg0KPG86U21hcnRUYWdU
eXBlID0NCm5hbWVzcGFjZXVyaT0zRCJ1cm46c2NoZW1hcy1taWNyb3NvZnQtY29tOm9mZmljZTpz
bWFydHRhZ3MiDQogbmFtZT0zRCJwbGFjZSIvPg0KPCEtLVtpZiAhbXNvXT4NCjxzdHlsZT4NCnN0
MVw6KntiZWhhdmlvcjp1cmwoI2RlZmF1bHQjaWVvb3VpKSB9DQo8L3N0eWxlPg0KPCFbZW5kaWZd
LS0+DQo8c3R5bGU+DQo8IS0tDQogLyogRm9udCBEZWZpbml0aW9ucyAqLw0KIEBmb250LWZhY2UN
Cgl7Zm9udC1mYW1pbHk6VGFob21hOw0KCXBhbm9zZS0xOjIgMTEgNiA0IDMgNSA0IDQgMiA0O30N
CiAvKiBTdHlsZSBEZWZpbml0aW9ucyAqLw0KIHAuTXNvTm9ybWFsLCBsaS5Nc29Ob3JtYWwsIGRp
di5Nc29Ob3JtYWwNCgl7bWFyZ2luOjBpbjsNCgltYXJnaW4tYm90dG9tOi4wMDAxcHQ7DQoJZm9u
dC1zaXplOjEyLjBwdDsNCglmb250LWZhbWlseToiVGltZXMgTmV3IFJvbWFuIjt9DQphOmxpbmss
IHNwYW4uTXNvSHlwZXJsaW5rDQoJe2NvbG9yOmJsdWU7DQoJdGV4dC1kZWNvcmF0aW9uOnVuZGVy
bGluZTt9DQphOnZpc2l0ZWQsIHNwYW4uTXNvSHlwZXJsaW5rRm9sbG93ZWQNCgl7Y29sb3I6cHVy
cGxlOw0KCXRleHQtZGVjb3JhdGlvbjp1bmRlcmxpbmU7fQ0Kc3Bhbi5FbWFpbFN0eWxlMTcNCgl7
bXNvLXN0eWxlLXR5cGU6cGVyc29uYWw7DQoJZm9udC1mYW1pbHk6QXJpYWw7DQoJY29sb3I6d2lu
ZG93dGV4dDt9DQpzcGFuLkVtYWlsU3R5bGUxOA0KCXttc28tc3R5bGUtdHlwZTpwZXJzb25hbC1y
ZXBseTsNCglmb250LWZhbWlseTpBcmlhbDsNCgljb2xvcjpuYXZ5O30NCkBwYWdlIFNlY3Rpb24x
DQoJe3NpemU6OC41aW4gMTEuMGluOw0KCW1hcmdpbjoxLjBpbiAxLjI1aW4gMS4waW4gMS4yNWlu
O30NCmRpdi5TZWN0aW9uMQ0KCXtwYWdlOlNlY3Rpb24xO30NCi0tPg0KPC9zdHlsZT4NCg0KPC9o
ZWFkPg0KDQo8Ym9keSBsYW5nPTNERU4tVVMgbGluaz0zRGJsdWUgdmxpbms9M0RwdXJwbGU+DQoN
CjxkaXYgY2xhc3M9M0RTZWN0aW9uMT4NCg0KPGRpdj4NCg0KPHAgY2xhc3M9M0RNc29Ob3JtYWw+
PGI+PGZvbnQgc2l6ZT0zRDIgZmFjZT0zRFRhaG9tYT48c3BhbiA9DQpzdHlsZT0zRCdmb250LXNp
emU6MTAuMHB0Ow0KZm9udC1mYW1pbHk6VGFob21hO2ZvbnQtd2VpZ2h0OmJvbGQnPkZyb206PC9z
cGFuPjwvZm9udD48L2I+PGZvbnQgPQ0Kc2l6ZT0zRDINCmZhY2U9M0RUYWhvbWE+PHNwYW4gc3R5
bGU9M0QnZm9udC1zaXplOjEwLjBwdDtmb250LWZhbWlseTpUYWhvbWEnPiBOb2phbiA9DQpNb3No
aXJpIDxicj4NCjxiPjxzcGFuIHN0eWxlPTNEJ2ZvbnQtd2VpZ2h0OmJvbGQnPlNlbnQ6PC9zcGFu
PjwvYj4gTW9uZGF5LCBEZWNlbWJlciA9DQozMSwgMjAwNw0KOTo0NyBBTTxicj4NCjxiPjxzcGFu
IHN0eWxlPTNEJ2ZvbnQtd2VpZ2h0OmJvbGQnPlRvOjwvc3Bhbj48L2I+IEVyaWMgR29ldHo8YnI+
DQo8Yj48c3BhbiBzdHlsZT0zRCdmb250LXdlaWdodDpib2xkJz5TdWJqZWN0Ojwvc3Bhbj48L2I+
IFJFOiBTaXRlc2NvcGUgPQ0KaW1hZ2UNCnJldHJpZXZhbDwvc3Bhbj48L2ZvbnQ+PG86cD48L286
cD48L3A+DQoNCjwvZGl2Pg0KDQo8cCBjbGFzcz0zRE1zb05vcm1hbD48Zm9udCBzaXplPTNEMyBm
YWNlPTNEIlRpbWVzIE5ldyBSb21hbiI+PHNwYW4gPQ0Kc3R5bGU9M0QnZm9udC1zaXplOg0KMTIu
MHB0Jz48bzpwPiZuYnNwOzwvbzpwPjwvc3Bhbj48L2ZvbnQ+PC9wPg0KDQo8cCBjbGFzcz0zRE1z
b05vcm1hbD48Zm9udCBzaXplPTNEMiBjb2xvcj0zRGJsdWUgZmFjZT0zREFyaWFsPjxzcGFuID0N
CnN0eWxlPTNEJ2ZvbnQtc2l6ZToNCjEwLjBwdDtmb250LWZhbWlseTpBcmlhbDtjb2xvcjpibHVl
Jz5JIHRoaW5rIHRoaXMgd291bGQgYmUgd29ydGh3aGlsZSB0byA9DQpkbyBvbg0KdGhlIFZJUHMs
IHRoZSBBa2FtYWkgbW9uaXRvcnMgdGhhdCBpcy48L3NwYW4+PC9mb250PjxvOnA+PC9vOnA+PC9w
Pg0KDQo8cCBjbGFzcz0zRE1zb05vcm1hbD48Zm9udCBzaXplPTNEMyBmYWNlPTNEIlRpbWVzIE5l
dyBSb21hbiI+PHNwYW4gPQ0Kc3R5bGU9M0QnZm9udC1zaXplOg0KMTIuMHB0Jz4mbmJzcDs8bzpw
PjwvbzpwPjwvc3Bhbj48L2ZvbnQ+PC9wPg0KDQo8cCBjbGFzcz0zRE1zb05vcm1hbD48Zm9udCBz
aXplPTNEMiBjb2xvcj0zRGJsdWUgZmFjZT0zREFyaWFsPjxzcGFuID0NCnN0eWxlPTNEJ2ZvbnQt
c2l6ZToNCjEwLjBwdDtmb250LWZhbWlseTpBcmlhbDtjb2xvcjpibHVlJz5PbiBhIHJlbGF0ZWQg
bm90ZSwgaXQgbG9va3MgbGlrZSA9DQp0aGUNCmFsZXJ0cyBpbiB0aGUgbmV3IFNpdGVjb3BlIG5l
ZWQgZnVydGhlciBtb2RpZmljYXRpb24uJm5ic3A7IENvdWxkIEkgPQ0KZW5saXN0IHlvdXINCmhl
bHAgb24gdGhpcyBvdmVyIHRoZSBuZXh0IHdlZWsgb3Igc28/PC9zcGFuPjwvZm9udD48bzpwPjwv
bzpwPjwvcD4NCg0KPHAgY2xhc3M9M0RNc29Ob3JtYWw+PGZvbnQgc2l6ZT0zRDMgZmFjZT0zRCJU
aW1lcyBOZXcgUm9tYW4iPjxzcGFuID0NCnN0eWxlPTNEJ2ZvbnQtc2l6ZToNCjEyLjBwdCc+Jm5i
c3A7PG86cD48L286cD48L3NwYW4+PC9mb250PjwvcD4NCg0KPHAgY2xhc3M9M0RNc29Ob3JtYWw+
PGZvbnQgc2l6ZT0zRDIgY29sb3I9M0RibHVlIGZhY2U9M0RBcmlhbD48c3BhbiA9DQpzdHlsZT0z
RCdmb250LXNpemU6DQoxMC4wcHQ7Zm9udC1mYW1pbHk6QXJpYWw7Y29sb3I6Ymx1ZSc+SSB3aWxs
IGFsc28gc2V0dXAgYSBicmllZiBTaXRlc2NvcGUNCnRyYWluaW5nIGZvciBNaWxlcyBhbmQgeW91
cnNlbGYuPC9zcGFuPjwvZm9udD48bzpwPjwvbzpwPjwvcD4NCg0KPHAgY2xhc3M9M0RNc29Ob3Jt
YWw+PGZvbnQgc2l6ZT0zRDMgZmFjZT0zRCJUaW1lcyBOZXcgUm9tYW4iPjxzcGFuID0NCnN0eWxl
PTNEJ2ZvbnQtc2l6ZToNCjEyLjBwdCc+Jm5ic3A7PG86cD48L286cD48L3NwYW4+PC9mb250Pjwv
cD4NCg0KPHAgY2xhc3M9M0RNc29Ob3JtYWw+PGZvbnQgc2l6ZT0zRDIgY29sb3I9M0RibHVlIGZh
Y2U9M0RBcmlhbD48c3BhbiA9DQpzdHlsZT0zRCdmb250LXNpemU6DQoxMC4wcHQ7Zm9udC1mYW1p
bHk6QXJpYWw7Y29sb3I6Ymx1ZSc+Tm9qPC9zcGFuPjwvZm9udD48bzpwPjwvbzpwPjwvcD4NCg0K
PHAgY2xhc3M9M0RNc29Ob3JtYWw+PGZvbnQgc2l6ZT0zRDMgZmFjZT0zRCJUaW1lcyBOZXcgUm9t
YW4iPjxzcGFuID0NCnN0eWxlPTNEJ2ZvbnQtc2l6ZToNCjEyLjBwdCc+PG86cD4mbmJzcDs8L286
cD48L3NwYW4+PC9mb250PjwvcD4NCg0KPGRpdiBjbGFzcz0zRE1zb05vcm1hbCBhbGlnbj0zRGNl
bnRlciBzdHlsZT0zRCd0ZXh0LWFsaWduOmNlbnRlcic+PGZvbnQgPQ0Kc2l6ZT0zRDMNCmZhY2U9
M0QiVGltZXMgTmV3IFJvbWFuIj48c3BhbiBzdHlsZT0zRCdmb250LXNpemU6MTIuMHB0Jz4NCg0K
PGhyIHNpemU9M0QyIHdpZHRoPTNEIjEwMCUiIGFsaWduPTNEY2VudGVyIHRhYkluZGV4PTNELTE+
DQoNCjwvc3Bhbj48L2ZvbnQ+PC9kaXY+DQoNCjxwIGNsYXNzPTNETXNvTm9ybWFsIHN0eWxlPTNE
J21hcmdpbi1ib3R0b206MTIuMHB0Jz48Yj48Zm9udCBzaXplPTNEMiA9DQpmYWNlPTNEVGFob21h
PjxzcGFuDQpzdHlsZT0zRCdmb250LXNpemU6MTAuMHB0O2ZvbnQtZmFtaWx5OlRhaG9tYTtmb250
LXdlaWdodDpib2xkJz5Gcm9tOjwvc3BhPQ0Kbj48L2ZvbnQ+PC9iPjxmb250DQpzaXplPTNEMiBm
YWNlPTNEVGFob21hPjxzcGFuID0NCnN0eWxlPTNEJ2ZvbnQtc2l6ZToxMC4wcHQ7Zm9udC1mYW1p
bHk6VGFob21hJz4gRXJpYw0KR29ldHogPGJyPg0KPGI+PHNwYW4gc3R5bGU9M0QnZm9udC13ZWln
aHQ6Ym9sZCc+U2VudDo8L3NwYW4+PC9iPiBUaHVyc2RheSwgRGVjZW1iZXIgPQ0KMjcsIDIwMDcN
CjU6MjAgUE08YnI+DQo8Yj48c3BhbiBzdHlsZT0zRCdmb250LXdlaWdodDpib2xkJz5Ubzo8L3Nw
YW4+PC9iPiBOb2phbiBNb3NoaXJpPGJyPg0KPGI+PHNwYW4gc3R5bGU9M0QnZm9udC13ZWlnaHQ6
Ym9sZCc+U3ViamVjdDo8L3NwYW4+PC9iPiBTaXRlc2NvcGUgaW1hZ2UgPQ0KcmV0cmlldmFsPC9z
cGFuPjwvZm9udD48bzpwPjwvbzpwPjwvcD4NCg0KPHAgY2xhc3M9M0RNc29Ob3JtYWw+PGZvbnQg
c2l6ZT0zRDIgZmFjZT0zREFyaWFsPjxzcGFuID0NCnN0eWxlPTNEJ2ZvbnQtc2l6ZToxMC4wcHQ7
DQpmb250LWZhbWlseTpBcmlhbCc+SGV5LCBJIGp1c3Qgbm90aWNlZCB0aGlzIGluIHRoZSBTaXRl
U2NvcGUgb25saW5lID0NCmhlbHA6PG86cD48L286cD48L3NwYW4+PC9mb250PjwvcD4NCg0KPHAg
Y2xhc3M9M0RNc29Ob3JtYWw+PGZvbnQgc2l6ZT0zRDIgZmFjZT0zREFyaWFsPjxzcGFuID0NCnN0
eWxlPTNEJ2ZvbnQtc2l6ZToxMC4wcHQ7DQpmb250LWZhbWlseTpBcmlhbCc+PG86cD4mbmJzcDs8
L286cD48L3NwYW4+PC9mb250PjwvcD4NCg0KPHAgY2xhc3M9M0RNc29Ob3JtYWw+PGZvbnQgc2l6
ZT0zRDIgZmFjZT0zREFyaWFsPjxzcGFuID0NCnN0eWxlPTNEJ2ZvbnQtc2l6ZToxMC4wcHQ7DQpm
b250LWZhbWlseTpBcmlhbCc+LS0tLTxvOnA+PC9vOnA+PC9zcGFuPjwvZm9udD48L3A+DQoNCjxw
IGNsYXNzPTNETXNvTm9ybWFsPjxmb250IHNpemU9M0QyIGZhY2U9M0RBcmlhbD48c3BhbiA9DQpz
dHlsZT0zRCdmb250LXNpemU6MTAuMHB0Ow0KZm9udC1mYW1pbHk6QXJpYWwnPjxvOnA+Jm5ic3A7
PC9vOnA+PC9zcGFuPjwvZm9udD48L3A+DQoNCjxwIGNsYXNzPTNETXNvTm9ybWFsPjxmb250IHNp
emU9M0QyIGZhY2U9M0RBcmlhbD48c3BhbiA9DQpzdHlsZT0zRCdmb250LXNpemU6MTAuMHB0Ow0K
Zm9udC1mYW1pbHk6QXJpYWwnPldoZW4gdGhlIFVSTCBNb25pdG9yIHJldHJpZXZlcyBhIFdlYiBw
YWdlLCBpdCA9DQpyZXRyaWV2ZXMgdGhlDQpwYWdlJ3MgY29udGVudHMuIEEgc3VjY2Vzc2Z1bCBw
YWdlIHJldHJpZXZhbCBhc3N1cmVzIHlvdSB0aGF0IHlvdXIgV2ViID0NCnNlcnZlcg0KaXMgZnVu
Y3Rpb25pbmcgcHJvcGVybHkuIFRoZSBVUkwgTW9uaXRvciBkb2VzIG5vdCBhdXRvbWF0aWNhbGx5
IHJldHJpZXZlID0NCmFueQ0Kb2JqZWN0cyBsaW5rZWQgZnJvbSB0aGUgcGFnZSwgc3VjaCBhcyBp
bWFnZXMgb3IgZnJhbWVzLiBZb3UgY2FuLCA9DQpob3dldmVyLA0KaW5zdHJ1Y3QgU2l0ZVNjb3Bl
IHRvIHJldHJpZXZlIHRoZSBpbWFnZXMgb24gdGhlIHBhZ2UgYnkgc2VsZWN0aW5nIHRoZSA9DQpS
ZXRyaWV2ZQ0KSW1hZ2VzIG9yIFJldHJpZXZlIEZyYW1lcyBib3ggbG9jYXRlZCBpbiB0aGUgQWR2
YW5jZWQgT3B0aW9ucyBzZWN0aW9uIG9mID0NCnRoZQ0KQWRkIFVybCBNb25pdG9yIEZvcm0uPG86
cD48L286cD48L3NwYW4+PC9mb250PjwvcD4NCg0KPHAgY2xhc3M9M0RNc29Ob3JtYWw+PGZvbnQg
c2l6ZT0zRDIgZmFjZT0zREFyaWFsPjxzcGFuID0NCnN0eWxlPTNEJ2ZvbnQtc2l6ZToxMC4wcHQ7
DQpmb250LWZhbWlseTpBcmlhbCc+PG86cD4mbmJzcDs8L286cD48L3NwYW4+PC9mb250PjwvcD4N
Cg0KPHAgY2xhc3M9M0RNc29Ob3JtYWw+PGZvbnQgc2l6ZT0zRDIgZmFjZT0zREFyaWFsPjxzcGFu
ID0NCnN0eWxlPTNEJ2ZvbnQtc2l6ZToxMC4wcHQ7DQpmb250LWZhbWlseTpBcmlhbCc+LS0tLTxv
OnA+PC9vOnA+PC9zcGFuPjwvZm9udD48L3A+DQoNCjxwIGNsYXNzPTNETXNvTm9ybWFsPjxmb250
IHNpemU9M0QyIGZhY2U9M0RBcmlhbD48c3BhbiA9DQpzdHlsZT0zRCdmb250LXNpemU6MTAuMHB0
Ow0KZm9udC1mYW1pbHk6QXJpYWwnPjxvOnA+Jm5ic3A7PC9vOnA+PC9zcGFuPjwvZm9udD48L3A+
DQoNCjxwIGNsYXNzPTNETXNvTm9ybWFsPjxmb250IHNpemU9M0QyIGZhY2U9M0RBcmlhbD48c3Bh
biA9DQpzdHlsZT0zRCdmb250LXNpemU6MTAuMHB0Ow0KZm9udC1mYW1pbHk6QXJpYWwnPldvdWxk
IGl0IGJlIHdvcnRoIGl0IHRvIHR1cm4gb24gcmV0cmlldmFsIG9mIG9iamVjdHMgPQ0KZnJvbQ0K
c29tZSBvZiBvdXIgcGFnZXM/Jm5ic3A7IExldCBtZSBrbm93IGlmIHlvdSB0aGluayBpdCYjODIx
NztzIGEgZ29vZCBpZGVhID0NCmZvciBtZQ0KdG8gbG9vayBpbnRvIHRoaXMuPG86cD48L286cD48
L3NwYW4+PC9mb250PjwvcD4NCg0KPHAgY2xhc3M9M0RNc29Ob3JtYWw+PGZvbnQgc2l6ZT0zRDIg
ZmFjZT0zREFyaWFsPjxzcGFuID0NCnN0eWxlPTNEJ2ZvbnQtc2l6ZToxMC4wcHQ7DQpmb250LWZh
bWlseTpBcmlhbCc+PG86cD4mbmJzcDs8L286cD48L3NwYW4+PC9mb250PjwvcD4NCg0KPHAgY2xh
c3M9M0RNc29Ob3JtYWw+PGZvbnQgc2l6ZT0zRDIgZmFjZT0zREFyaWFsPjxzcGFuID0NCnN0eWxl
PTNEJ2ZvbnQtc2l6ZToxMC4wcHQ7DQpmb250LWZhbWlseTpBcmlhbCc+RXJpYzxvOnA+PC9vOnA+
PC9zcGFuPjwvZm9udD48L3A+DQoNCjxwIGNsYXNzPTNETXNvTm9ybWFsPjxmb250IHNpemU9M0Qy
IGZhY2U9M0RBcmlhbD48c3BhbiA9DQpzdHlsZT0zRCdmb250LXNpemU6MTAuMHB0Ow0KZm9udC1m
YW1pbHk6QXJpYWwnPjxvOnA+Jm5ic3A7PC9vOnA+PC9zcGFuPjwvZm9udD48L3A+DQoNCjxwIGNs
YXNzPTNETXNvTm9ybWFsPjxmb250IHNpemU9M0QyIGNvbG9yPTNEIiMzMzMzMzMiIGZhY2U9M0RB
cmlhbD48c3Bhbg0Kc3R5bGU9M0QnZm9udC1zaXplOjEwLjBwdDtmb250LWZhbWlseTpBcmlhbDtj
b2xvcjojMzMzMzMzJz4tLTwvc3Bhbj48L2Zvbj0NCnQ+PG86cD48L286cD48L3A+DQoNCjxwIGNs
YXNzPTNETXNvTm9ybWFsPjxmb250IHNpemU9M0QyIGNvbG9yPTNEIiMzMzMzMzMiIGZhY2U9M0RB
cmlhbD48c3Bhbg0Kc3R5bGU9M0QnZm9udC1zaXplOjEwLjBwdDtmb250LWZhbWlseTpBcmlhbDtj
b2xvcjojMzMzMzMzJz5FcmljID0NCkdvZXR6PC9zcGFuPjwvZm9udD48bzpwPjwvbzpwPjwvcD4N
Cg0KPHAgY2xhc3M9M0RNc29Ob3JtYWw+PGZvbnQgc2l6ZT0zRDIgY29sb3I9M0QiIzMzMzMzMyIg
ZmFjZT0zREFyaWFsPjxzcGFuDQpzdHlsZT0zRCdmb250LXNpemU6MTAuMHB0O2ZvbnQtZmFtaWx5
OkFyaWFsO2NvbG9yOiMzMzMzMzMnPlNlbmlvciA9DQpJbnRlcm5ldA0KRW5naW5lZXIvTmV3IE1l
ZGlhPGJyPg0KVGhlIFNlYXR0bGUgVGltZXMgQ29tcGFueTxicj4NClJlcHJlc2VudGluZyB0aGUg
PHN0MTpwbGFjZSB3OnN0PTNEIm9uIj48c3QxOkNpdHkgPQ0KdzpzdD0zRCJvbiI+U2VhdHRsZTwv
c3QxOkNpdHk+PC9zdDE6cGxhY2U+DQpQb3N0LUludGVsbGlnZW5jZXI8YnI+DQpwOiAyMDYvNDY0
LTMzMDY8L3NwYW4+PC9mb250PjxvOnA+PC9vOnA+PC9wPg0KDQo8cCBjbGFzcz0zRE1zb05vcm1h
bD48Zm9udCBzaXplPTNEMiBjb2xvcj0zRCIjMzMzMzMzIiBmYWNlPTNEQXJpYWw+PHNwYW4NCnN0
eWxlPTNEJ2ZvbnQtc2l6ZToxMC4wcHQ7Zm9udC1mYW1pbHk6QXJpYWw7Y29sb3I6IzMzMzMzMyc+
bndzb3VyY2UuY29tJm49DQpic3A7fA0Kc2VhdHRsZXRpbWVzLmNvbSZuYnNwO3wgc2VhdHRsZXBp
LmNvbTwvc3Bhbj48L2ZvbnQ+PG86cD48L286cD48L3A+DQoNCjxwIGNsYXNzPTNETXNvTm9ybWFs
Pjxmb250IHNpemU9M0QzIGZhY2U9M0QiVGltZXMgTmV3IFJvbWFuIj48c3BhbiA9DQpzdHlsZT0z
RCdmb250LXNpemU6DQoxMi4wcHQnPjxvOnA+Jm5ic3A7PC9vOnA+PC9zcGFuPjwvZm9udD48L3A+
DQoNCjwvZGl2Pg0KDQo8L2JvZHk+DQoNCjwvaHRtbD4NCgQxDQotLS0tLS09X05leHRQYXJ0XzAw
MF8wMTc3XzAxQzg1MzlDLjZCOTFGM0YwLS0NCgAAAAAAAKCCCNwwggJkMIIBzaADAgECAhAD7abG
gLltA7REK+yK6Y+hMA0GCSqGSIb3DQEBBQUAMGIxCzAJBgNVBAYTAlpBMSUwIwYDVQQKExxUaGF3
dGUgQ29uc3VsdGluZyAoUHR5KSBMdGQuMSwwKgYDVQQDEyNUaGF3dGUgUGVyc29uYWwgRnJlZW1h
aWwgSXNzdWluZyBDQTAeFw0wNzEyMTEwMDE5NDRaFw0wODEyMTAwMDE5NDRaMEkxHzAdBgNVBAMT
FlRoYXd0ZSBGcmVlbWFpbCBNZW1iZXIxJjAkBgkqhkiG9w0BCQEWF2Vnb2V0ekBzZWF0dGxldGlt
ZXMuY29tMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCpf37M95KuMDuqI6mPPbT3JAKtDBmu
rVJMS97+/mIw08GZ53WEzd71vnOUDbSu+Z2GBjcDte0hykNULG2M+JawMPk8Mlenb5TDgmu5xqBZ
3cEwdYXMc1cW9uLaeZFPTy9oBOng/OMXNCTjFfBrgkUwb2sSLC00yB/Dv/bk8JAbFwIDAQABozQw
MjAiBgNVHREEGzAZgRdlZ29ldHpAc2VhdHRsZXRpbWVzLmNvbTAMBgNVHRMBAf8EAjAAMA0GCSqG
SIb3DQEBBQUAA4GBAGSjGVzwgw6GsNM8Mpg3oPgH1ErvSASwWfYgPB9J0OxEryQOnQokEEt0B4yV
BZVBj4LWGWTlWope2uPIOTLyKMybzM0u+q8oo9AlgrlEzCQh83NFCtXeoAmUWsdY9QNaViFK9sUJ
6JgCxJLGX8jExbAu3lFtmafwRBBqzVRyZLgyMIIDLTCCApagAwIBAgIBADANBgkqhkiG9w0BAQQF
ADCB0TELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTESMBAGA1UEBxMJQ2FwZSBU
b3duMRowGAYDVQQKExFUaGF3dGUgQ29uc3VsdGluZzEoMCYGA1UECxMfQ2VydGlmaWNhdGlvbiBT
ZXJ2aWNlcyBEaXZpc2lvbjEkMCIGA1UEAxMbVGhhd3RlIFBlcnNvbmFsIEZyZWVtYWlsIENBMSsw
KQYJKoZIhvcNAQkBFhxwZXJzb25hbC1mcmVlbWFpbEB0aGF3dGUuY29tMB4XDTk2MDEwMTAwMDAw
MFoXDTIwMTIzMTIzNTk1OVowgdExCzAJBgNVBAYTAlpBMRUwEwYDVQQIEwxXZXN0ZXJuIENhcGUx
EjAQBgNVBAcTCUNhcGUgVG93bjEaMBgGA1UEChMRVGhhd3RlIENvbnN1bHRpbmcxKDAmBgNVBAsT
H0NlcnRpZmljYXRpb24gU2VydmljZXMgRGl2aXNpb24xJDAiBgNVBAMTG1RoYXd0ZSBQZXJzb25h
bCBGcmVlbWFpbCBDQTErMCkGCSqGSIb3DQEJARYccGVyc29uYWwtZnJlZW1haWxAdGhhd3RlLmNv
bTCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA1GnX1LCUZFtx6UfYDFG26nKRsIRefS0Nj3sS
34UldSh0OkIsYyeflXtL734Zhx2G6qPduc6WZBrCFG5ErHzmj+hND3EfQDimAKOHePb5lIZererA
Xnbr2RSjXW56fAylS1V/Bhkpf56aJtVquzgkCGqYx7Hao5iR/Xnb5VrEHLkCAwEAAaMTMBEwDwYD
VR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQQFAAOBgQDH7JJ+Tvj1lqVnYiqk8E0RYNBvjWBYYawm
u1I1XAjPMPuoSpaKH2JCI4wXD/S6ZJwXrEcp352YXtJsYHFcoqzceePnbgBHH7UNKOgCneSa/RP0
ptl8sfjcXyMmCZGAc9AUG95DqYMl8uacLxXK/qarigd1iwzdUYRr5PjRzneigTCCAz8wggKooAMC
AQICAQ0wDQYJKoZIhvcNAQEFBQAwgdExCzAJBgNVBAYTAlpBMRUwEwYDVQQIEwxXZXN0ZXJuIENh
cGUxEjAQBgNVBAcTCUNhcGUgVG93bjEaMBgGA1UEChMRVGhhd3RlIENvbnN1bHRpbmcxKDAmBgNV
BAsTH0NlcnRpZmljYXRpb24gU2VydmljZXMgRGl2aXNpb24xJDAiBgNVBAMTG1RoYXd0ZSBQZXJz
b25hbCBGcmVlbWFpbCBDQTErMCkGCSqGSIb3DQEJARYccGVyc29uYWwtZnJlZW1haWxAdGhhd3Rl
LmNvbTAeFw0wMzA3MTcwMDAwMDBaFw0xMzA3MTYyMzU5NTlaMGIxCzAJBgNVBAYTAlpBMSUwIwYD
VQQKExxUaGF3dGUgQ29uc3VsdGluZyAoUHR5KSBMdGQuMSwwKgYDVQQDEyNUaGF3dGUgUGVyc29u
YWwgRnJlZW1haWwgSXNzdWluZyBDQTCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAxKY8VXNV
+065yplaHmjAdQRwnd/p/6Me7L3N9VvyGna9fww6YfK/Uc4B1OVQCjDXAmNaLIkVcI7dyfArhVqq
P3FWy688Cwfn8R+RNiQqE88r1fOCdz0Dviv+uxg+B79AgAJk16emu59l0cUqVIUPSAR/p7bRPGEE
QB5kGXJgt/sCAwEAAaOBlDCBkTASBgNVHRMBAf8ECDAGAQH/AgEAMEMGA1UdHwQ8MDowOKA2oDSG
Mmh0dHA6Ly9jcmwudGhhd3RlLmNvbS9UaGF3dGVQZXJzb25hbEZyZWVtYWlsQ0EuY3JsMAsGA1Ud
DwQEAwIBBjApBgNVHREEIjAgpB4wHDEaMBgGA1UEAxMRUHJpdmF0ZUxhYmVsMi0xMzgwDQYJKoZI
hvcNAQEFBQADgYEASIzRUIPqCy7MDaNmrGcPf6+svsIXoUOWlJ1/TCG4+DYfqi2fNi/A9BxQIJNw
PP2t4WFiw9k6GX6EsZkbAMUaC4J0niVQlGLH2ydxVyWN3amcOY6MIE9lX5Xa9/eH1sYITq726jTl
EBpbNU1341YheILcIRk13iSx0x1G/11fZU8xggL4MIIC9AIBATB2MGIxCzAJBgNVBAYTAlpBMSUw
IwYDVQQKExxUaGF3dGUgQ29uc3VsdGluZyAoUHR5KSBMdGQuMSwwKgYDVQQDEyNUaGF3dGUgUGVy
c29uYWwgRnJlZW1haWwgSXNzdWluZyBDQQIQA+2mxoC5bQO0RCvsiumPoTAJBgUrDgMCGgUAoIIB
2DAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0wODAxMTAyMzIxMDZa
MCMGCSqGSIb3DQEJBDEWBBTaB9QTLr4S9QYb3vdhwL6gg/VuYjBnBgkqhkiG9w0BCQ8xWjBYMAoG
CCqGSIb3DQMHMA4GCCqGSIb3DQMCAgIAgDANBggqhkiG9w0DAgIBQDAHBgUrDgMCBzANBggqhkiG
9w0DAgIBKDAHBgUrDgMCGjAKBggqhkiG9w0CBTCBhQYJKwYBBAGCNxAEMXgwdjBiMQswCQYDVQQG
EwJaQTElMCMGA1UEChMcVGhhd3RlIENvbnN1bHRpbmcgKFB0eSkgTHRkLjEsMCoGA1UEAxMjVGhh
d3RlIFBlcnNvbmFsIEZyZWVtYWlsIElzc3VpbmcgQ0ECEAPtpsaAuW0DtEQr7Irpj6EwgYcGCyqG
SIb3DQEJEAILMXigdjBiMQswCQYDVQQGEwJaQTElMCMGA1UEChMcVGhhd3RlIENvbnN1bHRpbmcg
KFB0eSkgTHRkLjEsMCoGA1UEAxMjVGhhd3RlIFBlcnNvbmFsIEZyZWVtYWlsIElzc3VpbmcgQ0EC
EAPtpsaAuW0DtEQr7Irpj6EwDQYJKoZIhvcNAQEBBQAEgYBGMjxYo84ptecot3Drwnz07uVB2w61
9YfWaRyDQnyuh0hO/uIF8eHttMYFzkM2GXWAbwGoZQmPfS1x3AYzF4J/At/Dg2Cst/eCgG5WMVc1
9Kpu6AZoJQLWlEslp19NVsgieZk+4rWNRUhdNILE+5P2r/tkUMFkiun+67Hsxre1TgAAAAAAAA==
END_MESSAGE
$mech->reload;
$mech->content_contains("smime.p7m");
$mech->content_lacks("Thawte Personal Freemail Issuing CA");


# Test Content-Types that are not all lowercase
my $headers = <<'HEADERS';
Received: (qmail 12589 invoked from network); 28 Jan 2008 00:51:54 -0000
Received: from unknown (HELO mserv4.leeds.ac.uk) (129.11.76.223) by
 bp.nmsrv.com with SMTP; 28 Jan 2008 00:51:54 -0000
Received: from remote-access (remote-access.leeds.ac.uk [129.11.76.196]) by
 mserv4.leeds.ac.uk (8.14.1/8.14.1) with ESMTP id m0S0pmis012054
 (version=TLSv1/SSLv3 cipher=EDH-RSA-DES-CBC3-SHA bits=168 verify=NOT); Mon,
 28 Jan 2008 00:51:48 GMT
Date: Mon, 28 Jan 2008 00:51:48 +0000
From: gooduser@example.com
Subject: Re: Comment: CSS / style breaks when page is reloaded. Text /
 javascript (#A5EU )
In-Reply-To: <20080125204649.S1522551@generated.hiveminder.com>
Message-ID: <Pine.GSO.4.64.0801280049540.12815@remote-access>
References: <20080122105133.S80114558@generated.hiveminder.com>
 <20080125204649.S1522551@generated.hiveminder.com>
MIME-Version: 1.0
Content-Type: TEXT/PLAIN; charset=US-ASCII; format=flowed

HEADERS

my $message2 .= <<'MESSAGE';
I've just tried to reproduce the fault. I was using Hiveminder from my 
Office machine...

* A heavily loaded Solaris box
* Usually logged in via a glorified X terminal
* Internet access via a Squid proxy
* Firefox 1.5

I'm not near the office system at the moment, but I can run Firefox on and
display it on my Linux box at home.

There is one odd feature - the style sheet arrives quite a long time after
the page starts to render. It could be a confused proxy.

A quick trawl of the Mozilla Bugzilla suggests that Firefox doesn't like
sluggish stylesheets.

   https://bugzilla.mozilla.org/show_bug.cgi?id=282813
   https://bugzilla.mozilla.org/show_bug.cgi?id=281526
   https://bugzilla.mozilla.org/show_bug.cgi?id=363109

- Jason
MESSAGE
chomp $message2;

ok ($message2, "We've defined our message");
ok ($headers, "We've defined our headers");
use_ok('BTDT::Model::TaskEmail');
can_ok('BTDT::Model::TaskEmail', 'new');
my $mail2 = BTDT::Model::TaskEmail->new(current_user => BTDT::CurrentUser->superuser);
isa_ok($mail2, 'BTDT::Model::TaskEmail');
can_ok($mail2, 'create');
my ($ok,$error) = $mail2->create( message => $headers.$message2 );
ok(!$ok,$error);

($ok) = $mail2->create( message => $headers.$message2, task_id => 1 );
ok($ok,"ya. created one message");

is_string( $mail2->body, $message2, "Message and ->body are the same" );

