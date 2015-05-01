use warnings;
use strict;

=head1 DESCRIPTION

Tests the textfile round-trip functionality

=cut

use BTDT::Test tests => 59;

my $gooduser = BTDT::CurrentUser->new( email => 'gooduser@example.com' );
my $collection = BTDT::Model::TaskCollection->new(current_user => $gooduser);
$collection->unlimit;
is($collection->count, 2, "We have two tasks");

my $sync = BTDT::Sync::TextFile->new;
$sync->current_user($gooduser);

# non pro {{{
$collection->unlimit;
$collection->from_tokens(qw/tag timetrackingtest/);
is($collection->count, 0, "Has no tasks");
my $text = $sync->as_text($collection);
like($text, qr|(.+)---(.+)---(.+)|s, "Has three parts");
my ($preamble, $tasks, $postamble ) = split '---', $text;

$tasks = <<EO_TASKS;

Some task [time: 2h]

Some other task [with tags]

Another task [time: 1h] [worked: 30m]

EO_TASKS
sync_ok((join "---", $preamble, $tasks, $postamble), created => 3);
$collection->redo_search;
is($collection->count, 3, "Has three tasks");

my $task = $collection->next;
is($task->summary, "Some task", "Has right summary");
is($task->time_estimate, undef, "Has correct time estimate - NONE");
is($task->time_left, undef, "Has correct time left - NONE");
is($task->time_worked, undef, "Has correct time worked - NONE");

$task = $collection->next;
is($task->summary, "Some other task", "Has right summary");
is($task->tags, "tags timetrackingtest with", "Has correct tags");

$task = $collection->next;
is($task->summary, "Another task", "Has right summary");
is($task->time_estimate, undef, "Has correct time estimate - NONE");
is($task->time_left, undef, "Has correct time left - NONE");
is($task->time_worked, undef, "Has correct time worked - NONE");
# }}}

# PRO {{{
my $user = BTDT::Model::User->new( current_user => BTDT::CurrentUser->superuser );
$user->load_by_cols( email => 'gooduser@example.com' );
ok( $user->id, "Got a user" );
$user->set_pro_account('t');
ok( $user->pro_account, "Has pro account" );

$collection->unlimit;
$collection->from_tokens(qw/tag timetracking/);
is($collection->count, 0, "Has no tasks");
$text = $sync->as_text($collection);
like($text, qr|(.+)---(.+)---(.+)|s, "Has three parts");
($preamble, $tasks, $postamble ) = split '---', $text;

$tasks = <<EO_TASKS;

Some task [time: 2h]

Some other task [time: 1h] [with tags]

Another task [time: 1h] [worked: 30m]

EO_TASKS
sync_ok((join "---", $preamble, $tasks, $postamble), created => 3);
$collection->redo_search;
is($collection->count, 3, "Has three tasks");

$task = $collection->next;
is($task->summary, "Some task", "Has right summary");
is($task->time_estimate, "2h", "Has correct time estimate");
is($task->time_left, "2h", "Has correct time left");
is($task->time_worked, undef, "Has correct time worked");

$task = $collection->next;
is($task->summary, "Some other task", "Has right summary");
is($task->tags, "tags timetracking with", "Has correct tags");
is($task->time_estimate, "1h", "Has correct time estimate");
is($task->time_left, "1h", "Has correct time left");
is($task->time_worked, undef, "Has correct time worked");

$task = $collection->next;
is($task->summary, "Another task", "Has right summary");
is($task->time_estimate, "1h", "Has correct time estimate");
is($task->time_left, "1h", "Has correct time left");
is($task->time_worked, "30m", "Has correct time worked");

# make some updates to this and try it again
$collection->redo_search;
$text = $sync->as_text($collection);
$text =~ s/Some task/Some task [worked: 30m]/;
$text =~ s/Some other task/Some other task [worked: 1h]/;
$text =~ s/Another task/Another task [worked: 30m] [time: 20m]/;

# upload
sync_ok($text, updated => 3);
$collection->redo_search;

$task = $collection->next;
is($task->summary, "Some task", "Has right summary");
is($task->time_estimate, "2h", "Has correct time estimate");
is($task->time_left, "1h30m", "Has correct time left");
is($task->time_worked, "30m", "Has correct time worked");

$task = $collection->next;
is($task->summary, "Some other task", "Has right summary");
is($task->time_estimate, "1h", "Has correct time estimate");
is($task->time_left, "0s", "Has correct time left");
is($task->time_worked, "1h", "Has correct time worked");

$task = $collection->next;
is($task->summary, "Another task", "Has right summary");
is($task->time_estimate, "1h", "Has correct time estimate");
is($task->time_left, "20m", "Has correct time left");
is($task->time_worked, "1h", "Has correct time worked");

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
