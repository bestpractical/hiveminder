use warnings;
use strict;

# {{{ Setup
use BTDT::Test tests => 60;
use Test::LongString;


my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');
my $URL = $server->started_ok;

my $session = $$."-".int(rand(100));

my $mech = Jifty::Test::WWW::Mechanize->new();
$mech->get("$URL/");
# }}}

$mech->html_ok;

$mech->fill_in_action_ok('loginbox',
    'address' => "$session\@example.com",
    'password' => 'secret',
);
$mech->submit_html_ok();
$mech->content_contains('We do not have an account', "The user we're going to create doesn't exist yet");


ok($mech->find_link(text => "Sign up"), "Found signup link");
$mech->follow_link_ok(text => "Sign up");

like($mech->uri, qr{splash/signup/}, "Got to the signup page");

# {{{ Test a signup with no username or password or name
# Should fail with errors about both username and pass

$mech->content_like(qr/Sign Up/i,"Returns a page containing signup");

my $login_form = $mech->form_name('signupform');
ok ($login_form, "Found the signup form");

$mech->submit_html_ok();

contains_string($mech->field_error_text('signupform', 'password'), "You need to fill in the 'Password' field");
contains_string($mech->field_error_text('signupform', 'email'), "You need to fill in the 'Email Address' field");
contains_string($mech->field_error_text('signupform', 'name'), "You need to fill in the 'Name' field");

# }}}

# XXX TODO Try different combinations of inputs left empty
# XXX TODO Test password and confirmation different

# Signs up successfully!

$mech->fill_in_action_ok('signupform',
    'email' => "$session\@example.com",
    'password' => 'secret',
    'password_confirm' => 'secret',
    'name' => 'New Test User',
);

# {{{ Test what happens when someone fills out the signup form successfully
#
my @emails = BTDT::Test->messages;
my $email_count = scalar @emails;

$mech->submit_html_ok();

$mech->content_like(qr/Before you can use Hiveminder/i,"Got confirmation page");
like($mech->uri, qr{/splash/signup/confirm\.html}i, "Redirected to the confirm page"); 
$mech->content_like(qr/Welcome to Hiveminder, New Test User/, "Contains greeting message");
@emails = BTDT::Test->messages;
is(scalar @emails, $email_count + 1, "Sent a confirmation email");

my $confirm_mail = $emails[-1];

my $confirm_URL_RE = qr!(http://.+let/$session%40example\.com/confirm_email.+)!;
like($confirm_mail->body, $confirm_URL_RE, "the email has a confirm URL");
$confirm_mail->body =~ $confirm_URL_RE;
my $confirm_URL = $1;
$confirm_URL =~ s!http://hiveminder.com!$URL!;

# Test resending mail

$mech->follow_link_ok(text => 'send you another one');

$mech->fill_in_action_ok('resend',
    address => "$session\@example.com",
);

$mech->submit_html_ok();
$mech->content_like(qr/Before you can use Hiveminder/i,"Back at confirmation page");
like($mech->uri, qr{/splash/signup/confirm[.]html}i, "Back at confirmation page"); 
$mech->content_like(qr/re-sent your confirmation/, "Confirmation message present");
$mech->content_unlike(qr/Welcome to Hiveminder, New Test User/, "Welcome message doesn't show again");

@emails = BTDT::Test->messages;
is(scalar @emails, $email_count + 2, "Resent a confirmation email");
$confirm_mail = $emails[-1];
like($confirm_mail->body, $confirm_URL_RE, "the second email has a confirm URL");
$confirm_mail->body =~ $confirm_URL_RE;
my $new_confirm_URL = $1;
$new_confirm_URL =~ s!http://hiveminder.com!$URL!;
is($new_confirm_URL, $confirm_URL, "got the same URL as last time");

# Now, we're going to try to log in as this unconfirmed user -- we shouldn't be
# able to

$mech->get("$URL/"); # top level URL
$mech->html_ok;

$mech->fill_in_action_ok('loginbox',
    'address' => "$session\@example.com",
    'password' => 'secret',
);
$mech->submit_html_ok();

$mech->content_like(qr/need to activate/, "The user we're going to create doesn't exist yet");
$mech->get($confirm_URL);
$mech->html_ok;


SKIP: {
    skip "Application EULA not in place", 3 unless BTDT->current_eula_version > 0;
    like($mech->uri, qr{/accept_eula}, "Redirected to the EULA accept page");
    $mech->fill_in_action_ok('accept_eula');
        ok($mech->click_button(value => 'Accept these terms and make our lawyers happy'));
}

like($mech->uri, qr{/todo}i, "Newly-signed-up user on inbox");
$mech->content_contains("Welcome to Hiveminder", "Gets a welcome message");
$mech->content_contains("Pay kidnappers", "Gets a braindump widget");


# Logout
ok($mech->find_link( text => "Logout" ), "Found the Logout link -- so I'm logged in!");
$mech->follow_link_ok( text => "Logout" );

#$mech->content_contains( "You're not currently signed in", "Make sure you're logged out");

like($mech->uri, qr{/splash}, "Redirected to the Welcome page");

$mech->fill_in_action_ok('loginbox',
    'address' => "$session\@example.com",
    'password' => 'secret',
);
$mech->submit_html_ok();

like($mech->uri, qr{/todo}i, "Redirected to the inbox"); 


# Logout
ok($mech->find_link( text => "Logout" ), "Found the Logout link: so we're logged back in");

$mech->follow_link_ok( text => "Logout" );
#$mech->content_contains( "You're not currently signed in", "Make sure you're logged out");

# attempt to log in on the new user page (should not work)

ok($mech->find_link(text => "Sign up"), "Found signup link");
$mech->follow_link_ok(text => "Sign up");

like($mech->uri, qr{splash/signup/}, "Got to the signup page");

$mech->fill_in_action_ok('signupform',
    'email' => "$session\@example.com",
    'password' => 'secret',
    'password_confirm' => 'secret',
    'name' => 'New Test User',
);

$mech->submit_html_ok();
ok( (not $mech->find_link( text => "Logout" )), "Can't find the logout link -- couldn't log in with correct password");


$mech->fill_in_action_ok('signupform',
    'email' => "$session\@example.com",
    'password' => 'wrong',
    'password_confirm' => 'wrong',
    'name' => 'New Test User',
);
$mech->submit_html_ok();
ok( (not $mech->find_link( text => "Logout" )), "Can't find the logout link -- couldn't log in with incorrect password");

1;
