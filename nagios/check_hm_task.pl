#!/usr/bin/env hmperl

use strict;
use warnings;
use LWP::UserAgent;

package LWP::UserAgent;

no warnings 'redefine';

sub redirect_ok {
  my $self = shift;
  return 1;
}

use warnings 'redefine';

package main;

use lib '/opt/nagios/libexec/';
use utils qw/$TIMEOUT %ERRORS/;

my $ua = LWP::UserAgent->new;
my $res;
# turn off alarms so that we can set our own
$ua->use_alarm(0);

eval {
  local $SIG{ALRM} = sub {die "alarm\n" };
  alarm $TIMEOUT;

  $ua->cookie_jar({});

  my $moniker = "fnord";
  my %args = (
              address  => 'nagios@bestpractical.com',
              password => 'hawtcher'
             );
  $res = $ua->post(
                      "http://hiveminder.com",
                      {
                       "J:A-$moniker" => "Login",
                       map { ("J:A:F-$_-$moniker" => $args{$_}) } keys %args
                      }
                     );
  alarm 0;
};

if ($@) {
  if ($@ eq "alarm\n") {
    print "Timeout\n";
    exit $ERRORS{CRITICAL};
  } else {
    print "Other exception\n";
    exit $ERRORS{CRITICAL};
    }
}  
  
if (! $res->is_success) {
  print $res->code, " didn't get a successful response\n";
  exit $ERRORS{CRITICAL};
}

if ($res->content !~ m/nagios test task/) {
  print $res->code, " couldn't find test task\n";
  exit $ERRORS{CRITICAL};
}

print $res->code, " found test task\n";
$ua->get("http://hiveminder.com/logout");
exit $ERRORS{OK};
