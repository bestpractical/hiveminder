use warnings;
use strict;

=head1 DESCRIPTION

makes sure that task collection acls work

=cut

use BTDT::Test tests => 26;

# create users: 
#  requestor 
#  owner
#  someone_else
my $requestor = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
$requestor->create( email => 'requestor@localhost',
                    access_level => 'staff',
		    email_confirmed => 1,
                    );
ok($requestor->id);

my $owner = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
$owner->create( email => 'owner@localhost',
                    access_level => 'staff',
		    email_confirmed => 1,
);

ok($owner->id);

my $someone_else = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
$someone_else->create( email => 'someoneelse@localhost',
                    access_level => 'staff',
		    email_confirmed => 1,
);
ok($someone_else->id);

#
# create a group:
#  visible
#    requestor, someone_else as member

my $visible = BTDT::Model::Group->new(current_user => BTDT::CurrentUser->new(id => $requestor->id));
$visible->create (name => 'visible');
ok($visible->id, 'visible group created');
$visible->add_member($someone_else, "member");

ok ($visible->has_member($requestor), 'requestor is a member of visible');
ok (!$visible->has_member($owner), 'owner is NOT a member of visible');
ok ($visible->has_member($someone_else), 'someone else is a member of visible');

#  hidden

my $hidden = BTDT::Model::Group->new(current_user => BTDT::CurrentUser->new(id =>$someone_else->id));
$hidden->create (name => 'hidden');
ok($hidden->id, 'hidden group created');
ok (!$hidden->has_member($requestor), 'requestor is NOT a member of hidden');
ok (!$hidden->has_member($owner), 'owner is NOT a member of hidden');
ok ($hidden->has_member($someone_else), 'someone else is a member of hidden');


my $ADMIN = BTDT::CurrentUser->superuser;
# create tasks
#
#  taska: owned by owner, requestor requestor - personal

my $task = BTDT::Model::Task->new( current_user =>BTDT::CurrentUser->new(id => $owner->id) );
my ($id,$msg) = $task->create(
    summary   => 'taska',
    owner     => $owner,
    requestor => $requestor,
    accepted  => 1
);
ok($id,$msg);
ok( $task->id, 'taska has an id' );
is( $task->requestor->email, $requestor->email, 
    'requestor email for task is right' );
is( $task->owner->email,     $owner->email, 
    'owner email for task is right');
is( $task->summary,          'taska' ,
    'summary for taska is right');

#  taskb: owned by owner, requestor someone_else - personal
$task = BTDT::Model::Task->new( current_user => $ADMIN );
$task->create(
    summary   => 'taskb',
    owner     => $owner,
    requestor => $someone_else
);
ok( $task->id );

#  taskc: owned by someone_else, requestor requestor - personal
$task = BTDT::Model::Task->new( current_user => $ADMIN );
$task->create(
    summary   => 'taskc',
    owner     => $someone_else,
    requestor => $requestor
);
ok( $task->id );
#  taskd: owned by someone_else, requestor someone_else - personal
$task = BTDT::Model::Task->new( current_user => $ADMIN );
$task->create(
    summary   => 'taskd',
    owner     => $someone_else,
    requestor => $someone_else
);
ok( $task->id );

#    grouptaska: group visible, owner someone_else, requestor requestor
$task = BTDT::Model::Task->new( current_user => $ADMIN );
$task->create(
    summary   => 'grouptaska',
    owner     => $someone_else,
    requestor => $requestor,
    group => $visible->id
);
ok( $task->id );

#    grouptaskb: group visible, owner requestor, requestor someone_else
$task = BTDT::Model::Task->new( current_user => $ADMIN );
$task->create(
    summary   => 'grouptaskb',
    owner     => $requestor,
    requestor => $someone_else,
    group => $visible->id
);
ok( $task->id );
#    grouptaskc: group visible, owner someone_else, requestor someone_else
$task = BTDT::Model::Task->new( current_user => $ADMIN );
$task->create(
    summary   => 'grouptaskc',
    owner     => $someone_else,
    requestor => $someone_else,
    group => $visible->id
);
ok( $task->id );
#    grouptaskd: group hidden, owner someone_else, requestor someone_else
$task = BTDT::Model::Task->new( current_user => $ADMIN );
$task->create(
    summary   => 'grouptaskd',
    owner     => $someone_else,
    requestor => $someone_else,
    group => $hidden->id
);
ok( $task->id );
    
# as "owner", find all tasks.
my $owner_tasks = BTDT::Model::TaskCollection->new(current_user => BTDT::CurrentUser->new(id => $owner->id));
$owner_tasks->unlimit();
is ($owner_tasks->count,2);
# results should contain:

#   taska
#   taskb

## as "requestor", find all tasks.
my $requestor_tasks = BTDT::Model::TaskCollection->new(current_user => BTDT::CurrentUser->new(id => $requestor->id));
$requestor_tasks->unlimit();
is($requestor_tasks->count,5);

#   taska
#   taskc
#   grouptaska
#   grouptaskb
#   grouptaskc





## as "someone_else"
my $someone_else_tasks = BTDT::Model::TaskCollection->new(current_user => BTDT::CurrentUser->new(id => $someone_else->id));
$someone_else_tasks->unlimit();
is ($someone_else_tasks->count, 7);
#   taskb
#   taskc
#   taskd
#   grouptaska
#   grouptaskb
#   grouptaskc
#   grouptaskd
#   
    
