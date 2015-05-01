use warnings;
use strict;

# setup {{{
use BTDT::Test tests => 486;
use BTDT::Test::IM;
my $gooduser  = BTDT::CurrentUser->new( email => 'gooduser@example.com');
BTDT::Test->make_pro($gooduser);
my $otheruser = BTDT::CurrentUser->new( email => 'otheruser@example.com');
BTDT::Test->make_pro($otheruser);

setup_screenname($gooduser->id  => 'tester');

my $group = BTDT::Model::Group->new( current_user => $gooduser );
$group->load_by_cols( name => 'alpha');
$group->set_name('Best Practical');
$group->add_member( $otheruser->user_object, 'member' );

my $m1 = BTDT::Model::Task->new( current_user => $gooduser );
$m1->create( type => "milestone", group_id => $group->id, summary => "M1" );
is( $m1->record_locator, "5" );

my $m2 = BTDT::Model::Task->new( current_user => $gooduser );
$m2->create( type => "milestone", group_id => $group->id, summary => "M2" );
is( $m2->record_locator, "6" );

im_like( "todo", qr/<#3>/, "list tasks" );
im_like( "estimate #3 takes 70m", qr/Recorded estimate for task <#3>/);
time_is('#3',
    left => '1h10m',
    estimate => '1h10m',
    worked => undef,
);
im_like( "estimate #3 takes 1h", qr/Recorded estimate for task <#3>/);
time_is('#3',
    left => '1h',
    estimate => '1h',
    worked => undef,
);

im_like('spent 5m on #3', qr/Recorded time worked on task <#3>/);
time_is('#3',
    left => '55m',
    estimate => '1h',
    worked => '5m',
);
aggregate_is(
    [ owner => 'me' ],
    left => '55m',
    estimate => '1h',
    worked => '5m',
);

im_like('move #3 to Best Practical', qr/Moved task <#3> into group 'Best Practical'/);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '55m',
    estimate => '1h',
    worked => '0s',
);

im_like('milestone #3 is M1', qr/Moved task <#3> into milestone 'M1'/);
my $task = BTDT::Model::Task->new( current_user => $gooduser );
$task->load(1);
{ local $TODO = "Milestone doesn't actually change?"; is($task->milestone->id, 3); }
$task->set_milestone(3);

# Task's overall stats are unchanged
time_is('#3',
    left => '55m',
    estimate => '1h',
    worked => '5m',
);
aggregate_is(
    [ milestone => '#5'],
    left => '55m',
    estimate => '55m',
    worked => '0s',
);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '55m',
    estimate => '1h',
    worked => '0s',
);
aggregate_is(
    [ owner => 'me' ],
    left => '55m',
    estimate => '1h',
    worked => '5m',
);

# Set to 45 left
im_like( "estimate #3 takes 45m", qr/Recorded estimate for task <#3>/);

# Updated stats
time_is('#3',
    left => '45m',
    estimate => '1h',
    worked => '5m',
);
aggregate_is(
    [ milestone => '#5' ],
    left => '45m',
    estimate => '55m',
    worked => '0s',
);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '45m',
    estimate => '1h',
    worked => '0s',
);
aggregate_is(
    [ owner => 'me' ],
    left => '45m',
    estimate => '1h',
    worked => '5m',
);

# Spend half an hour on it
im_like('spent 30m on #3', qr/Recorded time worked on task <#3>/);

# Updated stats
time_is('#3',
    left => '15m',
    estimate => '1h',
    worked => '35m',
);
aggregate_is(
    [ milestone => '#5' ],
    left => '15m',
    estimate => '55m',
    worked => '30m',
);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '15m',
    estimate => '1h',
    worked => '30m',
);
aggregate_is(
    [ owner => 'me' ],
    left => '15m',
    estimate => '1h',
    worked => '35m',
);

# Set to 50 left
im_like( "estimate #3 takes 50m", qr/Recorded estimate for task <#3>/);

# Updated stats
time_is('#3',
    left => '50m',
    estimate => '1h',
    worked => '35m',
);
aggregate_is(
    [ milestone => '#5' ],
    left => '50m',
    estimate => '55m',
    worked => '30m',
);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '50m',
    estimate => '1h',
    worked => '30m',
);
aggregate_is(
    [ owner => 'me' ],
    left => '50m',
    estimate => '1h',
    worked => '35m',
);

# Change milestone
im_like('milestone #3 is M2', qr/Moved task <#3> into milestone 'M2'/);
$task->load(1);
{ local $TODO = "Milestone doesn't actually change?"; is($task->milestone->id, 4); }
$task->set_milestone(4);

# Task stats unchanged
time_is('#3',
    left => '50m',
    estimate => '1h',
    worked => '35m',
);
aggregate_is(
    [ milestone => '#5' ],
    left => '0s',
    estimate => '0s',
    worked => '30m',
);
aggregate_is(
    [ milestone => '#6' ],
    left => '50m',
    estimate => '50m',
    worked => '0s',
);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '50m',
    estimate => '1h',
    worked => '30m',
);
aggregate_is(
    [ owner => 'me' ],
    left => '50m',
    estimate => '1h',
    worked => '35m',
);

# Set to 41 left
im_like( "estimate #3 takes 41m", qr/Recorded estimate for task <#3>/);

# Updated stats
time_is('#3',
    left => '41m',
    estimate => '1h',
    worked => '35m',
);
aggregate_is(
    [ milestone => '#5' ],
    left => '0s',
    estimate => '0s',
    worked => '30m',
);
aggregate_is(
    [ milestone => '#6' ],
    left => '41m',
    estimate => '50m',
    worked => '0s',
);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '41m',
    estimate => '1h',
    worked => '30m',
);
aggregate_is(
    [ owner => 'me' ],
    left => '41m',
    estimate => '1h',
    worked => '35m',
);

# Work for 40
im_like('spent 40m on #3', qr/Recorded time worked on task <#3>/);

# Updated stats
time_is('#3',
    left => '1m',
    estimate => '1h',
    worked => '1h15m',
);
aggregate_is(
    [ milestone => '#5' ],
    left => '0s',
    estimate => '0s',
    worked => '30m',
);
aggregate_is(
    [ milestone => '#6' ],
    left => '1m',
    estimate => '50m',
    worked => '40m',
);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '1m',
    estimate => '1h',
    worked => '1h10m',
);
aggregate_is(
    [ owner => 'me' ],
    left => '1m',
    estimate => '1h',
    worked => '1h15m',
);

# Hide forever
im_like('hide #3 forever', qr/Hiding task <#3> forever/);
time_is('#3',
    left => '1m',
    estimate => '1h',
    worked => '1h15m',
);
aggregate_is(
    [ milestone => '#5' ],
    left => '0s',
    estimate => '0s',
    worked => '30m',
);
aggregate_is(
    [ milestone => '#6' ],
    left => '0s',
    estimate => '50m',
    worked => '40m',
);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '0s',
    estimate => '1h',
    worked => '1h10m',
);
aggregate_is(
    [ owner => 'me' ],
    left => '0s',
    estimate => '1h',
    worked => '1h15m',
);

# Mark as complete (this unhides it)
im_like('done #3', qr/Marking task <#3> as done/);
time_is('#3',
    left => '1m',
    estimate => '1h',
    worked => '1h15m',
);
aggregate_is(
    [ milestone => '#5' ],
    left => '0s',
    estimate => '0s',
    worked => '30m',
);
aggregate_is(
    [ milestone => '#6' ],
    left => '0s',
    estimate => '50m',
    worked => '40m',
);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '0s',
    estimate => '1h',
    worked => '1h10m',
);
aggregate_is(
    [ owner => 'me' ],
    left => '0s',
    estimate => '1h',
    worked => '1h15m',
);

# Adjust the time left on it
im_like( "estimate #3 takes 5m", qr/Recorded estimate for task <#3>/);

# Updated stats
time_is('#3',
    left => '5m',
    estimate => '1h',
    worked => '1h15m',
);
aggregate_is(
    [ milestone => '#5' ],
    left => '0s',
    estimate => '0s',
    worked => '30m',
);
aggregate_is(
    [ milestone => '#6' ],
    left => '0s',
    estimate => '50m',
    worked => '40m',
);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '0s',
    estimate => '1h',
    worked => '1h10m',
);
aggregate_is(
    [ owner => 'me' ],
    left => '0s',
    estimate => '1h',
    worked => '1h15m',
);

# No longer complete
im_like('undone #3', qr/Marking task <#3> as not done/);
# Unchanged stats
time_is('#3',
    left => '5m',
    estimate => '1h',
    worked => '1h15m',
);
aggregate_is(
    [ milestone => '#5' ],
    left => '0s',
    estimate => '0s',
    worked => '30m',
);
aggregate_is(
    [ milestone => '#6' ],
    left => '5m',
    estimate => '50m',
    worked => '40m',
);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '5m',
    estimate => '1h',
    worked => '1h10m',
);
aggregate_is(
    [ owner => 'me' ],
    left => '5m',
    estimate => '1h',
    worked => '1h15m',
);


# Set to 30 left
im_like( "estimate #3 takes 30m", qr/Recorded estimate for task <#3>/);

# Updated stats
time_is('#3',
    left => '30m',
    estimate => '1h',
    worked => '1h15m',
);
aggregate_is(
    [ milestone => '#5' ],
    left => '0s',
    estimate => '0s',
    worked => '30m',
);
aggregate_is(
    [ milestone => '#6' ],
    left => '30m',
    estimate => '50m',
    worked => '40m',
);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '30m',
    estimate => '1h',
    worked => '1h10m',
);
aggregate_is(
    [ owner => 'me' ],
    left => '30m',
    estimate => '1h',
    worked => '1h15m',
);

# Move back to M1
im_like('milestone #3 is M1', qr/Moved task <#3> into milestone 'M1'/);
$task->load(1);
{ local $TODO = "Milestone doesn't actually change?"; is($task->milestone->id, 3); }
$task->set_milestone(3);

# Updated stats
time_is('#3',
    left => '30m',
    estimate => '1h',
    worked => '1h15m',
);
aggregate_is(
    [ milestone => '#5' ],
    left => '30m',
    estimate => '55m',
    worked => '30m',
);
aggregate_is(
    [ milestone => '#6' ],
    left => '0s',
    estimate => '0s',
    worked => '40m',
);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '30m',
    estimate => '1h',
    worked => '1h10m',
);
aggregate_is(
    [ owner => 'me' ],
    left => '30m',
    estimate => '1h',
    worked => '1h15m',
);

# Work some more
im_like('spent 20m on #3', qr/Recorded time worked on task <#3>/);

# Updated stats
time_is('#3',
    left => '10m',
    estimate => '1h',
    worked => '1h35m',
);
aggregate_is(
    [ milestone => '#5' ],
    left => '10m',
    estimate => '55m',
    worked => '50m',
);
aggregate_is(
    [ milestone => '#6' ],
    left => '0s',
    estimate => '0s',
    worked => '40m',
);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '10m',
    estimate => '1h',
    worked => '1h30m',
);
aggregate_is(
    [ owner => 'me' ],
    left => '10m',
    estimate => '1h',
    worked => '1h35m',
);

# All of the above, the actor has been the same as the owner.  We now
# want to check that time_worked is aggregated over all tasks where
# the _actor_ was me, but not time_left and time_estimate are
# aggregated over all tasks where the _owner_ is me.

# Give the task to someone else
im_like('give #3 to otheruser@example.com', qr/Gave task <#3> to otheruser\@example\.com/);
time_is('#3',
    left => '10m',
    estimate => '1h',
    worked => '1h35m',
);
aggregate_is(
    [ milestone => '#5' ],
    left => '10m',
    estimate => '55m',
    worked => '50m',
);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '10m',
    estimate => '1h',
    worked => '1h30m',
);
aggregate_is(
    [ owner => 'me' ],
    left => '0s',
    estimate => '0s',
    worked => '1h35m',
);
aggregate_is(
    [ owner => 'otheruser@example.com' ],
    left => '10m',
    estimate => '1h',
    worked => '0s',
);

# If I change the time left on the task they now own, their totals
# change, not mine.
im_like('estimate #3 is 20m',qr/Recorded estimate for task <#3>/);
time_is('#3',
    left => '20m',
    estimate => '1h',
    worked => '1h35m',
);
aggregate_is(
    [ milestone => '#5' ],
    left => '20m',
    estimate => '55m',
    worked => '50m',
);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '20m',
    estimate => '1h',
    worked => '1h30m',
);
aggregate_is(
    [ owner => 'me' ],
    left => '0s',
    estimate => '0s',
    worked => '1h35m',
);
aggregate_is(
    [ owner => 'otheruser@example.com' ],
    left => '20m',
    estimate => '1h',
    worked => '0s',
);


# If I work on the task they own, my time_worked goes up, not theirs
im_like('spent 15m on #3', qr/Recorded time worked on task <#3>/);
time_is('#3',
    left => '5m',
    estimate => '1h',
    worked => '1h50m',
);
aggregate_is(
    [ milestone => '#5' ],
    left => '5m',
    estimate => '55m',
    worked => '1h5m',
);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '5m',
    estimate => '1h',
    worked => '1h45m',
);
aggregate_is(
    [ owner => 'me' ],
    left => '0s',
    estimate => '0s',
    worked => '1h50m',
);
aggregate_is(
    [ owner => 'otheruser@example.com' ],
    left => '5m',
    estimate => '1h',
    worked => '0s',
);

# If I create a task which starts with a group, milestone, owner, and
# time left and worked, it gets recorded correctly.
$task = BTDT::Model::Task->new( current_user => $gooduser );
$task->create(
    summary => "New task",
    time_left => "2h",
    time_worked => "1h",
    group_id => $group->id,
    owner_id => $gooduser->id,
    milestone => $m1->id,
);
ok($task->id, "Created successfully");
time_is("#7",
    left => '2h',
    estimate => '2h',
    worked => '1h',
);
aggregate_is(
    [ milestone => '#5' ],
    left => '2h5m',
    estimate => '2h55m',
    worked => '2h5m',
);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '2h5m',
    estimate => '3h',
    worked => '2h45m',
);
aggregate_is(
    [ owner => 'me' ],
    left => '2h',
    estimate => '2h',
    worked => '2h50m',
);

# Work it a tiny bit
sleep 2; im_like('spent 30m on #7', qr/Recorded time worked on task <#7>/);
time_is("#7",
    left => '1h30m',
    estimate => '2h',
    worked => '1h30m',
);
aggregate_is(
    [ milestone => '#5' ],
    left => '1h35m',
    estimate => '2h55m',
    worked => '2h35m',
);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '1h35m',
    estimate => '3h',
    worked => '3h15m',
);
aggregate_is(
    [ owner => 'me' ],
    left => '1h30m',
    estimate => '2h',
    worked => '3h20m',
);


# Moving it to another milestone gets it updated correctly
sleep 2; im_like('milestone #7 is M2', qr/Moved task <#7> into milestone 'M2'/);
{ local $TODO = "Milestone doesn't actually change?"; is($task->milestone->id, 4); }
$task->set_milestone(4);
time_is("#7",
    left => '1h30m',
    estimate => '2h',
    worked => '1h30m',
);
aggregate_is(
    [ milestone => '#5' ],
    left => '5m',
    estimate => '55m',
    worked => '2h35m',
);
aggregate_is(
    [ milestone => '#6' ],
    left => '1h30m',
    estimate => '1h30m',
    worked => '40m',
);
aggregate_is(
    [ group => 'Best Practical' ],
    left => '1h35m',
    estimate => '3h',
    worked => '3h15m',
);
aggregate_is(
    [ owner => 'me' ],
    left => '1h30m',
    estimate => '2h',
    worked => '3h20m',
);


# If we work a task before giving it a time left, we still get an
# estimate.
$task = BTDT::Model::Task->new( current_user => $gooduser );
$task->create(
    summary => "Newest task",
    group_id => $group->id,
    owner_id => $gooduser->id,
);
ok($task->id, "Created successfully");
time_is("#8",
    left => undef,
    estimate => undef,
    worked => undef,
);

im_like('spent 30m on #8', qr/Recorded time worked on task <#8>/);
time_is("#8",
    left => undef,
    estimate => undef,
    worked => "30m",
);


im_like('estimate #8 takes 1h', qr/Recorded estimate for task <#8>/);
time_is("#8",
    left => "1h",
    estimate => "1h30m",
    worked => "30m",
);

im_like('estimate #8 takes 2h', qr/Recorded estimate for task <#8>/);
time_is("#8",
    left => "2h",
    estimate => "1h30m",
    worked => "30m",
);


sub _method_is {
    my $method   = shift;
    my $locator  = shift;
    my $expected = shift;
    my $name     = shift || "Right time for $method";

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');

    my $task = BTDT::Model::Task->new( current_user => $gooduser );
    $task->load_by_locator($locator);
    ok $task->id, "Got task";
    is $task->$method, $expected, $name;
}

sub worked_is {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    _method_is('time_worked', @_);
}

sub left_is {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    _method_is('time_left', @_);
}

sub aggregate_is {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my ($tokens, %args) = @_;

    my $tasks = BTDT::Model::TaskCollection->new( current_user => $gooduser );
    $tasks->from_tokens( @$tokens );
    my $data = $tasks->aggregate_time_tracked;
    $data->{$_} = BTDT::Model::Task->concise_duration($data->{$_}) for keys %{$data};
    is($data->{'Total worked'}, $args{worked}, "worked is right on @{$tokens}") if exists $args{worked};
    is($data->{'Estimate'}, $args{estimate}, "estimate is right on @{$tokens}") if exists $args{estimate};
    is($data->{'Time left'}, $args{left}, "left is right on @{$tokens}") if exists $args{left};
}

sub time_is {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $locator = shift;
    my %args = (
        worked   => undef,
        left     => undef,
        @_,
    );

    for my $method (keys %args) {
        _method_is("time_$method", $locator, $args{$method});
    }
}
