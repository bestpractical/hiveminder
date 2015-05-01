use strict;
use warnings;

use BTDT::Test tests => 44;
use BTDT::Test::WWW::Selenium;

my $page_wait = 20000;

my $server = BTDT::Test->make_server();
isa_ok($server, 'Jifty::TestServer');
my $URL = $server->started_ok;

my $gooduser = BTDT::CurrentUser->new(email => 'gooduser@example.com');
BTDT::Test->make_pro($gooduser);

my $tester = BTDT::Test::WWW::Selenium->login_and_run_tests(
    browsers  => ["*firefox"],
    num_tests => 17,
    url       => $URL,
    username  => 'gooduser@example.com',
    password  => 'secret',
    server    => $server,
    tests     => sub {
        my $sel = shift;
        $sel->open_ok("/todo");
        sleep 2;

        # open the stopwatch
        $sel->click_ok("//a[ancestor::span[contains(\@class,\"time_tracking\")]]");
        $sel->wait_for_element_present("//div[\@id=\"modalContainer\"]", $page_wait);

        # close the stopwatch with the X
        $sel->click_ok("//a[contains(\@class,\"modalClose\")]");
        $sel->do_command("waitForElementNotPresent", "//div[\@id=\"modalContainer\"]");

        # open the stopwatch
        $sel->click_ok("//a[ancestor::span[contains(\@class,\"time_tracking\")]]");
        $sel->wait_for_element_present("//div[\@id=\"modalContainer\"]", $page_wait);

        # toggle pause/unpause
        $sel->wait_for_element_present("//button[contains(\@class,\"sw-pause\")][contains(text(),\"Pause\")]", $page_wait);
        $sel->click_ok("//button[contains(\@class,\"sw-pause\")]");
        $sel->wait_for_element_present("//button[contains(\@class,\"sw-resume\")][contains(text(),\"Resume\")]", $page_wait);
        $sel->click_ok("//button[contains(\@class,\"sw-resume\")]");
        $sel->wait_for_element_present("//button[contains(\@class,\"sw-pause\")][contains(text(),\"Pause\")]", $page_wait);

        # make sure some time gets registered
        sleep 3;

        # update the task
        $sel->click_ok("//input[\@type=\"submit\"][contains(\@class,\"modalClose\")][\@value=\"Update\"]");
        $sel->do_command("waitForElementNotPresent", "//div[\@id=\"modalContainer\"]");

        sleep 1;

        # make sure we have some time worked
        my $task = BTDT::Model::Task->new(current_user => $gooduser);
        $task->load_by_cols(summary => "01 some task");
        ok($task->id, "created a task");
        cmp_ok($task->time_worked_seconds, '>', 0, "added some time worked");
        ok(!$task->complete, "did not mark the task as complete");

        # let's make sure we update time left too!
        $task->set_time_left('1h');

        my $task_id = $task->id;
        undef $task;

        # open stopwatch
        $sel->open_ok("/todo");
        sleep 2;

        $sel->click_ok("//a[ancestor::span[contains(\@class,\"time_tracking\")]]");
        $sel->wait_for_element_present("//div[\@id=\"modalContainer\"]", $page_wait);

        # add a comment
         $sel->type_ok("//textarea[starts-with(\@id,\"J:A:F-comment-edit-time-\")]", "megaman");

        # make sure we get some time..
        sleep 3;

        # click update and complete
        $sel->click_ok("//input[\@type=\"submit\"][contains(\@class,\"modalClose\")][\@value=\"Update and Complete\"]");
        $sel->do_command("waitForElementNotPresent", "//div[\@id=\"modalContainer\"]");

        sleep 1;

        # make sure we've updated the task
        Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');

        $task = BTDT::Model::Task->new(current_user => $gooduser);
        $task->load($task_id);
        cmp_ok($task->time_left_seconds, '<', 3600, "subtracted some time left");
        ok($task->complete, "marked the task as complete");

        my $messages = join '', map { $_->message } @{ $task->comments->items_array_ref };
        like($messages, qr/megaman/, "added the comment");

        # now make sure that we can edit the time and have it be updated
        $sel->open_ok("/todo");
        sleep 2;

        $sel->click_ok("//a[ancestor::span[contains(\@class,\"time_tracking\")]]");
        $sel->wait_for_element_present("//div[\@id=\"modalContainer\"]", $page_wait);
        $sel->wait_for_element_present("//button[contains(\@class,\"sw-pause\")][contains(text(),\"Pause\")]", $page_wait);

        sleep 2;

        $sel->click_ok("//button[contains(\@class,\"sw-pause\")]");
        sleep 1;

        # add a bunch of time
        $sel->type_keys_ok("//input[starts-with(\@id, \"J:A:F-add_time_worked-edit-time-\")]", "\b\b\b\b\b\b\b\b00:15:00");
        sleep 1;

        # unpause
        $sel->click_ok("//button[contains(\@class,\"sw-resume\")]");
        $sel->wait_for_element_present("//button[contains(\@class,\"sw-pause\")][contains(text(),\"Pause\")]", $page_wait);

        # make sure some time gets registered
        sleep 3;

        $sel->click_ok("//input[\@type=\"submit\"][contains(\@class,\"modalClose\")][\@value=\"Update\"]");
        $sel->do_command("waitForElementNotPresent", "//div[\@id=\"modalContainer\"]");
        sleep 1;

        $task = BTDT::Model::Task->new(current_user => $gooduser);
        $task->load_by_cols(summary => "02 other task");

        my $worked = $task->time_worked_seconds;
        my $left = $task->time_left_seconds;

        cmp_ok($worked, '>', 600, "added a lot of time worked");
        cmp_ok($left, '<', 3000, "subtracted a lot of time left");
        ok(!$task->complete, "did not mark the task as complete");

        # click X with a lot of time worked, say no, say yes, etc
        $sel->open_ok("/todo");
        sleep 2;

        $sel->click_ok("//a[ancestor::span[contains(\@class,\"time_tracking\")]]");
        $sel->wait_for_element_present("//div[\@id=\"modalContainer\"]", $page_wait);
        $sel->wait_for_element_present("//button[contains(\@class,\"sw-pause\")][contains(text(),\"Pause\")]", $page_wait);

        sleep 2;

        $sel->click_ok("//button[contains(\@class,\"sw-pause\")]");
        sleep 1;

        # add a bunch of time
        $sel->type_keys_ok("//input[starts-with(\@id, \"J:A:F-add_time_worked-edit-time-\")]", "\b\b\b\b\b\b\b\b01:01:01");
        sleep 1;

        $sel->click_ok("//button[contains(\@class,\"sw-resume\")]");
        $sel->wait_for_element_present("//button[contains(\@class,\"sw-pause\")][contains(text(),\"Pause\")]", $page_wait);

        # make sure some time gets registered
        sleep 3;

        # click the X, cancel the close
        # XXX: Selenium doesn't seem to like this..
        $sel->do_command("chooseCancelOnNextConfirmation");
        $sel->click_ok("//a[contains(\@class,\"modalClose\")]");
        $sel->do_command("waitForConfirmation");

        sleep 1;

        ok(!$sel->is_element_present("//div[\@id=\"modalContainer\"]"), "modal dialog box is still there");

        Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
        $task = BTDT::Model::Task->new(current_user => $gooduser);
        $task->load_by_cols(summary => "02 other task");

        is($task->time_worked_seconds, $worked, "no change in time worked");
        is($task->time_left_seconds, $left, "no change in time worked");

        # now update, ensuring we have all the time worked from before
        $sel->click_ok("//input[\@type=\"submit\"][contains(\@class,\"modalClose\")][\@value=\"Update\"]");
        $sel->do_command("waitForElementNotPresent", "//div[\@id=\"modalContainer\"]");
        sleep 1;

        Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
        $task = BTDT::Model::Task->new(current_user => $gooduser);
        $task->load_by_cols(summary => "02 other task");

        cmp_ok($task->time_worked_seconds, '>', $worked+3600, "worked another hour");
    },
);

