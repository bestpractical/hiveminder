use warnings;
use strict;

use BTDT::Test tests => 4;

use_ok('BTDT::Model::User');

use BTDT::CurrentUser;

my $user = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);

my ($id, $msg) = $user->create( name => $$, email => $$.'@example.com');

ok($id, "Created a new user");
is ($id, $user->id);
is($user->name, $$);

1;
