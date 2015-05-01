#!/usr/bin/env hmperl
use strict;
use warnings;
use Net::Jabber;
use Time::HiRes 'time';

use lib '/opt/nagios/libexec/';
use utils qw/$TIMEOUT %ERRORS/;

my $screenname = 'hmnagios';
my $password   = 'zhophnen';
my $resource   = 'nagios';
my $server     = 'jabber.org';
my $port       = 5222;

my $check_screenname = 'hmtasks@jabber.org';

my $start_time;
my $signed_on;

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

eval {
    alarm $TIMEOUT;

    my $jabber = Net::Jabber::Client->new();

    $jabber->Connect(hostname => $server,
                    port     => $port);
    $jabber->Connected
        or unreachable "Unable to connect to $server:$port.";

    my ($ok, $msg) = $jabber->AuthSend(username => $screenname,
                                       password => $password,
                                       resource => $resource);

    $ok eq 'ok'
        or unreachable "Unable to get authorization: $ok - $msg.";

    $signed_on = 1;

    $jabber->SetCallBacks(message => sub {
        my ($sid, $msg) = @_;
        my $message = $msg->GetBody;
        return if $message eq ''; # status update
        my $sender = $msg->GetFrom;

        # remove resource
        for ($sender, $check_screenname) { s{/.*}{} }

        ok if lc($sender) eq lc($check_screenname);
    });

    $jabber->PresenceSend();

    $jabber->MessageSend(
            to   => $check_screenname,
            type => 'chat',
            body => 't',
    );
    $start_time = time;

    while (1) {
        defined $jabber->Process(1)
            or unreachable "Net::Jabber error: " . $jabber->GetErrorCode;
    }
};

unreachable "Timed out while signing on"
    unless $signed_on;
down "Timed out while waiting for a response";

