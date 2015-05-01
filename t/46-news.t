use warnings;
use strict;

=head1 DESCRIPTION

Test the news page -- creating, viewing, and the Atom feed

=cut

use BTDT::Test tests => 29;

my $user = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
$user->create(
    name     => 'Some Staffer',
    email    => 'staff@localhost',
    password => 'staffer',
    access_level => 'staff',
    email_confirmed => 1);

ok($user->id, 'Created a staff user');

my $server = BTDT::Test->make_server;
my $URL = $server->started_ok;

my $mech = BTDT::Test->get_logged_in_mech($URL, 'staff@localhost', 'staffer');

ok($mech, "Logged in as Some Staffer");

$mech->follow_link_ok(text => 'News');

$mech->content_contains('Add a news item', 'Staffers can add news');

$mech->fill_in_action_ok('newnews', title => 'Test news article', content => 'Newsnewsnews. More news.');
$mech->submit_html_ok();

$mech->content_contains('Newsnewsnews');

# Make sure we don't create two articles in the same second, since
# that can cause them to sort incorrectly.
sleep(2);

$mech->fill_in_action_ok('newnews', title => 'Second Test news article', content => 'Article 2. Hooray!');
$mech->submit_html_ok();

$mech->content_contains('Article 2');

$mech->follow_link_ok(text => 'Edit', n => 1);

$mech->fill_in_action_ok($mech->moniker_for('BTDT::Action::UpdateNews', id => 2),
                         content => 'Edited article 2');
$mech->submit_html_ok();

$mech->content_contains('Edited article', 'Edited a news post');


# Log in again as not-a-staffer
$mech = BTDT::Test->get_logged_in_mech($URL);

$mech->follow_link_ok(text => 'News');

$mech->content_lacks('Add a news item', "Non-staffers can't post news");
$mech->content_contains('Edited article', 'See the first news post');
$mech->content_contains('Second Test news', 'See the second news post');
$mech->content_contains('<b>Second Test news article</b> by <span class="username">Some Staffer</span>', 'Permissions allow you to see the poster\'s name');

$mech->get_ok("$URL/news/atom");

use XML::Atom;

my $feed = XML::Atom::Feed->new(\($mech->content));

ok($feed, "Parsed an atom feed");

like($feed->link->href, qr{/news$});
is([$feed->entries]->[0]->title,  'Second Test news article');
is([$feed->entries]->[0]->content->body, 'Edited article 2');
is([$feed->entries]->[0]->author->name, 'Some Staffer');
is([$feed->entries]->[1]->title, 'Test news article');
is([$feed->entries]->[1]->content->body, 'Newsnewsnews. More news.');
is([$feed->entries]->[1]->author->name, 'Some Staffer');
