use warnings;
use strict;

use Test::MockTime 'set_fixed_time';
use BTDT::Test;
use BTDT::Test::IM;

set_fixed_time(1203449047); # Tue Feb 19 14:24:07 2008 EST
my @cases = (
    tonight     => "today",
    tomorrow    => "tomorrow",
    yesterday   => undef,

    tuesday     => "today",
    wednesday   => "tomorrow",
    thursday    => "2008-02-21",
    friday      => "2008-02-22",
    saturday    => "2008-02-23",
    sunday      => "2008-02-24",
    monday      => "2008-02-25",

    "April 16"  => "2008-04-16",
    "4/30"      => undef, # is this day/month or month/day?
);

# each case is three tests, plus setup tests
plan tests => 5 + (@cases + @cases / 2);

setup_screenname('gooduser@example.com' => 'tester');

while (my ($in, $expected) = splice @cases, 0, 2) {
    $in = "foo $in bar";

    if (defined $expected) {
        im_like("c $in", qr/\[due: $expected\]/, "'$in' intuits to $expected")
    }
    else {
        im_unlike("c $in", qr/\[due: /, "'$in' does not intuit")
    }
}

