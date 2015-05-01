package BTDT::RTM::Transactions;

use strict;
use warnings;

use base 'BTDT::RTM';

=head1 NAME

BTDT::RTM::Transactions - Transaction support

=head1 METHODS

=head2 method_undo

Unimplemented; could be done by looking at txn changes

=cut

sub method_undo { shift->send_unimplemented; }

1;
