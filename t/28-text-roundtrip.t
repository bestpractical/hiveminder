use warnings;
use strict;

=head1 DESCRIPTION

Tests the textfile round-trip functionality

=cut

use BTDT::Test tests => 104;

my $collection = BTDT::Model::TaskCollection->new(current_user => BTDT::CurrentUser->superuser);
$collection->unlimit;
is($collection->count, 2, "We have two tasks");


my $sync = BTDT::Sync::TextFile->new;
$sync->current_user(BTDT::CurrentUser->superuser);
my $text = $sync->as_text($collection);

# round-trip basic tasks {{{
like($text, qr|(.+)---(.+)---(.+)|s, "Has three parts");
my ( $preamble, $tasks, $postamble ) = split '---', $text;
like($preamble, qr|http://([\w\.]+)(:\d+)?/upload|, "Contains URL in first part");

like($postamble, qr|(.*?)\n\n(.*)$|s, "Postamble contains metadata");

my $meta;
if ($postamble =~ m|(.*?)\n\n(.*)| ) {
    $meta = $2;
}

my %metadata = (%{Jifty::YAML::Load(Compress::Zlib::uncompress MIME::Base64::decode_base64($meta) )});

is($metadata{'format_version'}, '0.02', "Metadata has an appropriate format version");

like($tasks, qr|01 some task|, "Contains first task");
like($tasks, qr|02 other task|, "Contains second task");

my @tasks = $sync->parse_tasks(data => $tasks, format_version=>'0.02');
is(scalar @tasks, 2, "Got two tasks out");

is_deeply(\@tasks,
          [
           {id => 1, summary => "01 some task", tags => "", description => "", __dependency_id => 1},
           {id => 2, summary => "02 other task", tags => "", description => "with a description", __dependency_id => 2},
          ],
         "Extracted two tasks correctly");
sync_ok($text, update_failed => 2);
$collection->redo_search;

is($collection->count, 2, "We still have two tasks");
while (my $task = $collection->next) {
    is($task->transactions->count, 1, "No new transactions on task ".$task->record_locator);
}
# }}}
# move the first task to last, to test re-ordering a list during edit {{{
$tasks =~ s|([^\n]+)\n(.*)|$2$1\n|s;
# }}}
# Change some stuff {{{
$tasks = <<EO_TASKS;

--renamed task [new tags] [group: alpha] (4)
    Some description goes here that will actually
    have multiple lines!  Quake in fear!

Another task goes here [tags rock] [due 2006-12-25]
    +new description

EO_TASKS

sync_ok((join "---", $preamble, $tasks, $postamble), created => 1, updated => 1, completed => 1);
$collection->redo_search;

is($collection->count_all, 3, "We have one new task");
$collection->order_by( { column => 'id',       order => 'ASC'} );
my $task = $collection->next;
is($task->id, 1, "Task 1 exists");
ok($task->complete, "..and is now complete");

$task = $collection->next;
is($task->id, 2, "Task 2 exists");
is($task->summary, "renamed task", "..and has been renamed properly");
is($task->tags, "new tags", "..and has new tags");
is($task->description, "Some description goes here that will actually\nhave multiple lines!  Quake in fear!","..and has new description");
is($task->priority, 1, "..and got the right priority");
is($task->group->name, 'alpha', "..and got the right group");

$task = $collection->next;
is($task->id, 3, "Task 3 exists");
is($task->summary, "Another task goes here", "..and has correct summary");
is($task->tags, "rock tags", "..and has correct tags");
is($task->description, "+new description", "..and got the right description");
is($task->priority, 3, "..and got the right priority");
is($task->due->ymd, "2006-12-25", "..and has correct due date");
# }}}
# Test that we receive/update task attributes in text form {{{
$collection->redo_search;
$text = $sync->as_text($collection);
like($text, qr/\[due: 2006-12-25\]/, "due date appeared");
like($text, qr/\[priority: lowest\]/, "priority lowest appeared");
unlike($text, qr/\[priority: normal\]/, "priority normal DIDN'T appear");

# make some edits
$text =~ s/\[due: 2006-12-25\]//;
$text =~ s/\[group: alpha\]/[group: personal]/;
$text =~ s/\[priority: lowest\]/[priority: high] [due: 2007-12-25] [hide: 2007-12-24]/;
$text =~ s/\[rock tags\]/[rock "no tags for you"]/;

# upload
sync_ok($text, updated => 2, update_failed => 1);
$collection->redo_search;

$task = $collection->next;
is($task->id, 1, "Task 1 exists");
ok($task->complete, "..and is now complete");

$task = $collection->next;
is($task->id, 2, "Task 2 exists");
is($task->summary, "renamed task", "..and has been renamed properly");
is($task->tags, "new tags", "..and has new tags");
is($task->description, "Some description goes here that will actually\nhave multiple lines!  Quake in fear!","..and has new description");
is($task->priority, 4, "..and got the right priority");
is($task->due->ymd, "2007-12-25", "..and NOW due christmas 07");
is($task->starts->ymd, "2007-12-24", "..and NOW starts christmas eve 07 (late! ;)");
ok(!$task->group->id, "..and NOW in personal tasks");

$task = $collection->next;
is($task->id, 3, "Task 3 exists");
is($task->summary, "Another task goes here", "..and has correct summary");
is($task->tags, '"no tags for you" rock', "..and has no tags");
is($task->description, "+new description", "..and got the right description");
is($task->priority, 3, "..and got the right priority");
is($task->due, undef, "..and now has NO due date");
# }}}
# Test defaults {{{
$collection->from_tokens(qw/tag something/);
is($collection->count, 0, "Has no tasks");
$text = $sync->as_text($collection);
like($text, qr|(.+)---(.+)---(.+)|s, "Has three parts");
($preamble, $tasks, $postamble ) = split '---', $text;

$tasks = <<EO_TASKS;

Some task

Some other task [with tags]

EO_TASKS
sync_ok((join "---", $preamble, $tasks, $postamble), created => 2);
$collection->redo_search;
is($collection->count, 2, "Has two tasks");

$task = $collection->next;
is($task->id, 4, "Task 4 exists");
is($task->summary, "Some task", "Has right summary");
is($task->tags, "something", "Has correct tags");

$task = $collection->next;
is($task->id, 5, "Task 5 exists");
is($task->summary, "Some other task", "Has right summary");
is($task->tags, "something tags with", "Has correct tags");

# }}}
# format version 0.01 {{{
$text = << 'TEXT';
Your todo list appears below.  If you want to make changes to any of
your existing tasks, just edit them below.  To add new tasks, just add
new lines; to mark tasks as done, just delete them.  Everything else
(priority, tags, and so on) works the same way it does in Braindump. 
When you're finished editing the file, point your web browser at
http://localhost:11523/upload to synchronize any changes you've
made with Hiveminder.

---
01 some CHANGED task (3)
renamed task [new tags] (4)
    Two lines is too many, let's cut back to one
new task!
Another task goes here [mega rock tags] (5)
    +new description
Some task [due 2007-01-01] (6)
---
The code below this line lets Hiveminder know which tasks are on this list.
Be careful not to mess with it, or you might confuse the poor computer.

eJzT1dXlSssvyk0siS9LLSrOzM+zUjDQMzDkykwptuJSUNBVMASTRmDSGEyagElTLgDkJg0Z
TEXT

sync_ok($text, created => 1, updated => 4, completed => 1);
$collection->unlimit;

is($collection->count_all, 6, "We have one new task");
$collection->order_by( { column => 'id',       order => 'ASC'} );

$task = $collection->next;
is($task->id, 1, "Task 1 exists");
is($task->summary, "01 some CHANGED task", "Task 1's summary was successfully changed");
ok($task->complete, "task 1 is complete");

$task = $collection->next;
is($task->id, 2, "Task 2 exists");
is($task->summary, "renamed task", "correct summary");
is($task->tags, "new tags", "correct tags");
is($task->description, "Two lines is too many, let's cut back to one", "correct description");
is($task->priority, 4, "priority NOT CHANGED");
is($task->due->ymd, "2007-12-25", "due NOT CHANGED");

$task = $collection->next;
is($task->id, 3, "Task 3 exists");
is($task->summary, "Another task goes here", "correct summary");
is($task->tags, "mega rock tags", "correct tags");
is($task->description, "+new description", "correct description");
ok(!$task->due, "due NOT CHANGED");

$task = $collection->next;
is($task->id, 4, "Task 4 exists");
is($task->summary, "Some task", "correct summary");
is($task->due->ymd, "2007-01-01", "correct due date");

$task = $collection->next;
is($task->id, 5, "Task 5 exists");
is($task->summary, "Some other task", "correct summary");
ok($task->complete, "is complete");

$task = $collection->next;
is($task->id, 6, "Task 6 exists");
is($task->summary, "new task!", "correct summary");
is($task->priority, 4, "correct priority");
# }}}
sub sync_ok { # {{{
    my $text = shift;
    my %args = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $ret = $sync->from_text($text);

    for (qw/created create_failed updated update_failed completed/) {
        $args{$_} ||= 0;
        is($args{$_}, @{ $ret->{$_} }, "$_ $args{$_} tasks");
    }
} # }}}

1;

