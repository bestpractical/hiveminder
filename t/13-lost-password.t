use warnings;
use strict;
use Test::LongString;

# {{{ Setup
use BTDT::Test tests => 55;


my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;

my $mech = Jifty::Test::WWW::Mechanize->new();

# }}}

$mech->get("$URL/");
$mech->html_ok;

# First try the password that we'll use later, and notice that it doesn't work.

$mech->fill_in_action_ok('loginbox',
    'address' => 'gooduser@example.com',
    'password' => 'lousymemory',
);
$mech->submit_html_ok();

$mech->content_contains('may have mistyped your email address or password', "the password we'll use later isn't the current one");


ok($mech->find_link(text => "Get it reset."), "Found lost password link");
$mech->follow_link_ok(text => "Get it reset.");

like($mech->uri, qr{splash/lostpass\.html}, "Got to the lost password page");

$mech->content_like(qr/send you a link/i,"Returns a page containing 'send you a link'");

ok($mech->form_name('lostpassword'), "Found the form");

$mech->submit_html_ok();
contains_string($mech->field_error_text('lostconf', 'address'), "need to fill in the 'Email address' field");

$mech->fill_in_action_ok('lostconf',
    'address' => 'baduser@example.com',
);

my @emails = BTDT::Test->messages;
my $email_count = scalar @emails;

$mech->submit_html_ok();
$mech->content_contains("can't find an account with that address");

@emails = BTDT::Test->messages;
is(scalar @emails, $email_count, "Got no email");

$mech->fill_in_action_ok('lostconf',
    'address' => 'gooduser@example.com',
);
$mech->submit_html_ok();

$mech->content_like(qr/We have sent a link/, "tells you that a confirmation has been sent");

$mech->content_unlike(qr/link to reset your password has been sent to your email account.*link to reset your password has been sent to your email account/, "tells you that a confirmation has been sent only once");

@emails = BTDT::Test->messages;
is(scalar @emails, $email_count + 1, "Got one email");

my $confirm_mail = $emails[-1];
is($confirm_mail->header("To"), 'gooduser@example.com', 'email goes to right place');
is($confirm_mail->header("Sender"), 'Hiveminder <do_not_reply@hiveminder.com>', 'Set the Sender header');

my $confirm_URL_RE = qr!(http://.+/let/gooduser%40example\.com/reset_password/.+)!;
like($confirm_mail->body, $confirm_URL_RE, "the email has a confirm URL");
$confirm_mail->body =~ $confirm_URL_RE;
my $confirm_URL = $1;
$confirm_URL =~ s!http://hiveminder.com!$URL!;

$mech->get($confirm_URL);
$mech->html_ok;

$mech->content_contains("reset your password");
$mech->submit_html_ok();
$mech->content_contains("From this page, you can reset your password to");
$mech->fill_in_action_ok('autoconfirm',
    password => 'lousymemory',
);
$mech->submit_html_ok();
$mech->content_contains("From this page, you can reset your password to");

is($mech->action_field_value('autoconfirm', 'password'), '', "passwords shouldn't be sticky!");

$mech->fill_in_action_ok('autoconfirm',
    password => '',
    password_confirm => 'lousymemory',
);
$mech->submit_html_ok();
$mech->content_contains("From this page, you can reset your password to");

$mech->fill_in_action_ok('autoconfirm',
    password => 'lousymemory',
    password_confirm => 'lousytyping',
);
$mech->submit_html_ok();
$mech->content_contains("From this page, you can reset your password to");

$mech->fill_in_action_ok('autoconfirm',
    password => 'lousymemory',
    password_confirm => 'lousymemory',
);
$mech->submit_html_ok();

SKIP: {
    skip "Application EULA not in place", 3 unless BTDT->current_eula_version > 0;
    like($mech->uri, qr{/accept_eula}, "Redirected to the EULA accept page");
    $mech->fill_in_action_ok('accept_eula');
    ok($mech->click_button(value => 'Accept these terms and make our lawyers happy'));
}

$mech->content_like(qr/Logout/i,"Logged in!");
$mech->content_like(qr/Your password has been reset.  Welcome back./,"got a login message");
$mech->content_unlike(qr/Your password has been reset.  Welcome back..*Your password has been reset.  Welcome back./,"got a login message only once");

like($mech->uri, qr{/todo}i, "Redirected to the inbox"); 

# Logout (to try new password)
ok($mech->find_link( text => "Logout" ), "Found the Logout link -- so I'm logged in!");
$mech->follow_link_ok( text => "Logout" );

#$mech->content_contains( "You're not currently signed in", "Make sure you're logged out");

like($mech->uri, qr{/splash}, "Redirected to the splash page");

$mech->fill_in_action_ok('loginbox',
    'address' => 'gooduser@example.com',
    'password' => 'lousymemory',
);
$mech->submit_html_ok();

like($mech->uri, qr{/todo}i, "Redirected to the inbox"); 

# Logout
ok($mech->find_link( text => "Logout" ), "Found the Logout link: so we're logged back in");
