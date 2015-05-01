use warnings;
use strict;

use BTDT::Test tests => 375;
use Encode ();

my $encoded = Encode::decode_utf8("\xd0\xbf\xd0\xbb\xd0\xb0\xd1\x82\xd0\xb5\xd0\xb6\xd0\xb8");

# Apache 404's anything with %2F in the path.  We insert a dispatcher
# rule to simulate that, so we can catch bugs that it would generate.
unshift @BTDT::Dispatcher::RULES_SETUP, [
    before => '*' => [
        [   run => sub {
                return unless Jifty->web->request->request_uri =~ /^[^?]+%2F/;
                warn "Simulated Apache hating on us!";
                Jifty->web->_redirect("/errors/404");
            },
        ]
    ]
];

my $server = Jifty::Test->make_server;
my $URL = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech($URL);

$mech->fill_in_action_ok("tasklist-new_item_create", summary => "New task", tags => $encoded);
$mech->submit("Created the task");

$mech->content_contains("New task", "Found the task");
$mech->content_contains($encoded, "Found the tag");

# Click on the tag
$mech->Test::WWW::Mechanize::follow_link_ok( {text => $encoded}, "Found tag in tagcloud" );
like($mech->uri, qr|/list/|);
like($mech->uri, qr|%25D0%25BF|, "Tag is properly encoded in URL");
$mech->content_contains("tag $encoded", "Found the tag in the search title");

# Find the task
$mech->content_contains("New task", "Found the task still");
$mech->content_contains($encoded, "Found the tag");

# Edit the task
$mech->Test::WWW::Mechanize::follow_link_ok( {text => "New task"}, "Found task edit link in tagcloud" );
like($mech->uri, qr|/task/\d+/edit|, "On edit page");
$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask"), summary => "New task summary");
$mech->click_button( value => "Save" );
$mech->content_contains("Task 'New task summary' updated.", 'updated tag');

# Back at tasklist
like($mech->uri, qr|/list/|);
like($mech->uri, qr|%25D0%25BF|, "Tag is properly encoded in URL");

$mech->content_contains("New task summary", "Found the task still");
$mech->content_contains($encoded, "Found the tag");

# URI encoding testing
# Test all of the 'reserved' URI characters plus a few innocents
my @chars = (qw{; / ? : @ & = + $ % foo ( ) %25 %2f %35 <evil>});
for my $i ( 0 .. $#chars) {
    my $tag = "some$chars[$i]thing";
    $mech->get($URL);
    $mech->fill_in_action_ok("tasklist-new_item_create", summary => "URI encoding $i", tags => $tag);
    $mech->submit("Created task with $chars[$i]");
    $mech->content_contains("URI encoding $i", "Found the task for $chars[$i]");
    $mech->text_contains($tag, "Found the tag '$tag'");
    $mech->content_lacks('<evil>', "we don't include unescaped HTML from tag names");

    for my $place (1 .. 2) {
        $mech->Test::WWW::Mechanize::follow_link_ok( {text => $tag, n => $place}, "Found tag link in place $place" );
        like($mech->uri, qr|/list/|);
        $mech->content_contains(Jifty::Web->escape("tag $tag"), "Found the tag '$tag' in the search title");
        $mech->content_contains("URI encoding $i", "Found the task");
        $mech->back;
    }
    $mech->Test::WWW::Mechanize::follow_link_ok({ text => "Search" });
    $mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::TaskSearch"), tag => $tag);
    $mech->form_number(2);
    $mech->click_button( value => "Search" );

    like($mech->uri, qr|/list/|);
    $mech->content_contains(Jifty::Web->escape("tag $tag"), "Found the tag '$tag' in the search subtitle");
    $mech->content_contains("URI encoding $i", "Found the task");

    # Make sure forms on the page still work
    $mech->fill_in_action_ok("quicksearch", query => "01");
    $mech->form_number(1);
    $mech->click_button( value => "Search" );
    $mech->content_contains("01 some task");
    unlike($mech->uri, qr|/errors/404|, "Not at a 404 page");
    $mech->back;
    
    $mech->back;
    $mech->back;

    my @links = $mech->find_all_links(text => "More...");
    $mech->get_ok( $links[-1]->url, "Opening action menu of last task using More... link" );

    $mech->form_number(2);
    my @deletes = grep {$_->value eq "Delete"} $mech->current_form->find_input(undef, 'submit');
    $mech->form_number(2);
    $mech->click_button( input => $deletes[-1]);
}
