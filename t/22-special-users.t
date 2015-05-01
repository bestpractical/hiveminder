use warnings;
use strict;

=head1 DESCRIPTION

This tests that the special users (nobody and superuser) work.

=cut

use BTDT::Test tests => 6;

my $nobody = BTDT::CurrentUser->nobody;
isa_ok($nobody, "BTDT::CurrentUser");
ok($nobody->id, "Nobody has an ID");
is($nobody->user_object->email, 'nobody');

my $superuser = BTDT::CurrentUser->superuser;
isa_ok($superuser, "BTDT::CurrentUser");
ok($superuser->id, "Superuser has an ID");
is($superuser->user_object->email, 'superuser@localhost');


1;

