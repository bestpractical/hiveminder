use warnings;
use strict;

=head1 DESCRIPTION

Test that we support old style
JIFTY_SID_80 cookies in addition to
the newfangled JIFTY_SID_HIVEMINDER cookies

=cut

use YAML;
use BTDT::Test tests => 8;

my $server = BTDT::Test->make_server;
my $URL = $server->started_ok;

my $uri = URI->new($URL);

my $mech = BTDT::Test->get_logged_in_mech($URL);

isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->content_like(qr/Logout/i,"Logged in!");

replace_cookie($mech);

$mech->get_ok($URL);
$mech->content_like(qr/Logout/i,"Logged in!");

{ 
    replace_cookie($mech);
    my %args = ( format => 'sync' );
    my $res = $mech->post("$URL/__jifty/webservices/yaml",
        {   "J:A-fnord" => 'DownloadTasks',
            map { ( "J:A:F-$_-fnord" => $args{$_} ) } keys %args
        }
    );
    if ( $res->is_success ) {
        ok(YAML::Load( Encode::decode_utf8($res->content))->{'fnord'}->{'success'},
           "Succesfully Downlaoded Tasks");
    } else {
        ok(0, "post failed ".$res->status_line);
    }

}

sub replace_cookie {
    my $mech = shift;
    my $cookie_name = Jifty->config->framework('Web')->{'SessionCookieName'};
    my $old_cookie_name = 'JIFTY_SID_'.$uri->port;
    if ($mech->cookie_jar->as_string =~ /$cookie_name=([^;]+)/) {
        my $sid = $1;
        $mech->cookie_jar->clear;
        # munge the cookie to have the old style of cookie
        # this code is how todo.pl does things and *should* still work

        # ..except that LWP and HTTP::Cookies conspire to have requests
        # for "localhost" not get cookies for "localhost", only for
        # "localhost.local" or ".local"  Fix it up:
        my $domain = $uri->host eq "localhost" ? "localhost.local" : $uri->host;
        $mech->cookie_jar->set_cookie(0, $old_cookie_name,
            $sid, '/', $domain, $uri->port,
            0, 0, undef, 1);
        like($mech->cookie_jar->as_string,qr/$old_cookie_name=$sid/,"correctly munged cookie");
    } else {
        fail("Couldn't find and replace $cookie_name with $old_cookie_name");
    }
}

1;
