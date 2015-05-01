use warnings;
use strict;

=head1 DESCRIPTION

This is a test for any unicode/i18n bugs we uncover and fix

=cut

use charnames ':full';
use BTDT::Test tests => 22;
use Test::LongString;

# See the caveats section of Test::More
my $builder = Test::More->builder;
binmode $builder->output,         ":utf8";
binmode $builder->failure_output, ":utf8";
binmode $builder->todo_output,    ":utf8";

my $server = BTDT::Test->make_server;

my $URL = $server->started_ok;

my $mech = BTDT::Test->get_logged_in_mech($URL);

# Test for a Text::Markdown bug with HTML blocks that contain UTF-8
$mech->fill_in_action_ok('tasklist-new_item_create',
                         summary => 'A task with a unicode description',
                         description => <<END_DESC);
The \N{GREEK SMALL LETTER ALPHA} and the \N{GREEK SMALL LETTER OMEGA}
END_DESC


ok($mech->submit());

$mech->content_contains('unicode description', 'created a task');

# Check RSS feed
$mech->follow_link( text => "Atom");
$mech->content_contains("\N{GREEK SMALL LETTER ALPHA}");
$mech->back;


$mech->fill_in_action_ok('quicksearch', query => 'unicode');
ok($mech->submit());

$mech->content_contains('unicode description');
$mech->content_contains("\N{GREEK SMALL LETTER ALPHA}");

# Test for a dispatcher/handler infinite redirect
# unfortunately this doesn't trigger the behavior
my $beta = "\N{GREEK SMALL LETTER BETA}";
$mech->fill_in_action_ok('tasklist-new_item_create',
                         summary => "A task with a unicode tag [${beta}eta]");
ok($mech->submit());
$mech->content_contains('unicode tag', 'created a task');
$mech->content_contains("${beta}eta");
my $uri = "$URL/list/tag/".URI::Escape::uri_escape_utf8(${beta})."eta";
is($uri, $URL.'/list/tag/%CE%B2eta');
$mech->get($uri);
$mech->content_contains('unicode tag', 'successfully searched');
$mech->content_contains("${beta}eta");

# Sign up with a name that contains UTF-8

$mech->follow_link_ok(text => 'Logout');
$mech->follow_link_ok(url_regex => qr{/splash/signup});

my $name = "Ask Bj\N{LATIN SMALL LETTER O WITH STROKE}rn Hansen";

# Cause an error, and make sure they give us back the name correctly
$mech->fill_in_action_ok('signupform',
                         name => $name);

ok($mech->submit);

use Encode;
$mech->content_contains($name,"contains ask");

# HTML::Truncate fail
my $comment = Encode::decode_utf8(<<"EOT");
看來能勝任。應安排時間嘗試一下。
EOT

chomp $comment;

my $snipped = Encode::decode_utf8(<<"EOT");
<p>看來能…</p>
EOT

chomp $snipped;

is_string( BTDT->format_text($comment, short => 1, chars => 3), $snipped, "UTF8 truncate okay" );

1;
