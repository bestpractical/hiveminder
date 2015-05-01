use warnings;
use strict;


use BTDT::Test tests => 18;


# Invitations to people who don't exist yet
my $user = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
$user->load_by_cols(email => 'jesse@example.com');
ok(!$user->id, "User doesn't yet exist");

my $group = BTDT::Model::Group->new(current_user => BTDT::CurrentUser->superuser);


$group->create( name => 'Test group');
ok($group->id, "Created the group");

my ($id,$msg) = $group->invite( recipient => 'jesse@example.com');

($id,$msg) = $group->invite( recipient => 'jesse@example.com');
ok(!$id,$msg);

$user = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
$user->load_by_cols(email => 'jesse@example.com');
ok($user->id, "User exists now");
is($user->invited_by->id, BTDT::CurrentUser->superuser->id, 'invited_by was set properly');
ok( $user->email_confirmed, 'Email address of invited group users is preconfirmed');


# now, check the invitation to make sure it contains the verbiage for non-users.
my @emails = BTDT::Test->messages;
my $nonuser_invitation_RE =  qr/FREE Hiveminder account/i;
my $invitation_mail = $emails[-1];

like($invitation_mail->body, $nonuser_invitation_RE, "group invitation has text for non-users");
like($invitation_mail->header("Sender"), qr!"?superuser"? <superuser\@localhost>!, "Set the Sender header");



use Jifty::Test::WWW::Mechanize;

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');
my $URL = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech($URL);

my $sender = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
$sender->load_by_cols( email => 'gooduser@example.com' );
ok( $sender->id, 'Got the logged-in user');

my $result = $mech->send_action("BTDT::Action::InviteNewUser", 
		   email => 'somenew@example.com',
);

@emails = BTDT::Test->messages;
$nonuser_invitation_RE =  qr/FREE Hiveminder account/i;
$invitation_mail = $emails[-1];
#use Data::Dumper; print Dumper @emails;

# the invited user exists
my $recipient = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
$recipient->load_by_cols( email => 'somenew@example.com' );
ok( $recipient->id, 'Got the invited user');
is( $recipient->invited_by->id, $sender->id, 'invited_by was set properly');
ok( $recipient->email_confirmed, 'Email address of invited individual users is preconfirmed');

# These could be more robust.
like($result->{message}, qr/You've invited/, "result message looks right");
is($invitation_mail->header('To'), 'somenew@example.com', "new user email goes to right place");
like($invitation_mail->body, $nonuser_invitation_RE, "individual invitation has text for non-users");
is($invitation_mail->header("Sender"), 'gooduser@example.com', "Set the Sender header");

1;

