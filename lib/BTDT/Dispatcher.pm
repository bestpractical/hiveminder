use warnings;
use strict;

package BTDT::Dispatcher;
use Jifty::Dispatcher -base;

use Number::RecordLocator;
our $LOCATOR = Number::RecordLocator->new();

use List::MoreUtils qw(all pairwise);
use CGI::Simple::Cookie;

# Any page that is NOT one of these
our $RESTRICTED = qr{^/(?!(
                         feeds|let|errors|dhandler|static|__jifty|fragments/no_auth|favicon.ico|
                         legal|splash|help|opted_out|about|braindump|news|tour|pro|
                         (mobile|mini)/login|integration|oauth($|/request_token|/access_token)|=|
                         pingdom|
                         services/rest
                     )($|/))}x;

=head1 BTDT's dispatcher

=head2 fragment_handler

We explicitly allow a small set of paths for fragments, and otherwise
skip the dispatcher entirely for page regions.

=cut

sub fragment_handler {
    my $path = Jifty->web->request->path;
    if ($path !~ m{^/(fragments/
                     |mini/fragments/
                     |account/fragments/
                     |task/_fragments/
                     |groups/dashboard/fragments/
                     |prefs/jott/
                     |admin/orders/
                     |admin/coupons/
                     |__jifty/admin/requests/
                     |empty$
                     |__jifty/empty$
                     )
                  }x
              or ($path =~ m{^(/__jifty)?/admin} and Jifty->web->current_user->access_level ne "staff")) {
        warn "Bad fragment request path: $path\n";
        Jifty->web->render_template("/empty");
    } else {
        Jifty->web->render_template($path);
    }
}

before '*' => run {
    # Sniff user agent
    if ((Jifty->web->request->user_agent || '') =~ /(?:hiptop|Blazer|Novarra|Vagabond|SonyEricsson|Symbian|NetFront|UP.Browser|UP.Link|Windows CE|MIDP|J2ME|DoCoMo|J-PHONE|PalmOS|PalmSource|iPhone|iPod|AvantGo|Nokia|Android|webOS)/io )  {
        set mobile_ua => '1';
    } else {
        set mobile_ua => '0';
    }

    # If we don't have a valid login yet, check for the old cookie
    return if Jifty->web->current_user->id;
    my %cookies = CGI::Simple::Cookie->parse(Jifty->web->request->env->{HTTP_COOKIE});
    my $oldname = 'JIFTY_SID_' . Jifty->config->framework('Web')->{'Port'};
    return unless $cookies{$oldname};

    # They have an old-style cookie
    my $session = Jifty->web->session->id;
    Jifty->web->session->load( $cookies{$oldname}->value );

    if ( my $userid = Jifty->web->session->get('user_id') ) {
        # We have a valid old session, let's use it
        Jifty->web->current_user( BTDT::CurrentUser->new( id => $userid ) );
        Jifty->web->session->set_cookie;
    } else {
        # Restore the session they had before
        Jifty->web->session->load( $session );
    }
};

# Deny actions based on who you are
before '*' => run {
    my $api = Jifty->api;
    unless (Jifty->web->current_user->access_level || '' eq 'staff') {
        $api->hide(qr/^BTDT::Action::(Create|Update|Delete)(News|Coupon)$/);
        $api->hide("CloseIMAPConnection");
    }
    unless (Jifty->web->current_user->pro_account) {
        $api->hide(qr/^BTDT::Action::(Create|Update|Delete|Search)(List|TaskAttachment)$/);
        $api->hide("ChangeListTokens");
        $api->hide("SendSupportRequest");
    }
    my $has_accepted_eula = Jifty->web->current_user->id ?
        ( Jifty->web->current_user->user_object->accepted_eula_version
        >= BTDT->current_eula_version ) : 0;

    unless ($has_accepted_eula) {
        # Non-user, or without EULA
        if ( Jifty->web->current_user->id and Jifty->web->request->path
                 !~ m{^/(?:logout|fragments|account/fragments|accept_eula|about|news|legal|tour|pro|__jifty|static|mobile)} )
            {
                # User, but not at accept_eula
                # XXX: for AJAX requests to the REST API we should be
                # smarter than redirecting to /accept_eula as an
                # action response
                Jifty->web->tangent( url => '/accept_eula' );
            }
        # We do this by hiding everything _not_ these things, rather than
        $api->deny(qr/^BTDT::Action/);
        $api->allow("AcceptEULA");
        $api->allow("ConfirmEmail");
        $api->allow("ConfirmLostPassword");
        $api->allow("EmailDispatch");
        $api->allow("GoLegit");
        $api->allow("GeneratePasswordToken");
        $api->allow("Login");
        $api->allow("ResendUserLink");
        $api->allow("SendFeedback");
        $api->allow("SendLostPasswordConfirmation");
        $api->allow("Signup");
    }

    # Superceded by TaskSearch
    $api->hide("SearchTask");

    # These BTDT actions aren't real actions
    $api->hide("ArgumentCacheMixin");
    $api->hide(qr/^BTDT::Action::Execute/);

    # These are just sketchy to put out at all
    $api->hide("CreateUser");
    $api->hide("SearchCoupon");
}

