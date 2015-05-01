use warnings;
use strict;

=head1 NAME

BTDT::Model::ListCollection

=cut

package BTDT::Model::ListCollection;
use base qw/BTDT::Collection/;

=head2 implicit_clauses

Order by name by default

=cut

sub implicit_clauses {
    my $self = shift;
    $self->order_by( column => 'name' );
}


1;
