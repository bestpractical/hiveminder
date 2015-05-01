use warnings;
use strict;

=head1 DESCRIPTION

Make sure we can't create duplicate users

=cut

use BTDT::Test tests => 10;

use_ok('BTDT::CurrentUser');

my $system_user = BTDT::CurrentUser->superuser;


use_ok('BTDT::Model::User');

{ 
my $u = BTDT::Model::User->new(current_user => $system_user);

my ($id)  = $u->create(email => $$.'root@example.com', name => 'Enoch Root');
ok ($id, "user create returned success");
ok ($u->id, 'Created the new user');
}
{
my $u2 = BTDT::Model::User->new( current_user => $system_user);

my ($id, $msg) = $u2->create(email => $$.'root@example.com', name => 'Enoch Root');
ok (!$id, "user create returned failure for a duplicate");
ok (!$u2->id, "Can't create a user with a duplicate email address");
}

{
my $u2 = BTDT::Model::User->new( current_user => $system_user);

my ($id, $msg) = $u2->create(email => $$.'root@example.com ', name => 'Enoch Root');
ok (!$id, "user create returned failure for a duplicate (with a space)");
ok (!$u2->id, "Can't create a user with a duplicate email address");
}

{
my $u2 = BTDT::Model::User->new( current_user => $system_user);

my ($id, $msg) = $u2->create(email => " ".$$.'other@example.com ', name => 'Enoch Root');
ok ($id, "user create ");
is($u2->email, $$.'other@example.com');
}


1;

