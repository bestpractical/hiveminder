use warnings;
use strict;

=head1 DESCRIPTION

Formatting task comments for html and email

=cut

use BTDT::Test tests => 6;
use BTDT::Model::TaskEmail;
use Test::LongString;

my $task_email = BTDT::Model::TaskEmail->new;

my ($text, $dequoted);

$text = <<'END';
this is a test blah
blah blah blah
foo bar baz


more text
happy, fun!

I'm going > to be tricky
yes, > I am

a
b
c
d

Jason / hiveminders with Hiveminder wrote:
> Jason <jhaas@bestpractical.com> has moved a task into hiveminders
>    http://hiveminder.com/task/9P7
> 
> Task information:
> =============================================================================
> Message IDs!
> We're still generating  message IDs that are too short and may not be globally unique
> =============================================================================
> 
> If you reply to this email, your reply will be added to the task's notes 
> and Hiveminder will notify the other members of your group.
> 
> 
> ------------------------------------------------------------------------
> 
> Jason <jhaas@bestpractical.com> said (Fri Aug 04 2006 12:07PM PDT)
> We're still generating   message IDs that are too short and may not be globally unique
>  ---
END

$dequoted = <<'END';
this is a test blah
blah blah blah
foo bar baz


more text
happy, fun!

I'm going > to be tricky
yes, > I am

a
b
c
d
END

chomp $dequoted;

is($task_email->_remove_quoted($text), $dequoted, "dequotes with message on top");

$text = <<'END';
Jason / hiveminders with Hiveminder wrote:
> Jason <jhaas@bestpractical.com> has moved a task into hiveminders
>    http://hiveminder.com/task/9P7
> 
> Task information:
> =============================================================================
> Message IDs!
> We're still generating  message IDs that are too short and may not be globally unique
> =============================================================================
this is a test blah
blah blah blah
foo bar baz
END

$dequoted = <<'END';
this is a test blah
blah blah blah
foo bar baz
END

chomp $dequoted;

is($task_email->_remove_quoted($text), $dequoted, "dequotes with message on bottom");

$text = <<'END';
this is a test blah
blah blah blah
foo bar baz
> Jason <jhaas@bestpractical.com> has moved a task into hiveminders
>    http://hiveminder.com/task/9P7
> 
> Task information:
> =============================================================================
> Message IDs!
> We're still generating  message IDs that are too short and may not be globally unique
> =============================================================================
END

$dequoted = <<'END';
this is a test blah
blah blah blah
foo bar baz
END

chomp $dequoted;

is($task_email->_remove_quoted($text), $dequoted, "dequotes without quoted block intro");

$text = <<'END';
foo bar
Jason / hiveminders with Hiveminder wrote:
> Jason <jhaas@bestpractical.com> has moved a task into hiveminders
>    http://hiveminder.com/task/9P7
> 
> Task information:
> =============================================================================
> Message IDs!
> We're still generating  message IDs that are too short and may not be globally unique
> =============================================================================
this is a test blah
blah blah blah
foo bar baz
END

chomp $text;

is($task_email->_remove_quoted($text), $text, "text left alone due to interleaving");

$text = <<'END';
foo bar



Jason / hiveminders with Hiveminder wrote:
> Jason <jhaas@bestpractical.com> has moved a task into hiveminders
>    http://hiveminder.com/task/9P7
> 
> Task information:
> =============================================================================
> Message IDs!
> We're still generating  message IDs that are too short and may not be globally unique
> =============================================================================

this is a test blah
blah blah blah
foo bar baz
END

chomp $text;

is($task_email->_remove_quoted($text), $text, "text left alone due to interleaving with spaces");

TODO: {
    local $TODO = "We currently fail at stripping multiline 'On X, Y wrote:' lines";
$text = <<'END';
No problem!  You guys are awesome.  I don't think I've ever seen new
functionality appear and bugs disappear so quickly.  Thank you!!

On 6/18/08 5:05 PM, "Alex Vandiver / hiveminders feedback with Hiveminder"
<comment-403795-fijupravydri@tasks.hiveminder.com> wrote:
> Task information:
> =============================================================================
> Message IDs!
> We're still generating  message IDs that are too short and may not be globally unique
> =============================================================================
END

$dequoted = <<'END';
No problem!  You guys are awesome.  I don't think I've ever seen new
functionality appear and bugs disappear so quickly.  Thank you!!
END

chomp $dequoted;

is_string($task_email->_remove_quoted($text), $dequoted, "works with 'On X, Y wrote:' lines with internal newlines");
}
