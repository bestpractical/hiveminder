use warnings;
use strict;

use BTDT::Test tests => 171;
use BTDT::Test::WWW::Selenium;

my $page_wait = 20000;

my $server = BTDT::Test->make_server();
isa_ok($server, 'Jifty::TestServer');
my $URL = $server->started_ok;
my $feedback_group = BTDT::Test->setup_hmfeedback_group;

my $tests = sub {
    my $sel = shift;

    create_task_inline($sel);
    set_priority_inline($sel);
    add_dependent_task($sel);
    submit_feedback($sel);
    inline_braindump($sel);
    complete_tasks($sel);
    bulk_update($sel);
    validators($sel);
    canonicalizers($sel);
    autocompleters($sel);
    calendar($sel);
};

my $tester = BTDT::Test::WWW::Selenium->login_and_run_tests(
    tests     => $tests,
    browsers  => ["*firefox"],
    num_tests => 12 + 9 + 15 + 9 + 0,
    url       => $URL,
    username  => 'gooduser@example.com',
    password  => 'secret',
    server    => $server,
);

sub create_task_inline {
    my $sel = shift;

    $sel->open_ok("/list/tag/selenium");

    # tag is automatically there, intuited from tasklist
    $sel->value_is("//input[\@name=\"J:A:F-tags-tasklist-new_item_create\"]", "selenium");

    # create the task
    $sel->type_ok("//input[\@name=\"J:A:F-summary-tasklist-new_item_create\"]", "hello from selenium!");
    $sel->click_ok("//input[contains(\@name, \"J:ACTIONS=tasklist-new_item_create\")]");

    $sel->wait_for_text_present_ok("hello from selenium!", $page_wait);

    # we canonicalized priority to 4 from the !
    $sel->text_is("//span[\@id=\"canonicalization_note-J:A:F-summary-tasklist-new_item_create\"]", "Set Priority to 4");

    $sel->text_is("//div[\@id=\"result-tasklist-new_item_create\"]", "Your task has been created!");

    my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
    $task->load_by_cols(summary => "hello from selenium!");
    ok($task->id, "created the task");
    is($task->priority, 4, "task's priority was intuited to 'high'");
    like($task->tags, qr/\bselenium\b/, "task has tag selenium");

    $sel->is_text_present_ok("#" . $task->record_locator, "the record locator");
}

sub set_priority_inline {
    my $sel = shift;

    # find the task we created in create_task_inline
    $sel->open_ok("/list/tag/selenium/priority/4");

    # open the priority context menu
    $sel->click_ok("//a[contains(\@onclick,\"Jifty.ContextMenu.hideshow\")]");

    # change priority to highest
    $sel->click_ok("//a[text()=\"highest\"]");

    $sel->wait_for_text_present_ok("Task 'hello from selenium!' updated.", $page_wait);
    $sel->text_is("//a[starts-with(\@href,\"/task/\")]", "Task 'hello from selenium!' updated.");

    # task left the tasklist because it's no longer priority 4
    ok(not $sel->is_element_present("//div[\@class=\"task_container\"]"));

    Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');

    my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
    $task->load_by_cols(summary => "hello from selenium!");
    ok($task->id, "loaded the task");
    is($task->priority, 5, "task's priority was changed to 'highest'");
    like($task->tags, qr/\bselenium\b/, "task has tag selenium");
}

