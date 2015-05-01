#!/usr/bin/env hmperl

use strict;
use warnings;
use Net::IMAP::Simple::SSL;

use lib '/opt/nagios/libexec/';
use utils qw/$TIMEOUT %ERRORS/;

eval {
    local $SIG{ALRM} = sub { die "alarm\n" };
    alarm $TIMEOUT;

    my $imap = Net::IMAP::Simple::SSL->new("hiveminder.com:993");
    $imap->login( 'nagios@bestpractical.com', 'hawtcher' ) or die "LOGIN failed";
    $imap->select("INBOX") or die "SELECT failed";
    my $body = $imap->get(1) or die "FETCH failed";
    $body->[0] =~ /nagios test task/ or die "FETCH content failed: $body";

    alarm 0;
};

if ($@) {
    if ( $@ eq "alarm\n" ) {
        print "Timeout\n";
        exit $ERRORS{CRITICAL};
    } else {
        print "Other exception: $@\n";
        exit $ERRORS{CRITICAL};
    }
}

exit $ERRORS{OK};
