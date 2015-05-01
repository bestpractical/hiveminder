use warnings;
use strict;

=head1 DESCRIPTION

Check that BTDT doesn't leak with reloadings of /todo

=cut

use BTDT::Test;
use Proc::ProcessTable;

unless ($ENV{JIFTY_LEAK_TESTS}) {
    plan skip_all => "Leak tests not run unless JIFTY_LEAK_TESTS is set";
}

plan tests => 103;

my $server = BTDT::Test->make_server;
my $URL = $server->started_ok;
my($pid) = $server->pids;

my $mech = BTDT::Test->get_logged_in_mech($URL);

# Some things take a bit to "spin up" to full size
my $max = memory();
for (1..15) {
    $mech->get("$URL/todo");
    my $current = memory();
    $max = $current if $current > $max;
}

ok($max, "Steady-state footprint is $max");

# You get *one* blip
my $blip = 0;

for (1 .. 100) {
    $mech->get("$URL/todo");
    my $now = memory();
    my $ok = $now <= $max;
    $ok = 1 if not $ok and $blip++ == 0;
    ok($ok, ($now <= $max ? 0 : int(($now-$max)/1024))."K leaked ($now used)");
}

my $end = memory();
ok($end <= $max, ($end <= $max ? 0 : int(($end-$max)/1024/100))."K leaked over 100 requests");

sub memory {
    my $table = Proc::ProcessTable->new();
    my ($proc) = grep {$_->pid == $pid} @{$table->table};
    return $proc->size;
}

1;
