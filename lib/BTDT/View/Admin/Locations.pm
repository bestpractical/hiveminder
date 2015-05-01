use warnings;
use strict;

=head1 NAME

BTDT::View::Admin::Locations

=cut

package BTDT::View::Admin::Locations;
use Jifty::View::Declare -base;
__PACKAGE__->use_mason_wrapper;

use BTDT::Report;
use Geography::States;
use List::MoreUtils qw(pairwise);

sub transform {
    my $data = shift;

    my @places;
    my @values;

    for my $set ( @$data ) {
        push @places, $set->[0];
        push @values, $set->[1];
    }

    return \@places, \@values
}

sub fix_states {
    my $data   = shift;
    my $lookup = Geography::States->new('USA', 'strict');
    my %states;

    for my $set ( @$data ) {
        my ( $state, $value ) = @$set;

        if ( length($state) != 2 ) {
            $state =~ s/^Hampshire$/New Hampshire/i; # Found in data
            $state = $lookup->state($state) or next;
        }
        $states{$state} += $value;
    }

    return [ pairwise { [$a, $b] } @{[keys %states]}, @{[values %states]} ];
}

template 'index.html' => page { title => 'Admin', subtitle => 'Locations' } content {
    h2 { "Pro (by number of orders)" };

    my $report = BTDT::Report->new;
    {
        my $data = $report->count_aggregate_values(
            group_by => 'upper(state)',
            query    => "upper(country) = 'US' and state != 'Yonder'",
            table    => 'financial_transactions',
        );
        show 'graph', 'usa', transform( fix_states($data) );
    }
    {
        my $data = $report->count_aggregate_values(
            group_by => 'upper(country)',
            query    => "country is not null and state != 'Yonder'",
            table    => 'financial_transactions',
        );
        show 'graph', 'world', transform($data);
    }
};

private template 'graph' => sub {
    my $self = shift;
    my ( $scale, $places, $values ) = @_;

    Jifty->web->chart(
        renderer => 'Google',
        type     => 'map',
        width    => 440,
        height   => 220,
        colors   => [qw(ffffff edf0d4 6c9642 13390a)],
        bgcolor  => ( $scale eq 'usa' ? 'ffffff' : 'EAF7FE' ),
        geoarea  => $scale,
        data     => [ $places, $values ],
    );
};

1;
