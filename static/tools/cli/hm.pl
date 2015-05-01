#!/usr/bin/env perl
use strict;
use warnings;
use Net::Jabber;

die "Usage: $0 message" unless @ARGV;

my $username  = '';
my $password  = '';
my $resource  = 'hm.pl';

my $server    = 'jabber.org';
my $port      = 5222;
my $email     = $username . '@localhost';

my $recipient = 'hmtasks@jabber.org';

die "You must edit this file and change the username and password.\n"
    if $username eq '' || $password eq '';

# connecting..
my $client = Net::Jabber::Client->new();
$client->Connect(hostname => $server,
                 port     => $port);

die "Unable to connect to $server:$port.\n"
    unless $client->Connected;

# logging in..
my ($ok, $msg) = $client->AuthSend(username => $username,
                                   password => $password,
                                   resource => $resource,
);

if ($msg eq 'not-authorized') {
    warn "Login failed. Trying to registering $username on $server.\n";
    my ($ok, $msg) = $client->RegisterSend(username => $username,
                                           resource => $resource,
                                           password => $password,
                                           email    => $email,
                                           key      => rand(2**31),
    );

    die "Registration failed: $ok - $msg\n"
        if $ok ne 'ok';
    warn "Registration successful.\n";
}
else {
    die "Login failed: $ok - $msg\n"
        unless $ok eq "ok";
}

# set up a way to receive the response
$client->SetCallBacks(message => \&msg);

# send the IM
$client->MessageSend(
    to => $recipient,
    body => "@ARGV",
);

my $got_response = 0;

for (1..5) {
    $ok = $client->Process(1);
    defined $ok or die "Connection broken: " . $client->GetErrorCode;
}

die "Timed out while waiting for a response.\n"
    unless $got_response;

sub msg {
    my ($sid, $msg) = @_;
    print $msg->GetBody, "\n";
    ++$got_response;
}