before GET '*' => run {
    # We need to lock this down again, because the ->allow calls above
    Jifty->api->deny(qr/.*/);
    # GeneratePasswordToken is used for login, and is readonly, thus safe
    Jifty->api->allow('GeneratePasswordToken');
    return unless Jifty->web->current_user->id;
    # TaskSearch is whitelisted because it's read-only, but only if the user is logged in
    Jifty->api->allow('TaskSearch');
};

# Before any page that's restricted, check credentials
before $RESTRICTED => run {

    # Not logged in, trying to access a protected page
    my $page;

    # If they're trying to get to a page that's not /splash and we've detected
    # that htey're mobile, let's give them the mobile login page
    if ( ( get 'mobile_ua' and Jifty->web->request->path !~ /^\/splash/ )
        || Jifty->web->request->path =~ /^\/mobile/ )
    {
        $page = '/mobile/login';
    } elsif ( Jifty->web->request->path =~ /^\/mini/ ) {
        $page = '/mini/login';
    } else {
        $page = '/splash/';
    }
    unless ( Jifty->web->current_user->id ) {
        if ( Jifty->web->request->path eq '/' ) {
            redirect $page;
        } else {
            tangent $page;
        }
    }

    # Let proxies know that this content shouldn't be cached
    Jifty->web->response->header( 'Cache-control' => 'private' );
    Jifty->web->response->header( 'Pragma' => 'no-cache' );
};

before HTTPS $RESTRICTED => run {
    # these pages always have SSL
    return if Jifty->web->request->path =~ m{^/(?:logout|accept_eula|fragments|__jifty|static|account(?:/.+)|index\.html|let/[^/]+/pro_signup/|$)};

    pro_lockdown('SSL');
};
# Protect elements directories
# do not anchor this, runs on _any_ level
before qr'/_elements/' => redirect "/errors/requested_private_component";

#Backwards compat for the bizarre offchance anyone kept these URLs
#around.
before '/legal/accept_eula' => redirect '/accept_eula';
before '/prefs/im'          => redirect '/prefs/IM';

before '/splash/lostactivation.html' => redirect '/splash/resend';
before '/splash/signup/resend.html'  => redirect '/splash/resend';
on '/splash/resend' => run {
    if (my $result = Jifty->web->response->result("resend")) {
        redirect '/splash/signup/confirm.html' if $result->content("address_confirm");
    }
    show '/splash/resend.html';
};

## Deprecated inbox
before qr'^/inbox(/.*)?' => run { redirect "/todo$1"};
before qr'^/groups/(\d+)/archive' => run { redirect "/groups/$1/all_tasks"  };

before qr'^/reports'       => run { pro_lockdown('reports') };
before qr'^/task/\w+/time' => run { pro_lockdown('time tracking') };

# we had bad links in our emails to the privacy policy
before '/privacy' => redirect '/legal/privacy';

before qr'^/fragments/tasklist/time' => run {
    pro_lockdown('time tracking');
};

# Deny model inspection unless you're logged in
before qr{^/=/model($|/)} => run {
    abort(403) unless Jifty->web->current_user->id;
};

before qr{^/api/?$}i => redirect '/=/help';

=head2 pro_lockdown feature

If the user is a pro user, nothing happens.

Otherwise, a message is displayed, telling the user the feature is pro-only,
and they're redirected to /pro.

=cut

