use warnings;
use strict;

=head1 DESCRIPTION

Make sure we don't leak memory because of user <-> current_user link

=cut

use BTDT::Test tests => 23;

use_ok('BTDT::CurrentUser');
use_ok('BTDT::Model::User');

my $system_user = BTDT::CurrentUser->superuser;
my $uid;
{ 
    my $u = BTDT::Model::User->new(current_user => $system_user);
    ($uid)  = $u->create(email => $$.'root@example.com', name => 'Enoch Root');
    ok ($uid, "user create returned success");
    ok ($u->id, 'Created the new user');
}

my %destroyed;

{
    no strict 'refs';
    *BTDT::CurrentUser::DESTROY = sub {
        $destroyed{'CurrentUser'}++;
    };

    *BTDT::Model::User::DESTROY = sub {
        $destroyed{'User'}++;
    };
}

%destroyed = ();
{
    my $current_user = BTDT::CurrentUser->new( id => $uid );
    ok $current_user->id, 'loaded user';
    ok $current_user->user_object, 'has user object';
}
is $destroyed{'CurrentUser'}, 1, "current user object's destroyed";
is $destroyed{'User'}, 1, "user object's destroyed";

%destroyed = ();
{
    my $current_user = BTDT::CurrentUser->new;

    my $user = BTDT::Model::User->new( current_user => $current_user );
    $user->load( $uid );
    ok $user->id, 'loaded user';

    $current_user->user_object( $user );

    ok $current_user->id, 'id is there';
    ok $current_user->user_object, 'has user object';
}
is $destroyed{'CurrentUser'}, 1, "current user object's destroyed";
is $destroyed{'User'}, 1, "user object's destroyed";

%destroyed = ();
{
    my $user;
    {
        my $current_user = BTDT::CurrentUser->new( id => $uid );
        ok $current_user->id, 'loaded user';
        ok $current_user->user_object, 'has user object';
        $user = $current_user->user_object;
    }
    ok $user->current_user, 'current user is still there';
}
is $destroyed{'CurrentUser'}, 2, "current user object's destroyed";
is $destroyed{'User'}, 1, "user object's destroyed";

%destroyed = ();
{
    my $current_user;
    {
        $current_user = BTDT::CurrentUser->new( id => $uid );
        ok $current_user->id, 'loaded user';
        ok $current_user->user_object, 'has user object';
    }
    ok $current_user->user_object, 'user object is still there';
}
is $destroyed{'CurrentUser'}, 1, "current user object's destroyed";
is $destroyed{'User'}, 1, "user object's destroyed";