sub add_dependent_task {
    my $sel = shift;

    # find the task we created in create_task_inline
    $sel->open_ok("/list/tag/selenium");

    # open up the edit context menu
    $sel->click_ok("//a[starts-with(\@onclick,\"Jifty.ContextMenu.hideshow\")][ancestor::li[contains(\@class,\"task_edit_menu\")]]");

    # open up a "but first" task list
    $sel->wait_for_text_present_ok("But first...", $page_wait);
    $sel->click_ok("//a[text()=\"But first...\"]");
    $sel->wait_for_text_present_ok("Add a new task (or the #id of an old one)", $page_wait);

    # tag was intuited from tasklist
    $sel->value_is("//input[starts-with(\@name,\"J:A:F-tags-tasklist-item-\")]", "selenium");

    # create the task
    $sel->type_ok("//input[starts-with(\@name,\"J:A:F-summary-tasklist-item-\")]", "install selenium");
    $sel->click_ok("//input[\@value=\"Create\"][contains(\@name,\"J:ACTIONS=tasklist-item-\")]");

    $sel->wait_for_text_present_ok("Your task has been created!", $page_wait);
    $sel->text_is("//div[starts-with(\@id,\"result-tasklist-item-\")]", "Your task has been created!");
    $sel->wait_for_text_present_ok("install selenium", $page_wait);

    my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
    $task->load_by_cols(summary => "install selenium");
    ok($task->id, "created the task");
    is($task->priority, 5, "task's priority was cargo-culted to 'highest'");
    like($task->tags, qr/\bselenium\b/, "task has tag selenium");

    $sel->is_text_present_ok("#" . $task->record_locator, "the record locator for the dependent task");

    my $dependency = BTDT::Model::TaskDependency->new(current_user => BTDT::CurrentUser->superuser);
    $dependency->load_by_cols(
        depends_on => $task->id,
    );
    ok($dependency->id, "loaded a task dependency");
    is($dependency->task->summary, "hello from selenium!", "correct dependent task");
}

sub submit_feedback {
    my $sel = shift;

    $sel->open_ok("/list/tag/selenium");

    # submit the feedback
    $sel->type_ok("//textarea[starts-with(\@id,\"J:A:F-content-feedback\")]", "kshhhh");
    $sel->click_ok("//input[\@value=\"Send this feedback!\"][contains(\@name,\"J:ACTIONS=feedback\")]");
    $sel->wait_for_text_present_ok("Thanks for the feedback. We appreciate it!", $page_wait);
    $sel->text_is("//div[\@id=\"result-feedback\"]", "Thanks for the feedback. We appreciate it!");

    my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
    $task->load_by_cols(summary => "kshhhh");
    ok($task->id, "created a feedback task");
    is($task->group_id, $feedback_group->id, "task is in the feedback group");
    is($task->owner->email, 'nobody', "task owned by nobody");
    is($task->requestor->email, 'gooduser@example.com', "task requested by submitter");
    unlike($task->tags, qr/selenium/, "no selenium tag from tasklist");
}

sub inline_braindump {
    my $sel = shift;

    # get a new tag for intuiting
    $sel->open_ok("/list/tag/selenium-braindump-inline");

    # click the "Braindump" link
    $sel->click_ok("//a[text()=\"Braindump\"]");

    # braindump box load
    $sel->wait_for_element_present_ok("//textarea[starts-with(\@id,\"J:A:F-text-quickcreate\")]", $page_wait);

    # sleep to make sure the placeholder JS has time to run
    sleep 1;
    $sel->click_ok("//textarea[starts-with(\@id,\"J:A:F-text-quickcreate\")]");
    sleep 1;

    $sel->type_keys_ok("//textarea[starts-with(\@id,\"J:A:F-text-quickcreate\")]", "good bye braindump [parting] [due tomorrow]");

    # hit enter
    $sel->key_press_ok("//textarea[starts-with(\@id,\"J:A:F-text-quickcreate\")]", "\\13");

    $sel->type_keys_ok("//textarea[starts-with(\@id,\"J:A:F-text-quickcreate\")]", "it was nice knowing you! [condolences]");

    # click off make sure the placeholder doesn't reappear
    $sel->click_ok("//input[starts-with(\@id,\"J:A:F-email-invite_new_user\")]");

    # submit
    $sel->click_ok("//input[\@type=\"submit\"][contains(\@name,\"J:ACTIONS=quickcreate\")]");

    $sel->wait_for_element_present_ok("//div[contains(\@class,\"quickcreate\")][contains(\@class,\"message\")][text()=\"2 tasks created\"]", $page_wait);

    # postgres seems to get wedged here
    sleep 1;

    my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
    $task->load_by_cols(summary => "good bye braindump");
    ok($task->id, "created the task");
    is($task->priority, 3, "task's priority is normal");
    like($task->tags, qr/\bselenium-braindump-inline\b/, "task has tag from tasklist");
    like($task->tags, qr/\bparting\b/, "task has explicit tag in summary");
    if ($task->due) {
        is($task->due->friendly_date, "tomorrow", "task is due tomorrow");
    }
    else {
        fail("no due date from the task's summary");
    }
    $sel->is_text_present_ok("#" . $task->record_locator, "the record locator for the first task");


    $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
    $task->load_by_cols(summary => "it was nice knowing you!");
    ok($task->id, "created the task");
    is($task->priority, 4, "task's priority was intuited to high");
    like($task->tags, qr/\bselenium-braindump-inline\b/, "task has tag from tasklist");
    like($task->tags, qr/\bcondolences\b/, "task has explicit tag in summary");
    $sel->is_text_present_ok("#" . $task->record_locator, "the record locator for the second task");
}

