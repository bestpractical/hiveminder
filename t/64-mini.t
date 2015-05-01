use warnings;
use strict;

use BTDT::Test tests => 10;

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;
# we're testing mini
$URL .= "/mini";
# specifically, we're testing the bit of mini used by the googlewidget
my $TODOURL = $URL.'/todo/on/today';

# my $mech = BTDT::Test->get_logged_in_mech($URL);
# get_logged_in_mech requires the page to have Logout
my $mech = log_into_mini();

isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->get_ok($TODOURL);


# make a task due today and one for tomorrow
$mech->fill_in_action_ok( 'today-new_item_create', summary => 'cows are purple [due today]' );
$mech->submit;
$mech->get_ok($TODOURL);

$mech->content_contains('cows are purple');

$mech->fill_in_action_ok( 'today-new_item_create', summary => 'cows are orange [due tomorrow]' );
$mech->submit;
$mech->get_ok($TODOURL);

$mech->content_contains('cows are orange');

#really need to fix get_logged_in_mech at some point
sub log_into_mini {
    my $mech = BTDT::Test::WWW::Mechanize->new;
    $mech->get("$URL");

    unless ($mech->content =~ /Login/) {
        $mech->follow_link( text => "Logout" );
    }
    my $login_form = $mech->form_name('loginbox');
    return unless $mech->fill_in_action('loginbox', 
                                        address => 'gooduser@example.com', 
                                        password => 'secret');
    $mech->submit;

    if ($mech->uri =~ m{accept_eula}) {
        # Automatically accept the EULA
        $mech->fill_in_action('accept_eula');
        $mech->click_button(value => 'Accept these terms and make our lawyers happy');
    }

    return $mech;
}
