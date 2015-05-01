use warnings;
use strict;

use BTDT::Test tests => 36;

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech($URL);
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->html_ok;
$mech->content_like(qr/Logout/i, "logged in");


#Create three tasks:

use_ok('BTDT::Model::Task');
use_ok('BTDT::Model::TaskCollection');
#"first task" due 1/1/80 tagged "a"
my $t1 = BTDT::Model::Task->new(current_user =>BTDT::CurrentUser->superuser);
$t1->create(summary => 'first task', tags => 'a', due => '1980-01-01', owner_email => 'gooduser@example.com');
ok($t1->id, "Created the first task ". $t1->id);
is($t1->due->ymd, '1980-01-01');
is($t1->tags,'a');

#"second task" due 1/1/81 tagged "c"
my $t2 = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
$t2->create(summary => 'second task', tags => 'c', due => '1981-01-01', owner_email => 'gooduser@example.com');
ok($t2->id, "Created the second task ". $t2->id);
is($t2->tags, 'c');

#"third task" due 1/1/79 tagged "b"

my $t3 = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
$t3->create(summary => 'third task', tags => 'b', due => '1979-01-01', owner_email => 'gooduser@example.com');
ok($t3->id, "Created the third task ". $t3->id);
is($t3->tags(), 'b');


# do a programmatic search by tokens for:


my $tasks = BTDT::Model::TaskCollection->new(current_user => BTDT::CurrentUser->superuser);

# sort_by 'magic' / sort_by_tags 'a b c'
$tasks->from_tokens('due', 'before', '1983-01-01', 'not', 'complete', 'sort_by', '', 'sort_by_tags', 'a b c');
is($tasks->count, 3);
is ($tasks->next->id, $t1->id);
is ($tasks->next->id, $t3->id);
is ($tasks->next->id, $t2->id);

# sort_by_tags 'a b c'
$tasks = BTDT::Model::TaskCollection->new(current_user => BTDT::CurrentUser->superuser);
$tasks->from_tokens('due', 'before', '1983-01-01', 'not', 'complete', 'sort_by_tags', 'a b c');
is($tasks->count, 3);
is ($tasks->next->id, $t1->id);
is ($tasks->next->id, $t3->id);
is ($tasks->next->id, $t2->id);


# sort_by 'magic' / sort_by_tags 'a c b'
$tasks = BTDT::Model::TaskCollection->new(current_user => BTDT::CurrentUser->superuser);
$tasks->from_tokens('due', 'before', '1983-01-01', 'not', 'complete', 'sort_by_tags', 'a c b');
is($tasks->count, 3);
is ($tasks->next->id, $t1->id);
is ($tasks->next->id, $t2->id);
is ($tasks->next->id, $t3->id);


# sort_by 'due'

# sort_by summary'
#
#
#hit the homepage. redo search to sort by tags "a b c" and sort by "magic"

$mech->get('/search/owner/me/not/complete');
$mech->follow_link(text =>'Search');
ok(!$mech->action_field_value('search', 'sort_by_tags'), "Not sorting by tags yet");
ok(!$mech->action_field_value('search', 'sort_by'),  "magic sorting");

$mech->fill_in_action_ok('search', sort_by_tags => 'a b c');
$mech->submit_html_ok();
$mech->follow_link(text =>'Search');
is($mech->action_field_value('search', 'sort_by_tags'),'a b c', "Not sorting by tags yet");

ok ($mech->content =~ /first.*third.*second/msi, "Our sort by tags worked!");
is ($mech->action_field_value('search', 'sort_by_tags'), 'a b c', "Not sorting by tags yet");

$mech->fill_in_action_ok('search', sort_by_tags => 
                         $mech->action_field_value('search', 'sort_by_tags'));
$mech->submit_html_ok();
ok ($mech->content =~ /first.*third.*second/msi, "Our sort by tags roundtripped !");
#hit the homepage. redo search to sort by tags "c a b" and sort by "magic"
#
#hit the search page,
#
#    find all tasks that aren't done
#
#    check that they're ordered by due date
#
#    fill in sort_by_tags to "a b c"
#
#    submit
#
#    check that they're ordered by tag
