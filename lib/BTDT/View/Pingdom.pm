package BTDT::View::Pingdom;
use strict;
use warnings;
use Jifty::View::Declare -base;

use XML::Writer;
use Time::HiRes 'time';
use constant TIMEOUT => 15;

use Net::OSCAR;
use Net::Jabber;

sub pingdom_status {
    my ($status, $time) = @_;
    return if get 'done';
    alarm 0;
    Jifty->web->response->content_type('text/xml; charset=UTF-8');
    my $output = "";
    my $writer = XML::Writer->new( OUTPUT => \$output );
    $writer->xmlDecl( "UTF-8", "yes" );
    $writer->startTag( "pingdom_http_custom_check" );
    $writer->dataElement( status => $status );
    $writer->dataElement( response_time => sprintf("%.3f",$time*100) ) if $time;
    $writer->endTag();
    $writer->end();
    Jifty->web->response->body( $output );
    set('done', 1);
}

sub down {
    my $status = shift;
    pingdom_status($status);
}

sub ok {
    my $start = get('start');
    pingdom_status( "OK", time - $start );
}

sub start {
    set('start', time);
}

template 'aim' => sub {
    my $screenname       = 'HM Nagios';
    my $password         = 'zhophnen';

    my $check_screenname = 'HM Tasks';

    my $signed_on = sub {
        my $oscar = shift;
        start();
        $oscar->send_im( $check_screenname, 'todo' );
    };

    my $received_im = sub {
        my ( $oscar, $sender, $message, $is_away ) = @_;

        my $expected = $check_screenname;
        for ( $sender, $expected ) {
            s/\s+//;
            $_ = lc $_;
        }

        ok if $sender eq $expected;
    };

    my $error = sub {
        my ( $oscar, $connecton, $error, $description, $fatal ) = @_;

        if ( $description =~ /is not logged in/ ) {
            down "not logged in";
        } else {
            down sprintf "%s UNREACHABLE: Got a %s Net::OSCAR error: %s\n",
                $check_screenname,
                $fatal ? 'fatal' : 'nonfatal',
                $description;
        }
    };

    eval {
        alarm TIMEOUT;

        my $oscar = Net::OSCAR->new();
        $oscar->set_callback_error($error);
        $oscar->set_callback_im_in($received_im);
        $oscar->set_callback_signon_done($signed_on);

        $oscar->signon(screenname => $screenname,
                       password   => $password);

        while (not get 'done') {
            $oscar->do_one_loop();
        }
    };

    if (get('done')) {
        return;
    } elsif (get 'start') {
        down "Timed out while waiting for a response";
    } else {
        down "Timed out while signing on";
    }
};

template 'jabber' => sub {
    my $screenname = 'hmtest';
    my $password   = 'yellow';
    my $resource   = 'pingdom';
    my $server     = 'plys.net';
    my $port       = 5222;

    my $check_screenname = 'hmtasks@hiveminder.com';
    my $jabber = Net::Jabber::Client->new();
    eval {
        alarm TIMEOUT;

        $jabber->Connect(hostname => $server,
                         port     => $port);
        $jabber->Connected
            or return down "Unable to connect to $server:$port.";

        my ($ok, $msg) = $jabber->AuthSend(username => $screenname,
                                           password => $password,
                                           resource => $resource);

        $ok eq 'ok'
            or return down "Unable to get authorization: $ok - $msg.";

        $jabber->SetCallBacks(message => sub {
            my ($sid, $msg) = @_;
            my $message = $msg->GetBody;
            return if $message eq ''; # status update
            my $sender = $msg->GetFrom;

            # remove resource
            for ($sender, $check_screenname) { s{/.*}{} }

            ok if lc($sender) eq lc($check_screenname);
        });

        $jabber->PresenceSend();

        $jabber->MessageSend(
            to   => $check_screenname,
            type => 'chat',
            body => 't',
        );
        start();

        while (not get 'done') {
            down "Net::Jabber error: " . $jabber->GetErrorCode
                unless defined $jabber->Process(1);
        }
    };
    $jabber->Disconnect();

    if (get 'done') {
        return;
    } elsif (get 'start') {
        down "Timed out while waiting for a response";
    } else {
        down "Timed out while signing on";
    }
};
