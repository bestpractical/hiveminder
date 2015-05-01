use warnings;
use strict;

use BTDT::Test;

eval "use Test::Pod::Coverage 1.00";
plan skip_all => "Test::Pod::Coverage 1.00 required for testing POD coverage"
    if $@;

# Skip View and Report classes
my @modules
    = grep { not /^BTDT::(View|Report)/ } Test::Pod::Coverage::all_modules();
plan( tests => scalar @modules );

pod_coverage_ok(
    $_,
    { nonwhitespace => 1, also_private => [qw/^is_(private|protected)$/] },
    "Pod coverage on $_"
) for @modules;
