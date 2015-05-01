use strict;
use warnings;

use BTDT::Test tests => 4;

is(Jifty->config->framework('ApplicationClass'), 'BTDT');
is(Jifty->config->framework('LogConfig'), 't/btdttest.log4perl.conf');
# Port is overridden by testconfig
ok(Jifty->config->framework('Web')->{'Port'} >= 10000, "test nested config");
ok(!Jifty->config->framework('DevelMode'), 'Disabled DevelMode');


1;


