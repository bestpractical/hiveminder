use warnings;
use strict;

use BTDT::Test tests => 15;

use_ok('BTDT::Model::Task');
use_ok('BTDT::CurrentUser');
my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);

my ($id,$msg) = $task->create( description => $$);

ok($id, "Created a new task");
is ($task->id, $id);
is($task->description, $$);
my $rl = $task->record_locator;
like($task->url, qr:/task/$rl$:, "task URL has record locator format");

can_ok($task, 'tags');
can_ok($task, 'set_tags');

ok($task->set_tags('i hate you'), "We set the tags");
is($task->tags, q{hate i you}, "its tag string is right");
is($task->tag_collection->count, 3, "It as 3 tags");

$task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
($id, $msg) = $task->create( description => "0" );

ok($id, "Created a new task");
is($task->id, $id, "the id is set right");
is($task->description, "0");

my $task2 = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
$task2->load_by_locator($task->record_locator);
is($task2->id, $task->id, "task->load_by_locator hits the right task");