sub pro_lockdown {
    my $feature = shift;

    return if Jifty->web->current_user->id
          and Jifty->web->current_user->user_object->pro_account;

    my $message = sprintf 'The %s feature is only available to Hiveminder Pro'
                        . ' users. <a href="%s">Upgrade now</a> to use %s!',
                            $feature,
                            Jifty->web->url(path => '/account/upgrade'),
                            $feature;

    my $result = Jifty::Result->new;
    $result->message($message);
    $result->action_class('Jifty::Action');
    Jifty->web->response->result( dontthinkso => $result );

    my $cont = Jifty::Continuation->new( request => Jifty::Request->new( path => '/pro' ), response => Jifty->web->response );
    my $url  = Jifty->web->url( path => '/pro', scheme => 'http' ) . '?J:CALL=' . $cont->id;
    Jifty->web->_redirect( $url );
}

## LetMes
before qr'^/let/(.*)' => run {
    my $let_me = Jifty::LetMe->new();
    $let_me->from_token($1);

    Jifty->api->deny(qr/^BTDT::Action/);
    Jifty->api->allow("SendFeedback");

    redirect '/errors/let_me/invalid_token' unless $let_me->validate;

    Jifty->web->temporary_current_user( $let_me->validated_current_user );

    my %args = %{ $let_me->args };
    set $_ => $args{$_} for keys %args;
    set let_me => $let_me;

    # These are the incoming actions which get allowed;
    # you want also to look at /html/let/*, which hand-add actions
    # and then invoke them.
    # XXX: Alex suggests that we shouldn't be able to do that,
    # but that's a fix for some other time.
    my %actions = (
        activate_account => 'GoLegit',
        reset_password   => 'ConfirmLostPassword',
        update_task      => qr'(Update|Accept)Task',
        opt_out          => 'UpdateUser',
        confirm_email    => 'ConfirmEmail',
        pro_signup       => qr'UpgradeAccount|ApplyCoupon',
    );

    Jifty->api->allow( $actions{ $let_me->path } ) if $actions{ $let_me->path };

    Jifty->web->request->add_action(
        moniker => 'confirm_email',
        class   => 'BTDT::Action::ConfirmEmail',
    ) if $let_me->path eq "confirm_email";
};

on qr'^/let/', => run {
    my $let_me = get 'let_me';
    show '/let/' . $let_me->path;
};

under qr'^/mobile' => [
    on qr'%(?!:login)$' => run {
        if ( !Jifty->web->current_user->id ) {
            # Not logged in, trying to access a protected page
            tangent '/mobile/login';
        }
    },
    on qr'(task|task_history|task_update)/(.*)' => run {
        set id => $2;
        my $page = $1;
        if ($page eq 'task_update') {
            $page = 'task';
            set mode => 'update';
        } else{
            set mode => 'read';

        }
        show "/mobile/$page";
    }
];

on qr'^/(?:|index.html)$' => run {
    if (get 'mobile_ua') {
        redirect '/mobile/';
    } else {
        redirect '/todo/';
    }
};

on qr'^(/mobile|/mini)?/logout', run {
    Jifty->web->current_user(undef);
    Jifty->web->session->remove_all;
    Jifty->web->redirect($1 || '/');
}

## Feeds
before qr'^/feeds/(.*)' => run {
    return if Jifty->web->temporary_current_user;
    redirect("/errors/feed/unrecognized-feed-url")
      unless ( $1 =~ '^(\w+)/(.*?)/(.*)' );

    my $auth_token    = URI::Escape::uri_unescape($1);
    my $address       = URI::Escape::uri_unescape($2);
    my $continue_path = $3;

    my $user = BTDT::CurrentUser->new( Email => $address );

    # XXX TODO prettier error message
    redirect('/errors/feed/permission-denied')
      unless ( $user->id && ( $auth_token eq $user->auth_token ) );

    Jifty->web->temporary_current_user($user);

    Jifty->api->deny(qr/^BTDT::Action/);
    Jifty->api->allow("TaskSearch");

    dispatch "/feeds/$continue_path";
};

on qr'^/feeds/(.*)' => run {
    redirect('/errors/feed/permission-denied')
        unless Jifty->web->temporary_current_user;

    if ($1 =~ /tasks/) {
        unless (get('collection')) {
            my $collection = BTDT::Model::TaskCollection->new();
            $collection->incomplete;
            $collection->limit(
                column   => 'owner_id',
                operator => '=',
                value    => Jifty->web->current_user->id
            );
            set collection => $collection;
        }
    }

};

