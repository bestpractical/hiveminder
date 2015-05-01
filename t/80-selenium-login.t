use warnings;
use strict;

use BTDT::Test tests => 13;

use BTDT::Test::WWW::Selenium;

my $server = BTDT::Test->make_server();
isa_ok($server, 'Jifty::TestServer');
my $URL = $server->started_ok;

 
my $tests = sub {
    my $sel = shift;
    $sel->open_ok("/splash/", "splash page opened");
    $sel->is_text_present("Sign in", "login text is present");
    $sel->type_ok("J:A:F-address-loginbox", "gooduser\@example.com", 
		  "filled in username");
    $sel->type_ok("J:A:F-password-loginbox", "secret",
		 "filled in password");
    $sel->click_ok("J:A:F-remember-loginbox", 
		   "Told the browser to remember me");
    $sel->click_ok('xpath=//input[@value="Sign in"]', 
		   "Clicked the Login button");

# XXX There is a race condition that prevents these from being useful,
# partially because we don't have the full complement of tests
# available in the Perl libraries that are available in the browser-based
# version of Selenium. But we can tolerate this, since if you're running
# tests in Selenium, we know that the login sequence works in a Javascript
# browser. 
#     $sel->get_value_ok("J:A:F-password-loginbox", "");
#     $sel->get_value_ok("J:A:F-password-loginbox", "");
#     $sel->get_value_unlike("J:A:F-token-loginbox", qr/^$/);

    $sel->wait_for_page_to_load_ok("10000", "The license agreement loads");

    $sel->click_ok('xpath=//input[@value="Accept these terms and make our lawyers happy"]', 
		   "Clicked the license agreement accept button");

    $sel->wait_for_page_to_load_ok("30000", "The inbox loads");
    $sel->is_text_present("Good Test User", "We logged in fine");

    $sel->click_ok("link=Logout", "Clicked the logout link");  
    $sel->wait_for_page_to_load_ok("10000", "Logout sent us back to login page");
    $sel->is_text_present("Sign in", "back to login page");
};

my $tester = BTDT::Test::WWW::Selenium->run_in_all_browsers(
    tests => $tests, browsers=>["*firefox"], num_tests=>10, url=>$URL);
#};

