use strict;
use warnings;

=head1 NAME

BTDT::Action::ApplyCoupon

=cut

package BTDT::Action::ApplyCoupon;
use base qw/BTDT::Action Jifty::Action/;

use Jifty::Param::Schema;
use Jifty::Action schema {
    param 'coupon' =>
        label is 'Coupon code',
        ajax validates;
};

=head2 validate_coupon

Ensures the coupon exists.

=cut

sub validate_coupon {
    my $self  = shift;
    my $value = shift;

    # We simply pass on empty values
    #return $self->validation_error( 'coupon' => 'Must specify a coupon.' )
    return $self->validation_ok('coupon')
        if not defined $value or not length $value;


    if ( BTDT::Model::Coupon->valid( $value ) ) {
        return $self->validation_ok('coupon');
    }
    else {
        return $self->validation_error( coupon => 'Invalid coupon code.' );
    }
}


=head2 take_action

Stores the coupon in the result, if one was provided.

=cut

sub take_action {
    my $self = shift;
    $self->report_success
        if     not $self->result->failure
           and defined $self->argument_value('coupon');
    return 1;
}

=head2 report_success

Stores the coupon in the result

=cut

sub report_success {
    my $self = shift;
    $self->result->content('coupon' => $self->argument_value('coupon'));
}

1;