on '/tag/*' => run {
    dispatch "/list/not/complete/tag/$1";
};

## Search (supports /search and /list)
before qr'^(/\w+)?/(list|search)(?:/(.*?))?(?:/page/(\d*))*$' => run {
    my $prefix  = $1 ||'';
    my $urltype = $2;
    my $page = defined $4 ? $4 : '1';

    my @tokens  = BTDT::Model::TaskCollection->split_tokens_url($3||'');
    set output_component => pop @tokens if $prefix eq "/feeds";
    set searchpath => BTDT::Model::TaskCollection->join_tokens_url(@tokens);
    set page => $page;
    Jifty->web->request->add_action(
        moniker   => 'search',
        class     => 'TaskSearch',
        arguments => {tokens => [@tokens]}
    );

    # if we have any non-token searches, redirect to a token-based path
    my %arguments;
    %arguments = (%arguments, %{ $_->arguments } )
      for grep {Jifty->api->qualify($_->class) eq 'BTDT::Action::TaskSearch'}
        Jifty->web->request->actions;
    delete $arguments{tokens};

    if (%arguments) {
        my $url = $prefix . "/$urltype/";
        $url .= BTDT::Model::TaskCollection->join_tokens_url( BTDT::Action::TaskSearch->arguments_to_tokens(%arguments) );

        # Clear out the actions so we don't see them after the redirect
        Jifty->web->request->clear_actions;
        Jifty->web->request->clear_state_variables;
        Jifty->web->clear_state_variables;
        redirect $url;
    }
};

on qr'^(/\w+)?/(?:list|search)(?:/(.*))?(?:/page/(\d+))?$' => run {
    my $prefix = $1 ||'';
    my $path = $prefix. "/search";
    my $search_action = Jifty->web->response->result("search");
    my $tasks = $search_action ? $search_action->content("tasks") : BTDT::Model::TaskCollection->new();
    if ($prefix eq "/feeds") {
        set collection => $tasks;
        show $prefix . "/" . get("output_component");
    } elsif ($prefix eq "/review") {
        # XXX: limit(column => 'complete', value => 0) doesn't to work here
        set tasks => join ",", map {$_->id}
                               @{$tasks->items_array_ref};
        set tokens => BTDT::Model::TaskCollection->join_tokens( grep { defined $_ } $tasks->tokens );
        show "/review/";
    } elsif ($prefix eq "/print") {
        set collection => $tasks;
        show "/print";
    } else {
        if (    $path eq '/search'
            and $search_action
            and $search_action->content("group") )
        {
            my $group = BTDT::Model::Group->new;
            $group->load( $search_action->content("group") );
            _setup_groupnav( $group );
        }
        show $path;
    }
};

# Task nav
sub _setup_tasknav {
    my $task = get('task');

    my $nav = Jifty->web->page_navigation;
    $nav->child("Edit"          => url => "edit");
    $nav->child("Discussion"    => url => "discussion");
    $nav->child("History"       => url => "history");

    if (Jifty->web->current_user->pro_account) {
        my $attachments = $task->attachments->count;
        my $attachments_label = $attachments ? "Attachments ($attachments)"
                                             : "Attachments";

        $nav->child($attachments_label => url => "attachments");

        $nav->child("Time Tracking"    => url => "time");
    }

    $nav->child("Delete"        => url => "delete");

    if ( $task->group_id ) {
        $nav->child( "Group (".$task->group->name.")",
                     url => "/groups/".$task->group_id );
    }

    my $path = Jifty->web->request->path;

    if ( $path =~ m{ / (view|edit|discussion|history|delete|attachments|time) $}x ) {
        my $page = $1;
        for my $child ($nav->children) {
            if ($child->url eq $page) {
                $child->active(1);
            }
        }
    }
};

# Tasks (record locator style; preferred)
on qr'^/task/([A-Za-z0-9]+)/attachment/(\d+)/?$' => run { redirect "/task/$1/attachment/$2/view" };
on qr'^/task/([A-Za-z0-9]+)/attachment/(\d+)/(view|download)' => run {
    my ( $task_id, $id, $type ) = ( $1, $2, $3 );

    my $task = BTDT::Model::Task->new();
    $task->load( $LOCATOR->decode( $task_id ) );

    redirect('/errors/task/forbidden')
        if not $task->id or not $task->current_user_can('read');

    my $file = BTDT::Model::TaskAttachment->new;
    $file->load( $id );

    redirect('/errors/task/forbidden')
        if not $file->id or not $file->current_user_can('read');

    set attachment => $file;
    show '/task/attachment/'.$type;
};

