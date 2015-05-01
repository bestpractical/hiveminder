use warnings;
use strict;
use Test::MockTime qw( :all );
use POSIX 'tzset';

# Using POSIX::tzset fixes a bug where the TZ environment variable is cached.
# tzset sets the internal timezone to the current value of ENV{TZ}. See also
# RT::Date.

# setup {{{
use BTDT::Test tests => 1403;

my $user = BTDT::CurrentUser->new(email => 'gooduser@example.com');
Jifty->web->current_user($user);

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');
my $URL = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech($URL);

isa_ok($mech, 'Jifty::Test::WWW::Mechanize');

sub task_info
{
    my $task = shift;
    my $original_summary = shift;
    my $field = shift || 'due';

    my $value = $task->$field
                ? $task->$field . ' in ' . $task->$field->time_zone
                : 'undef';

    my $now;
    {
        local $ENV{TZ} = $user->user_object->time_zone;
        tzset();
        my ($sec, $min, $hour, $d, $m, $y, $wday) = localtime;
        $y += 1900; $m++; $wday = (qw/Sun Mon Tue Wed Thu Fri Sat/)[$wday];

        $now = sprintf '%04d-%02d-%02d %3s %02d:%02d:%02d', $y,$m,$d,$wday,$hour,$min,$sec;
    }
    tzset();

    diag sprintf "Task    : %s\nOriginal: %s\nCreated : %s in %s\n%-8s: %s",
         $task->summary,
         $original_summary,
         $now,
         $user->user_object->time_zone,
         ucfirst($field),
         $value;
    return 0;
}

sub new_task
{
    my $summary = shift;
    my $task = BTDT::Model::Task->new(current_user => $user);
    my ($ok, $msg) = $task->create(summary => $summary);
    local $TODO; # task creation should always work for these tests
    ok($ok) or diag $msg;
    return $task;
}

sub due_is($$;$)
{
    my $summary = shift;
    my $expected = shift;
    my $description = shift;

    my $task = new_task($summary);
    return task_info($task, $summary) if !defined($task->due);
    my $due = defined $task->due ? $task->due->friendly_date : undef;
    is($due, $expected, $description || "Due date set correctly for '$summary'") or task_info($task, $summary);
}

sub due_like($$;$)
{
    my $summary = shift;
    my $expected = shift;
    my $description = shift;

    my $task = new_task($summary);
    return task_info($task, $summary) if !defined($task->due);
    my $due = defined $task->due ? $task->due->friendly_date : undef;
    like($due, $expected, $description || "Due date set correctly for '$summary'") or task_info($task, $summary);
}

sub starts_is($$;$)
{
    my $summary = shift;
    my $expected = shift;
    my $description = shift;

    my $task = new_task($summary);
    my $starts = defined $task->starts ? $task->starts->friendly_date : undef;
    is($starts, $expected, $description || "Starts date set correctly for '$summary'") or task_info($task, $summary, 'starts');
}
# }}}

for my $tz ('America/New_York',
            'Pacific/Auckland',
            'America/Anchorage',
            'UTC',
)
{
    $user->user_object->set_time_zone($tz);

    for my $date ('2007-05-31', # during daylight saving
                  '2007-01-05') # not during daylight saving
    {
        for my $time ('00:12:53',
                      '06:03:00',
                      '12:00:00',
                      '18:30:31',
                      '23:54:12')
        {
            diag "Testing $date $time in $tz" if $ENV{TEST_VERBOSE};
            # we want $time to be local to $tz, not to GMT or your tz
            # therefore, when $time is 06:03:00 and $tz is America/Anchorage,
            # gmtime will be 14:03:00 or 15:03:00 (depending on DST)
            my ($y, $M, $d) = split '-', $date;
            my ($h, $m, $s) = split ':', $time;
            my $dt = DateTime->new(
                year => $y,
                month => $M,
                day => $d,
                hour => $h,
                minute => $m,
                second => $s, 
                time_zone => $tz,
            );
            $dt->set_time_zone('UTC');
            set_fixed_time($dt->ymd . 'T' . $dt->hms, "%Y-%m-%dT%H:%M:%S");

            due_is "Hello world [due: today]", 'today';
            due_is "Hello world [due: tomorrow]", 'tomorrow';
            due_is "Hello world [due: yesterday]", 'yesterday';

            # "monthname daynumber" used to be forced ahead a year
            due_is "Got the right year [due: november 17]", "2007-11-17";
            due_like "Issue recall [due: march]", qr/^\d\d\d\d-03-\d\d/;

            my $task = new_task("Pay day! [due: thurs]");
            is($task->due->day_name, 'Thursday', "thurs works as synonym for thursday") or task_info($task, "Pay day! [due: thurs]");

            due_is "Fixed future date outside of daylight savings [due: 2009-12-24]"
                => '2009-12-24';

            due_is "Fixed future date inside daylight savings [due: 2009-05-15]"
                => '2009-05-15';

            due_is "Hello world today", 'today';
            due_is "Hello tomorrow world", 'tomorrow';
            # we won't intuit a date in the past, including "yesterday"

            $task = new_task("Pay day on thurs");
            is($task->due->day_name, 'Thursday', "thurs works as synonym for thursday") or task_info($task, "Pay day on thurs");

            is($task->due->time_zone->name, 'floating', "due dates are given in the floating timezone");
            is($task->due->hms, '00:00:00', "due indeed looks like a date");

            is($task->created->time_zone->name, $tz, "created-at datetimes are given in the local timezone");

            due_is "Fixed future date outside of daylight savings 2009-12-24"
                => '2009-12-24';

            due_is "Fixed future date inside 2009-05-15 daylight savings"
                => '2009-05-15';

            starts_is "People reporting bugs with hidetoday [starts: today]  ", 'today';
            starts_is "People reporting bugs with hide20091224 [starts: 2009-12-24]  ", '2009-12-24';
            starts_is "People reporting bugs with hide20090515 [starts: 2009-05-15]  ", '2009-05-15';
        }
    }
}

