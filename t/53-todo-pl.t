use warnings;
use strict;

=head1 DESCRIPTION

Test the todo.pl script

=cut

use BTDT::Test tests => 6, actual_server => 1;

my $script = `which todo.pl`;

if ($script) { 
    plan tests => 6;
} else {
    plan skip_all => "No todo.pl";

}
use_ok('App::Todo');

my $server = BTDT::Test->make_server;
my $URL = $server->started_ok;

# Write out a test config file for todo.pl
my $uri = URI->new($URL);

# This has the side-effect of acceping the EULA
BTDT::Test->get_logged_in_mech($URL);

my $config = {
    email     => 'gooduser@example.com',
    password  => 'secret',
    site      => 'http://127.0.0.1:' . $uri->port
   };

Jifty::Test->test_file("t/todo.pl.conf");
umask(0077);
open(my $cf, ">", "t/todo.pl.conf");
print $cf Jifty::YAML::Dump($config);
close($cf);

my ($t1, $t2) = run_todo();

like($t1, qr/01 some task/);
like($t2, qr/02 other task/);

my ($created) = run_todo(qw(add 03 foo task));
like($created,qr/Created task/);

my (undef, undef, $t3) = run_todo();

like($t3, qr/03 foo task/);

sub run_todo {
    my @args = @_;
    chomp $script;
    open(my $todo, "-|", $^X, $script, "--config", "t/todo.pl.conf", @args)
      or die("Error opening $script: $!");
    my @lines = <$todo>;
    close($todo);
    return @lines;
}


1;

