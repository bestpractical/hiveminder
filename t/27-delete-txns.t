use strict;
use warnings;
use BTDT::Test tests => 12;

my $cu = BTDT::CurrentUser->new(email => 'gooduser@example.com');

Jifty->web->current_user($cu);

# happens with regular task creation..
my $task = BTDT::Model::Task->new;
my ($ok, $msg) = $task->create(summary => "yeea!");
ok($ok, $msg);

ok($task->transactions->count, "task has transactions before delete");

BTDT::Test->setup_mailbox();

Jifty->web->response(Jifty::Response->new);
Jifty->web->request(Jifty::Request->new);

my $delete = BTDT::Action::DeleteTask->new(
    record => $task,
);

ok $delete->validate;
$delete->run;
ok $delete->result->success;

my @emails = BTDT::Test->messages;
TODO: {
    local $TODO = "we don't send out DeletedTask notifications";
    is(@emails, 1, "Task deleted mail");
}

# ---------------------------------------------

# ..and happens with braindump too
Jifty->web->response(Jifty::Response->new);
Jifty->web->request(Jifty::Request->new);

my $braindump = BTDT::Action::ParseTasksMagically->new(
    arguments => {
        text        => "yaa!"
    }
);

ok $braindump->validate;
$braindump->run;
my $result = $braindump->result;
ok $result->success;
my @created = @{ $result->content('created') };
is(@created, 1, "got one task");
$task = shift @created;

ok($task->transactions->count, "task has transactions before delete");

BTDT::Test->setup_mailbox();

$delete = BTDT::Action::DeleteTask->new(
    record => $task,
);

ok $delete->validate;
$delete->run;
ok $delete->result->success;

@emails = BTDT::Test->messages;
TODO: {
    local $TODO = "we don't send out DeletedTask notifications";
    is(@emails, 1, "Task deleted mail");
}