on qr'^/task/([A-Za-z0-9]+)/?$' => run { redirect "/task/$1/edit" };
on qr'^/task/([A-Za-z0-9]+)/(.*)' => run {
    my $id = $LOCATOR->decode($1);
    my $task = BTDT::Model::Task->new();
    $task->load($id);

    redirect('/errors/task/forbidden')
        if not $task->id or not $task->current_user_can('read');

    set task => $task;
    set id => $id;
    _setup_tasknav();
    show "/task/$2";
};

## Tasks (id style; deprecated)
on qr'^/tasks/(\d+)/?$' => run {
    my $rl = $LOCATOR->encode($1);
    redirect "/task/$rl/edit"
};

on qr'^/tasks/(\d+)/(.*)' => run {
    my $task = BTDT::Model::Task->new();
    $task->load($1);
    my $rl = $LOCATOR->encode($1);

    redirect('/errors/task/forbidden')
        if not $task->id or not $task->current_user_can('read');

    set task => $task;
    set id => $1;
    _setup_tasknav();
    show "/task/$2";
};



before qr'^/groups/(\d+)' => run {
    my $group = BTDT::Model::Group->new();
    $group->load($1);
    my $page = $2;
    redirect('/errors/group/forbidden') unless ($group->id && $group->current_user_can('read'));
    set group => $group;
    set group_id => $group->id;
    set id => $group->id;
    _setup_groupnav( $group, $page );
};



sub _setup_groupnav {
    my $group = shift;
    my $page  = shift;

    my $prefix = "/groups/".$group->id."/";

    my $nav = Jifty->web->page_navigation;

    $nav->child("Dashboard" => url => $prefix."dashboard/group-management")
        if $group->has_feature('Projects');

    $nav->child("My tasks"   => url => $prefix."my_tasks");
    $nav->child("Everybody else's tasks"   => url => $prefix."their_tasks");
    $nav->child("Up for grabs"   => url => $prefix."unowned_tasks");
    $nav->child("All tasks" => url => $prefix."all_tasks");

    $nav->child("Reports" => url => "/reports/group/" . $group->id)
        if Jifty->web->current_user->pro_account;

    if ($group->current_user_can("manage")) {
        $nav->child("Manage" => url => $prefix."manage");
    } else {
        $nav->child("Members" => url => $prefix."manage");
    }


    if ( defined $page ) {
        for my $child ($nav->children) {
            if ($child->url =~ m|/$page$|) {
                $child->active(1);
            }
        }
    }
}

on '/mini/date/*' => run {
    my $now = BTDT::DateTime->now();
    $now->truncate(to => "day");

    my $date = BTDT::DateTime->intuit_date_explicit( $1 );

    if ($date >= $now) {
        redirect '/mini/todo/on/'.$1;
    } else {
        redirect '/mini/history/'.$1;
    }

};


before qr'^/(?:on|mini\/history)/(.*)' => run {
    my $start = $1;
    my $starting = BTDT::DateTime->intuit_date_explicit($start)
                || BTDT::DateTime->today;

    # intuit_date_explicit gives us floating, so we want to force it to the
    # current user's timezone
    $starting->set_time_zone($starting->current_user_has_timezone || 'GMT');

    # now change to GMT which the database uses
    $starting->set_time_zone('GMT');

    my $today = BTDT::DateTime->today;
    $today->set_time_zone('GMT');

    my $ending = $starting->clone->add( days => 1 );
    my $dates = {};

    my $txns = BTDT::Model::TaskTransactionCollection->new();
    my ($tasks_alias, $histories_aliases) = $txns->between(starting => $starting, ending => $ending);

    while ( my $txn = $txns->next ) {
        my $date = $txn->modified_at->ymd;
        push @{ $dates->{$date}->{'txns'}->{ $txn->task_id } }, $txn;
        $dates->{$date}->{'tasks'}->{ $txn->task_id } = $txn->task;
    }
    set dates => $dates;
    set starting => $starting;
    set ending => $ending;
    set today => $today;
};

on '/on/*' => show '/radar';

