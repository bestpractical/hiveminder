use warnings;
use strict;

=head1 NAME

BTDT::View::Reports

=cut

package BTDT::View::Reports;
use Jifty::View::Declare -base;
__PACKAGE__->use_mason_wrapper;

my %options = (
    chart_border  => { bottom_thickness => 1 },
    axis_category => { size             => '11', color => '808080' },
    axis_value    => { size             => '11', color => '808080' },
    axis_ticks    => { major_color      => '808080' },
    legend_label  => { size             => '11', bullet => 'line' },

    #  red, blue, green, orange (bright, dark, light)
    series_color => {
        color => [qw(
            FF0000 0067B3 00CC00 FF8000
            990000 003E6B 007A00 994D00
            FF6666 66BFFF 66FF66 FFB366
        )]
    },

    chart_value => { position => 'cursor', size => '11', color => '666666' },
    chart_pref =>
        { line_thickness => 2, fill_shape => 'false', point_shape => 'none' },
);

sub subtitle {
    my $subtitle = shift;
    my $title    = 'Reports';

    if ( my $group = get 'group' ) {
        $title = 'Group Reports: ' . $group->name;
    }

    return ( title => $title, subtitle => $subtitle );
}

template 'index.html' => page { subtitle 'Overview' }
content {
    my $group = get 'group';
    my $report;

    if ($group) {
        require BTDT::Report::Group::Tasks;
        $report = BTDT::Report::Group::Tasks->new(
            group     => $group,
            groupings => [ 'created', 'completed_at' ]
        );

        p {
            _(  qq(Is your team getting work done faster than it comes in?  Or are %1's tasks stacking up faster than you folks can deal with them?),
                $group->name
            );
        };
    } else {
        require BTDT::Report::User::Tasks;
        $report = BTDT::Report::User::Tasks->new(
            groupings => [ 'created', 'completed_at' ] );

        p {
            _(  qq(Are you getting work done faster than it comes in?  Or are tasks stacking up faster than you can deal with them?)
            );
        };
    }

    $report->run;
    outs lines_chart(report => $report, legend => ['New', 'Completed']);
};

template 'completed' => page { subtitle 'Completed Tasks' }
content {
    my $report;
    my $group = get 'group';

    if ($group) {

        # groups get a per-user breakdown
        {
            require BTDT::Report::Group::Completers;
            my $report
                = BTDT::Report::Group::Completers->new( group => $group );

            p {
                _( qq(Is each member of %1 pulling their own weight?),
                    $group->name );
            };

            $report->run;
            outs lines_chart(report => $report);
        }

        require BTDT::Report::Group::DayOfWeek;
        $report = BTDT::Report::Group::DayOfWeek->new( group => $group );

        p {
            _(  qq(Tasks completed by day of the week over the lifetime of group %1's use of Hiveminder.),
                $group->name
            );
        };
    } else {
        require BTDT::Report::User::DayOfWeek;
        $report = BTDT::Report::User::DayOfWeek->new;

        p {
            _(  qq(Tasks completed by day of the week over the lifetime of your use of Hiveminder.)
            );
        };
    }

    $report->run;
    outs line_chart(report => $report, color => $options{series_color}->{color}[1] );

    if ($group) {
        require BTDT::Report::Group::HourOfDay;
        $report = BTDT::Report::Group::HourOfDay->new( group => $group );

        p {
            _(  qq(Tasks completed by hour of the day over the lifetime of group %1's use of Hiveminder.),
                $group->name
            );
        };
    } else {
        require BTDT::Report::User::HourOfDay;
        $report = BTDT::Report::User::HourOfDay->new;

        p {
            _(  qq(Tasks completed by hour of the day over the lifetime of your use of Hiveminder.)
            );
        };
    }

    $report->run;
    outs line_chart(report => $report, color => $options{series_color}->{color}[1]);
};

template 'created' => page { subtitle 'New Tasks' }
content {
    my $group = get 'group';
    my $report;

    if ($group) {
        require BTDT::Report::Group::DayOfWeek;
        $report = BTDT::Report::Group::DayOfWeek->new(
            column => 'created',
            group  => $group
        );

        p {
            _(  qq(Tasks created by day of the week over the lifetime of group %1's use of Hiveminder.),
                $group->name
            );
        };
    } else {
        require BTDT::Report::User::DayOfWeek;
        $report = BTDT::Report::User::DayOfWeek->new( column => 'created' );

        p {
            _(  qq(Tasks created by day of the week over the lifetime of your use of Hiveminder.)
            );
        };
    }

    $report->run;
    outs line_chart(report => $report, color => $options{series_color}->{color}[0]);

    if ($group) {
        require BTDT::Report::Group::HourOfDay;
        $report = BTDT::Report::Group::HourOfDay->new(
            column => 'created',
            group  => $group
        );

        p {
            _(  qq(Tasks created by hour of the day over the lifetime of group %1's use of Hiveminder.),
                $group->name
            );
        };
    } else {
        require BTDT::Report::User::HourOfDay;
        $report = BTDT::Report::User::HourOfDay->new( column => 'created' );

        p {
            _(  qq(Tasks created by hour of the day over the lifetime of your use of Hiveminder.)
            );
        };
    }

    $report->run;
    outs line_chart(report => $report, color => $options{series_color}->{color}[0]);
};

template 'statistics' => page { subtitle 'Statistics' }
content {
    my $group = get 'group';
    my $report;

    if ($group) {
        p {
            _( "More numbers describing %1's use of Hiveminder.",
                $group->name );
        }
        require BTDT::Report::Group::Statistics;
        $report = BTDT::Report::Group::Statistics->new( group => $group );
    } else {
        p { _("More numbers describing your use of Hiveminder."); };
        require BTDT::Report::User::Statistics;
        $report = BTDT::Report::User::Statistics->new;
    }

    $report->run;
    set count   => $report->results->{count};
    set average => $report->results->{average};
    show '_statistics';
};

private template '_statistics' => sub {
    my %count = %{ get 'count' };
    my %avg   = %{ get 'average' };

    use Time::Duration qw(duration);

    table {
        { class is 'statistics' };
        row {
            cell {
                { class is 'label' };
                _("Number of tasks (owned or requested):");
            };
            cell { outs( $count{all} ) };
        };

        row {
            cell {
                { class is 'label' };
                _("Tasks delegated:");
            };
            cell {
                outs( sprintf "%0.0f%% (%d)",
                    ( $count{requestor} / $count{all} ) * 100,
                      $count{requestor} );
            };
        }
        if $count{all};

        row {
            cell {
                { class is 'label' };
                _("Tasks with definite due dates:");
            };
            cell {
                outs( sprintf "%0.0f%% (%d)",
                    ( $count{due} / $count{all} ) * 100,
                      $count{due} );
            };
        }
        if $count{all};

        row {
            cell {
                { class is 'label' };
                _("Tasks completed on time:");
            };
            cell {
                outs(
                    sprintf "%0.0f%% (%d)",
                    ( $count{ontime} / ( $count{ontime} + $count{late} ) )
                        * 100,
                    $count{ontime}
                );
            };
        }
        if $count{ontime} + $count{late};

        row {
            cell {
                { class is 'label' };
                _(q[Tasks marked as "won't complete":]);
            };
            cell {
                outs( sprintf "%0.0f%% (%d)",
                    ( $count{never} / $count{all} ) * 100,
                      $count{never} );
            };
        }
        if $count{all};

        row {
            cell {
                { class is 'label' };
                _("Average time to completion:");
            };
            cell { outs( duration( $avg{completion_time}, 2 ) ) };
        }
        if $avg{completion_time};

        if ( $avg{time_left_ontime} or $avg{time_left_all} ) {
            row {
                cell {
                    { class is 'label' };
                    _("Average time left before due date for...");
                };
                cell { outs_raw("&nbsp;") };
            };

            row {
                cell {
                    { class is 'label' };
                    _("...tasks completed on time:");
                };
                cell { outs( duration( $avg{time_left_ontime}, 2 ) ) };
            }
            if $avg{time_left_ontime};

            row {
                cell {
                    { class is 'label' };
                    _("...all completed tasks:");
                };
                cell {
                    { class is 'negative' if $avg{time_left_all} < 0; };
                    outs( duration( $avg{time_left_all}, 2 ) );
                    outs( $avg{time_left_all} < 0 ? ' late' : '' );
                };
            }
            if $avg{time_left_all};
        }
    }
};

template 'groups' => page { subtitle 'By Group' }
content {
    my $groups = Jifty->web->current_user->user_object->groups;
    if ( $groups->count == 0 ) {
        p {
            outs _(qq(I'm afraid you're in no groups. You can ));
            hyperlink(
                label => _(qq(create a new one)),
                url   => "/groups/create"
            );
            outs _(qq( if you want to.));
        };
    } else {
        p {
            _(qq(A breakdown of where all of your tasks fall into groups.));
        };

        require BTDT::Report::User::Groups;
        my $report = BTDT::Report::User::Groups->new;
        $report->run;
        outs pie_chart(labels => [$report->labels], data => [$report->data]);

        p {
            _(qq(Looking for some reports for each group? You're in luck!));
        };

        ul {
            for my $group ( @{ $groups->items_array_ref } ) {
                li {
                    hyperlink(
                        label => $group->name,
                        url   => "/reports/group/" . $group->id
                    );
                }
            }
        }
    }
};

template 'owners' => page { subtitle 'By Owners' }
content {
    my $group = get 'group';

    my @complete_types = (
        [ 0     => "A breakdown of where %1's incomplete tasks fall by owner" ],
        [ 1     => "A breakdown of where %1's complete tasks fall by owner" ],
        [ undef => "A breakdown of where all of %1's tasks fall by owner" ],
    );

    for (@complete_types) {
        my ( $complete, $description ) = @$_;

        p {
            _( $description, $group->name );
        };

        require BTDT::Report::Group::Owners;
        my $report = BTDT::Report::Group::Owners->new(
            group    => $group,
            complete => $complete
        );
        $report->run;
        outs pie_chart(labels => [$report->labels], data => [$report->data]);
    }
};

template 'time' => page { subtitle 'Estimated time vs. Actual time' }
content {
    my $group = get 'group';
    my $report;

    if ($group) {
        require BTDT::Report::Group::TimeTracking;
        $report = BTDT::Report::Group::TimeTracking->new( group => $group );
        p {
            _(qq(How good is your team at estimating the time it takes to complete tasks?));
        };
    } else {
        require BTDT::Report::User::TimeTracking;
        $report = BTDT::Report::User::TimeTracking->new();
        p {
            _(qq(How good are you at estimating the time it takes to complete tasks?));
        };
    }

    $report->run;
    outs scatter_chart(
        report  => $report,
        axes    => ['Estimated (in hours)','Actual (in hours)'],
    );
};

=head2 lines_chart report => BTDT::Report[, legend => arrayref]

Generates a chart with multiple lines on it. If you don't specify a legend,
the legend will be extracted from the report. Returns the raw HTML.

=cut

sub lines_chart {
    my %args = @_;
    my $report = $args{report};
    my $legend = $args{legend} || $report->legend;

    if (Jifty->config->framework('TestMode')) {
        pre {
            my @labels = map { length $_ ? $_ : undef } $report->labels;
            my @totals = $report->totals_as_array;
            for my $name (@$legend) {
                my @t = map { defined $_ ? $_ : 'undef' } @{ shift @totals };
                outs "$name:\n";
                for (@labels) {
                    my $l = defined($_) ? $_ : 'undef';
                    outs "\t$l:\t" . shift(@t) . "\n";
                }
            }
        };
    }
    else {
        Jifty->web->chart(
            type    => 'Lines',
            width   => 580,
            height  => 200,
            options => { %options, },
            legend  => $legend,
            data    => [
                [ map { length $_ ? $_ : undef } $report->labels ],
                $report->totals_as_array
            ]
        );
    }
}

=head2 line_chart report => BTDT::Report

Generates a chart with one line on it. Returns the raw HTML.


=cut

sub line_chart {
    my %args = @_;
    my $report = $args{report};
    my $color  = $args{color};

    delete $args{$_} for qw(report color);

    if (Jifty->config->framework('TestMode')) {
        pre {
            my @labels  = $report->labels;
            my $results = $report->results;
            for ( 0 .. $#$results ) {
                my $r = defined($results->[$_]) ? $results->[$_] : 'undef';
                outs "$labels[$_]:\t$r\n";
            }
        };
    }
    else {
        Jifty->web->chart(
            type    => 'Lines',
            width   => '580',
            height  => '200',
            options => {
                %options,
                legend_rect  => { x     => -500, y => -500 },
                series_color => { color => [$color] },
                %args
            },
            data => [ [ $report->labels ], $report->results ]
        );
    }
}

=head2 pie_chart report => BTDT::Report or labels => ArrayRef, data => ArrayRef

Generates a pie chart using the given report, or labels and data. Returns the
raw HTML.

=cut

sub pie_chart {
    my %args = @_;
    my $report = $args{report};
    my $labels = $args{labels} || [$report->labels];
    my $data   = $args{data}   || [$report->data];

    delete $args{$_} for qw(report labels data);

    if (Jifty->config->framework('TestMode')) {
        pre {
            for ( @$labels ) {
                my $r = shift @$data;
                outs "$_:\t$r\n";
            }
        }
    }
    else {
        Jifty->web->chart(
            type    => 'Pie',
            width   => '580',
            height  => '250',
            options => {
                chart_rect => { x => 50, y => 0, width => 200, height => 200 },
                chart_pref   => { rotation_x => 60 },
                chart_grid_h => { thickness  => 0 },
                legend_label => {
                    size   => '11',
                    layout => 'horizontal',
                    bullet => 'circle',
                    color  => '000000'
                },
                legend_rect => {
                    x              => 280,
                    y              => 10,
                    height         => 10,
                    width          => 50,
                    margin         => '10',
                    fill_color     => 'ffffff',
                    line_thickness => 0
                },
                chart_value => {
                    position      => 'outside',
                    size          => '11',
                    color         => '808080',
                    as_percentage => 'true'
                },
                series_color => $options{series_color},
            },
            data => [ $labels, @$data ],
            %args
        );
    }
};

=head2 scatter_chart report => BTDT::Report or labels => ArrayRef, data => ArrayRef

Generates a scatter chart using the given report, or labels and data. Returns the
raw HTML.

=cut

sub scatter_chart {
    my %args = @_;
    my $report = $args{report};
    my $legend = $args{legend} || $report->legend;
    my $axes   = $args{axes}   || [];

    delete $args{$_} for qw(report legend axes);

    Jifty->web->chart(
        type    => 'Points',
        width   => 580,
        height  => 210,
        legend  => $legend,
        options => {
            %options,
            chart_pref => { trend_thickness => 2, trend_alpha => 40 },
            chart_rect => { x => 70, y => 30 },
            legend_rect => { x => 70, y => 0,  },
            legend_label => { size => '11', bullet => 'circle' },
            draw => {
                text => [
                    { x => 230, y => 190, size => 11, content => $axes->[0], color => '808080' },
                    { x => 30, y => 140, rotation => '-90', size => 11, content => $axes->[1], color => '808080' },
                ],
            },
            %args
        },
        data    => [
            $report->labels,
            @{$report->results}
        ]
    );
}

template 'timetracking' => sub {
    my $tokens = get 'tokens';
    my $list_metadata = get 'list_metadata';

    # if they give just a number, interpret it as a task. otherwise, tokens
    $tokens = "id ".BTDT::Record->record_locator($tokens) if $tokens =~ /^\d+$/;

    my $tasks = BTDT::Model::TaskCollection->new;
    $tasks->from_tokens($tasks->split_tokens($tokens));
    my $count = $tasks->count;

    if ($count == 0) {
        return p { "No tasks given." }
    }

    my $tracking = $tasks->group_time_tracked(by => "owner");
    my $worked_for;

    # we want just time worked
    for my $owner_id (keys %{ $tracking->{owner} }) {
        my $time = $tracking->{"owner"}{$owner_id};
        $worked_for->{ $time->{"object"}->name } = $time->{"worked"};
    }

    # we do want time left in the graph
    $worked_for->{"left"} = $tracking->{"left"};

    div {
        attr { class => 'time_tracking_report' };
        outs pie_chart(
            width   => 450,
            height  => 220,
            ( $count > 1 ? (bgcolor => '#f0f0f0') : ()),
            labels => [
                map {
                    sprintf '%s (%s)',
                        $_,
                        BTDT::Model::Task->concise_duration($worked_for->{$_}),
                }
                keys %$worked_for
            ],

            data => [
                [ 0, values %$worked_for ]
            ],
        );

        if ($list_metadata) {
            my $item = sub {
                my $label = shift;
                my $value = shift;

                cell {{ class is 'label' }; outs_raw "$label:"; };
                cell { outs(BTDT::Model::Task->concise_duration($value)); };
            };

            my $report = sub {
                my $name = shift;
                my $key  = shift;
                $item->(
                    ($count == 1 ? ucfirst($name) : "Total $name"),
                    $tracking->{$key}
                );
            };

            table {{ class is 'statistics metadata' };
                row { $report->("time worked" => "worked"); }
                row { $report->("original estimate" => "estimate"); }
                row { $report->("time left" => "left"); };

                if ($count > 1) {
                    row {
                        $item->(
                            "Average time worked",
                            $tracking->{"worked"} / $count
                        );
                    }

                    row {
                        $item->(
                            "Average estimated time",
                            $tracking->{"estimate"} /  $count
                        );
                    }
                }
            }
        }
    }
};

1;
