use warnings;
use strict;

use BTDT::Test tests => 17;
use BTDT::Test::IM;

setup_screenname('gooduser@example.com' => 'tester');

im_like( "todo", qr/<#3>/ );
im_like( "hide #3 forever", qr/Hiding task <#3> forever./ );
im_unlike( "todo", qr/<#3>/ );
im_like( "hide #3 forever", qr/Task <#3> is already hidden forever./ );

