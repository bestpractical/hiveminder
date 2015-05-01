use warnings;
use strict;

package BTDT::Notification::ProLaunch;
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

    $self->subject("Hiveminder Pro launches today!");

    $self->body(<<'    END_BODY');
   Today, we're releasing Hiveminder Pro, a major update to our online task
   management system. Here at Best Practical, we're addicted to Hiveminder's
   slick, simple task tracking and sharing, but that's not too surprising--
   we built Hiveminder to be the shared todo list we always wanted.  You
   don't have to take it from us, though. Sarah Linder of the Austin
   American-Statesman writes:

    "I am crazy about Hiveminder. I started using the online to-do list a
     little more than a year ago, and we're very content together. I had been
     lost, adrift -- trying different ways to track my stuff, but never
     settling down. Hiveminder made me less flaky, less absent-minded, less
     likely to wake up at 3 a.m. realizing I had forgotten something
     important. Hiveminder, you complete me."

   Last February, PC World Magazine ranked Hiveminder as one of the best Todo
   list apps on the web. Since then, we've been hard at work to make
   Hiveminder even better:

     * We've improved performance across the board
     * We've added new Google Calendar and iGoogle integrations
     * We've added new AOL IM and Jabber chat interfaces
     * We've significantly improved the API (more on that in the next few
       weeks)
     * We've added integrations with Firefox and IE7
     * We've cleaned up and streamlined the interface
     * We've made repeating tasks easier to use ...and a whole bunch more

   Today, we're launching Hiveminder Pro. It's $30/year (but read on to find
   out how to save a few bucks.) For your money, you get:

Reports

   Pretty charts and graphs are a great motivator and they can provide useful
   input about how you work. One of the folks here at Best Practical found
   out that he tends to get more work done on Wednesday than on every other
   day of the week combined and that his most productive times are when
   everyone else is out of the office at lunch. Of course, Hiveminder Pro
   reports are also available for your groups, so you can see who's
   overloaded, who's slacking off and whether you're getting ahead or falling
   behind. To turn on graphs and charts, visit
   https://hiveminder.com/account/upgrade

Attachments

   Many of you who use Hiveminder to collaborate with team members both
   inside and outside your organization have told us that you'd really like
   to use Hiveminder to share documents related to your tasks. The wait is
   over. As of today, each Pro user has a 500MB task attachment quota. You
   can work with attachments through the Web UI or simply attach them to
   tasks you create by email. Attachments you sent in before we created Pro
   accounts will magically appear when you upgrade at
   https://hiveminder.com/account/upgrade

Saved lists

   Hiveminder makes it easy to search and sort your task list. But until
   today, you needed to redo your searches day after day. Hiveminder Pro
   gives you a "Save list" link on every task list. It's easy to build a list
   of all items tagged "shopping" or everything you need to do for your boss.
   We have a bunch more things you'll be able to do with your saved lists
   soon, too! To start saving your lists, visit
   https://hiveminder.com/account/upgrade

SSL Security

   On today's wider web, protecting your information from prying eyes is
   increasingly important to many of you. Hiveminder has always protected
   your password when you log in, but today we've enabled SSL (https)
   encrypted logins for ALL Hiveminder users. Pro users can choose to protect
   all their interactions with Hiveminder by visiting https://hiveminder.com
   to log in.  To protect your account with SSL, visit
   https://hiveminder.com/account/upgrade

with.hm

   I've saved my favorite for last. Hiveminder has always made it easy for
   you to create incoming addresses so others can send you tasks by email,
   but until today it was still hard to assign a task to someone else from
   your email client. Today, we're introducing a never-before-seen way to
   talk to an application from any email client.

   Once you set up your secret code in your Hiveminder Pro settings, you can
   send a task to anyone on the planet by appending ".mysecret.with.hm" to
   their email address. You don't need to do anything to configure your email
   client.

   If I wanted to ask the president to give me a balanced budget, I'd open up
   my email client and dash off a note like this:

        To: president@whitehouse.gov.mysecret.with.hm
        Subject: Balanced budget, please?

        It would be great if you could take care of this next week!

        Thanks,
        Jesse

   Hiveminder Pro will make a task and notify the President that I've
   assigned him a task. If he's an existing Hiveminder user, the task will
   pop into his todo list. If not, he'll get an email with a URL to view and
   reply to the task I assigned him. To get started assigning
   tasks by email, just visit
   https://hiveminder.com/account/upgrade

It's time to go Pro!

   Hiveminder Pro accounts are just $30/year, but since you're a friend of
   ours (or a friend of a friend), we'd like to offer you (and your friends)
   an additional $5 discount.  Just enter LAUNCHCODE at
   https://hiveminder.com/account/upgrade
   The coupon is good through February 1st.

   If you know someone (or many someones) who could use the gift of
   productivity, you can use your coupon to give them Hiveminder Pro at
   https://hiveminder.com/account/gift

   In the coming weeks and months, we'll be adding a number of other really
   cool features to Hiveminder and Hiveminder Pro. We'd love to hear your
   feature suggestions. Just drop them in the "feedback" box on the left-hand
   side of every page on the site.

   Be Productive,

   Jesse, for Hiveminder

If you'd like to turn off service updates (like this one) again, you
can update your preferences at http://hiveminder.com/prefs
    END_BODY

    $self->html_body(<<'    END_BODY');
<p>Today, we're releasing Hiveminder Pro, a major update to our online task management system. Here at Best Practical, we're addicted to Hiveminder's slick, simple task tracking and sharing, but that's not too surprising-- we built Hiveminder to be the shared todo list we always wanted.  You don't have to take it from us, though. Sarah Linder of the Austin American-Statesman writes:</p>

