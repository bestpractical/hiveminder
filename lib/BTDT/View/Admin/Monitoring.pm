use warnings;
use strict;

=head1 NAME

BTDT::View::Admin::Monitoring

=cut

package BTDT::View::Admin::Monitoring;
use DateTime::Format::ISO8601;
use Jifty::Plugin::Monitoring::Model::MonitoredDataPoint;

use constant DIVISIONS => 4;
use constant PARSER    => DateTime::Format::ISO8601->new();
use constant TIMESCALE => {
    second => { args => [ hours  => 1 ], title => "One hour, every two minutes" },
    minute => { args => [ hours  => 4 ], title => "Four hours, every two minutes" },
    hour   => { args => [ days   => 1 ], title => "One day, every hour" },
    day    => { args => [ months => 1 ], title => "One month, every day" },
    week   => { args => [ months => 6 ], title => "Six months, every week" },
    month  => { args => [ years  => 1 ], title => "One year, every month" },
};

use constant OPTIONS => {
    chart_border  => { bottom_thickness => 1 },
    axis_category => { size             => '11', color => '808080' },
    axis_value    => { size             => '11', color => '808080' },
    axis_ticks    => { major_color      => '808080' },
    legend_label  => { size             => '11', bullet => 'line' },

    series_color => {
        color => [
            qw( CC0000 00CC00 0000CC
                CCCC00 CC00CC 00CCCC 777777
                AA6666 66AA66 6666AA 2A2A2A
                772233 227733 336677 C0C0C0
                666600 660066 006666)
        ]
    },

    chart_value => { position => 'cursor', size => '11', color => '666666', decimals => 2 },
    chart_pref =>
        { line_thickness => 2, fill_shape => 'false', point_shape => 'none' },
};

sub scale_title {
    return TIMESCALE->{shift @_}{title};
}

sub graph {
    my ( $scale, $category, @samples ) = @_;
    my $since = BTDT::DateTime->now->subtract( @{ TIMESCALE->{$scale}{args} } );
    $since->set_time_zone("UTC");
    my $since_quoted = Jifty->handle->dbh->quote($since);
    my $cat_quoted   = Jifty->handle->dbh->quote($category);
    my $scale_quoted = Jifty->handle->dbh->quote($scale);
    my @merged;
    my %when;

    for my $sample (@samples) {
        my $sample_quoted = Jifty->handle->dbh->quote($sample);
        my $sth           = Jifty->handle->simple_query(<<"EOT");
select date_trunc($scale_quoted, sampled_at) as when,
       avg(cast(value as float)) as value
  from @{[Jifty::Plugin::Monitoring::Model::MonitoredDataPoint->table]}
 where category = $cat_quoted
   and sample_name = $sample_quoted
 group by date_trunc($scale_quoted, sampled_at)
having date_trunc($scale_quoted, sampled_at) > $since_quoted
EOT
        my $data = $sth->fetchall_arrayref( {} );
        for my $point ( @{$data} ) {
            $when{ $point->{when} } = scalar @merged
                unless exists $when{ $point->{when} };
            $merged[ $when{ $point->{when} } ] ||= { when => $point->{when} };
            $merged[ $when{ $point->{when} } ]{$sample} = $point->{value};
        }
    }

    @merged = sort { $a->{when} cmp $b->{when} } @merged;

    my %label;
    $label{ int( $#merged  * $_ / DIVISIONS ) }++
        for ( 0 .. DIVISIONS );
    for my $i ( 0 .. $#merged ) {
        if ( $label{$i} ) {
            $merged[$i]{when} =~ s/ /T/;
            $merged[$i]{when}
                = bless PARSER->parse_datetime( $merged[$i]{when} ),
                "BTDT::DateTime";
            $merged[$i]{when}->set_time_zone("UTC");
            $merged[$i]{when}->set_current_user_timezone;
            if ( $scale eq "second" or $scale eq "minute" or $scale eq "hour" ) {
                $merged[$i]{when} = $merged[$i]{when}->strftime("%H:%M");
            } else {
                $merged[$i]{when} = $merged[$i]{when}->ymd;
            }
        } else {
            $merged[$i]{when} = undef;
        }
    }

    Jifty->web->chart(
        type    => 'Lines',
        width   => 780,
        height  => 400,
        options => OPTIONS,
        legend  => [ map { ucfirst $_ } @samples ],
        data    => [
            [ map $_->{when}, @merged ],
            map { $a = $_; [ map $_->{$a}, @merged ] } @samples,
        ]
    );
}

1;