sub complete_tasks {
    my $sel = shift;
    $sel->open_ok("/todo");

    my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
    $task->load_by_cols(summary => "good bye braindump");
    ok($task->id, "got the task");
    ok(!$task->complete, "task is not yet complete");

    # find the task container
    $sel->wait_for_element_present_ok("//input[starts-with(\@id,\"J:A:F-complete\")][\@type=\"checkbox\"][following-sibling::span/a[text()=\"good bye braindump\"]]", $page_wait);

    # click the checkbox next to the task to complete it
    $sel->click_ok("//input[starts-with(\@id,\"J:A:F-complete\")][\@type=\"checkbox\"][following-sibling::span/a[text()=\"good bye braindump\"]]");
    $sel->wait_for_text_present_ok("Task 'good bye braindump' updated.", $page_wait);

    # make sure the task is complete in the database
    Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
    $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
    $task->load_by_cols(summary => "good bye braindump");
    ok($task->id, "got the task");
    ok($task->complete, "task is now complete");

    # task is now styled as complete
    $sel->wait_for_element_present_ok("//dt[contains(\@class,\"complete\")][descendant::a[text()=\"good bye braindump\"]]", $page_wait);

    # click the checkbox next to the task to un-complete it
    $sel->click_ok("//input[starts-with(\@id,\"J:A:F-complete\")][\@type=\"checkbox\"][following-sibling::span/a[text()=\"good bye braindump\"]]");

    # task is now styled as incomplete
    $sel->wait_for_element_present_ok("//dt[not(contains(\@class,\"complete\"))][descendant::a[text()=\"good bye braindump\"]]", $page_wait);
    $sel->wait_for_text_present_ok("Task 'good bye braindump' updated.", $page_wait);

    # make sure the task is incomplete in the database
    Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
    $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
    $task->load_by_cols(summary => "good bye braindump");
    ok($task->id, "got the task");
    ok(!$task->complete, "task is now incomplete");
}

sub bulk_update {
    my $sel = shift;
    $sel->open_ok("/todo");

    # click Bulk Update
    $sel->click_ok("//a[text()=\"Bulk Update\"]");
    $sel->wait_for_element_present_ok("//input[\@type=\"submit\"][\@value=\"Save Changes\"][contains(\@name,\"J:ACTIONS=bulk_edit\")]", $page_wait);

    # click [not this] on task "it was nice knowing you"
    $sel->click_ok("//a[contains(\@class,\"argument-select\")][text()=\"[not this]\"][following-sibling::span/a[text()=\"it was nice knowing you!\"]]");

    # wait for task to disappear
    # WWW::Selenium doesn't have wait_for_element_not_present
    $sel->do_command("waitForElementNotPresent", "//a[contains(\@class,\"argument-select\")][text()=\"[not this]\"][following-sibling::span/a[text()=\"it was nice knowing you!\"]]", $page_wait);

    # add bulk-update tag
    $sel->type_ok("//input[\@type=\"text\"][starts-with(\@id,\"J:A:F-add_tags-bulk_edit\")]", "bulk-update");

    # submit
    $sel->click_ok("//input[\@type=\"submit\"][\@value=\"Save Changes\"][contains(\@name,\"J:ACTIONS=bulk_edit\")]");
    $sel->wait_for_text_present_ok("Updated 4 tasks", $page_wait);

    sleep 5;

    Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');

    # check that the task we used [not this] on didn't get the tag
    my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
    $task->load_by_cols(summary => "it was nice knowing you!");
    ok($task->id, "got the task");
    like($task->tags, qr/\bselenium-braindump-inline\b/, "task has tag from before");
    unlike($task->tags, qr/\bbulk-update\b/, "task did not receive tag from bulk update");

    # check that the tasks we bulk updated got the tag
    for my $summary ("good bye braindump", "install selenium", "01 some task", "02 other task") {
        $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
        $task->load_by_cols(summary => $summary);
        ok($task->id, "got the task '$summary'");
        like($task->tags, qr/\bbulk-update\b/, "'$summary' did receive tag from bulk update");
    }
}

