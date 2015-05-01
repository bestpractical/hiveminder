use warnings;
use strict;

use Test::MockTime 'set_fixed_time';
use BTDT::Test tests => 368;
use BTDT::Test::IM;

Jifty->config->app('FeatureFlags')->{TimeTracking} = 1;

my $user = BTDT::CurrentUser->new( email => 'gooduser@example.com' );

setup_screenname('gooduser@example.com' => 'tester');

# time tracking is hidden. can't mark these tests as todo because there are
# a few tests in each command_help_includes, and most of them pass
#command_help_includes("estimate");
#command_help_includes("worked");

# pro only checks {{{
im_like( "todo", qr/<#3>/, "list tasks" );
im_like( "worked #3 for 3h", qr/This feature is for pro users only/, "pro block - work on task" );
im_like( "estimate #3 takes 5h", qr/This feature is for pro users only/, "pro block - estimate task" );
im_like( "estimate #3 takes foo", qr/This feature is for pro users only/, "pro block - bad duration" );
im_like( "worked #3 for bar", qr/This feature is for pro users only/, "pro block - bad duration" );

worked_is('#3' => undef, "time tracking is for pro only");
im_like( "worked #3 for 30m", qr/This feature is for pro users only/ );
worked_is('#3' => undef, "time tracking is for pro only");

im_like('start #3', qr/This feature is for pro users only/, "pro block - start");
im_like('stop', qr/This feature is for pro users only/, "pro block - stop");
im_like('pause', qr/This feature is for pro users only/, "pro block - pause");
im_like('unpause', qr/This feature is for pro users only/, "pro block - unpause");
# }}}

$user->user_object->__set( column => 'pro_account', value => 't' );
ok $user->pro_account, "Got pro";

im_like( "todo", qr/<#3>/, "list tasks" );

im_like( "worked #3 for 3h", qr/Recorded time worked on task <#3>/, "work on task" );
im_like( "todo #3", qr/\[time: 3h\]/ );

im_like( "estimate #3 takes 5h", qr/Recorded estimate for task <#3>/, "estimate task" );
im_like( "todo #3", qr{\[time: 3h / 5h\]} );

im_like( "estimate #3 takes foo", qr/I don't understand the duration 'foo'/, "bad duration" );
im_like( "todo #3", qr{\[time: 3h / 5h\]} );

im_like( "worked #3 for bar", qr/I don't understand the duration 'bar'/, "bad duration" );
im_like( "todo #3", qr{\[time: 3h / 5h\]} );

im_like('spent baz on #3', qr/I don't understand the duration 'baz'/, "bad duration" );
im_like( "todo #3", qr{\[time: 3h / 5h\]} );
worked_is('#3' => '3h');

im_like( "worked #3 for 30m", qr/Recorded time worked on task <#3>/ );
worked_is('#3' => '3h30m');

im_like( "todo #3", qr{\[time: 3h30m / 4h30m\]} );
left_is('#3' => '4h30m');

im_like('spent 1h on #3', qr/Recorded time worked on task <#3>/);
worked_is('#3' => '4h30m');
im_like( "todo #3", qr{\[time: 4h30m / 3h30m\]} );

im_like('worked 1 min: #3', qr/Recorded time worked on task <#3>/);
im_like( "todo #3", qr{\[time: 4h31m / 3h29m\]} );

im_like('estimate 1 minute: #3', qr/Recorded estimate for task <#3>/);
time_is('#3',
    left => '1m',
    worked => '4h31m',
);
im_like( "todo #3", qr{\[time: 4h31m / 1m\]} );

im_like('c banana [worked 3m] [estimate 5m]', qr/Created 1 task/);
time_is('#5' =>
    left     => '5m',
    worked   => '3m',
);
im_like( "todo #5", qr{\[time: 3m / 5m\]} );

my ($loc) = create_tasks('foo');
time_is($loc);

($loc) = create_tasks('foo [worked 3m]');
time_is($loc,
    worked => '3m',
);
im_like( "todo $loc", qr{\[time: 3m\]} );

($loc) = create_tasks('foo [estimate 3m]');
time_is($loc,
    left => '3m',
);
im_like( "todo $loc", qr{\[time: 0h / 3m\]} );

for my $input ('0m', '0') {
    ($loc) = create_tasks("foo [worked $input]");
    time_is($loc,
        worked => '0s',
    );
    im_like( "todo $loc", qr{\[time: 0s\]} );

    ($loc) = create_tasks("foo [estimate $input]");
    time_is($loc,
        left => '0s',
    );
    im_like( "todo $loc", qr{\[time: 0h / 0s\]} );

    ($loc) = create_tasks("foo [worked $input] [estimate $input]");
    time_is($loc,
        worked   => '0s',
        left     => '0s',
    );
    im_like( "todo $loc", qr{\[time: 0s / 0s\]} );
}

# start, stop, pause, unpause
set_fixed_time(time);

my ($distraction) = create_tasks('setting up context');

($loc) = create_tasks('live time tracking [estimate: 3h]');
im_like("start $loc", qr/Starting the timer on task <$loc>/);
im_like("start $loc", qr/There's already a timer on task <$loc>!/);
im_like("start banana", qr/There's already a timer on task <$loc>!/);

set_fixed_time(time + 60*60);
im_like("stop", qr/You worked on task <$loc> for 1 hour/);
im_like("stop", qr/You're not working on any tasks/);
worked_is($loc => '1h');
left_is($loc => '2h');

my (@locs) = create_tasks('time tracking A', 'time tracking B');
im_like("start @locs", qr/Starting the timer on tasks <$locs[0]> and <$locs[1]>/);

set_fixed_time(time + 2*60*60);
im_like("stop", qr/You worked on tasks <$locs[0]> and <$locs[1]> for 2 hours/);
im_like("stop", qr/You're not working on any tasks/);
worked_is($locs[0] => '2h');
worked_is($locs[1] => '2h');

im_like("start $loc", qr/Starting the timer on task <$loc>/);
set_fixed_time(time + 60*60);
im_like("pause", qr/Pausing the timer \(at 1h\) on task <$loc>/);
im_like("pause", qr/The timer on task <$loc> is already paused!/);
im_like("start $locs[0]", qr/There's already a timer on task <$loc>!/);
set_fixed_time(time + 10*60*60);
im_like("unpause", qr/Unpausing the timer \(at 1h\) on task <$loc>/);
im_like("unpause", qr/The timer on task <$loc> is already running!/);
set_fixed_time(time + 60*60);
im_like("stop", qr/You worked on task <$loc> for 2 hours/);
worked_is($loc => '3h');

im_like("start @locs", qr/Starting the timer on tasks <$locs[0]> and <$locs[1]>/);
set_fixed_time(time + 60*60);
for (1..5) {
    im_like("pause", qr/Pausing the timer \(at \w+\) on tasks <$locs[0]> and <$locs[1]>/);
    set_fixed_time(time + 10*60*60);
    im_like("unpause", qr/Unpausing the timer \(at \w+\) on tasks <$locs[0]> and <$locs[1]>/);
    set_fixed_time(time + 60*60);
}

im_like("stop", qr/You worked on tasks <$locs[0]> and <$locs[1]> for 7 hours/);
worked_is($locs[0] => '9h');
worked_is($locs[1] => '9h');

im_like("pause", qr/You're not working on any tasks/);
im_like("unpause", qr/You're not working on any tasks/);

im_like("show $distraction", qr/$distraction/);
im_like("start $loc", qr/Starting the timer on task <$loc>/);
im_like("show", qr/$loc/, "start sets context");

im_like("show $distraction", qr/$distraction/);
im_like("pause", qr/Pausing the timer \(at \w+\) on task <$loc>/);
im_like("show", qr/$loc/, "pause sets context");

im_like("show $distraction", qr/$distraction/);
im_like("unpause", qr/Unpausing the timer \(at \w+\) on task <$loc>/);
im_like("show", qr/$loc/, "unpause sets context");

im_like("show $distraction", qr/$distraction/);
im_like("stop", qr/You worked on task <$loc> for/);
im_like("show", qr/$loc/, "stop sets context");

sub _method_is {
    my $method   = shift;
    my $locator  = shift;
    my $expected = shift;
    my $name     = shift || "Right time for $method";

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');

    my $task = BTDT::Model::Task->new( current_user => $user );
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

