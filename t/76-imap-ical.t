use warnings;
use strict;

=head1 DESCRIPTION

Tests iCal integration

=cut

use Data::Plist::BinaryReader;
use BTDT::Test tests => 75;

ok( 1, "Loaded the test script" );

# Set us up an IMAP server
my $client = BTDT::Test->start_imap;
my $GOODUSER = BTDT::CurrentUser->new( email => 'gooduser@example.com' );
my $task
    = BTDT::Model::Task->new( current_user => BTDT::CurrentUser->superuser );
my $mime;

use constant MAILBOX => "Apple Mail To Do";

#################### Login
BTDT::Test->make_pro('gooduser@example.com');
ok ($client->login ('gooduser@example.com', "secret"), "OK login" );
ok (!$client->create_mailbox(MAILBOX), "Mailbox creation fails without flag");
ok ($client->quit, "Quit IMAP server");

$client = BTDT::Test->imap_client;
ok( $client->login( 'gooduser@example.com/appleical', "secret" ), "OK login" );
my $messages = $client->select(MAILBOX);
ok( defined $messages, "Selected Apple Mail To Do mailbox" );
is( $messages, 2, "Have right number of messages in inbox" );

#################### Sanity check prepopulated messages
$mime = mime_object(1);
ok( $mime, "Mime object obtained" );
my @parts = $mime->parts;
is( scalar @parts, 2 );
like( $parts[0]->content_type, qr/^text\/plain/ );
like( $parts[1]->content_type, qr/application\/vnd\.apple\.mail\+todo/ );
my $data = $parts[1]->body;
my $plist = eval { Data::Plist::BinaryReader->open_string($data) };
is( "$@", '', "No errors thrown" );
ok( $plist, '$data was actually a binary file' );
is( $plist->is_archive, 1, "Attachment is an NSKeyedArchiver object" );
my $object = $plist->object;
ok ($object, "Got LibraryToDo object");
isa_ok($object, "Data::Plist::Foundation::LibraryToDo");
is($object->title, "01 some task", "Plist created correctly");

$mime = mime_object(2);
ok( $mime, "Mime object obtained" );
@parts = $mime->parts;
is( scalar @parts, 2 );
like( $parts[0]->content_type, qr/^text\/plain/ );
like( $parts[1]->content_type, qr/application\/vnd\.apple\.mail\+todo/ );
$data = $parts[1]->body;
$plist = eval { Data::Plist::BinaryReader->open_string($data) };
is( "$@", '', "No errors thrown" );
ok( $plist, '$data was actually a binary file' );
is( $plist->is_archive, 1, "Attachment is an NSKeyedArchiver object" );
ok ($object, "Got LibraryToDo object");
isa_ok($object, "Data::Plist::Foundation::LibraryToDo");
is($object->title, "01 some task", "Plist created correctly");

#################### Append a task
ok( $client->put( MAILBOX, <<EOT, "seen" ), "Appended successfully" );
X-Uniform-Type-Identifier: com.apple.mail-todo
Message-Id: D3150819-B128-4FB9-8DB7-FA1DF5300A90
Subject: New To Do
Mime-Version: 1.0 (Apple Message framework v924)
Content-Type: multipart/alternative;
	boundary=Apple-Mail-1-949468959
Date: 


--Apple-Mail-1-949468959
Content-Type: text/plain;
	charset=WINDOWS-1252;
	format=flowed
Content-Transfer-Encoding: quoted-printable

=97
=97 This is a To Do stored on an IMAP server.
=97 It is managed by Mail so please don=92t modify or delete it.
=97

=92New To Do=92 [D3150819-B128-4FB9-8DB7-FA1DF5300A90]
Has no due date.
Is incomplete.
Has no priority.
Is stored in the calendar calendar.
Has no alarms.
Contains the URL 	=
mailitem:D3150819-B128-4FB9-8DB7-FA1DF5300A90?type=3Dtodo&action=3Dshowpar=
ent
Has no note.=

--Apple-Mail-1-949468959
Content-Type: application/vnd.apple.mail+todo
Content-Transfer-Encoding: base64

