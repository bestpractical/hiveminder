#!/usr/bin/env hmperl
# DEPRECATED
use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
my $dir = dirname(abs_path($0));
exec "$dir/jifty fastcgi";
