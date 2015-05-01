use warnings;
use strict;

=head1 NAME

BTDT::Model::Purchase

=cut

package BTDT::Model::Purchase;

use base  qw( BTDT::Record );
use Jifty::DBI::Schema;
sub is_protected {1}
use Jifty::Record schema {

    column owner_id =>
        refers_to BTDT::Model::User,
        is mandatory,
        is immutable;

    column transaction_id =>
        refers_to BTDT::Model::FinancialTransaction,
        is immutable;

    column description =>
        type is 'text',
        is mandatory,
        is immutable;

    column gift =>
        is boolean,
        since '0.2.61',
        is immutable;

    column created =>
        type is 'timestamp',
        filters are qw( Jifty::Filter::DateTime Jifty::DBI::Filter::DateTime),
        default is defer { DateTime->now->iso8601 },
        is immutable;

    column renewal =>
        is boolean,
        since '0.2.85',
        is immutable;

};


=head2 since

This first appeared in version 0.2.60

=cut

sub since { '0.2.60' }

=head2 current_user_can

If the user is associated with the purchase or the user is staff, let
them read it.  Otherwise, reject everything.  (We use the superuser for create.)

=cut

sub current_user_can {
    my $self  = shift;
    my $right = shift;

    if ( $right eq 'read' ) {
        return 1 if $self->current_user->id == $self->__value('owner_id');
        return 1 if $self->current_user->access_level eq 'staff';
    }

    return 1 if $self->current_user->is_superuser;
    return 0;
}

1;