YnBsaXN0MDDUAQIDBAUGCQpYJHZlcnNpb25UJHRvcFkkYXJjaGl2ZXJYJG9iamVjdHMSAAGGoNEH
CFRyb290gAFfEA9OU0tleWVkQXJjaGl2ZXKuCwwnKzIzNDU2Oj1DREdVJG51bGzdDQ4PEBESExQV
FhcYGRobHB0eHyAhIh8kHyZWJGNsYXNzW1RvRG8gQWxhcm1zXxAQVG9EbyBDYWxlbmRhciBJRFxU
b0RvIGlDYWwgSURaVG9EbyBUaXRsZV8QFVRvRG8gRHVlIERhdGUgRW5hYmxlZF1Ub0RvIFByaW9y
aXR5XxATVG9EbyBDYWxlbmRhciBUaXRsZVhUb0RvIFVSTF5Ub0RvIENvbXBsZXRlZF8QEVRvRG8g
RGF0ZSBDcmVhdGVkXxAVVG9EbyBQcmlvcml0eSBFbmFibGVkXxAQVG9EbyBLZXlzIERpZ2VzdIAN
gAKABIAGgAcIEAGABYAKCIAICIAA0g0oKSpXTlMuZGF0YYADTxDnYnBsaXN0MDDUAQIDBAUGCQpY
JHZlcnNpb25UJHRvcFkkYXJjaGl2ZXJYJG9iamVjdHMSAAGGoNEHCFRyb290gAFfEA9OU0tleWVk
QXJjaGl2ZXKjCwwRVSRudWxs0g0ODxBWJGNsYXNzXxAQVG9EbyBBbGFybXMgTGlzdIACgADSEhMU
FVgkY2xhc3Nlc1okY2xhc3NuYW1lohUWWlRvRG9BbGFybXNYTlNPYmplY3QIERofKTI3Oj9BU1dd
Yml8foCFjpmcpwAAAAAAAAEBAAAAAAAAABcAAAAAAAAAAAAAAAAAAACw0iwtLi9YJGNsYXNzZXNa
JGNsYXNzbmFtZaMvMDFdTlNNdXRhYmxlRGF0YVZOU0RhdGFYTlNPYmplY3RfECRERkNGRUZENS0w
RjRELTQ2OUUtODNFMC1FNkNBMjhDOEY3ODZYY2FsZW5kYXJfECREMzE1MDgxOS1CMTI4LTRGQjkt
OERCNy1GQTFERjUzMDBBOTBZTmV3IFRvIERv0g03ODlXTlMudGltZYAJI0Gsh3ixK0Vr0iwtOzyi
PDFWTlNEYXRl0w0+P0AmQldOUy5iYXNlW05TLnJlbGF0aXZlgAyAAIALXxBJbWFpbGl0ZW06RDMx
NTA4MTktQjEyOC00RkI5LThEQjctRkExREY1MzAwQTkwP3R5cGU9dG9kbyZhY3Rpb249c2hvd3Bh
cmVudNIsLUVGokYxVU5TVVJM0iwtSEmjSUoxW0xpYnJhcnlUb0RvVFRvRG8ACAARABoAHwApADIA
NwA6AD8AQQBTAGIAaACDAIoAlgCpALYAwQDZAOcA/QEGARUBKQFBAVQBVgFYAVoBXAFeAV8BYQFj
AWUBZgFoAWkBawFwAXgBegJkAmkCcgJ9AoECjwKWAp8CxgLPAvYDAAMFAw0DDwMYAx0DIAMnAy4D
NgNCA0QDRgNIA5QDmQOcA6IDpwOrA7cAAAAAAAACAQAAAAAAAABLAAAAAAAAAAAAAAAAAAADvA==

--Apple-Mail-1-949468959--

EOT

# Check task creation
$task->load(3);
ok( $task->id, "Load successful" );
is( $task->summary, "New To Do", "Can create tasks by append" );
is( $task->requestor->email, 'gooduser@example.com',
    "Has current user as requestor" );
is( $task->owner->email, 'gooduser@example.com',
    "Has current user as owner" );
is( $task->tags, "", "Didn't get any tags" );
ok( not($task->complete), "Isn't complete");

# Check that the message on the server as as we appended it
$mime = mime_object(3);
ok( $mime, "Mime object obtained" );
@parts = $mime->parts;
is( scalar @parts, 2 );
is( $mime->header("Mime-Version"), "1.0 (Apple Message framework v924)");
like( $parts[0]->content_type, qr/^text\/plain/ );
like( $parts[1]->content_type, qr/application\/vnd\.apple\.mail\+todo/ );
$data = $parts[1]->body;
$plist = eval { Data::Plist::BinaryReader->open_string($data) };
is( "$@", '', "No errors thrown" );
ok( $plist, '$data was actually a binary file' );
is( $plist->is_archive, 1, "Attachment is an NSKeyedArchiver object" );

