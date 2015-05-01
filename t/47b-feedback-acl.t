use warnings;
use strict;

# setup {{{
use BTDT::Test tests => 27;
use Email::Simple;

# set up HM feedback group
my $gooduser_cu = BTDT::CurrentUser->new( email => 'gooduser@example.com'  );
my $onlooker_cu = BTDT::CurrentUser->new( email => 'onlooker@example.com'  );

my $gooduser = BTDT::Model::User->new();
$gooduser->load_by_cols(email => 'gooduser@example.com');
ok($gooduser->id, "gooduser loads properly");
my $otheruser = BTDT::Model::User->new();
$otheruser->load_by_cols(email => 'otheruser@example.com');
ok($otheruser->id, "otheruser loads properly");
my $onlooker = BTDT::Model::User->new();
$onlooker->load_by_cols(email => 'onlooker@example.com');
ok($onlooker->id, "onlooker loads properly");

my $group = BTDT::Model::Group->new(current_user => $onlooker_cu);
$group->create(
    name => 'hiveminders feedback',
    description => 'dummy feedback group'
);
$group->add_member($otheruser, 'member');

# this needs to be done as superuser because gooduser can't se eeveryone
my $sugroup = BTDT::Model::Group->new(current_user => BTDT::CurrentUser->superuser);
$sugroup->load($group->id);
is(@{$sugroup->members->items_array_ref}, 2, "group has two members");

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;

my $mech = BTDT::Test->get_logged_in_mech($URL);
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->content_like(qr/Logout/i,"Logged in!");

my $othermech = BTDT::Test->get_logged_in_mech($URL, 'otheruser@example.com', 'something');
isa_ok($othermech, 'Jifty::Test::WWW::Mechanize');
$othermech->content_like(qr/Logout/i,"Logged in!");
# }}}

$mech->fill_in_action_ok($mech->moniker_for('BTDT::Action::SendFeedback'),
                         content => "yello");
$mech->submit_html_ok;
$mech->content_contains("Thanks for the feedback");

my @emails = BTDT::Test->messages;
BTDT::Test->setup_mailbox();  # clear the emails.

is(scalar @emails, 2, "Feedback action sent mail");
for (0..1)
{
    my $email = $emails[$_] || Email::Simple->new('');
    unlike($email->body, qr/<> created a task/, "<> indicates ACL issue");
    like($email->body,
        qr/Good Test User <gooduser\@example\.com> created a task and put/,
        "Email included name and email");
}

ok($emails[0]->header('Subject') =~ /\(\s*(#\w+)\s*\)/, 'got record locator');
my $locator = $1;

$othermech->follow_link_ok(text => "hiveminders feedback");
TODO:
{
    local $TODO = "this fails because the 'private debugging information' has literal high-bit chars";
    $othermech->follow_link_ok(text => "All tasks");
}
$othermech->follow_link_ok(text => 'yello');
$othermech->fill_in_action_ok
(
    $othermech->moniker_for('BTDT::Action::UpdateTask'), 
    owner_id => 'me'
);
$othermech->submit_html_ok(value => 'Save');
@emails = BTDT::Test->messages;
BTDT::Test->setup_mailbox();  # clear the emails.

is(scalar @emails, 1, "Feedback acceptance sent mail");

my $superuser_rx = qr/superuser <(.*?)> has accepted a task/;
my $email = $emails[0] || Email::Simple->new('');
my ($body) = $email->body =~ /(\n.+ a task.*\n)/; # for less spewy failures
$body = "...$body...";
unlike($body, qr/<> has accepted a task/, "<> indicates ACL issue");
if ($body =~ $superuser_rx)
{
    unlike($body, $superuser_rx, "presence of superuser indicates an error");
}
else
{
    like($body,
        qr/Other User <otheruser\@example\.com> has taken a task/,
        "Email included name and email");
}

