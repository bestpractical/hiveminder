use warnings;
use strict;

=head1 NAME

BTDT::Model::Coupon

=cut

package BTDT::Model::Coupon;

use base  qw( BTDT::Record );
use Jifty::DBI::Schema;
sub is_private {1}
use Jifty::Record schema {

    column code =>
        type is 'text',
        label is 'Coupon Code',
        is distinct,
        is mandatory;

    column discount =>
        type is 'integer',
        label is 'Discount',
        is mandatory;

    column minimum =>
        type is 'integer',
        label is 'Minimum',
        default is 0,
        is mandatory,
        since '0.2.74';

    column description =>
        type is 'text',
        label is 'Description';

    column expires =>
        type is 'date',
        label is 'Expires On',
        filters are 'Jifty::DBI::Filter::Date',
        render_as 'Date';

    column use_limit =>
        type is 'integer',
        label is 'Use Limit',
        since '0.2.72';

    column use_count =>
        type is 'integer',
        label is 'Used',
        default is 0,
        is immutable,
        since '0.2.72';

    column once_per_user =>
        is boolean, is mandatory,
        label is 'Once per user?',
        since '0.2.73';

    column created =>
        type is 'timestamp',
        filters are qw( Jifty::Filter::DateTime Jifty::DBI::Filter::DateTime),
        default is defer { DateTime->now->iso8601 };

};


=head2 since

This first appeared in version 0.2.70

=cut

sub since { '0.2.70' }

=head2 current_user_can

If the user is staff, let them do whatever.  Otherwise, reject everything.

=cut

sub current_user_can {
    my $self  = shift;
    my $right = shift;

    return 1 if $self->current_user->access_level eq 'staff';
    return 1 if $self->current_user->is_superuser;
    return 0;
}

=head2 valid [STRING]

Returns true if the coupon is valid, otherwise false.

If called with a coupon code and as an object method on an unloaded object or
as a class method, it will attempt to load and validate the specificed coupon
and return accordingly.

=cut

sub valid {
    my $self  = shift;
    my $code  = uc shift;
    my $valid = 1;

    if ( defined $code ) {
        # We want an empty object if called as a class method
        $self = $self->new( current_user => BTDT::CurrentUser->superuser )
            if not ref $self;

        # Try to load up an object if it's empty
        $self->load_by_cols( code => $code )
            if not $self->id;
    }

    # If we don't have a record, it can't possibly be valid
    return 0 if not $self->id;

    # Is it expired?
    if ( defined $self->expires and time >= $self->expires->epoch ) {
        $valid = 0;
    }

    # Has it been used up?
    if ( defined $self->use_limit and $self->use_count >= $self->use_limit ) {
        $valid = 0;
    }

    # Has the user used it before?
    if ( $self->once_per_user ) {
        my $trans = Jifty->web->current_user->user_object->financial_transactions;
        $trans->limit( column => 'coupon', value => $self->code );
        $trans->limit(
            column   => 'authorization_code',
            operator => 'is not',
            value    => 'null'
        );
        $valid = 0 if $trans->count;
    }

    return $valid;
}

=head2 apply_to NUMERIC

Takes a numeric argument and applies the discount to it, returning the new price.
If the given price is not greater than or equal to the minimum of the coupon,
the original price will be returned.

=cut

sub apply_to {
    my $self  = shift;
    my $price = shift;

    my $newprice = $price >= $self->minimum
                        ? $price - $self->discount
                        : $price;

    return sprintf "%0.02f", $newprice;
}

=head2 increment_use_count

Increments the number of uses of this coupon.

=cut

sub increment_use_count {
    my $self = shift;
    $self->__set(
        column          => 'use_count',
        value           => 'use_count + 1',
        is_sql_function => 1
    );
}

=head2 decrement_use_count

Decrements the number of uses of this coupon.

=cut

sub decrement_use_count {
    my $self = shift;
    $self->__set(
        column          => 'use_count',
        value           => 'use_count - 1',
        is_sql_function => 1
    );
}

=head2 set_code

Forces the code to be uppercase, because load_by_cols doesn't let us search
case-insensitively.

=cut

sub set_code {
    my $self = shift;
    my $code = shift;
    $self->_set( column => 'code', value => uc $code);
}

=head2 autogenerate_action

Despite being private, B<do> generate all actions for this.  We'll
just hide them from most users.

=cut

sub autogenerate_action { 1 }

1;
