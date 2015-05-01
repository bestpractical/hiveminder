use warnings;
use strict;

=head1 DESCRIPTION

Date testing

=cut

use Test::MockTime qw( :all );

use BTDT::Test tests => 135;

use_ok('BTDT::Model::Task');
use_ok('BTDT::CurrentUser');

{
    # testing a specific bug
    my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
    $task->create( summary => "Issue recall [due: march]" );

    is($task->summary, "Issue recall");
    ok($task->due, "Due date set at all (nevermind if it's correct)");
    my @now = localtime();
    my $year = $now[5] + 1900;
    my $mon = $now[4] + 1;
    if ($mon >= 3) { $year++ } #need to find out when next march is
    like($task->due, qr"^@{[$year]}-03", "Due date set to some time in March");

    exercise_dates(1);

    # other tests shouldn't fail because of us

};

# Test "after midnight EST" failure
{
    set_fixed_time('2007-01-05T06:08:53Z');

    # test that "thurs" works as a synonym for thursday
    my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
    $task->create( summary => "Pay day on thurs!");
    is($task->summary, "Pay day on thurs!");
    is($task->due, "2007-01-11", "'thurs' works as synonym for thursday");

    ### Jifty chooses a port based off our pid; if we just let it start another
    ### server, it'll try to bind to the same (still in use) port.  Pick a 
    ### new port instead.
    Jifty->config->framework('Web')->{'Port'} = int(rand(5000) + 10000);

    exercise_dates(0);

    # other tests shouldn't fail because of us
    restore_time();

};

# Test "before midnight EST" failure
{
    set_fixed_time('2007-03-04T21:48:53Z');

    ### Jifty chooses a port based off our pid; if we just let it start another
    ### server, it'll try to bind to the same (still in use) port.  Pick a 
    ### new port instead.
    Jifty->config->framework('Web')->{'Port'} = int(rand(5000) + 10000);

    exercise_dates(0);

    # other tests shouldn't fail because of us
    restore_time();

};

# test a date during daylight savings 
{
    set_fixed_time('2007-05-31T09:08:53Z');

    ### Jifty chooses a port based off our pid; if we just let it start another
    ### server, it'll try to bind to the same (still in use) port.  Pick a 
    ### new port instead.
    Jifty->config->framework('Web')->{'Port'} = int(rand(5000) + 10000);

    exercise_dates(0);

    # other tests shouldn't fail because of us
    restore_time();

};

1;


sub exercise_dates {

my $fulltest = shift;

use DateTime;    
my $dt = DateTime->now;
$dt->set_time_zone('America/New_York');
my $today = $dt->ymd;

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');
my $URL = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech($URL);

isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->html_ok;
$mech->content_like(qr/Logout/i, "logged in");

ok($mech->find_link( text => "01 some task" ), "Task edit link exists");
$mech->follow_link_ok( text => "01 some task" );
$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 1),
                         due => "today",
                        );
$mech->form_number(2); $mech->click_button( value => 'Save' );
$mech->content_contains("Task '01 some task' updated");
like($mech->uri, qr|/todo|, "Back to inbox" );
$mech->follow_link_ok( text => "01 some task" );
like($mech->uri, qr|/task/3/edit|, "On task edit page" );
is($mech->action_field_value($mech->moniker_for("BTDT::Action::UpdateTask", id => 1),
			     'due'),
     $today,
     "due date properly set to today $today");

$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 1));
$mech->form_number(2); $mech->click_button( value => 'Save' );
$mech->content_lacks("Task '01 some task' updated");
like($mech->uri, qr|/todo|, "Back to inbox" );

my ($friendly_date) = $mech->content =~ /title="Due date">([^<]+)</;
is($friendly_date, 'today');

$mech->follow_link_ok( text => "01 some task" );
like($mech->uri, qr|/task/3/edit|, "On task edit page" );

is($mech->action_field_value($mech->moniker_for("BTDT::Action::UpdateTask", id => 1),
			     'due'),
     $today,
     "due date properly remains $today");

ok($mech->find_link( text => "Edit" ), "Task edit link exists");
$mech->follow_link_ok( text => "Edit" );
$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 1),
                         due => "",
                        );    $mech->form_number(2); $mech->click_button( value => 'Save' );
$mech->content_contains("Task '01 some task' updated"); 
like($mech->uri, qr|/todo|, "Back to inbox" );

$mech->follow_link_ok( text => "01 some task" );
like($mech->uri, qr|/task/3/edit|, "On task edit page" );

is($mech->action_field_value($mech->moniker_for("BTDT::Action::UpdateTask", id => 1),
			     'due'),
     '',
     "due date properly not set");

# test fixed future date without daylight savings
if ($fulltest)
{
    ok($mech->find_link( text => "Edit" ), "Task edit link exists");
    $mech->follow_link_ok( text => "Edit" );
    $mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 1),
                            due => "2009-12-24",
                            );    $mech->form_number(2); $mech->click_button( value => 'Save' );
    $mech->content_contains("Task '01 some task' updated"); 
    like($mech->uri, qr|/todo|, "Back to inbox" );
    $mech->follow_link_ok( text => "01 some task" );
    like($mech->uri, qr|/task/3/edit|, "On task edit page" );

    is($mech->action_field_value($mech->moniker_for("BTDT::Action::UpdateTask", id => 1),
                    'due'),
        '2009-12-24',
        "due date properly set to future non-daylight savings date, 2009-12-24");

# test fixed future date with daylight savings
    ok($mech->find_link( text => "Edit" ), "Task edit link exists");
    $mech->follow_link_ok( text => "Edit" );
    $mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 1),
                            due => "2009-05-15",
                            );    $mech->form_number(2); $mech->click_button( value => 'Save' );
    $mech->content_contains("Task '01 some task' updated"); 
    like($mech->uri, qr|/todo|, "Back to inbox" );
    $mech->follow_link_ok( text => "01 some task" );
    like($mech->uri, qr|/task/3/edit|, "On task edit page" );

    is($mech->action_field_value($mech->moniker_for("BTDT::Action::UpdateTask", id => 1),
                    'due'),
        '2009-05-15',
        "due date properly set to future daylight savings date 2009-05-15");
}

}
