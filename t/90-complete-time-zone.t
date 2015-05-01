use warnings;
use strict;
use Test::MockTime qw( :all );
use BTDT::Test tests => 7;

# setup {{{
my $user = BTDT::CurrentUser->new(email => 'gooduser@example.com');
Jifty->web->current_user($user);

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');
my $URL = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech($URL);

isa_ok($mech, 'Jifty::Test::WWW::Mechanize');

sub create {
    my $summary = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $task = BTDT::Model::Task->new(current_user => $user);
    my ($ok, $msg) = $task->create(summary => $summary);
    ::ok($ok, $msg);

    return $task;
}
# }}}

my $dt = DateTime->new(
    year      => 2009,
    month     => 10,
    day       => 1,
    hour      => 2,
    minute    => 12,
    second    => 44,
    time_zone => 'UTC',
);
set_fixed_time($dt->ymd . 'T' . $dt->hms, "%Y-%m-%dT%H:%M:%S");

my $task = create('test');
$task->set_complete('t');
ok($task->complete, 'task is complete');

my $tasks = BTDT::Model::TaskCollection->new;
$tasks->from_tokens(qw(completed before 2009-10-02));
is($tasks->count, 1, 'found the task with a wide date');

$tasks = BTDT::Model::TaskCollection->new;
$tasks->from_tokens(qw(completed before 2009-10-01));

is($tasks->count, 1, 'found the task with a narrow date');

