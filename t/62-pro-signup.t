use warnings;
use strict;

use BTDT::Test tests => 39;

# setup {{{
my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL  = $server->started_ok;
my $mech = BTDT::Test::WWW::Mechanize->new;

my $session  = $$."-".int(rand(100));
my $email    = "$session\@example.com";
my $password = 'abcxyz';

my $coupon =
    BTDT::Model::Coupon->new( current_user => BTDT::CurrentUser->superuser );
$coupon->create(code => "TENBUX", discount => 10);
# }}}
# try to go to pro signup without signing up {{{
$mech->get_ok("$URL/splash/signup/confirm.html");

$mech->content_lacks("get one now!", "pro 'let' link doesn't appear");
$mech->content_contains("you'll have to wait until you're logged in", "but we do offer our consolation");
# }}}
# sign up {{{
$mech->get_ok("$URL/");
$mech->follow_link_ok(text => "Sign up");

$mech->fill_in_action_ok('signupform',
    'email'            => $email,
    'name'             => 'Enthusiast',
    'password'         => $password,
    'password_confirm' => $password,
);

$mech->submit_html_ok();
break_out();
# }}}
# begin the financial transaction {{{
like($mech->uri, qr{/splash/signup/confirm\.html}i, "Redirected to the confirm page");
$mech->content_contains("get one now!", "Got pro 'let' link");

$mech->follow_link_ok(text => "get one now!");

$mech->content_contains("upgraded to Hiveminder Pro", "got the financial txn region");
$mech->content_contains("We accept Visa", "got the financial txn region");
$mech->content_contains('$30.00 USD', "default \$30.00 USD price");
break_out();
# }}}
# apply a $10 off coupon {{{
$mech->fill_in_action_ok(
    $mech->moniker_for('BTDT::Action::ApplyCoupon'),
    coupon => $coupon->code,
);
ok( $mech->click_button( value => 'Apply coupon' ), "Clicked apply coupon" );

$mech->content_contains("TENBUX", "coupon shows up");
$mech->content_contains('$20.00 USD', "coupon's discount taken into account");
break_out();
# }}}
# perform the upgrade {{{
my %data = (
    first_name       => 'John',
    last_name        => 'Doe',
    address          => '123 Anystreet',
    city             => 'Anycity',
    state            => 'Anyplace',
    zip              => '12345',
    country          => 'US',
    cvv2             => '123',
    expiration_month => '01',
    expiration_year  => DateTime->today->year + 1,
);
my $goodcard           = '4007000000027'; # Visa
my $goodcard_lastfour  = 'xxxxxxxxx0027';

$mech->fill_in_action_ok(
    $mech->moniker_for('BTDT::Action::UpgradeAccount'),
    %data,
    card_number      => $goodcard,
);
$mech->submit_html_ok();
# }}}
# now we have to log in again {{{
$mech->fill_in_action_ok(
    'loginbox',
    address  => $email,
    password => $password,
);
$mech->submit_html_ok();

# at this point we stop trying to break out, because we're now allowed to break 
# out. we've completed the financial transaction, and all we have to do is 
# accept the EULA
# }}}
# accept the EULA {{{
$mech->fill_in_action('accept_eula');
$mech->click_button(value => 'Accept these terms and make our lawyers happy');
# }}}

$mech->content_contains("Congratulations, you now have a Hiveminder Pro account!");

# log them out and make sure we can sign in again {{{
$mech->follow_link( text => "Logout" );
$mech->fill_in_action_ok(
    'loginbox',
    address  => $email,
    password => $password,
);
$mech->submit_html_ok();
like($mech->uri, qr{todo}, "got to the todo page");
# }}}
# are we actually pro? {{{
$mech->follow_link_ok( text => "Reports" );
$mech->content_contains("Are you getting work done", "got to the Reports page");
# }}}
# was our order correct? {{{
$mech->get_ok("$URL/account/orders");
$mech->follow_link_ok(text_regex => qr/^\d\d\d\d-\d\d-\d\d$/);
$mech->content_contains("This is a receipt for your order.", "made it to the order page");
$mech->content_contains('$20.00 USD', "the coupon really was applied");
# }}}

sub break_out { # {{{
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $mech = $mech->clone;
    $mech->get("$URL/todo");
    like($mech->uri, qr{/splash}, "unable to get to /todo");

    $mech->post("$URL/=/model/BTDT.Model.Task.yml", { summary => "hooray!" });
    is($mech->status, 403, "unable to post a new task");
} # }}}