on '/mini/history/*' => show '/mini/history';


## Group invitations
before '/groups/invitation/*/*' => run {
    my $action = $1;
    my $invite_id = $2;

    return unless $action eq "accept" or $action eq "decline";

    my $invite = BTDT::Model::GroupInvitation->new();
    $invite->load_by_cols( id => $invite_id );
    return unless $invite->id;
        my $class = 'BTDT::Action::'.ucfirst($action).'GroupInvitation';
    Jifty->api->allow($class);
    Jifty->web->request->add_action( moniker => 'groupinvite', class => $class, arguments => { invitation => $invite_id });
    set group_id => $invite->group->id;
};

#After we run the appropriate action
on '/groups/invitation/*/*'  => run {
    my $action = $1;
    my $result = Jifty->web->response->result('groupinvite');
    if (!$result || $result->failure) {
        if ($result) {
                set reason =>  $result->error;
        } else {
                set reason => "Sorry, but there was some sort of error accepting that invitation.  Please check that link again.";
        }

        show "/groups/invitation/$action";
    } else {
        redirect $action eq "accept" ? "/groups/" . (get 'group_id') ."/my_tasks" : "/todo";
    }
};


before '/mini/date/*' => run {
    my $now = BTDT::DateTime->now();
    $now->truncate(to => "day");

    my $date = BTDT::DateTime->intuit_date_explicit( $1 );

    if ($date >= $now) {
        redirect '/mini/todo/on/'.$1;
    } else {
        redirect '/mini/history/'.$1;

    }
};

on '/mini' => redirect '/mini/todo';

on '/mini/todo/on/*' => run {
    my $date = BTDT::DateTime->intuit_date_explicit( $1 );

    # intuit_date_explicit gives us floating, so we want to force it to the
    # current user's timezone
    $date->set_time_zone($date->current_user_has_timezone || 'GMT');

    set date => $date;
    show '/mini/date';

};



on qr'^/news' => run {
    if ( Jifty->web->current_user->id ) {
        my $now  = DateTime->now; # XXX: should this be Jifty::DateTime?
        my $user = BTDT::Model::User->new(
            current_user => BTDT::CurrentUser->superuser );
        $user->load( Jifty->web->current_user->id );
        $user->set_last_visit( $now->ymd . ' ' . $now->hms );
    }
};

on qr'/news/(\d+)(?:-.*)?' => run {
    my $news = BTDT::Model::News->new;
    $news->load($1);
    $news->id or abort 404;

    set title => $news->title;
    set id    => $news->id;
    show '/news/item';
};

before qr'^/account' => run {
    my $nav = Jifty->web->page_navigation;
    $nav->child("Hiveminder Store"    => url => "/account");
    $nav->child("Upgrade to Pro!"     => url => "/account/upgrade");
    $nav->child("Give a Gift!"        => url => "/account/gift");
    $nav->child("Order History"       => url => "/account/orders");
    $nav->child("Delete"              => url => "/account/delete");
};

before qr'^/admin' => run {
    my $nav = Jifty->web->page_navigation;
    $nav->child("Updates"     => url => "/admin");
    $nav->child("Orders"      => url => "/admin/orders");
    $nav->child("Coupons"     => url => "/admin/coupons");
    $nav->child("Performance" => url => "/admin/performance");
    $nav->child("Usage"       => url => "/admin/usage");
    $nav->child("Locations"   => url => "/admin/locations");
    $nav->child("IMAP"        => url => "/admin/imap");
};

on '/account/orders/*' => run {
    my $id = $1;
    substr( $id, 0, 8, '' );
    my $record = BTDT::Model::FinancialTransaction->new;
    $record->load( $id );

    if ( not $record->id or not $record->current_user_can('read') ) {
        redirect '/account/orders';
    }
    else {
        set record => $record;
        show '/account/one_order';
    }
};

before HTTP qr'^(/account/(?:upgrade|gift|orders)(?:.*)?|/let/[^/]+/pro_signup/|/admin/orders)' => run {
    return if Jifty->config->app('SkipSSL');
    my $path = $1;
    Jifty->web->_redirect( Jifty->web->url( path => $path, scheme => 'https' ) );
};