sub validators {
    my $sel = shift;
    $sel->open_ok("/todo");

    # expand the fields for inline task creation
    $sel->click_ok("//a[text()='more...'][parent::div[contains(\@class,\"line\")]]");

    # click the owner field
    $sel->click_ok("//input[starts-with(\@id,\"J:A:F-owner_id-tasklist-new_item_create\")]");

    # replace the owner field with X
    $sel->type_ok("//input[starts-with(\@id,\"J:A:F-owner_id-tasklist-new_item_create\")]", "X");

    # and add a Y
    $sel->type_keys_ok("//input[starts-with(\@id,\"J:A:F-owner_id-tasklist-new_item_create\")]", "Y");

    # try to tab off the field so it gets validated
    $sel->key_press_ok("//input[starts-with(\@id,\"J:A:F-owner_id-tasklist-new_item_create\")]", "\t");

    # XXX: submitting is the only thing I could find that forces input
    # validation. nothing else triggers the ajaxvalidation blur
    $sel->click_ok("//input[contains(\@name, \"J:ACTIONS=tasklist-new_item_create\")]");
    $sel->wait_for_text_present_ok("Are you sure that's an email address?", $page_wait);
}

sub canonicalizers {
    my $sel = shift;
    $sel->open_ok("/todo");

    # we received a report that canonicalization failed the second time around,
    # so do this test twice
    for (1..2) {
        $sel->type_ok("//input[\@name=\"J:A:F-summary-tasklist-new_item_create\"]", "canonicaliiize $_");

        # set due to "tomorrow"
        $sel->click_ok("//a[text()='more...'][parent::div[contains(\@class,\"line\")]]");
        $sel->type_ok("//input[\@name=\"J:A:F-due-tasklist-new_item_create\"]", "tomorrow");

        # Selenium apparently doesn't easily trigger this one. This is when we
        # perform canonicalization, so we do need it
        $sel->fire_event("//input[\@name=\"J:A:F-due-tasklist-new_item_create\"]", "blur");

        sleep 2;

        $sel->value_like("//input[\@name=\"J:A:F-due-tasklist-new_item_create\"]", qr/^\d\d\d\d-\d\d-\d\d$/, "value was canonicalized from 'tomorrow' to yyyy-mm-dd form");

        $sel->click_ok("//input[contains(\@name, \"J:ACTIONS=tasklist-new_item_create\")]");

        $sel->wait_for_text_present_ok("Your task has been created!");
        $sel->text_is("//div[\@id=\"result-tasklist-new_item_create\"]", "Your task has been created!");

        Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');

        my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
        $task->load_by_cols(summary => "canonicaliiize $_");
        ok($task->id, "loaded the task");
        is($task->priority, 3, "task's priority is normal");
        ok($task->due, "task has a due date");
    }

    # without this, we tend to get a "Server unavailable" exception
    sleep 1;
}

