use warnings;
use strict;

=head1 DESCRIPTION

Tests for TaskTransaction code, which maintains task histories.

=cut

use BTDT::Test tests => 28;

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech($URL);
$mech->html_ok;


ok($mech->find_link( text => "01 some task" ), "Task edit link exists");
$mech->follow_link_ok( text => "01 some task" );

like($mech->uri, qr|/task/3/edit|, "On task edit page" );

ok($mech->find_link( url_regex =>qr/history/ ), "Task history link exists");
$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 1));
$mech->form_number(2); $mech->click_button( value => 'Save' );
$mech->content_lacks( "changed" );
like($mech->uri, qr|/todo|, "Back to inbox" );
$mech->follow_link_ok( text => "01 some task" );
like($mech->uri, qr|/task/3/edit|, "On task edit page" );


$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 1),
                         description => "new description",
			 due => '01-01-2010',
                        );
$mech->form_number(2); $mech->click_button( value => 'Save' );
like($mech->uri, qr|/todo|, "Back to inbox" );
$mech->follow_link_ok( text => "01 some task" );
like($mech->uri, qr|/task/3/edit|, "Still on edit page");

$mech->follow_link_ok( url_regex => qr|history|, "now on the history page" );
$mech->content_contains( "created", "We saw the 'task created' message in the history");
$mech->content_contains( "notes" );
$mech->content_contains( "due", "We saw the 'Due set to' message in the history");
$mech->follow_link_ok( url_regex => qr|edit| );

like($mech->uri, qr|/task/3/edit|, "Back on task edit page" );


$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UpdateTask", id => 1),
                         description => "newer description",
                         tags        => "foo bar",
                        );
$mech->form_number(2); $mech->click_button( value => 'Save' );
like($mech->uri, qr|/todo|, "Back to inbox" );
$mech->follow_link_ok( text => "01 some task" );
$mech->follow_link_ok( url_regex => qr|history|, "now on the history page" );
$mech->content_contains( "notes" );
$mech->content_contains( "changed tags of the task from &#39;&#39; to &#39;bar foo&#39;" );

1;

