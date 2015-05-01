use warnings;
use strict;

=head1 DESCRIPTION

Test ``but first'' and ``and then'' tasks

=cut

use BTDT::Test tests => 53;

use_ok('BTDT::Model::Task');
use_ok('BTDT::Model::TaskCollection');
my $t1 = BTDT::Model::Task->new(current_user =>BTDT::CurrentUser->superuser);
$t1->create(summary => 'A sample project');
ok($t1->id, "Created the first task ". $t1->id);
my $t2 = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
$t2->create(summary => 'The first step of the sample project');
ok($t2->id, "Created the second task ". $t2->id);

$t1->add_dependency_on($t2->id);
is($t1->depends_on->count(), 1, "we have on dependency");
is($t2->depended_on_by->count(),1,"we are depended on by one task");


my $c1 = BTDT::Model::TaskCollection->new(current_user => BTDT::CurrentUser->superuser);
$c1->from_tokens(depended_on_by =>$t1->id);
is($c1->count,1, " t1 depends on one thing");


my $c2 = BTDT::Model::TaskCollection->new(current_user => BTDT::CurrentUser->superuser);
$c2->from_tokens(depends_on =>$t2->id);
is($c2->count,1, " one thing depends on t2");

# test dependencies on the site

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;

my $mech = BTDT::Test->get_logged_in_mech($URL);

isa_ok($mech, 'Jifty::Test::WWW::Mechanize');

$mech->form_number(2);
$mech->set_fields('J:A:F-summary-tasklist-new_item_create' => "dep test 1");
$mech->submit_html_ok();
ok($mech->success, "first dependency test task submit successful");

ok($mech->find_link(text => "But first...", n => 3),
   "found the 'But first...' link");
$mech->follow_link_ok(text => "But first...", n => 3,
                      "followed the 'But first...' link");

TODO: {
  local $TODO = "bug when not using javascript, but it's not critical";
  ok($mech->find_link(text => 'tags test 1'),
     "dependant task creation page has original task on it");
}

$mech->form_number(2);
$mech->set_fields('J:A:F-summary-tasklist-item-5-new_item_create' => "dep test 2");
$mech->submit_html_ok();
ok($mech->success, "second dependency test task submit successful");

$mech->content_unlike(qr/(?<!And then) dep test 1/, "first task is not on the page");
$mech->content_contains('dep test 2', "second task is on the page");

# test that we can make dependant tasks of one word

$mech->get($URL);
$mech->follow_link_ok(text => '01 some task');

$mech->fill_in_action_ok('depends_on-new_item_create', summary => 'report');
$mech->submit_html_ok();

$mech->content_lacks('No such task: report', 'Page contains the dependency');

my $newtask = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
$newtask->load_by_cols( summary => 'report' );

my $td = BTDT::Model::TaskDependency->new(current_user =>  BTDT::CurrentUser->superuser);
$td->load_by_cols(task_id => 1, depends_on => $newtask->id);
ok($td->id, "Created dependency relationship on new task");

$mech->follow_link(text => 'More...');
$mech->form_number(2);
ok($mech->click_button(value => 'Remove link to #3'));
$mech->content_contains('Deleted');

# Test the ability to add/remove dependencies between existing tasks

$mech->get($URL);
$mech->follow_link_ok(text => '01 some task');

$mech->fill_in_action_ok('depends_on-new_item_create', summary => '#4');
$mech->submit_html_ok();

$mech->content_contains('02 other task', 'Page contains the dependency');

$td = BTDT::Model::TaskDependency->new(current_user =>  BTDT::CurrentUser->superuser);
$td->load_by_cols(task_id => 1, depends_on => 2);
ok($td->id, "Created dependency relationship");

$mech->fill_in_action_ok('depends_on-new_item_create', summary => '#4');
$mech->submit_html_ok();
$mech->content_contains('already exists', "Can't create duplicate relationships");

$mech->follow_link(text => 'More...');
$mech->form_number(2);
ok($mech->click_button(value => 'Remove link to #3'));
$mech->content_contains('Deleted');
$mech->content_lacks('02 other task');

# Now do the same thing with ``and then''

$mech->fill_in_action_ok('depended_on_by-new_item_create', summary => 'task.hm/4');
$mech->submit_html_ok();

$mech->content_contains('02 other task', 'Page contains the dependency');

$td = BTDT::Model::TaskDependency->new(current_user =>  BTDT::CurrentUser->superuser);
$td->load_by_cols(task_id => 2, depends_on => 1);
ok($td->id, "Created dependency relationship");

$mech->fill_in_action_ok('depended_on_by-new_item_create', summary => 'task 4');
$mech->submit_html_ok();
$mech->content_contains('already exists', "Can't create duplicate relationships");

$mech->follow_link(text => 'More...');
$mech->form_number(2);
ok($mech->click_button(value => 'Remove link to #3'));
$mech->content_contains('Deleted');

$mech->content_lacks('02 other task');


# Try creating a relationship to a task that doesn't exist
$mech->fill_in_action_ok('depended_on_by-new_item_create', summary => '#NOT');
$mech->submit_html_ok();
$mech->content_contains('Your task has been created', "If the task doesn't exist, then we create a new one");

my $not = BTDT::Model::Task->new(current_user =>BTDT::CurrentUser->superuser);
$not->load_by_cols(summary => "#NOT");
ok($not->id, "created the task");

$td = BTDT::Model::TaskDependency->new(current_user =>  BTDT::CurrentUser->superuser);
$td->load_by_cols(task_id => $not->id, depends_on => 1);
ok($td->id, "Created dependency relationship with the #NOT task");


1;

