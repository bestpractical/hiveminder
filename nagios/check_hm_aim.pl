#!/usr/bin/env hmperl
use strict;
use warnings;
require Net::OSCAR;
use Time::HiRes 'time';

use lib '/opt/nagios/libexec/';
use utils qw/$TIMEOUT %ERRORS/;

my $screenname = 'HM Nagios';
my $password = 'zhophnen';

my $check_screenname = 'HM Tasks';

my $start_time;
my $signedon = 0;

sub down {
    print "$check_screenname DOWN - @_\n";
    exit $ERRORS{CRITICAL};
}

sub unreachable {
    print "$check_screenname UNREACHABLE - @_\n";
    exit $ERRORS{WARNING};
}

sub ok {
    print "$check_screenname OK | Time to respond: " . (time - $start_time) . "s\n";
    exit $ERRORS{OK};
}

eval
{
    alarm $TIMEOUT;

    my $oscar = Net::OSCAR->new();
    $oscar->set_callback_error(\&error);
    $oscar->set_callback_im_in(\&received_im);
    $oscar->set_callback_signon_done(\&signed_on);

    $oscar->signon(screenname => $screenname,
                   password   => $password);

    while (1)
    {
        $oscar->do_one_loop();
    }
};

down "response timed out after 20 seconds: $@\n"
    if $signedon;

unreachable "sign on timed out after 20 seconds: $@\n";

sub signed_on
{
    my $oscar = shift;
    $signedon = 1;
    $start_time = time;
    $oscar->send_im($check_screenname, 'todo');
}

sub error
{
    my ($oscar, $connecton, $error, $description, $fatal) = @_;

    down "not logged in"
        if $description =~ /is not logged in/;

    unreachable sprintf "%s UNREACHABLE: Got a %s Net::OSCAR error: %s\n",
                    $check_screenname,
                    $fatal ? 'fatal' : 'nonfatal',
                    $description;
}

sub received_im
{
    my ($oscar, $sender, $message, $is_away) = @_;

    my $expected = $check_screenname;
    for ($sender, $expected) {
        s/\s+//;
        $_ = lc $_;
    }

    ok if $sender eq $expected;
}
