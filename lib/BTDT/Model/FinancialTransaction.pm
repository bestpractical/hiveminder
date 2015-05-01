use warnings;
use strict;

=head1 NAME

BTDT::Model::FinancialTransaction

=cut

package BTDT::Model::FinancialTransaction;

use base qw( BTDT::Record );
use Jifty::DBI::Schema;
use Business::OnlinePayment;

sub is_protected {1}
use Jifty::Record schema {
    column user_id =>
        refers_to BTDT::Model::User,
        label is 'User',
        is mandatory,
        is immutable;

    column created =>
        type is 'timestamp',
        filters are qw( Jifty::Filter::DateTime Jifty::DBI::Filter::DateTime),
        label is 'Created on',
        default is defer { DateTime->now->iso8601 },
        is immutable;

    column description =>
        type is 'text',
        label is 'Description',
        is immutable;

    column amount =>
        type is 'int',
        label is 'Amount (in cents)',
        is mandatory,
        is immutable;

    column 'first_name' =>
        type is 'text',
        label is 'First name',
        is mandatory,
        is immutable;

    column 'last_name' =>
        type is 'text',
        label is 'Last name',
        is mandatory,
        is immutable;

    column 'address' =>
        type is 'text',
        label is 'Address',
        is mandatory,
        is immutable;

    column 'city' =>
        type is 'text',
        label is 'City',
        is mandatory,
        is immutable;

    # this column was added, removed, and finally re-added in 0.8.2
    column 'state' =>
        type is 'text',
        label is 'State / Province',
        since '0.2.82',
        is immutable;

    column 'zip' =>
        type is 'text',
        label is 'Postal Code',
        is mandatory,
        is immutable;

    column 'country' =>
        type is 'text',
        label is 'Country',
        is mandatory,
        is immutable;

    column 'last_four' =>
        type is 'text',
        label is 'Card number',
        is mandatory,
        is immutable;

    column 'expiration' =>
        type is 'text',
        label is 'Expiration',
        is mandatory,
        is immutable;

    column 'authorization_code' =>
        type is 'text';

    column 'error_message' =>
        type is 'text';

    column 'card_type' =>
        type is 'text',
        label is 'Card type',
        is immutable;

    column 'submitted' =>
        is boolean,
        label is 'Submitted?',
        is mandatory;

    column 'remote_addr' =>
        type is 'text',
        is mandatory,
        is immutable;

    column 'cookie' =>
        type is 'text',
        is immutable;

    column 'user_agent' =>
        type is 'text',
        is immutable;

    column 'server_response' =>
        type is 'text';

    column 'result_code' =>
        type is 'int';

    column 'coupon' =>
        type is 'text',
        references BTDT::Model::Coupon by 'code',
        since '0.2.71',
        is immutable;

};

=head2 since

This first appeared in version 0.2.60

=cut

sub since { '0.2.60' }

=head2 current_user_can

If the user is associated with the transaction or the user is staff, let
them read it.  Otherwise, reject everything.  (We use the superuser for create.)

=cut

sub current_user_can {
    my $self  = shift;
    my $right = shift;

    if ( $right eq 'read' ) {
        return 1 if $self->current_user->id == $self->__value('user_id');
        return 1 if $self->current_user->access_level eq 'staff';
    }

    return 1 if $self->current_user->is_superuser;
    return 0;
}

=head2 order_id

Returns the order ID of this payment.

=cut

sub order_id {
    my $self = shift;
    return $self->created->ymd('').$self->id;
}

=head2 formatted_amount

Returns a formatted string of the amount of the transaction

=cut

sub formatted_amount {
    my $self = shift;
    return sprintf('$%0.2f USD', $self->amount / 100);
}

=head2 country_name

Returns the name of the country of the transaction

=cut

sub country_name {
    my $self = shift;
    use Locale::Country qw(code2country);
    return code2country( $self->country );
}

=head2 create_and_submit QUANTITY, PARAMHASH

Creates a FinancialTransaction record, submits the record to the transaction
processor, and records the result in the newly created record.

=cut

sub create_and_submit {
    my $self    = shift;
    my $total   = shift;
    my $req     = Jifty->web->request;
    # For record creation ($self->create)
    my %fields  = (
        @_,
        amount      => $total * 100, # need this in cents
        remote_addr => $req->address,
        cookie      => Jifty->web->session->id,
        user_agent  => $req->user_agent,
    );

    # For CC processing ($self->_submit_transaction)
    my %data = (
        card_number => $fields{'card_number'},
        cvv2        => $fields{'cvv2'},
        customer_id => $fields{'user_id'},
        customer_ip => $fields{'remote_addr'},
        amount      => $total,
        x_line_item => qq(1<|>Hiveminder Pro<|>1 year<|>1<|>$total<|>N),
    );

    $data{$_} = $fields{$_}
        for qw( description first_name last_name address city state
                zip country expiration );

    # We only really want to submit the state/province if we have one
    delete $data{'state'}
        if not defined $data{'state'} or not length $data{'state'};

    delete $fields{$_} for qw( card_number cvv2 );

    # Should never be less than this, but if it is somehow, substr would die
    if ( length $data{'card_number'} > 6 ) {
        # Mask card number except for last four digits
        $fields{'last_four'} = $data{'card_number'};
        substr( $fields{'last_four'}, 0, -4, "x" x (length($fields{'last_four'}) - 4) );

        # Set the cardtype
        use Business::CreditCard qw(cardtype);
        my $masked = $data{'card_number'};
        substr( $masked, 6, length($masked), "x" x (length($masked) - 6) );
        $fields{'card_type'} = cardtype($masked);
    }

    my $id;
    my $msg = $self->create( %fields );

    if ( ref $msg ) {
        # It's a Class::ReturnValue
        ( $id, $msg ) = $msg->as_array;
    }

    if ( not $self->id ) {
        $self->log->warn(_("Create of %1 failed: %2", __PACKAGE__, $msg));
        $self->log->warn(_("Unable to record transaction!"));
        return;
    }

    # Set invoice number for future reference
    $data{'invoice_number'} = $self->id;

    my $ret;

    if ( $data{amount} > 0 ) {
        # Submit the transaction for processing
        $ret = $self->_submit_transaction( %data );
    }

    if ( $ret ) {
        BTDT::Notification::FinancialTransactionReceipt->new( transaction => $self )
                                                       ->send
    }

    return $data{amount} > 0 ? $ret : 1;
}

sub _submit_transaction {
    my $self    = shift;
    my %config  = %{ Jifty->config->app('AuthorizeNet') };
    my %data    = (
        login    => $config{'login'},
        password => $config{'transaction_key'},
        action   => 'normal authorization',
        type     => 'CC',
        @_
    );

    # Truncate description for authorize.net
    $data{description} = substr $data{description}, 0, 255
        if length $data{description} > 255;

    my $tx = Business::OnlinePayment->new("AuthorizeNet");

    if ( not $config{'LiveMode'} ) {
        $tx->server('test.authorize.net');
        $tx->test_transaction( 1 );
    }

    $tx->content( %data );
    $tx->submit;

    $self->log->debug("[AuthNet] Result code: ".$tx->result_code);
    $self->set_submitted(1);
    $self->set_result_code( $tx->result_code );
    $self->set_server_response( $tx->server_response );

    if ( $tx->is_success ) {
        $self->log->debug("[AuthNet] Card processed successfully: ".$tx->authorization);
        $self->set_authorization_code( $tx->authorization );
        return 1;
    } else {
        $self->log->debug("[AuthNet] Card was rejected: ".$tx->error_message);
        $self->set_error_message( $tx->error_message );
        return 0;
    }
}

1;
