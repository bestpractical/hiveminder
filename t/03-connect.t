use strict;
use warnings;

use BTDT::Test tests => 6;

use_ok('Jifty');
can_ok('Jifty', 'handle');

isa_ok(Jifty->handle, "Jifty::DBI::Handle");
isa_ok(Jifty->handle, "Jifty::DBI::Handle::".Jifty->config->framework('Database')->{'Driver'}); 

can_ok(Jifty->handle->dbh, 'ping');
ok(Jifty->handle->dbh->ping);

