use warnings;
use strict;

=head1 DESCRIPTION

Tests for our API, when and as we get one.

=cut

use BTDT::Test tests => 8;


my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;

my $mech = BTDT::Test->get_logged_in_mech($URL);

my $result = $mech->send_action('BTDT::Action::DownloadTasks',
                                query  => 'owner/me',
                                format => 'yaml');

ok($result, "Got a reply from DownloadTasks");
ok($result->{_content}->{'result'}, "Got tasks back");

my $tasks = Jifty::YAML::Load($result->{'_content'}->{'result'});

is(scalar @$tasks, 2, "Got 2 tasks back");

is($tasks->[0]->{summary},'01 some task');
is($tasks->[1]->{summary},'02 other task');
is($tasks->[1]->{description},'with a description');

1;
