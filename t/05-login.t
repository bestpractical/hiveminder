use warnings;
use strict;


# {{{ Setup
use BTDT::Test tests => 94;
use Test::LongString;
use Test::WWW::Mechanize;

my $server=Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;

my $mech = Jifty::Test::WWW::Mechanize->new;

$mech->get_html_ok($URL);
like($mech->uri, qr{splash}, 'Redirected to splash page');
unlike($mech->uri, qr'J:C', 'Not a tangent');
 
$mech->get_html_ok("$URL/groups/");
like($mech->uri, qr{splash}, "bounced to the splash page");
like($mech->uri, qr'J:C', 'Tangented');
# }}}

# {{{ Test a login with no username or password
# Should fail with errors about both username and pass

$mech->content_like(qr/Login/i,"Returns a page containing a login box");

my $login_form = $mech->form_name('loginbox');
ok ($login_form, "Found the login form");

$mech->submit_html_ok();

contains_string($mech->field_error_text('loginbox', 'password'), "fill in the 'password' field");
contains_string($mech->field_error_text('loginbox', 'address'), "fill in the 'Email address' field");


# }}}

# {{{ Test what happens when someone fills out the login form 
# as an unknown user with no password

$mech->fill_in_action_ok('loginbox',
    'address' => 'user@unknownexample.com',
);

$mech->submit_html_ok();

contains_string($mech->field_error_text('loginbox', 'password'), "You need to fill in the 'password' field");
# }}}


# {{{ Test what happens when someone fills out the login form 
# as an unknown user with a password

$mech->fill_in_action_ok('loginbox',
    'address' => 'user@unknownexample.com',
    'password' => 'secret',
);
$mech->submit_html_ok();

$mech->content_contains('We do not have an account', "Bogus users can't log in");
# }}}

# {{{ Try as a valid user with no password.
$mech->fill_in_action_ok('loginbox',
    'address' => 'gooduser@example.com',
    'password' => '',
);
$mech->submit_html_ok();


contains_string($mech->field_error_text('loginbox', 'password'), "You need to fill in the 'password' field");
# }}}

# {{{ Test as a legit user with a bogus password
$mech->fill_in_action_ok('loginbox',
    'address' => 'gooduser@example.com',
    'password' => 'secrets',
);
$mech->submit_html_ok();
$mech->content_contains('may have mistyped your email address or password', "Users can't log in with bogus passwords");
# }}}


# {{{ Get token for logging in with a JS-based md5-hashed password
my $service='/__jifty/webservices/yaml';
my $service_request ="$URL$service?J:A-moniker=BTDT::Action::GeneratePasswordToken&J:A:F-address-moniker=gooduser\@example.com"; 
$mech->get_ok($service_request, "Token-generating webservice $service_request exists");

# XXX needs to be more precise in checking for the token, but this works
# as long as we're using time() for the token
$mech->content_like(qr/\d+/);

use Jifty::YAML;
my $data = Jifty::YAML::Load($mech->content);

#use Data::Dumper;
#warn Dumper $data;
my $token = $data->{'moniker'}->{'_content'}->{'token'};
my $salt = $data->{'moniker'}->{'_content'}->{'salt'};
like($salt, qr/^[0-9A-F]{8}$/i, 'Got a salt');
use Digest::MD5 qw(md5_hex);
my $password = '';
# }}}

# Test a proper login with blank pw using a javascript browser
$mech->get_html_ok("$URL/groups/");
like( $mech->uri, qr{splash}, "Bounced back to the login page");
$mech->content_like(qr/Login/i,"Returns a page containing a login box");


sub try_login {
    my $token = shift;
    my $salt = shift;
    my $password = shift;
    my $hashed_pw = md5_hex("$token " . md5_hex($password . $salt));
    {
        local $^W = 0;
        $mech->fill_in_action_ok('loginbox',
                                 'address' => 'gooduser@example.com',
                                 'password' => '',
                                 'hashed_password' =>$hashed_pw,
                                 'token' => $token
                                );
    }
    $mech->submit_html_ok();
}

try_login($token, $salt, '');

# contains_string($mech->field_error_text('loginbox', 'password'), 'fill in this field');

sub get_token {
    my $user = shift;
    $mech->get($service_request);
    my $data = Jifty::YAML::Load($mech->content);
    my $token = $data->{'moniker'}->{'_content'}->{'token'};
    my $salt = $data->{'moniker'}->{'_content'}->{'salt'};
    $mech->back;
    return ($token, $salt);
}

