#!/usr/bin/env hmperl
use strict;
use warnings;
use DBI::ProfileData;

my $prof = DBI::ProfileData->new(File => "dbi.prof");
$prof->match(key2 => "execute");
warn $prof->count();
$prof->sort(field => 'total');
print $prof->report(number => $prof->count());
