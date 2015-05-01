use warnings;
use strict;

=head1 DESCRIPTION

Test the /fragments/tasklist/view Mason component.

=cut

use BTDT::Test tests => 29;
use Test::LongString;

use constant VIEW_PATH => "/fragments/tasklist/view";

my $server = Jifty::Test->make_server;

isa_ok($server, 'Jifty::TestServer');


my $URL = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech($URL);
isa_ok($mech, 'Test::WWW::Mechanize');

my $tasks = BTDT::Model::TaskCollection->new(current_user => BTDT::CurrentUser->superuser);
$tasks->unlimit;
$tasks->limit(column => "summary", value => "02 other task");

is($tasks->count, 1, "Found task 02");

my $task = $tasks->first;

# Add some tags. Use weird tag names so we don't accidentally pick up
# other content when searching for them

$task->set_tags("1234some 5678tags");

my $view_url = $URL . VIEW_PATH;

## Test that the view contains all relevant data
my $content = $mech->fragment_request(VIEW_PATH, id => $task->id, tokens => "");

contains_string($content, "02 other task", "contains task summary");
contains_string($content, "1234some", "contains tag");
contains_string($content, "5678tags", "contains other tag");
contains_string($content, "with a description", "contains task description");

#Test that it does the right thing with maybe_view
$content = $mech->fragment_request(VIEW_PATH, id => $task->id, maybe_view => 1, tokens => q{owner me tags 1234some});

contains_string($content, "02 other task", "contains task summary with maybe_view");
contains_string($content, "1234some", "contains tag with maybe_view");
contains_string($content, "5678tags", "contains other tag with maybe_view");
contains_string($content, "with a description", "contains task description with maybe_view");

#maybe_view without a search should return the task
$content = $mech->fragment_request(VIEW_PATH, id => $task->id, maybe_view => 1, tokens => "");

contains_string($content, "02 other task", "contains task summary with maybe_view and no search");
contains_string($content, "1234some", "contains tag with maybe_view and no search");
contains_string($content, "5678tags", "contains other tag with maybe_view and no search");
contains_string($content, "with a description", "contains task description with maybe_view and no search");

#Test with a search that doesn't match
$content = $mech->fragment_request(VIEW_PATH, id => $task->id, maybe_view => 1, tokens => q{tag someothertag});
is($content, "", "Filters task with maybe_view");

#Make sure that we don't leak content to users who aren't logged in

$mech->get("$URL/logout");
$mech->content_contains("Login", "Logged out");

$content = $mech->fragment_request(VIEW_PATH, id => $task->id, tokens => "");

lacks_string($content, "02 other task", "hides task summary");
lacks_string($content, "1234some", "hides tag");
lacks_string($content, "5678tags", "hides other tag");
lacks_string($content, "with a description", "hides task description");
lacks_string($content, 'gooduser@example.com', "hides user email address");

#Make sure we don't leak content to other users

$mech = BTDT::Test->get_logged_in_mech($URL, 'otheruser@example.com', 'something');
ok($mech, 'Logged in as Other user');

$content = $mech->fragment_request(VIEW_PATH, id => $task->id, tokens => "");

lacks_string($content, "02 other task", "hides task summary from other user");
lacks_string($content, "1234some", "hides tag from other user");
lacks_string($content, "5678tags", "hides other tag to logged in user");
lacks_string($content, "with a description", "hides task description from other user");
lacks_string($content, 'gooduser@example.com', "hides user email address from other user");