before '*' => run {
    return unless rand(100) < 5;

    # Non-logged in never get a pitch
    return unless Jifty->web->current_user->id;

    # If you're about to go pro, don't badger you
    return if Jifty->web->request->path =~ m{^/account/upgrade};

    my $u     = Jifty->web->current_user->user_object;
    my $today = DateTime->today->epoch;

    # Expires in two weeks or less
    if (     $u->pro_account
         and defined $u->paid_until
         and $u->paid_until < DateTime->today->add( weeks => 2 ) )
    {
        my $result = Jifty::Result->new;
        $result->action_class('Jifty::Action');
        $result->message(
            "Your Hiveminder Pro upgrade expires "
            . $u->english_paid_until
            . qq(.  Go <a href="/account/upgrade">renew it</a>.)
        );
        Jifty->web->response->result( 'upgradeaccountnotice' => $result );
    }
    # Expired at most three days ago
    elsif (     $u->was_pro_account and not $u->pro_account
            and DateTime->today->subtract( days => 3 ) < $u->paid_until )
    {
        my $result = Jifty::Result->new;
        $result->action_class('Jifty::Action');
        $result->error(
            "Your Hiveminder Pro upgrade expired "
            . $u->english_paid_until
            . qq(.  Go <a href="/account/upgrade">renew it</a>.)
        );
        Jifty->web->response->result( 'expirednotice' => $result );
    }
};

before qr{/reports/(?:([^/]+)/)?group/(\d+)$} => run {
    my $report = $1 || '';
    my $group_id = $2;

    my $group = BTDT::Model::Group->new();
    $group->load($group_id);

    redirect('/errors/group/forbidden')
        unless $group->id && $group->current_user_can('read');

    set group => $group;

    dispatch "/reports/$report";
};

before qr'^/reports' => run {
    my $nav   = Jifty->web->page_navigation;
    my $group = get 'group';
    my $add   = $group ? '/group/' . $group->id : '';

    $nav->child("Overview"          => url => "/reports$add");
    $nav->child("Statistics"        => url => "/reports/statistics$add");
    $nav->child("Completed Tasks"   => url => "/reports/completed$add");
    $nav->child("New Tasks"         => url => "/reports/created$add");

    $nav->child("Time tracking"     => url => "/reports/time$add")
        if Jifty->web->current_user->has_feature('TimeTracking');

    if ($group) {
        $nav->child("Owners"            => url => "/reports/owners$add");
    }
    else {
        $nav->child("Groups"            => url => "/reports/groups");
    }
};

# Admin
before qr'^(/__jifty)?/admin' => run {
    redirect '/errors/admin/unauthorized'
        if Jifty->web->current_user->access_level ne 'staff';
};

on qr'^/admin/orders/(\d{9,})/?' => run {
    my $id = $1;
    substr( $id, 0, 8, '' );
    my $record = BTDT::Model::FinancialTransaction->new;
    $record->load( $id );

    if ( not $record->id or not $record->current_user_can('read') ) {
        redirect '/admin/orders';
    }
    else {
        set record => $record;
        show '/admin/orders/one_order';
    }
};

on '/admin/users/edit/*' => run {
    my $id = $1;

    # If it's an email address, fetch the id
    if ( $id =~ /\@/ ) {
        my $user = BTDT::Model::User->new;
        $user->load_by_cols( email => $id );
        $id = $user->id if $user->id;
    }

    set action => Jifty->web->new_action(
        class       => 'UpdateUser',
        moniker     => 'useredit',
        arguments   => { id => $id }
    );

    show '/admin/users/edit';
};

## Project management (within groups)

my $GROUP = qr{^/groups/(?:\d+)}i;
my $VIEW  = qr{(?:project|milestone|owner)}i;
my $ID    = qr|(?:[^/]*)|i;

# Pull out all of the views and their IDs
before qr{$GROUP(?:/dashboard)?/(?:($VIEW)/($ID)(?:/($VIEW)/($ID)(?:/($VIEW)/($ID))?)?)} => run {
    # XXX TODO ACL
    redirect '/errors/404'
        unless get('group')->has_feature('Projects');

    my @views = ($1);
    my @ids   = ($2);
    my @recs  = ( projects_load_record( $1, $2 ) );

    if ( defined $3 ) {
        push @views, $3;
        push @ids,   $4;
        push @recs,  projects_load_record( $3, $4 );

        if ( defined $5 ) {
            push @views, $5;
            push @ids,   $6;
            push @recs,  projects_load_record( $5, $6 );
        }
    }

    set views    => \@views;
    set locators => \@ids;
    set records  => \@recs;

    pairwise { set $a => $b } @views => @ids;
};