<blockquote><p >&quot;I am crazy about Hiveminder. I started using the online to-do list a little more than a year ago, and we're very content together. I had been lost, adrift -- trying different ways to track my stuff, but never settling down. Hiveminder made me less flaky, less absent-minded, less likely to wake up at 3 a.m. realizing I had forgotten something important. Hiveminder, you complete me.&quot; </p></blockquote>

<p>Last February, PC World Magazine ranked Hiveminder as one of the best Todo list apps on the web. Since then, we've been hard at work to make Hiveminder even better:</p>

<ul>
<li> We've improved performance across the board </li>
<li> We've added new Google Calendar and iGoogle integrations </li>
<li> We've added new AOL IM and Jabber chat interfaces </li>
<li> We've significantly improved the API (more on that in the next few weeks) </li>
<li> We've added integrations with Firefox and IE7 </li>
<li> We've cleaned up and streamlined the interface </li>
<li> We've made repeating tasks easier to use ...and a whole bunch more </li>
</ul>

<p>Today, we're launching Hiveminder Pro. It's $30/year (but read on to find out how to save a few bucks.) For your money, you get:</p>

<h2>Reports</h2><p>Pretty charts and graphs are a great motivator and they can provide useful input about how you work. One of the folks here at Best Practical found out that he tends to get more work done on Wednesday than on every other day of the week combined and that his most productive times are when everyone else is out of the office at lunch. Of course, Hiveminder Pro reports are also available for your groups, so you can see who's overloaded, who's slacking off and whether you're getting ahead or falling behind. To turn on graphs and charts, visit <a href="https://hiveminder.com/account/upgrade">https://hiveminder.com/account/upgrade</a></p>

<h2>Attachments</h2>
<p>Many of you who use Hiveminder to collaborate with team members both inside and outside your organization have told us that you'd really like to use Hiveminder to share documents related to your tasks. The wait is over. As of today, each Pro user has a 500MB task attachment quota. You can work with attachments through the Web UI or simply attach them to tasks you create by email. Attachments you sent in before we created Pro accounts will magically appear when you upgrade at <a href="https://hiveminder.com/account/upgrade">https://hiveminder.com/account/upgrade</a> </p>

<h2>Saved lists</h2>
<p>Hiveminder makes it easy to search and sort your task list. But until today, you needed to redo your searches day after day. Hiveminder Pro gives you a &quot;Save list&quot; link on every task list. It's easy to build a list of all items tagged &quot;shopping&quot; or everything you need to do for your boss. We have a bunch more things you'll be able to do with your saved lists soon, too! To start saving your lists, visit <a href="https://hiveminder.com/account/upgrade">https://hiveminder.com/account/upgrade</a></p>

<h2>SSL Security</h2><p> On today's wider web, protecting your information from prying eyes is increasingly important to many of you. Hiveminder has always protecte your password when you log in, but today we've enabled SSL (https) encrypted logins for ALL Hiveminder users. Pro users can choose to protect all their interactions with Hiveminder by visiting <a href="https://hiveminder.com" >https://hiveminder.com</a> to log in. To protect your account with SSL, visit <a href="https://hiveminder.com/account/upgrade">https://hiveminder.com/account/upgrade</a></p>

<h2>with.hm</h2>
<p>I've saved my favorite for last. Hiveminder has always made it easy for you to create incoming addresses so others can send you tasks by email, but until today it was still hard to assign a task to someone else from your email client. Today, we're introducing a never-before-seen way to talk to an application from any email client.</p>

<p>Once you set up your secret code in your Hiveminder Pro settings, you can send a task to anyone on the planet by appending &quot;.mysecret.with.hm&quot; to their email address. You don't need to do anything to configure your email client.</p>

<p>If I wanted to ask the president to give me a balanced budget, I'd open up my email client and dash off a note like this:</p>
<blockquote>

<pre>
To: president@whitehouse.gov.mysecret.with.hm
Subject: Balanced budget, please?

It would be great if you could take care of this next week!

Thanks,
Jesse
</pre>
</blockquote>
<p>Hiveminder Pro will make a task and notify the President that I've assigned him a task. If he's an existing Hiveminder user, the task will pop into his todo list. If not, he'll get an email with a URL to view and reply to the task I assigned him. To get started assigning<br /> tasks by email, just visit <a href="https://hiveminder.com/account/upgrade">https://hiveminder.com/account/upgrade</a></p>

<h2>It's time to go Pro!</span></h2>

<p><b>Hiveminder Pro accounts are just $30/year</b>, but since you're a friend of ours (or a friend of a friend), we'd like to offer you (and your friends) <b>an additional $5 discount</b>.  Just enter <strong >LAUNCHCODE</strong> at <a href="https://hiveminder.com/account/upgrade" >https://hiveminder.com/account/upgrade</a>  The coupon is good through February 1st.</p>

<p >If you know someone (or many someones) who could use the gift of productivity, you can use your coupon to give them Hiveminder Pro at <a href="https://hiveminder.com/account/gift" >https://hiveminder.com/account/gift</a></p>

<p>In the coming weeks and months, we'll be adding a number of other really cool features to Hiveminder and Hiveminder Pro. We'd love to hear your feature suggestions. Just drop them in the &quot;feedback&quot; box on the left-hand side of every page on the site.</p>

<p>Be Productive,</p>

<p>Jesse, for Hiveminder</p>

<hr>
<p>If you'd like to turn off service updates (like this one) again, you can update your preferences at <a href="http://hiveminder.com/prefs">http://hiveminder.com/prefs</a></p>
    END_BODY
}

1;
