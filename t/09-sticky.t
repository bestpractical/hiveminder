use warnings;
use strict;

# {{{ Setup
use BTDT::Test tests => 14;
use Test::WWW::Mechanize;
use Test::LongString;


my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;

my $session = $$."-".int(rand(100));


my $mech = Jifty::Test::WWW::Mechanize->new();


    $mech->get_html_ok("$URL/splash/signup/");
# }}}


like($mech->uri, qr{splash/signup/}, "Got to the signup page");

$mech->content_like(qr/Sign Up/i,"Returns a page containing signup");

$mech->fill_in_action_ok('signupform',
    'email' => "$session\@example.com",
);

my $form = $mech->form_name('signupform');
ok ($form, "Found the signup form");
is($mech->value("J:A:F-email-signupform"), "$session\@example.com", "the address was actually entered");

$mech->submit_html_ok();

unlike(($mech->field_error_text('signupform', 'address')||''), qr/\S/, "the errors for address is empty");
contains_string($mech->field_error_text('signupform', 'password'), "You need to fill in the 'Password' field");
# This error should only trigger if your passwords don't match
#contains_string($mech->field_error_text('signupform', 'password_confirm'), 'need to fill in this field');

contains_string($mech->field_error_text('signupform', 'name'), "You need to fill in the 'Name' field");

$form = $mech->form_name('signupform');
ok ($form, "Found the signup form");
# THIS IS THE POINT OF THIS TEST FILE:
is($mech->value("J:A:F-email-signupform"), "$session\@example.com", "the address we entered shows up on this page");

