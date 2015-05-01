use strict;
use warnings;

use BTDT::Test tests => 5;
my $gooduser = BTDT::CurrentUser->new( email => 'gooduser@example.com' );
_setup($gooduser);

my $im = BTDT::Model::UserIM->new(current_user => $gooduser);
$im->create(user_id => $gooduser->id, protocol => 'Test');
ok($im->id);

# can one user see other users' UserIMs?
my $otheruser = BTDT::CurrentUser->new( email => 'otheruser@example.com' );
_setup($otheruser);

my $ims = BTDT::Model::UserIMCollection->new(current_user => $otheruser);
$ims->limit(column => 'user_id', value => $gooduser->id);
is($ims->first, undef); # previously, this was a count, but count doesn't actually do acl checks. it's fast and dumb.


# can a user delete his own UserIMs?
_setup($gooduser);
my $delete = Jifty->web->new_action(class => 'DeleteUserIM', record => $im);
ok $delete->validate;
$delete->run;
my $result = $delete->result;
ok $result->success;

my $newim = BTDT::Model::UserIM->new(current_user => $gooduser);
$newim->load($im->id);
is($newim->id, undef);

sub _setup
{
    my $cu = shift;
    Jifty->web->current_user($cu);
    Jifty->web->response(Jifty::Response->new);
    Jifty->web->request(Jifty::Request->new);
}

