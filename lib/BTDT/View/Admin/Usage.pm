use warnings;
use strict;

=head1 NAME

BTDT::View::Admin::Usage

=cut

package BTDT::View::Admin::Usage;
use Jifty::View::Declare -base;
__PACKAGE__->use_mason_wrapper;

use BTDT::View::Admin::Monitoring;
use BTDT::IM;

use constant GROUPINGS => {
    all_tasks => {
        category => "tasks",
        samples => [ qw/all complete incomplete accepted group/ ],
        title => "All tasks",
    },
    tasks => {
        category => "tasks",
        samples => [
            "created today",
            "completed today",
            "modified today",
            "tags modified today",
        ],
        title => "Tasks today",
    },
    sharing => {
        category => "tasks",
        samples => [
            "changed not by requestor today",
            "changed not by owner today",
            "completed not by owner today",
            "changed in a group",
        ],
        title => "Task sharing",
    },
    # comments
    # feedbacks
    all_users => {
        category => "users",
        samples => [ qw/all pro/ ],
        title => "All users",
    },
    users => {
        category => "users",
        samples => [
            "active today",
            "pro active today",
            "new today",
        ],
        title => "Users today",
    },
    users_week => {
        category => "users",
        samples => [
            "active this week",
            "pro active this week",
        ],
        title => "Users this week",
    },
    pro => {
        category => "users",
        samples => [
            "pro today",
            "gift pro today",
            "renew today",
        ],
        title => "Pro purchases",
    },
    imap => {
        category => "imap",
        samples => [
            "sent today",
            "received today",
        ],
        title => "IMAP megabytes transferred",
    },
    im => {
        category => "im",
        samples => [
            "received today",
            map { "$_ received today" } @BTDT::IM::protocols,
        ],
        title => "IMs received",
    },
    im_users => {
        category => "im_users",
        samples => [
            "users today",
            map { "$_ users today" } @BTDT::IM::protocols,
        ],
        title => "IM users active",
    },
    revenue => {
        category => "revenue",
        samples => [qw/today/],
        title => "Revenue",
    },
    yaks => {
        category => "yaks",
        samples => [qw/count/],
        title => "Yaks",
    },
};

sub graph {
    my ( $scale, $name ) = @_;
    BTDT::View::Admin::Monitoring::graph(
        $scale,
        GROUPINGS->{$name}{category},
        @{ GROUPINGS->{$name}{samples} },
    );
}

template 'index.html' => page { title => 'Admin', subtitle => 'Usage graphs' } content {
    for (qw/all_tasks tasks sharing all_users users users_week imap im pro revenue yaks/) {
        h2 {
            hyperlink(
                url => "/admin/usage/$_",
                label => GROUPINGS->{$_}{title},
            );
            outs( " - " . BTDT::View::Admin::Monitoring::scale_title("day"));
        };
        graph( day => $_ );
    }
};

for my $name (keys %{GROUPINGS()}) {
    template $name => page { title => 'Admin', subtitle => GROUPINGS->{$name}{title} } content {
        for my $scale (qw/day week month/) {
            h2 { BTDT::View::Admin::Monitoring::scale_title($scale) };
            graph( $scale, $name );
        }
    };
};

1;
