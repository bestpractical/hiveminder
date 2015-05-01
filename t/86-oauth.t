use warnings;
use strict;

use BTDT::Test tests => 30;

# setup {{{
use Scalar::Defer 'defer';

my $admin = BTDT::CurrentUser->superuser;
my $gooduser = BTDT::CurrentUser->new(email => 'gooduser@example.com');

my $consumer_obj = Jifty::Plugin::OAuth::Model::Consumer->new(current_user => BTDT::CurrentUser->superuser);
my ($ok, $msg) = $consumer_obj->create(
    consumer_key => 'c_key',
    secret       => 'c_secret',
    name         => 'Bowser',
    url          => 'http://bowser.mk/',
);
ok($ok, $msg);

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;

my $user = BTDT::Test->get_logged_in_mech($URL);
isa_ok($user, 'BTDT::Test::WWW::Mechanize');
$user->content_like(qr/Logout/i,"Logged in!");
my $consumer = BTDT::Test::WWW::Mechanize->new;
# }}}
# sanity checking {{{
$consumer->get_ok($URL . "/oauth");
$consumer->content_like(qr/This application supports OAuth/, "don't need to be logged in to get to the informational /oauth page");

$user->get_ok("/oauth/authorize");
$user->content_like(qr/If you trust this application/);

for (qw/request_token access_token/) {
    my $response = $consumer->get("/oauth/$_");
    is($response->code, 405, "GET /oauth/$_ fails, needs to be POST");
}

$consumer->get("/oauth/authorize");
$consumer->content_like(qr/Sign in below/, "need to log in to authorize tokens");

$consumer->get("/oauth/authorized");
$consumer->content_like(qr/Sign in below/, "need to log in to authorize tokens (redirected from authorized)");

$user->get("/oauth/authorized");
$user->content_like(qr/If you trust this application/, "authorized redirects to authorize");
# }}}
# straightforward oauth {{{
my ($token, $secret) = $consumer->request_token_request;

$user->fill_in_action_ok(
    $user->moniker_for('AuthorizeRequestToken'),
    token => $token
);
$user->click_button(value => "Allow");

($token, $secret) = $consumer->exchange_for_access_token($token, $secret);

my $response = $consumer->oauth_get('/=/model/Task/id/1.yml', $token, $secret);
is($response->code, 200, "response code 200");
unlike($response->content, qr/Sign in below/, "didn't get to a login page");
like($response->content, qr/01 some task/, "got the task!");

my $access_token = Jifty::Plugin::OAuth::Model::AccessToken->new(current_user => BTDT::CurrentUser->superuser);
$access_token->load_by_cols(id => 1);
($ok, $msg) = $access_token->set_valid_until(DateTime->now->subtract(days => 1));
ok($ok, $msg);

$response = $consumer->oauth_get('/=/model/Task/id/1.yml', $token, $secret);
is($response->code, 403, "response code 403");
# }}}
# helper methods {{{
BEGIN {
    our %defaults = (
        consumer_key     => 'c_key',
        consumer_secret  => 'c_secret',
        request_method   => 'POST',
        signature_method => 'HMAC-SHA1',
    );
}
my $timestamp = 0;

sub BTDT::Test::WWW::Mechanize::request_token_request {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $self = shift;

    ++$timestamp;

    my $request = Net::OAuth::RequestTokenRequest->new(
        timestamp   => $timestamp,
        nonce       => $timestamp,
        request_url => Jifty->web->url(path => '/oauth/request_token'),
        %main::defaults,
    );
    $self->get_oauth_token($request);
}

sub BTDT::Test::WWW::Mechanize::exchange_for_access_token {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $self = shift;
    my $token = shift;
    my $secret = shift;

    ++$timestamp;

    my $request = Net::OAuth::AccessTokenRequest->new(
        timestamp    => $timestamp,
        nonce        => $timestamp,
        request_url  => Jifty->web->url(path => '/oauth/access_token'),
        %main::defaults,
        token        => $token,
        token_secret => $secret,
    );

    $self->get_oauth_token($request);
}

sub BTDT::Test::WWW::Mechanize::get_oauth_token {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $self = shift;
    my $request = shift;

    $request->sign;
    ok($request->verify, "verified request's signature");

    my $response = $self->post(
        $request->request_url,
        Content_Type => 'application/x-www-form-urlencoded',
        Content => $request->to_post_body,
    );

    is($response->code, 200, "response code 200");

    for (split '&', $response->content) {
        $token = $1 if /^oauth_token=(\w+)$/;
        $secret = $1 if /^oauth_token_secret=(\w+)$/;
    }
    ok($token, "got an oauth_token in the response");
    ok($secret, "got an oauth_token_secret in the response");
    $token && $secret or diag "Response was: " . $response->content;

    return ($token, $secret);
}

sub BTDT::Test::WWW::Mechanize::oauth_get {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $self   = shift;
    my $uri    = shift;
    my $token  = shift;
    my $secret = shift;

    ++$timestamp;

    my $request = Net::OAuth::ProtectedResourceRequest->new(
        timestamp      => $timestamp,
        nonce          => $timestamp,
        request_url    => Jifty->web->url(path => $uri),
        %main::defaults,
        request_method => 'GET',
        token          => $token,
        token_secret   => $secret,
    );

    $request->sign;
    ok($request->verify, "verified request's signature");

    $self->add_header(Authorization =>
        $request->to_authorization_header('hiveminder.com', "\n   "));

    my $response = $self->get($request->request_url);

    return $response;
}
# }}}

