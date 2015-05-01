package BTDT::View::RequestInspector;
use strict;
use warnings;
use Jifty::View::Declare -base;

template set => page { "Debugging cookie set" } content {
    Jifty->web->response->cookies->{HIVEMINDER_DEBUG} = {
        value   => get('name') || Jifty->web->current_user->username || Jifty->web->request->remote_host,
        path    => "/",
        expires => undef,
    };

    h2 { "What is this?" };
    div {
        "This sets a cookie which allows us to analyze and profile your requests.  ".
        "Using this, we can better determine why you may be having certain weird classes of bugs.  ".
        "The server may seem slightly slower while the cookie is enabled."
    };

    h2 { "What about privacy?" };
    div {
        outs "We take your privacy very seriously.  ".
            "This cookie does not let us see any of your tasks, it merely records more timing information than usual.  ".
                "See our ";
        hyperlink( label => "privacy policy", url => "/legal/privacy" );
        outs " for more details."
    };

    h2 { "How long does it stick around?" };
    div {
        outs "Until you close your browser.  If you want to turn it off earlier than that, just visit ";
        hyperlink( label => "here", url => "/debugging/clear" );
        outs ".";
    };
};

template clear => page { title => "Debugging cookie cleared" } content {
    Jifty->web->response->cookies->{HIVEMINDER_DEBUG} = {
        value   => undef,
        path    => "/",
        expires => undef,
    };

    div { "You're all set!" }
};


1;