sub autocompleters {
    my $sel = shift;

    $sel->open_ok("/todo");
    sleep 2;

    my $tags_xpath = "//input[\@name=\"J:A:F-tags-tasklist-new_item_create\"]";

    $sel->type_ok("//input[\@name=\"J:A:F-summary-tasklist-new_item_create\"]", "testing with pressing enter for autocomplete");

    # anything less than this and the autocomplete widget doesn't show up
    $sel->click_ok($tags_xpath);
    $sel->key_down_ok($tags_xpath, "s");
    $sel->key_press_ok($tags_xpath, "s");
    $sel->key_up_ok($tags_xpath, "s");

    # press enter on the tag field to select selenium
    my $tags_autocomplete = "//li[\@rel=\"selenium\"][ancestor::div[starts-with(\@id,\"J:A:F-tags-tasklist-new_item_create\")]]";
    $sel->wait_for_element_present_ok($tags_autocomplete, $page_wait);

    $sel->click_ok($tags_xpath);
    $sel->key_down_ok($tags_xpath, "\\13");
    $sel->key_press_ok($tags_xpath, "\\13");
    $sel->key_up_ok($tags_xpath, "\\13");

    # WWW::Selenium doesn't have wait_for_not_visible
    $sel->do_command("waitForNotVisible", $tags_autocomplete, $page_wait);

    # submit
    $sel->click_ok("//input[contains(\@name, \"J:ACTIONS=tasklist-new_item_create\")]");
    $sel->wait_for_element_present_ok("//div[\@id=\"result-tasklist-new_item_create\"]", $page_wait);
    $sel->text_is("//div[\@id=\"result-tasklist-new_item_create\"]", "Your task has been created!");

    Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
    my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
    $task->load_by_cols(summary => "testing with pressing enter for autocomplete");
    ok($task->id, "got the autocomplete task");
    like($task->tags, qr/\bselenium\b/, "task did receive selenium tag from autocomplete");
}

sub calendar {
    my $sel = shift;

    # assumptions: cell 0 of the calendar is always before today
    #              cell 33 of the calendar is always after today
    # because the calendar always centers on the current month and shows a week
    # before and after, it should all work fine

    $sel->open_ok("/todo");

    # open inline edit
    $sel->click_ok("//a[text()=\"Edit\"][ancestor::ul[contains(\@class,\"context_menu\")]]");
    $sel->wait_for_element_present_ok("//input[starts-with(\@id,\"J:A:F-starts-edit\")]", $page_wait);

    # open up the calendar for "due"
    $sel->click_ok("//input[starts-with(\@id,\"J:A:F-due-edit\")]");
    $sel->wait_for_element_present_ok("//div[starts-with(\@id,\"cal_J:A:F-due-edit\")]", $page_wait);

    # go back a month
    $sel->click_ok("//a[contains(\@class,\"calnavleft\")]");

    # click the first day
    $sel->click_ok("//td[contains(\@id,\"cell0\")][starts-with(\@id,\"cal_J:A:F-due-edit-\")]");

    # click to another field to hide the calendar
    $sel->click_ok("//input[starts-with(\@id,\"J:A:F-summary-edit\")]");

    # WWW::Selenium doesn't have wait_for_element_not_present
    $sel->do_command("waitForElementNotPresent", "//div[starts-with(\@id,\"cal_J:A:F-due-edit\")]", $page_wait);

    # open up the calendar for "starts"
    $sel->click_ok("//input[starts-with(\@id,\"J:A:F-starts-edit\")]");
    $sel->wait_for_element_present_ok("//div[starts-with(\@id,\"cal_J:A:F-starts-edit\")]", $page_wait);

    # click the 33rd day, which will be well past today
    $sel->click_ok("//td[contains(\@id,\"cell33\")][starts-with(\@id,\"cal_J:A:F-starts-edit-\")]");

    # submit the form to make sure our edits went through
    $sel->click_ok("//input[\@type=\"submit\"][\@value=\"Save\"][contains(\@name,\"J:ACTIONS=edit-\")]");

    my $summary = "good bye braindump";
    $sel->wait_for_text_present_ok("Task '$summary' updated.", $page_wait);

    Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');

    my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->superuser);
    $task->load_by_cols(summary => $summary);

    my $due = $task->due;
    my $starts = $task->starts;

    ok($task->id, "got the task '$summary'");
    ok($due < DateTime->now, "due date ($due) is in the past");
    ok($starts > DateTime->now, "starts date ($starts) is in the future");
}

