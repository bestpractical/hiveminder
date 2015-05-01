use warnings;
use strict;

=head1 DESCRIPTION

Tests the text, iCal and ATOM feeds

=cut

# {{{ Setup
use BTDT::Test tests => 116;
use Data::ICal;
use XML::Atom::Feed;
use XML::Atom::Entry;
use DateTime;
use DateTime::Duration;

#------ globals
my ($today, $tomorrow);
    
my $dt = DateTime->now;
$dt->set_time_zone('America/New_York');
$today = $dt->ymd;
my $dt2 = $dt + DateTime::Duration->new(days => 1);
$tomorrow = $dt2->ymd;

my $good_user = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
$good_user->load_by_cols(email => 'gooduser@example.com');

#---------

    
my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;

# }}}

my $mech = BTDT::Test->get_logged_in_mech($URL);
my $thirdtitle = "buy groceries";
my $thirddesc = "with a due date";
make_new_task_due_tomorrow($thirdtitle, $thirddesc);

# text personal feed

ok($mech->find_link( url_regex => qr'format/text'), "text feed link exists");
my $text_url = $mech->find_link( url_regex => qr'format/text')->url;
$mech->follow_link_ok( text => "Logout" );

$mech->get_ok($text_url);

$mech->content_like(qr|http://([\w\.]+)(:\d+)?/upload|, "text feed  $text_url has upload URL");
$mech->content_contains("01 some task (3)", "text feed has the first task");
$mech->content_contains("02 other task (4)\x{0d}\x{0a}    with a description", "text feed has the second task");

# text search feed
$mech = BTDT::Test->get_logged_in_mech($URL);
$mech->fill_in_action_ok("quicksearch", query => "task");
$mech->form_number(1); $mech->click_button( value => 'Search' );
ok($mech->find_link( url_regex => qr'format/text'), "search text feed link exists");
$text_url = $mech->find_link( url_regex => qr'format/text')->url;
$mech->follow_link_ok( text => "Logout" );

$mech->get_ok($text_url);

$mech->content_like(qr|http://([\w\.]+)(:\d+)?/upload|, "text feed has upload URL");
$mech->content_contains("01 some task (3)", "text feed has the first task");
$mech->content_contains("02 other task (4)\x{0d}\x{0a}    with a description", "text feed has the second task");

# print personal feed
$mech = BTDT::Test->get_logged_in_mech($URL);
ok($mech->find_link( url_regex => qr'/print/'), "print feed link exists");
$mech->follow_link_ok( url_regex => qr'/print/');

ok($mech->find_link(url_regex => qr|http://([\w\.]+)(:\d+)?/list/not/complete/owner/me/starts/before/tomorrow/accepted/but_first/nothing|), "print feed has search url");
ok($mech->find_link(text => "01 some task"), "print feed has the first task");
ok($mech->find_link(text => "02 other task"), "print feed has the second task");

# print search feed
$mech = BTDT::Test->get_logged_in_mech($URL);
$mech->fill_in_action_ok("quicksearch", query => "task");
$mech->form_number(1); $mech->click_button( value => 'Search' );
ok($mech->find_link( url_regex => qr'/print/'), "search print feed link exists");
$mech->follow_link_ok( url_regex => qr'/print/' );

ok($mech->find_link(url_regex => qr|http://([\w\.]+)(:\d+)?/list/query/task|), "print feed has search url");
ok($mech->find_link(text => "01 some task"), "print feed has the first task");
ok($mech->find_link(text => "02 other task"), "print feed has the second task");

# iCal personal feed
$mech = BTDT::Test->get_logged_in_mech($URL);
ok($mech->find_link( url_regex => qr|format/ical| ), "iCal feed link exists");
my $iCal = $mech->find_link( url_regex => qr|format/ical| )->url;
$mech->follow_link_ok( text => "Logout" );
like($iCal, qr|^webcal://|, "Is a webcal:// link");
$iCal =~ s/^webcal/http/;

$mech->get_ok( $iCal );

my $data = Data::ICal->new( data => $mech->content );
is($data->property('X-WR-CALNAME')->[0]->value, 'Hiveminder Tasks', 
   'iCal export is properly named for Google Calendar');
is($data->property('X-WR-CALNAME')->[0]->parameters->{'VALUE'}, 'TEXT',
   'iCal export X-WR-CALNAME is a VALUE=TEXT for gcal');
is($data->property('X-WR-CALDESC')->[0]->value, 
   'Exported tasks from http://hiveminder.com', 
   'iCal export has a X-WR-CALDESC for Google Calendar');
is($data->property('X-WR-CALDESC')->[0]->parameters->{'VALUE'}, 'TEXT',
   'iCal export X-WR-CALDESC is a VALUE=TEXT for gcal');
my $tz = $data->property('X-WR-TIMEZONE')->[0]->value;
isnt($tz, '', "iCal export has a X-WR-TIMEZONE for Google Calendar; it's $tz");
is($data->property('X-WR-TIMEZONE')->[0]->parameters->{'VALUE'}, 'TEXT',
   'iCal export X-WR-TIMEZONE is a VALUE=TEXT for gcal');

#X-WR-CALDESC;VALUE=TEXT:Upcoming events at the DNA Lounge nightclub:\n
# 375 Eleventh Street\, San Francisco.\n
# All events are 21+\, and a valid photo ID is required.
#X-WR-TIMEZONE;VALUE=TEXT:US/Pacific

is($data->property('CALSCALE')->[0]->value, 'gregorian',
   'iCal export has a correct CALSCALE');
is($data->property('METHOD')->[0]->value, 'publish',
   'iCal export has a correct METHOD');
is($data->property('PRODID')->[0]->value, '-//hiveminder.com//',
   'iCal export has a correct PRODID');

is(scalar @{$data->entries}, 4, "Four tasks in iCal feed");

is($data->entries->[0]->ical_entry_type, "VTODO", "Entry 1 is a TODO");
is(scalar @{$data->entries->[0]->property("URL")}, 1, "Has a URL");
like($data->entries->[0]->property("URL")->[0]->value, qr!http://([\w\.]+)(:\d+)?/task/5!,
   "URL is task link for task 3 (record locator 5)");

is($data->entries->[1]->ical_entry_type, "VEVENT", "Entry 2 is a VEVENT");
is(scalar @{$data->entries->[1]->property("URL")}, 1, "Has a URL");
like($data->entries->[1]->property("URL")->[0]->value, qr!http://([\w\.]+)(:\d+)?/task/5!,
   "URL is task link for task 3 (record locator 5)");
like($data->entries->[1]->property("DESCRIPTION")->[0]->value, qr!$thirddesc http://([\w\.]+)(:\d+)?/task/5!,
   "Description contains description text and task link for task 3 (record locator 5)"); 

like($data->entries->[1]->property("DTSTART")->[0]->value, qr{\d{8}},
     "VEVENT has a start date");
like($data->entries->[1]->property("DTEND")->[0]->value, qr{\d{8}},
     "VEVENT has an end date");
like($data->entries->[1]->property("DTSTAMP")->[0]->value, qr{\d{8}},
     "VEVENT has a date stamp with time and date"); # REQUIRED for google calendar to behave



is($data->entries->[2]->ical_entry_type, "VTODO", "Entry 3 is a TODO");
is(scalar @{$data->entries->[2]->property("URL")}, 1, "Has a URL");
like($data->entries->[2]->property("URL")->[0]->value, qr!http://([\w\.]+)(:\d+)?/task/3!,
   "URL is task link for task 1 (record locator 3)");

is($data->entries->[3]->ical_entry_type, "VTODO", "Entry 4 is a TODO");
is(scalar @{$data->entries->[3]->property("URL")}, 1, "Has a URL");
like($data->entries->[3]->property("URL")->[0]->value, qr!http://([\w\.]+)(:\d+)?/task/4!,
   "URL is task link for task 2 (record locator 4)");


# iCal search feed
$mech = BTDT::Test->get_logged_in_mech($URL);
$mech->fill_in_action_ok("quicksearch", query => "task");
$mech->form_number(1); $mech->click_button( value => 'Search' );
$mech->content_like(qr/01 some task/);
$mech->content_like(qr/02 other task/);

ok($mech->find_link( url_regex => qr|format/ical| ), "iCal feed link exists");
$iCal = $mech->find_link( url_regex => qr|format/ical| )->url;
$mech->follow_link_ok( text => "Logout" );
like($iCal, qr|^webcal://|, "Is a webcal:// link");
$iCal =~ s/^webcal/http/;
$mech->get_ok( $iCal );

$data = Data::ICal->new( data => $mech->content );
is(scalar @{$data->entries}, 2, "Two tasks in iCal feed");

# atom personal feed
$mech = BTDT::Test->get_logged_in_mech($URL);
ok($mech->find_link( url_regex => qr'format/atom'), "atom feed link exists");
my $atom_url = $mech->find_link( url_regex => qr'format/atom')->url;
$mech->follow_link_ok( text => "Logout" );

$mech->get_ok($atom_url);

my $atom = XML::Atom::Feed->new(\$mech->content);
ok($atom, "XML::Atom::Feed object created without error");
my @entries = $atom->entries;
is(scalar @entries, 3, "three tasks in atom feed");
ok($entries[0]->link, "first entry has a link");
like($entries[0]->link->href, qr!http://([\w\.]+)(:\d+)?/task/5!, "first entry's link looks right");
ok($entries[1]->link, "second entry has a link");
like($entries[1]->link->href, qr!http://([\w\.]+)(:\d+)?/task/3!, "second entry's link looks right");
ok($entries[2]->link, "third entry has a link");
like($entries[2]->link->href, qr!http://([\w\.]+)(:\d+)?/task/4!, "third entry's link looks right");

# atom search feed
$mech = BTDT::Test->get_logged_in_mech($URL);
$mech->fill_in_action_ok("quicksearch", query => "task");
$mech->form_number(1); $mech->click_button( value => 'Search' );
ok($mech->find_link( url_regex => qr'format/atom'), "search atom feed link exists");
$atom_url = $mech->find_link( url_regex => qr'format/atom')->url;
$mech->follow_link_ok( text => "Logout" );

$mech->get_ok($atom_url);

$atom = XML::Atom::Feed->new(\$mech->content);
ok($atom, "XML::Atom::Feed object created without error");
@entries = $atom->entries;
is(scalar @entries, 2, "two tasks in atom feed");

# Test that changing our password invalidates feeds

$mech = BTDT::Test->get_logged_in_mech($URL);
$mech->follow_link_ok(text => 'Preferences');
$mech->follow_link_ok(text => 'Security');

$mech->fill_in_action_ok('useredit',
                         current_password   => 'secret',
                         password           => 'moresecret',
                         password_confirm   => 'moresecret');

$mech->submit_html_ok();

$mech->content_contains('Your new password is now saved.', 'Changed password');

$mech->get($iCal);
like($mech->uri,qr/invalid_token/, "Feed links changed");

# Now try changing the feed links explicitly

$mech->follow_link_ok(text => 'To Do');
$iCal = $mech->find_link( url_regex => qr|format/ical| )->url;
$iCal =~ s/^webcal/http/;

$mech->get_ok($iCal);
unlike($mech->uri, qr/invalid_token/, 'Feed link works');

$mech->back();
$mech->follow_link_ok(text => 'Preferences');
$mech->follow_link_ok(text => 'Security');
$mech->fill_in_action_ok('regenauth');
$mech->submit_html_ok();

$mech->get($iCal);
like($mech->uri,qr/invalid_token/, "Feed links changed");


# Make sure that we aren't double-encoding URLs on searches that include
# a user and a tagcloud filter. See Task #T7V.
$mech->get($URL);

for (3..25) {
    my $tags = ($_ % 2) ? 'foo bar' : 'foo baz';
    my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->new(id => $good_user->id));
    $task->create(summary => "hello $_", tags => $tags);
}

$mech->follow_link_ok( url => '/search', "Found the search page");
$mech->fill_in_action_ok("search", owner => $good_user->email );
$mech->submit_html_ok();
$mech->follow_link_ok(text => 'foo');
$mech->content_unlike(qr/webcal:\S*%2540/, "Tagged-search result pages contain no double-encoded @ signs");
$mech->get_ok($URL);

# similar manifestation of #T7V shows up for multi-tag searches with a 
# space between them
$mech->follow_link_ok( url => '/search', "Found the search page");
$mech->fill_in_action_ok("search", tag => "foo bar" );
$mech->submit_html_ok();
$mech->follow_link_ok(text => 'foo');
$mech->content_unlike(qr/webcal:\S*%2520/, "Tagged-search result pages contain no double-encoded spaces");

 
$mech->get_ok($URL."/search/not/tag/bar foo");
$mech->content_contains("01 some task");
$mech->content_contains("02 other task");
$mech->content_lacks("hello 3");
$mech->content_lacks("hello 4");

$mech->follow_link_ok( url_regex => qr'format/text');
$mech->content_contains("01 some task");
$mech->content_contains("02 other task");
$mech->content_lacks("hello 3");
$mech->content_lacks("hello 4", "multi-value tokens do the right thing");

sub make_new_task_due_tomorrow {
    my $summary = shift;
    my $desc = shift;

    my $task = BTDT::Model::Task->new(current_user => BTDT::CurrentUser->new(id => $good_user->id));
    $task->create(summary => $summary, description => $desc, due => $tomorrow);
    return $task;
}