# Close the mailbox and re-open it, and make sure it's still so
$client->close;
$client->select(MAILBOX);
$mime = mime_object(3);
ok( $mime, "Mime object obtained" );
@parts = $mime->parts;
is( scalar @parts, 2 );
{
    local $TODO = "Message changes, alas";
    is( $mime->header("Mime-Version"), "1.0 (Apple Message framework v924)");

    # Check it off in the client
    is_deeply( [sort $client->msg_flags(3)], ['\Seen']);
}
ok( $client->delete(3) );

{
    local $TODO = "Flags aren't kept";
    is_deeply( [sort $client->msg_flags(3)], ['\Deleted', '\Seen']);
}
ok( $client->put( MAILBOX, <<EOT, "seen" ), "Appended successfully" );
X-Uniform-Type-Identifier: com.apple.mail-todo
Message-Id: D3150819-B128-4FB9-8DB7-FA1DF5300A90
Subject: New To Do
Mime-Version: 1.0 (Apple Message framework v924)
Content-Type: multipart/alternative;
	boundary=Apple-Mail-2-949478989
Date: 


--Apple-Mail-2-949478989
Content-Type: text/plain;
	charset=WINDOWS-1252;
	format=flowed
Content-Transfer-Encoding: quoted-printable

=97
=97 This is a To Do stored on an IMAP server.
=97 It is managed by Mail so please don=92t modify or delete it.
=97

=92New To Do=92 [D3150819-B128-4FB9-8DB7-FA1DF5300A90]
Has no due date.
Was completed on August 1, 2008.
Has no priority.
Is stored in the calendar calendar.
Has no alarms.
Contains the URL 	=
mailitem:D3150819-B128-4FB9-8DB7-FA1DF5300A90?type=3Dtodo&action=3Dshowpar=
ent
Has no note.=

--Apple-Mail-2-949478989
Content-Type: application/vnd.apple.mail+todo
Content-Transfer-Encoding: base64


YnBsaXN0MDDUAQIDBAUGCQpYJHZlcnNpb25UJHRvcFkkYXJjaGl2ZXJYJG9iamVjdHMSAAGGoNEH
CFRyb290gAFfEA9OU0tleWVkQXJjaGl2ZXKvEA8LDCktMzc7PD0+P0JISUxVJG51bGzeDQ4PEBES
ExQVFhcYGRobHB0eHyAhIiMkJSAnKFYkY2xhc3NbVG9EbyBBbGFybXNfEBBUb0RvIENhbGVuZGFy
IElEXFRvRG8gaUNhbCBJRFpUb0RvIFRpdGxlXxAVVG9EbyBEdWUgRGF0ZSBFbmFibGVkXVRvRG8g
UHJpb3JpdHlfEBNUb0RvIENhbGVuZGFyIFRpdGxlWFRvRG8gVVJMXlRvRG8gQ29tcGxldGVkXxAR
VG9EbyBEYXRlIENyZWF0ZWRfEBVUb0RvIFByaW9yaXR5IEVuYWJsZWRfEBNUb0RvIERhdGUgQ29t
cGxldGVkXxAQVG9EbyBLZXlzIERpZ2VzdIAOgASABoAIgAkIEAGAB4ALCYAKCIACgADSDSorLFdO
Uy50aW1lgAMjQayHeMVPwiLSLi8wMVgkY2xhc3Nlc1okY2xhc3NuYW1lojEyVk5TRGF0ZVhOU09i
amVjdNINNDU2V05TLmRhdGGABU8Q52JwbGlzdDAw1AECAwQFBgkKWCR2ZXJzaW9uVCR0b3BZJGFy
Y2hpdmVyWCRvYmplY3RzEgABhqDRBwhUcm9vdIABXxAPTlNLZXllZEFyY2hpdmVyowsMEVUkbnVs
bNINDg8QViRjbGFzc18QEFRvRG8gQWxhcm1zIExpc3SAAoAA0hITFBVYJGNsYXNzZXNaJGNsYXNz
bmFtZaIVFlpUb0RvQWxhcm1zWE5TT2JqZWN0CBEaHykyNzo/QVNXXWJpfH6AhY6ZnKcAAAAAAAAB
AQAAAAAAAAAXAAAAAAAAAAAAAAAAAAAAsNIuLzg5ozk6Ml1OU011dGFibGVEYXRhVk5TRGF0YV8Q
JERGQ0ZFRkQ1LTBGNEQtNDY5RS04M0UwLUU2Q0EyOEM4Rjc4NlhjYWxlbmRhcl8QJEQzMTUwODE5
LUIxMjgtNEZCOS04REI3LUZBMURGNTMwMEE5MFlOZXcgVG8gRG/SDSorQYADI0Gsh3ixK0Vr0w1D
REUoR1dOUy5iYXNlW05TLnJlbGF0aXZlgA2AAIAMXxBJbWFpbGl0ZW06RDMxNTA4MTktQjEyOC00
RkI5LThEQjctRkExREY1MzAwQTkwP3R5cGU9dG9kbyZhY3Rpb249c2hvd3BhcmVudNIuL0pLoksy
VU5TVVJM0i4vTU6jTk8yW0xpYnJhcnlUb0RvVFRvRG8ACAARABoAHwApADIANwA6AD8AQQBTAGUA
awCIAI8AmwCuALsAxgDeAOwBAgELARoBLgFGAVwBbwFxAXMBdQF3AXkBegF8AX4BgAGBAYMBhAGG
AYgBjQGVAZcBoAGlAa4BuQG8AcMBzAHRAdkB2wLFAsoCzgLcAuMDCgMTAzoDRANJA0sDVANbA2MD
bwNxA3MDdQPBA8YDyQPPA9QD2APkAAAAAAAAAgEAAAAAAAAAUAAAAAAAAAAAAAAAAAAAA+k=

