use warnings;
use strict;

package BTDT::Test::WWW::Selenium;

=head2 NAME

BTDT::Test::WWW::Selenium;

=head2 USAGE

use BTDT::Test;
use BTDT::Test::WWW::Selenium;   # NOTE that you can't use this module alone

=head2 DESCRIPTION

This class defines helper functions for testing BTDT using the Selenium
browser automation server.

To use this module, you will need to be running a Selenium server, available at
http://www.openqa.org/selenium-rc/download.action .

For more information on developing Selenium tests, see:

=over 4

=item http://release.openqa.org/selenium-core/nightly/reference.html

=item http://www.openqa.org/selenium-ide/

=back

=cut

use Test::WWW::Selenium;
use Test::More;
use base 'Jifty::Test::WWW::Selenium';
require BTDT::Test;

=head2 setup

Sets up the test suite and initializes the database with test users.

=cut

sub setup {
    my $class = shift;
    my ($browsers) = @_;
    $class->SUPER::setup();
}


=head2 run_in_all_browsers %args

A skeleton for running c<Test::WWW::Selenium> tests over a set
of browsers. Takes a series of named arguments:

=over 4

=item tests

A sub full of tests to run.

=item num_tests

The number of tests being passed, so that the testing framework can
skip them if there's no Selenium server running.

=item browsers

An arrayref of named browsers. Currently, only "*firefox" and "*iexplore"
are supported. Eventually, this function will detect the user's
platform and run appropriate browser tests for that platform.

=item url

The base URL for the server you're testing.

=back

=cut

sub run_in_all_browsers {
    my $self = shift;
    my %args = @_;

    my $coderef = $args{tests};

    foreach my $b ( @{ $args{browsers} } ) {
        my $sel;
        eval {
            $sel = $self->rc_ok(
                $args{server},
                host        => "localhost",
                port        => 4444,
                browser     => $b,
                browser_url => $args{url},
            );
        };
        warn $@ if $@;

    SKIP: {
            skip "No Selenium server running here: $@", $args{num_tests}
                unless eval { $sel->open('/') };

            eval {
                &$coderef( $sel, $args{num_tests} );
                1;
            } or do {
                my $err = $@;
                if (my $str = eval { $sel->get_string("captureScreenshotToString") }) {
                    require MIME::Base64;
                    my $testfile = lc($0);
                    $testfile =~ s/\.t$//;
                    $testfile =~ s/(\W|[_-])+//g;
                    my $fh = File::Temp->new(
                        TEMPLATE => "selenium-screenshot-$testfile-XXXXX",
                        UNLINK   => 0,
                        TMPDIR   => 1 );
                    print $fh MIME::Base64::decode_base64($str);
                    close $fh;
                    rename "$fh" => "$fh.png";
                    diag "failed selenium test: screenshot at $fh.png";
                }
                else {
                    diag "failed selenium test: screenshot not available";
                }

                die $err;
            };
            $sel->stop;
        }
    }
}

=head2 login_and_run_tests ARGS

Behaves like run_in_all_browsers, but logs in a browser first.
Extra arguments are "username" and "password".

=cut

sub login_and_run_tests {
    my $self = shift;
    my %args = @_;

    my $login_tests = 8;

    my $composite = sub {
        my $sel = shift;
        my $innertests = shift(@_) - $login_tests;

        $sel->open_ok("/splash/", "splash page opened");
        $sel->is_text_present("Sign in", "login text is present");
        $sel->type_ok("J:A:F-address-loginbox", $args{username},
                "filled in username");
        $sel->type_ok("J:A:F-password-loginbox", $args{password},
                "filled in password");
        $sel->click_ok("J:A:F-remember-loginbox",
                "Told the browser to remember me");
        $sel->click_ok('xpath=//input[@value="Sign in"]',
                "Clicked the Login button");
        $sel->wait_for_page_to_load_ok("60000", "The EULA page loads");
        $sel->click_ok('xpath=//input[@value="Accept these terms and make our lawyers happy"]',
            "Clicked the license agreement accept button");
        $sel->wait_for_page_to_load_ok("60000", "The inbox loads");
        $sel->is_text_present("Good Test User", "We logged in fine");

        $args{tests}->($sel, $innertests, @_);
    };

    $self->run_in_all_browsers(
        %args,
        tests     => $composite,
        num_tests => $args{num_tests} + 8,
    );
}

1;
