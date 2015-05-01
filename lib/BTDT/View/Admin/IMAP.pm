use warnings;
use strict;

=head1 NAME

BTDT::View::Admin::IMAP

=cut

package BTDT::View::Admin::IMAP;
use Jifty::View::Declare -base;
__PACKAGE__->use_mason_wrapper;

use Time::Duration qw(ago duration concise);
use IO::Socket::INET;

template 'index.html' => page { title => 'Admin', subtitle => 'IMAP status' } content {
    unless (Jifty->config->app("IMAP")->{monitor_port}) {
        h1 { "IMAP monitoring is disabled." };
        return;
    }

    my $socket = IO::Socket::INET->new(
        PeerHost => "localhost",
        PeerPort => Jifty->config->app("IMAP")->{monitor_port},
    );

    unless ($socket) {
        h1 { "IMAP server is down!" };
        return;
    }

    $socket->print("list\n");
    form {
        table {
            attr { id => "imap-clients" };
            while ( my $line = $socket->getline ) {
                chomp $line;
                my ( $host, $auth, $selected, $commands, $sent, $received, $coro, $idle, $compute, $since ) = split /\t/, $line;
                my $name = "unauth";
                if ($auth) {
                    my $user = BTDT::Model::User->new(
                        current_user => BTDT::CurrentUser->superuser );
                    $user->load($auth);
                    $name = $user->email;
                }
                $selected ||= "unselected";

                row { { attr { class => "top" } }
                    cell { $name };
                    cell { $selected };
                    cell { BTDT->english_filesize($sent) . " out" };
                    cell { concise(ago(time - $since, 1)) };
                    cell {
                        attr { class => "controls", rowspan => 2 };
                        my $a = new_action(class => "CloseIMAPConnection", moniker => "coro-".$coro);
                        $a->button(arguments=>{coro => $coro, method => $_}, label => ucfirst $_, class => "delete")->render
                            for qw/close kill/;
                    };
                };
                row { { attr { class => "bottom" } }
                    cell { $host };
                    cell { "idle ".concise(duration($idle)) };
                    cell { BTDT->english_filesize($received) . " in" };
                    cell { sprintf("%d / %.3fs", $commands, $compute) };
                };
            }
            $socket->close;
            "";
        };
    };
};

1;