--Apple-Mail-2-949478989--

EOT
$client->expunge_mailbox($client->current_box);
is( $client->select( $client->current_box ), 3, "Has only three messages now");

# Sanity check the new message in the mailbox
$mime = mime_object(3);
ok( $mime, "Mime object obtained" );
@parts = $mime->parts;
is( scalar @parts, 2 );
like( $parts[0]->content_type, qr/^text\/plain/ );
like( $parts[1]->content_type, qr/^application\/vnd\.apple\.mail\+todo/ );
$plist = eval { Data::Plist::BinaryReader->open_string($parts[1]->body) };
is( "$@", '', "No errors thrown" );
ok( $plist, '$data was actually a binary file' );
is( $plist->is_archive, 1, "Attachment is an NSKeyedArchiver object" );

# Didn't create a new task
$task->load(4);
{
    local $TODO = "Update failure! :(";
    ok( not($task->id), "Didn't create a new task" );
}

# Reload the old task
$task->load(3);
ok( $task->id, "Load successful" );
{
    local $TODO = "Update failure! :(";
    ok( $task->complete, "Is now complete");
}

# Check polling
$task->load(3);
ok( $task->id, "Load successful" );
$task->set_summary("Updated Task");
$client->noop;
{
    local $TODO = "Push failure. :(";
    like($client->untagged->[0], qr/3 EXPUNGE/, "Is an EXPUNGE");
    like($client->untagged->[1], qr/3 EXISTS/, "Is an EXISTS");
}

# Sanity check the plist
$mime = mime_object(3);
ok ($mime, "Mime object obtained");
@parts = $mime->parts;
is( scalar @parts, 2 );
like( $parts[0]->content_type, qr/^text\/plain/ );
like( $parts[1]->content_type, qr/application\/vnd\.apple\.mail\+todo/ );
$data = $parts[1]->body;
$plist = eval { Data::Plist::BinaryReader->open_string($data) };
is( "$@", '', "No errors thrown" );
ok( $plist, '$data was actually a binary file' );
is( $plist->is_archive, 1, "Attachment is an NSKeyedArchiver object" );
{
    local $TODO = "Hasn't updated";
    is( $plist->object->title, "Updated Task", "Plist was updated properly");
}

# Check limits on task_collection
$task->load(3);
ok($task->id, "Load successful");
$task->set_complete(1, BTDT::DateTime->now->subtract( weeks => 2 )->ymd);
$client->noop;
{
    local $TODO = "Push failure";
    like($client->untagged->[0], qr/3 EXPUNGE/, "Is an EXPUNGE");
    is( $client->select( $client->current_box ), 2, "Has only two messages now");
}


sub mime_object {
    my ($n) = @_;
    my $lines = $client->get($n);
    my $str = join( "", @{ $lines || [] } );
    return Email::MIME->new($str);
}

1;