# Load up the record of the last specified breakdown
before qr|$GROUP(?:/dashboard)?(?:/($VIEW)/($ID)){1,3}| => run {
    my ( $view, $locator ) = ( $1, $2 );

    my $record = projects_load_record( $view, $locator );

    redirect '/errors/task/forbidden' if not $record->id;

    set type    => $view;
    set locator => $locator;
    set record  => $record;
};

=head2 projects_load_record VIEW IDENTIFIER

Loads the appropriate record from the appropriate model for a project view

=cut

sub projects_load_record {
    my $view    = lc shift;
    my $locator = shift;

    my %viewmap = (
        project   => 'BTDT::Project',
        milestone => 'BTDT::Milestone',
        owner     => 'BTDT::Model::User',
    );

    my $record = $viewmap{$view}->new;

    # Try an load it up
    if ( $view eq 'owner' ) {
        $record->load_by_cols( email => $locator );
    }
    else {
        $record->load_by_locator( $locator );
    }
    return $record;
}

on qr{$GROUP(?:/dashboard)?(?:/$VIEW/$ID){1,3}/?$} => run {
    my @views = @{ get 'views' };
    my @ids   = @{ get 'locators' };

    my $view    = get 'type';
    my $locator = get 'locator';
    my $record  = get 'record';

    my $page;

    # First-level view
    if ( @views == 1 ) {
        $page = $view eq 'owner'
                    ? '/groups/dashboard/owner'
                    : '/groups/dashboard/breakdown';
    }

    # Second level view
    elsif ( @views == 2 ) {
        $page = '/groups/dashboard/two-of-three';
    }

    # Third level is always the same!
    else {
        $page = '/groups/dashboard/project-milestone-owner';
    }

    show $page;
};

on qr{$GROUP/dashboard(?:/$VIEW/$ID){0,3}/(.+)} => run {
    set "dashboard-page" => $1;
    show "/groups/dashboard/$1";
};

## Groups

on qr'^/groups/(\d+)$' => run {
    # XXX TODO ACL
    redirect ( get('group')->has_feature('Projects')
                 ? "/groups/$1/dashboard/group-management"
                 : "/groups/$1/my_tasks" );
};

on qr'^/groups/new/(.*)' => run {
    # XXX TODO, should this be an on rule or a before one?
    my $id = Jifty->web->response->result("newgroup")->content("id");
    redirect "/groups/$id/$1";
};

on qr'^/groups/(\d+)/(.*)' => run {
    my $page = $2;

    # XXX TODO ACL
    if ( $page eq 'dashboard' ) {
        redirect '/errors/404'
            unless get('group')->has_feature('Projects');
    }

    show "/groups/$page";
};

on '/prefs/twitter' => run {
    set 'instructions' => 'twitter';
    show "/prefs/IM";
};

### Stopwatch
on qr'/stopwatch/task/([A-Za-z0-9]+)' => run {
    my $id = $LOCATOR->decode( $1 );

    my $task = BTDT::Model::Task->new();
    $task->load( $id );

    redirect('/errors/task/forbidden')
        if not $task->id or not $task->current_user_can('read');

    set task_id => $id;
    show '/stopwatch';
};


### Debugging cookies
on qr'/debugging/set/(.*)' => run {
    set name => $1;
    show '/debugging/set';
};

### RTM compat
use BTDT::RTM;
on qr'/services/rest/' => run {
    BTDT::RTM->serve;
};

# Update session time after a REST hit
after qr'^/=/' => run {
    my $rest = Jifty->web->session->get('REST') || 0;
    Jifty->web->session->set( REST => $rest + 1 );
};

after '/__jifty/webservices/*' => run {
    # Ignore AJAX requests made by Real Browsers
    return if Jifty->web->request->user_agent || "" =~ /Mozilla|Opera/;
    my $webservices = Jifty->web->session->get('webservices') || 0;
    Jifty->web->session->set( webservices => $webservices + 1 );
};

# Redirect people trying to get to /static/tools/cli/todo.pl to the CPAN dist
on '/static/tools/cli/todo.pl' => run {
    Jifty->web->_redirect('http://search.cpan.org/dist/App-Todo/');
};

1;
