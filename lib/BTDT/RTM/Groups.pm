package BTDT::RTM::Groups;

use strict;
use warnings;

use base 'BTDT::RTM';

=head1 NAME

BTDT::RTM::Groups - Group management

=head1 METHODS

=head2 method_add

Unimplemented.

=head2 method_addContact

Unimplemented.

=head2 method_delete

Unimplemented.

=head2 method_getList

Unimplemented.

=head2 method_removeContact

Unimplemented, but could be implemented in terms of Hiveminder groups.

=cut

sub method_add           { shift->send_unimplemented; }
sub method_addContact    { shift->send_unimplemented; }
sub method_delete        { shift->send_unimplemented; }
sub method_getList       { shift->send_unimplemented; }
sub method_removeContact { shift->send_unimplemented; }

1;
