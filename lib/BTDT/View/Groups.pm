use warnings;
use strict;

=head1 NAME

BTDT::View::Groups

=cut

package BTDT::View::Groups;
use Jifty::View::Declare -base;
__PACKAGE__->use_mason_wrapper;

require BTDT::View::Groups::Dashboard;
alias BTDT::View::Groups::Dashboard under 'dashboard/';

template 'reports' => page {
    title    => 'Group ' . get('group')->name,
    subtitle => 'Reports'
    } content {
    my $group = get('group');

    use BTDT::Report::Group::Statistics;
    my $report = BTDT::Report::Group::Statistics->new( group => $group );
    $report->run;

    my %count = %{ $report->results->{count} };
    my %avg   = %{ $report->results->{average} };

    use Time::Duration qw(duration);

    table {
        { class is 'statistics' };
        row {
            cell {
                { class is 'label' };
                _("Number of tasks:");
            };
            cell { outs( $count{all} ) };
        };

        row {
            cell {
                { class is 'label' };
                _("Unowned tasks:");
            };
            cell {
                outs( sprintf "%0.0f%%",
                    ( $count{unowned} / $count{all} ) * 100 );
            };
        }
        if $count{all};

        row {
            cell {
                { class is 'label' };
                _("Tasks with definite due dates:");
            };
            cell {
                outs( sprintf "%0.0f%%",
                    ( $count{due} / $count{all} ) * 100 );
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
                    sprintf "%0.0f%%",
                    ( $count{ontime} / ( $count{ontime} + $count{late} ) )
                        * 100
                );
            };
        }
        if $count{ontime} + $count{late};

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
    };
    };

1;
