use warnings;
use strict;

=head1 DESCRIPTION

Test the text export and re-import functionality.

=cut

use BTDT::Test tests => 8;
use Test::LongString;
use IO::File;

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');


my $URL = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech($URL);
isa_ok($mech, 'Test::WWW::Mechanize');

# count the tasks
my $initial_task_count = count_tasks($mech->content);

# download the task export.
$mech->follow_link_ok(url_regex => qr{feed/format/text});

my $tempfile = Jifty::Test->test_file(
    Jifty::Util->absolute_path("t/text-export")
);
open my $FILE, ">", $tempfile;
print $FILE $mech->content;
close $FILE;

# XXX check that the text is sane

# assume that 28-roundtrip catches brokenness of task parsing within a line
# for now; but given the test failures we're seeing, maybe not.

# upload it again
$mech->get_ok($URL."/upload");
$mech->fill_in_action_ok($mech->moniker_for("BTDT::Action::UploadTasks"),
			 file => $tempfile);
$mech->submit_html_ok(value => "Update it!");

# check the upload, make sure we don't have anything new
is(count_tasks($mech->content), $initial_task_count,
   "Export and re-import of unchanged text kept the same number of tasks");

sub count_tasks {
    my $text = shift;
    my @matches = $text =~ m/<span class="task_summary">/g;
    return scalar @matches;
}
