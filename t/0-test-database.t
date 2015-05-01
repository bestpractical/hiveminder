use warnings;
use strict;

use BTDT::Test tests => 30;

use DateTime;

my $MAIN_USER_ID;
my $SUPERUSER = BTDT::CurrentUser->superuser;

    can_ok( 'BTDT::Model::UserCollection', 'new');
    my $users = BTDT::Model::UserCollection->new(current_user => $SUPERUSER);
    isa_ok( $users, 'BTDT::Model::UserCollection');
    can_ok($users, 'limit');
    $users->limit(column => 'id', operator => '>', value => '2');
is( $users->count, 3, "We made three users");
    
    my $user = $users->next;
    isa_ok( $user, 'BTDT::Model::User' );
    is( $user->name, 'Good Test User', "good name" );
    is( $user->email, 'gooduser@example.com', "good email" );
    ok( $user->password_is( 'secret'), "good (?) password" ); 
    is( $user->email_confirmed, '1' ); 
    is( $user->created_on, '2006-01-01', "user has created date of a charter user" ); 

    $MAIN_USER_ID = $user->id;
    
    $user = $users->next;
    isa_ok( $user, 'BTDT::Model::User' );
    is( $user->name, 'Other User', "good name" );
    is( $user->email, 'otheruser@example.com', "good email" );
    ok( $user->password_is( 'something'), "good (?) password" ); 
    is( $user->email_confirmed, '1' );
 
    is( $user->created_on, DateTime->now->ymd, 
	"user created date defaults to today" ); 

    can_ok( 'BTDT::Model::TaskCollection', 'new');
    my $tasks = BTDT::Model::TaskCollection->new(current_user => $SUPERUSER);
    isa_ok( $tasks, 'BTDT::Model::TaskCollection');
    $tasks->unlimit;
    is( $tasks->count, 2, "We made two tasks");
    
    my @t = sort { $a->summary cmp $b->summary } @{ $tasks->items_array_ref };
    
    is(scalar @t, 2, "Still have two tasks");

    isa_ok($t[0], 'BTDT::Model::Task');
    is($t[0]->summary, '01 some task', "good summary 1");
    ok( ! $t[0]->description, 'good desc 1');
    isa_ok($t[0]->requestor, 'BTDT::Model::User');
    is($t[0]->requestor->id, $MAIN_USER_ID);

    isa_ok($t[1], 'BTDT::Model::Task');
    is($t[1]->summary, '02 other task', "good summary 2");
    is($t[1]->description, 'with a description', 'good desc 2');
    isa_ok($t[1]->requestor, 'BTDT::Model::User');
    is($t[1]->requestor->id, $MAIN_USER_ID);

1;
