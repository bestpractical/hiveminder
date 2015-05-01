#!/usr/bin/env hmperl
use strict;
use warnings;

use Jifty;
BEGIN { Jifty->new }
use Getopt::Long;

use BTDT::Statistics;

# XXX parameterize this and use Getopt::Long so we can test a local instance
print BTDT::Statistics::get_timing_data();
