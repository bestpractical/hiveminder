use warnings;
use strict;

=head1 NAME

BTDT::View::Admin::Performance

=cut

package BTDT::View::Admin::Performance;
use Jifty::View::Declare -base;
__PACKAGE__->use_mason_wrapper;

use BTDT::View::Admin::Monitoring;

use constant GROUPINGS => {
    basic => {
        samples => [ "login", "list tasks", "page 2", "view task", "preferences", ],
        title => "Basic performance",
    },
    access => {
        samples => [
            "pageregion load",
            "three pageregion loads",
            "validate",
            "start of tasklist data",
            "end of tasklist data",
        ],
        title => "Low-level performance",
    },
    static => {
        samples => [ "static javascript", "static css", "static image", ],
        title => "Static file performance",
    },
    size => {
        category => "size",
        samples => [qw/todo CSS javascript/ ],
        title => "File size",
        default => "day",
    },
};

sub graph {
    my ( $scale, $name ) = @_;
    BTDT::View::Admin::Monitoring::graph(
        $scale,
        GROUPINGS->{$name}{category} || "performance",
        @{ GROUPINGS->{$name}{samples} },
    );
}

template 'index.html' => page { title => 'Admin', subtitle => 'Performance graphs' } content {
    for (qw/basic access static size/) {
        my $scale = GROUPINGS->{$_}{default} || "second";
        h2 {
            hyperlink(
                url   => "/admin/performance/$_",
                label => GROUPINGS->{$_}{title}
            );
            outs( " - " . BTDT::View::Admin::Monitoring::scale_title($scale));
        };
        graph( $scale, $_ );
    }
};

for my $name (keys %{GROUPINGS()}) {
    template $name => page { title => 'Admin', subtitle => GROUPINGS->{$name}{title} } content {
        for my $scale (qw/minute hour day month/) {
            next if $name eq "size" and ($scale eq "minute" or $scale eq "hour");
            h2 { BTDT::View::Admin::Monitoring::scale_title($scale) };
            graph( $scale, $name );
        }
    };
}

1;
