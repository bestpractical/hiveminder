use warnings;
use strict;

=head1 NAME

BTDT::Model::TaskAttachmentCollection

=cut

package BTDT::Model::TaskAttachmentCollection;
use base qw/BTDT::Collection/;

=head2 implicit_clauses

Don't show hidden attachments.

=cut

sub implicit_clauses {
    my $self = shift;
    $self->limit( column => 'hidden', value => 0 )
        if not (   $self->current_user->is_superuser
                or $self->current_user->pro_account );
}


1;
