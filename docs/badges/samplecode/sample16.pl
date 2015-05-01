use strict;
use GD::Graph::bars;
use GD::Graph::hbars;
require 'save.pl';

my @data = ( 
    [ qw( 1st 2nd 3rd 4th 5th 6th 7th 8th 9th ) ],
    [    5,   12,undef,   33,   19,    8,    5,    15,    21],
    [   -6,   -5,   -9,   -8,  -11, -9.3,undef,    -9,   -12]
);

my $refit = 4;

sub y_format
{
    my $value = shift;
    my $ret;

    if ($value >= 0)
    {
	$ret = sprintf("\$%3d", $value * $refit);
    }
    else
    {
	$ret = sprintf("-\$%3d", abs($value) * $refit);
    }
}

my @names = qw/sample16 sample16-h/;

for my $my_graph (GD::Graph::bars->new, GD::Graph::hbars->new)
{
    my $name = shift @names;
    print STDERR "Processing $name\n";

    $my_graph->set( 
	x_label             => 'Day',
	y_label             => 'AUD',
	title               => 'Credits and Debits',
	y_max_value         => 35,
	y_min_value         => -15,
	y_tick_number       => 10,
	y_label_skip        => 2,
	overwrite           => 1, 
	dclrs               => [ qw( green lred ) ],
	axislabelclr        => 'black',
	legend_placement    => 'RB',
	zero_axis_only      => 0,
	y_number_format     => \&y_format,
	x_label_position    => 1/2,

	transparent         => 0,
    );

    $my_graph->set_legend( 'credits', 'debets' );
    $my_graph->plot(\@data);
    save_chart($my_graph, $name);
}
