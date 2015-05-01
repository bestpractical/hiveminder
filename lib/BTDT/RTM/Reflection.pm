package BTDT::RTM::Reflection;

use strict;
use warnings;

use base 'BTDT::RTM';

=head1 NAME

BTDT::RTM::Reflection - Unimplemeted reflection API

=head1 METHODS

=head2 method_getMethods

Unimplemented.

=head2 method_getMethodInfo

Unimplemented.

=cut

sub method_getMethods    { shift->send_unimplemented; }
sub method_getMethodInfo { shift->send_unimplemented; }

1;
