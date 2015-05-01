use warnings;
use strict;

=head1 DESCRIPTION

Test to make sure that current_user is overridable

=cut

use BTDT::Test tests => 9;

use_ok ('BTDT::CurrentUser');

use_ok('Jifty::Web');

can_ok('Jifty::Web', 'setup_session');
can_ok('Jifty::Web', 'session');

my $testuser = BTDT::Model::User->new( current_user => BTDT::CurrentUser->superuser);
$testuser->create( email => $$.'@localhost');


my $web = Jifty::Web->new();
$web->setup_session;
my $u = BTDT::CurrentUser->new(email => $$.'@localhost');
$web->current_user($u);
ok($u, "Our 'real' user serializes as ".$u);

is($u->id,$web->current_user->id, "We've set a current user. it's there" . $u->id ." " .$web->current_user->id);

my $u2 = BTDT::CurrentUser->new(email => 'nobody');
ok($u2, "Our 'unreal' user serializes as ".$u2);
$web->temporary_current_user($u2);

is($web->current_user, $u2 ,"When we set a temp currentuser, it's there");
$web->temporary_current_user(undef);
is($web->current_user->id, $u->id, "When we remove the temporary current user, the original is there");


1;

