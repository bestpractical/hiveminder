use warnings;
use strict;
use BTDT::Test tests => 79;

# note: tasks in this must be uniquely named because we load by summary

# note: this test is chock-full of whitespace
my $results = check_braindump(
    created_summaries => ['eat dinner', 'pay taxes'],
    new_dependencies => 0,
    text => "

eat dinner [due tonight] [food]     
   
    I'm feeling like barbecue     
          
        probably steak      

pay taxes [due 4/15] [money]      
     
");

is($results->{created}[0]->description."\n", << "DESC", "correct description");
I'm feeling like barbecue
probably steak
DESC

check_braindump(
    created_summaries => ['go out', 'have fun'],
    new_dependencies => 1,
    dependencies => [
        "go out" => "have fun",
    ],
    text => "
go out
    then: have fun
");

check_braindump(
    created_summaries => ['eat', 'drink', 'be merry'],
    new_dependencies => 2,
    dependencies => [
        "eat"   => "drink",
        "drink" => "be merry",
    ],
    text => "
eat
 then: drink
  and then be merry
");

$results = check_braindump(
    created_summaries => ['get bacon', 'press button', 'eat bacon'],
    new_dependencies => 2,
    dependencies => [
        "press button" => "get bacon",
        "get bacon" => "eat bacon",
    ],
    text => "
get bacon
                            but first: press button
            it's red!
    and then: eat bacon
        delicious
");

is($results->{created}[0]->description, "it's red!");
is($results->{created}[2]->description, "delicious");

check_braindump(
    created_summaries => ['foo', 'bar', 'baz', 'quux'],
    new_dependencies => 3,
    dependencies => [
        "foo" => "bar",
        "foo" => "baz",
        "foo" => "quux",
    ],
    text => "
foo
   then: bar
  then: baz
 then: quux
");

$results = check_braindump(
    created_summaries => ['summary', 'follow-up'],
    new_dependencies => 1,
    dependencies => [
        "summary" => "follow-up",
    ],
    text => "
summary
    then: follow-up
    description on original task
");

like($results->{created}[0]->description, qr/description on original/);

$results = check_braindump(
    created_summaries => ['other summary', 'other follow-up'],
    new_dependencies => 1,
    dependencies => [
        "summary" => "follow-up",
    ],
    text => "
other summary
    then: other follow-up
     description on follow-up task
");

like($results->{created}[1]->description, qr/description on follow-up/);

check_braindump(
    created_summaries => ['clean room', 'dust fan', 'vacuum floor', 'make bed'],
    new_dependencies => 3,
    dependencies => [
        "dust fan" => "clean room",
        "vacuum floor" => "clean room",
        "make bed" => "clean room",
    ],
    text => "
clean room
    first: dust fan
    butfirst: vacuum floor
    But-First: make bed
");

$results = check_braindump(
    created_summaries => ["learn how to program", "write program 1", "write program 2"],
    new_dependencies => 2,
    dependencies => [
        "write program 1" => "learn how to program",
        "write program 2" => "learn how to program",
    ],
    text => "
learn how to program
 in any language!
 first: write program 1
 at any time!
 first: write program 2
 for only 10 bucks!
");

is($results->{created}[0]->description, "in any language!\nat any time!\nfor only 10 bucks!");

$results = check_braindump(
    created_summaries => ["using existant tasks"],
    new_dependencies => 2,
    dependencies => [
        "01 some task" => "using existant tasks",
        "using existant tasks" => "eat dinner",
    ],
    text => "
using existant tasks
    but_first: #3
    then: #5
");

my $dep_count;
sub check_braindump {
    my %args = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    Jifty->web->current_user(BTDT::CurrentUser->new(email => 'gooduser@example.com'));
    Jifty->web->response(Jifty::Response->new);
    Jifty->web->request(Jifty::Request->new);

    my $braindump = BTDT::Action::ParseTasksMagically->new(
        arguments => {
            text => delete $args{text},
        }
    );

    ok $braindump->validate;
    $braindump->run;
    my $result = $braindump->result;
    ok $result->success;

    my $deps = BTDT::Model::TaskDependencyCollection->new;
    $deps->unlimit;
    my $new = $deps->count - ($dep_count || 0);

    if (defined $args{new_dependencies}) {
        is($new, delete $args{new_dependencies}, "new dependency count");
    }
    $dep_count = $deps->count;

    for (keys %args) {
        my $function = main->can("check_$_")
            or Carp::croak "I don't know how to handle '$_'";

        local $Test::Builder::Level = $Test::Builder::Level + 1;
        $function->(delete $args{$_}, $result);
    }

    return $result->content;
}

sub check_dependencies {
    my @deps = @{ shift @_ };

    SET: while (my ($indep_summary, $dep_summary) = splice @deps, 0, 2) {
        my ($dep_task, $indep_task) = map {
            my $task = BTDT::Model::Task->new;
            $task->load_by_cols(summary => $_);
            $task->id or do {
                fail "Unable to load task '$dep_summary'";
                next SET;
            };
            $task
        } ($dep_summary, $indep_summary);

        my $dep = BTDT::Model::TaskDependency->new;
        $dep->load_by_cols(
            task_id    => $dep_task->id,
            depends_on => $indep_task->id,
        );

        ok($dep->id, "'$dep_summary' depends on '$indep_summary'");
    }
}

sub check_created_summaries {
    my @summaries = @{ shift @_ };
    my $result    = shift;
    my @created =  @{ $result->content->{created} };

    for (0 .. $#summaries) {
        is(
            eval { $created[$_]->summary } || undef,
            $summaries[$_],
            "Correct task summary for #$_"
        );
    }
    for (@summaries .. $#created) {
        fail("Created an additional task, " . $created[$_]->summary);
    }
}