$password = 'secret';

# Now that we've failed a login, make sure we can't reuse the token

try_login($token, $salt, $password);
$mech->content_contains('Login', "Can't reuse a token");
SKIP: {                        # Try with an expired token
    skip "Not waiting 40s for token to expire", 3;
    
    ($token, $salt) = get_token();
    sleep 40;
    try_login($token, $salt, $password);
    $mech->content_contains('Login', "Can't use an expired token");
}

# Try an unexpired token that we made up
try_login(time, $salt, $password);
$mech->content_contains('Login', "Have to get a token from the server");

# Test a proper login using a javascript browser, with redirect to groups

$mech->get_html_ok("$URL/groups/");
like( $mech->uri, qr{splash}, "Bounced back to the login page");
$mech->content_like(qr/Login/i,"Returns a page containing a login box");

($token, $salt) = get_token();

try_login($token, $salt, $password);
$mech->content_like(qr/Logout/i,"Logged in using token/pw hash!");

# Logout 
ok($mech->find_link( text => "Logout" ), "Found the Logout link");
$mech->follow_link_ok( text => "Logout" );



$mech->content_contains( "Don't have an account", "Make sure you're logged out");
like($mech->uri, qr{/splash}, "Redirected to the Welcome page");

# Log back in, emulating a non-javascript browser, with redirect to groups
$mech->get_html_ok("$URL/groups/");
like( $mech->uri, qr{splash}, "Bounced back to the login page");
$mech->content_like(qr/Login/i,"Returns a page containing a login box");
$mech->fill_in_action_ok('loginbox',
    'address' => 'gooduser@example.com',
    'password' => $password,
);
$mech->submit_html_ok();
$mech->content_like(qr/Logout/i,"Logged in without token/pw hash!");

    like($mech->uri, qr/eula/, "Redirected to the EULA accept page");
    $mech->fill_in_action_ok('accept_eula');
    ok($mech->click_button(value => 'Accept these terms and make our lawyers happy'));

$mech->content_like(qr/Welcome back, Good Test User/,"got a login message");
$mech->content_unlike(qr/Welcome back, Good Test User.*Welcome back, Good Test User/,"got a login message only once");

like($mech->uri, qr{/groups}i, "It remembered that we wanted to go to the groups page"); 


# Logout
ok($mech->find_link( text => "Logout" ), "Found the Logout link");
$mech->follow_link_ok( text => "Logout" );
$mech->content_contains( "Don't have an account", "Make sure you're logged out");
like($mech->uri, qr{/splash}, "Redirected to the Welcome page");

# Now log in without being forwarded to the groups page
$mech->get_html_ok("$URL/");
$mech->content_like(qr/Login/i,"Returns a page containing a login box");

$mech->fill_in_action_ok('loginbox',
    'address' => 'gooduser@example.com',
    'password' => 'secret',
);
$mech->submit_html_ok();
$mech->content_like(qr/Logout/i,"Logged in!");
$mech->content_like(qr/Welcome back, Good Test User/,"got a login message");
$mech->content_unlike(qr/Welcome back, Good Test User.*Welcome back, Good Test User/,"got a login message only once");

like($mech->uri, qr{/todo}i, "It went to the default page"); 


# Create a group so we can test going to a group during login
ok($mech->find_link( text => "Groups" ), "Found groups link");
$mech->follow_link_ok( text => "Groups" );
$mech->follow_link_ok( text => "New group" );
$mech->fill_in_action_ok('newgroup',
                         name => "New group",
                         description => "Some group");
$mech->submit_html_ok();
$mech->content_like(qr/New group/);
like($mech->uri, qr|/groups/2/manage|);

# Logout
ok($mech->find_link( text => "Logout" ), "Found the Logout link");
$mech->follow_link_ok( text => "Logout" );
$mech->content_contains( "Don't have an account", "Make sure you're logged out");
like($mech->uri, qr{/splash}, "Redirected to the Welcome page");

# Try going to a protected page
$mech->get_html_ok("$URL/groups/2/manage");
$mech->content_like(qr/Login/i,"Returns a page containing a login box");

$mech->fill_in_action_ok('loginbox',
    'address' => 'gooduser@example.com',
    'password' => 'secret',
);
$mech->submit_html_ok();
$mech->content_like(qr/Logout/i,"Logged in!");
$mech->content_like(qr/New group/, "Has group information");
like($mech->uri, qr|/groups/2/manage|, "At group page");

1;
