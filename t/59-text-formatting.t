use warnings;
use strict;

use BTDT::Test tests => 8;
use Test::LongString;

my ($text, $linked);

$text = <<'END';
this is a test blah
blah blah blah references #ABCD
foo bar baz
and one #MORE
END

$linked = <<'END';
this is a test blah
blah blah blah references <a href="http://task.hm/ABCD" target="_blank">#ABCD</a>
foo bar baz
and one <a href="http://task.hm/MORE" target="_blank">#MORE</a>
END

is_string(BTDT->autolinkify($text), $linked, "works at end of line in multiline");

$text = <<'END';
this is a simple #TEST okay?
and #MORE now
but#N0Tthis
or #TH1Sokay
END

$linked = <<'END';
this is a simple <a href="http://task.hm/TEST" target="_blank">#TEST</a> okay?
and <a href="http://task.hm/MORE" target="_blank">#MORE</a> now
but#N0Tthis
or #TH1Sokay
END

is_string(BTDT->autolinkify($text), $linked, "works with multiples, in the middle of the line");

$text   = 'and this works #TOO';
$linked = 'and this works <a href="http://task.hm/TOO" target="_blank">#TOO</a>';
is_string(BTDT->autolinkify($text), $linked, "works with end of line, no newline");

$text   = '#TOO';
$linked = '<a href="http://task.hm/TOO" target="_blank">#TOO</a>';
is_string(BTDT->autolinkify($text), $linked, "only thing around");

$text   = 'foo#TOO';
is_string(BTDT->autolinkify($text), $text, "not linked");

$text   = '#TOObar';
is_string(BTDT->autolinkify($text), $text, "not linked");

# Based on http://task.hm/34XRX
TODO: {
    local $TODO = "This doesn't work yet.";
    my $input  = q{Replace the original "<Directory "/www/private">" block};
    my $output = q{<p>Replace the original "&lt;Directory "/www/private"&gt;" block</p>}."\n";
    is_string(BTDT->format_text($input), $output, "denied tag is escaped and content passed thru");
}

$text   = 'this is an evernote:///view/73126/s1/4e27309f-a7ed-421f-8214-e24daff25b22/4a22809s-f7ad-422f-8214-e14dfff25123/ url';
$linked = 'this is an <a href="evernote:///view/73126/s1/4e27309f-a7ed-421f-8214-e24daff25b22/4a22809s-f7ad-422f-8214-e14dfff25123/" target="_blank">evernote:///view/73126/s1/4e27309f-a7ed-421f-8214-e24daff25b22/4a22809s-f7ad-422 f-8214-e14dfff25123/</a> url';
is_string(BTDT->autolinkify($text), $linked, "linked evernote uri");

# XXX TODO We should be testing more functionality of BTDT->format_text too
