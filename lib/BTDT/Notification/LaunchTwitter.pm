use warnings;
use strict;

package BTDT::Notification::LaunchTwitter;
use base qw/BTDT::Notification/;

=head1 NAME

BTDT::Notification::ProLaunch - We're launching Pro!

=head1 ARGUMENTS

C<to>

=head2 setup

Sets up the email.

=cut

sub setup {
    my $self = shift;
    $self->SUPER::setup(@_);

    $self->subject("Hiveminder Loves You! (And now supports Twitter and SMS)");

    my $leadin;
    my $leadin_html;
    if ($self->to->pro_account) {
        $leadin = << '        END_BODY';
   We have a small present for you today. We've been spending an awful
   lot of time using Twitter to broadcast what we're up to. And we've
   spent enough time leaving ourselves memos by Twitter that we
   decided it was time to do something.
        END_BODY
        $leadin_html = << '        END_BODY';
<p>We have a small present for you today. We've been spending an awful lot of time using Twitter to broadcast what we're up to. And we've spent enough time leaving ourselves memos by Twitter that we decided it was time to do something.</p>
        END_BODY
    } else {
        $leadin = << '        END_BODY';
   There's nothing romantic about a gift of todo lists; there. We said it.
   But we wanted to offer you a little something to show you how much we love
   you. For one day only, use the coupon code HIVEMINDERLOVE to get 25% off
   of a year of Hiveminder Pro.  Just visit:

       https://hiveminder.com/account/upgrade

   But, we're not writing just to tell you how much we love you. We have
   another present for you today. We've been spending an awful lot of time
   using Twitter to broadcast what we're up to. And we've spent enough time
   leaving ourselves memos by Twitter that we decided it was time to do
   something.
        END_BODY
        $leadin_html = << '        END_BODY';
<p>There's nothing romantic about a gift of todo lists. There. We said it. But we wanted to offer you a little something to show you how much we love you. For one day only, use the coupon code <strong>HIVEMINDERLOVE</strong> to get 25% off of a year of Hiveminder Pro.&nbsp; Just visit:</p>

<p>&nbsp; &nbsp; <a href="https://hiveminder.com/account/upgrade">https://hiveminder.com/account/upgrade</a></p>

<p>But, we're not writing just to tell you how much we love you. We have another present for you today. We've been spending an awful lot of time using Twitter to broadcast what we're up to. And we've spent enough time leaving ourselves memos by Twitter that we decided it was time to do something.</p>
        END_BODY
    }

    $self->body($leadin . <<'    END_BODY');

   Today we're launching Hiveminder Integration for Twitter. If you're eager
   to get going, you can get started right now by visiting:

       http://hiveminder.com/prefs/twitter

   Using Hiveminder by Twitter works a lot like our IM and Jabber interfaces
   with a few important differences to take advantage of everything Twitter
   has to offer.

   Twitter lets you send private messages using the "d" command; to address
   messages straight to Hiveminder, just prefix them with "d hmtasks". You
   can use any of the Hiveminder IM commands to work with your existing
   tasks.

   To create your first task from Twitter, just tweet "d hmtasks call my mom
   tonight". Hiveminder will create the task and then tweet you back with the
   task id.

   If you want to do a bit more, just tweet "d hmtasks help" to find out how.

   One of the coolest things about Twitter is the ability to broadcast your
   thoughts and status to all your friends. Now you can add things to your
   todo list and let your friends know what you're up to at the same time.
   Just include "@hmtasks" somewhere in your tweet and Hiveminder will take
   care of the rest. And your friends might just help pressure you into
   getting stuff done ;)

   I've saved the best for last.  Through Twitter, you can now update
   Hiveminder by SMS.  In the US, just text your tweets to 40404. Outside the
   US, you'll want to refer to Twitter's SMS help.

   Be productive,

   Jesse, for Hiveminder
    END_BODY

    $self->html_body($leadin_html . <<'    END_BODY');

<p>Today we're launching Hiveminder Integration for Twitter. If you're eager to get going, you can get started right now by visiting:</p>

<p>&nbsp; &nbsp; <a href="http://hiveminder.com/prefs/twitter">http://hiveminder.com/prefs/twitter</a></p>

<p>Using Hiveminder by Twitter works a lot like our IM and Jabber interfaces with a few important differences to take advantage of everything Twitter has to offer.</p>

<p>Twitter lets you send private messages using the &quot;d&quot; command; to address messages straight to Hiveminder, just prefix them with &quot;d hmtasks&quot;. You can use any of the Hiveminder IM commands to work with your existing tasks. </p>

<p>To create your first task from Twitter, just tweet &quot;d hmtasks call my mom tonight&quot;. Hiveminder will create the task and then tweet you back with the task id. </p>

<p>If you want to do a bit more, just tweet &quot;d hmtasks help&quot; to find out how.</p>

<p>One of the coolest things about Twitter is the ability to broadcast your thoughts and status to all your friends. Now you can add things to your todo list and let your friends know what you're up to at the same time. Just include &quot;@hmtasks&quot; somewhere in your tweet and Hiveminder will take care of the rest. And your friends might just help pressure you into getting stuff done ;)</p>

<p>I've saved the best for last.&nbsp; Through Twitter, you can now update Hiveminder by SMS.&nbsp; In the US, just text your tweets to 40404. Outside the US, you'll want to refer to Twitter's SMS help.</p>

<p>Be productive,</p>

<p>Jesse, for Hiveminder</p>
    END_BODY
}

1;
