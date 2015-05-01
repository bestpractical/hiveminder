use GD::Graph::bars;
use GD::Graph::colour qw(hex2rgb add_colour);
use List::Util qw(min max sum);
use List::MoreUtils qw(pairwise);
require 'save.pl';

my @data = ( 
    ["1st","2nd","3rd","4th","5th","6th","7th", "8th", "9th"],
    [   11,   12,   15,   16,    3,  1.5,    1,     3,     4],
    [    5,   12,   24,   15,   19,    8,    6,    15,    21],
    [    12,   3,    1,   5,    12,    9,   16,    25,    11],
    [ map { $_ * -1 } (   11,   12,   15,   16,    3,  1.5,    1,     3,     4) ],
    [ map { $_ * -1 } (    5,   12,   24,   15,   19,    8,    6,    15,    21) ],
    [ map { $_ * -1 } (    12,   3,    1,   5,    12,    9,   16,    25,    11) ],
);

# massage data time

sub cumulate {
    my @sets = @_;
    for my $i ( 1..$#sets ) {
        pairwise { $b = $b + $a; } @{$sets[$i - 1]}, @{$sets[$i]};
    }
    return \@sets;
}

my @names = qw/mixed/;

for my $my_graph (GD::Graph::bars->new(90,75))
{
    my $name = shift @names;
    print STDERR "Processing $name\n";
    my $max = max @{cumulate(@data[1..3])->[2]};
    my $min = min @{cumulate(@data[4..6])->[2]};

    warn $max, "/", $min;

    add_colour( personal  => [hex2rgb('#6883a7')] );
    add_colour( others    => [hex2rgb('#257324')] );
    add_colour( delegated => [hex2rgb('#b12926')] );

    $my_graph->set( 
    title            => '                      My week       '."\nDone\n2121\nNew\n12121",
    text_space => '5',
    no_axes          => 0,
    x_ticks          => 0,
    tick_length      => 0,
#	cumulate         => 0,
    overwrite        => 1,
	borderclrs       => [qw/ delegated others personal delegated others personal /],
	dclrs            => [qw/ delegated others personal delegated others personal /],
    textclr          => 'black',
    labelclr         => 'black',
    fgclr            => 'white',
	bar_spacing      => 1,
	transparent      => 0,
    text_space       => 2,
    axis_space       => 0,
    values_space     => 0,
    legend_spacing   => 0,
    t_margin         => 0,
    b_margin         => 0,
    l_margin         => 0,
    r_margin         => 0,
    x_label          => "hiveminder.com",
    logo            => 'hmlogo.png',
    logo_position   => 'LL',
    y_max_value      => $max,
    y_min_value      => $min
    );


    $my_graph->set_title_font("calibri.ttf", 8);
    $my_graph->set_x_label_font("calibri.ttf", 8);
#    my $plot = [ $data[0], reverse(@{cumulate(@data[1..3])}), reverse(@{cumulate(@data[4..6])}) ];
    my $plot = [ $data[0], reverse(@data[1..3]), reverse(@data[4..6]) ];
    #use Data::Dumper; die Dumper($plot);
    $my_graph->plot($plot);
    save_chart($my_graph, $name);
}
