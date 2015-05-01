use warnings;
use strict;

=head1 DESCRIPTION

This tests basic acess control of tasks and user information

=cut

use BTDT::Test tests => 28;

use_ok('BTDT::CurrentUser');
use_ok('BTDT::Model::User');

 my $bootstrap = BTDT::CurrentUser->new(_bootstrap => 1) ;
isa_ok($bootstrap, 'BTDT::CurrentUser');
isa_ok($bootstrap, 'Jifty::CurrentUser');
ok($bootstrap->is_bootstrap_user, "IT's a bootstrap user");
#isa_ok($bootstrap, 'BTDT::Record');
#isa_ok($bootstrap, 'Jifty::Record');

my $nobodyuser = BTDT::Model::User->new( current_user => $bootstrap);
{my ($id,$msg) = $nobodyuser->create( name => 'nobodyuser', email => 'nobodyuser@localhost' );
ok ($id,$msg);
}

my $user;
{ 
 $user = BTDT::Model::User->new( current_user => BTDT::CurrentUser->new(id => $nobodyuser->id));
my ($id,$msg) = $user->create( name => 'acl_test_user', email => 'acl_test_user@localhost' );
ok (!$id,$msg);
ok(!$user->id, "Didn't create a user since the creator had no credentials");

}

{ 
 $user = BTDT::Model::User->new( current_user => $bootstrap );
my ($id,$msg) = $user->create( name => 'acl_test_user', email => 'acl_test_user@localhost' );
ok ($id,$msg);
ok($user->id, "Created our new user just fine");

}

my $other_user;

{ $other_user = BTDT::Model::User->new( current_user => $bootstrap );
my ($id,$msg) = $other_user->create( name => 'acl_test_user_2', email => 'acl_test_user_2@localhost' );
ok ($id,$msg);
ok($other_user->id, "Created our new user just fine");

}



my $task_as_creator = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->new( id => $user->id));

$task_as_creator->create(
               summary => 'a private task',
               requestor_id => $user->id,
               owner_id => $user->id);

my $task_id = $task_as_creator->id;
ok ($task_as_creator->owner, "As the creator of a task, I can see the owner object");
is($task_as_creator->owner->id, $user->id, "Task owned by the creator");
foreach my $right (qw (read update)) { 
    ok($task_as_creator->current_user_can($right), "The creator can $right this task");
}


my $task_as_random = BTDT::Model::Task->new(current_user =>  BTDT::CurrentUser->new(id => $other_user->id));
$task_as_random->load($task_id);

foreach my $right (qw (read update)) { 
    ok(!$task_as_random->current_user_can($right), "The random user can't $right this task");
}
is($task_as_random->summary, undef, "The random user can't see a task summary"); 

is($task_as_random->id, $task_id, "The random can see a task id");

# Assign the task to someone random
$task_as_creator->set_owner_id('otheruser@example.com');

# I shouldn't be able to accept tasks I don't own
ok(!$task_as_creator->current_user_can('update', column => 'accepted', value => 1 ),
   "Can't accept someone else's tasks");


#Check user ACLs
$user->current_user(BTDT::CurrentUser->new(id => $user->id));
ok($user->current_user_can('read'), 'Can read my own data');

$user->current_user(BTDT::CurrentUser->new(id => $other_user->id));
ok(!$user->current_user_can('read', column => 'email'), "Can't see another user's info");

#Now put the two users in a group together

my $group = BTDT::Model::Group->new(current_user => $bootstrap);
$group->create(name => "test", description => "Test group");
$group->add_member($user, "member");
$group->add_member($other_user, "member");

ok($user->current_user_can('read', column => 'email'), "Can see other members of my groups - email");
ok($user->current_user_can('read', column => 'name'), "Can see other members of my groups - name");
ok(!$user->current_user_can('read', column => 'auth_token'), "Can't see private data of other members of my groups - auth_token");

my $third_user = BTDT::Model::User->new( current_user => $bootstrap);
$third_user->create(name => 'acl_test_user_3', email => 'acl_test_user_3@localhost');

#Assign the task requested by $user to $third_user
$task_as_creator->set_owner_id($third_user->id);

#I should be able to see people who assign me tasks
$user->current_user(BTDT::CurrentUser->new(id => $third_user->id));
ok($user->current_user_can('read', column => 'email'), "Can see users who've assigned tasks to me");

#Make sure that $user can't read $third_user's information by
#assigning him a task, unless $third_user accepts it first
#$third_user->current_user(BTDT::CurrentUser->new(id => $user->id));
#ok(!$third_user->current_user_can('read'), "Can't see users who haven't accepted any tasks I've assigned them");

$task_as_creator->set_accepted(1);

ok($user->current_user_can('read', column => 'email'), "Can see users who have accepted a task I've assigned them");

1;
