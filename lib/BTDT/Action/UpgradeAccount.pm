use warnings;
use strict;

=head1 NAME

BTDT::Action::UpgradeAccount - Upgrade a user's account (to pro, for now)

=cut

package BTDT::Action::UpgradeAccount;
use base qw/BTDT::Action Jifty::Action/;

use BTDT::Model::User;
use BTDT::Model::FinancialTransaction;
use BTDT::Model::Purchase;

use Business::CreditCard qw();
use Locale::Country qw(all_country_names country2code);
Locale::Country::rename_country('tw' => 'Taiwan');

my @countries = sort { $a->{'display'} cmp $b->{'display'} }
                map  { { display => $_, value => uc(country2code($_)) } }
                all_country_names();

use Jifty::Param::Schema;
use Jifty::Action schema {

    # User(s) to *upgrade*
    param 'user_id' =>
        ajax validates,
        ajax canonicalizes,
        is mandatory;

    param 'first_name' =>
        type is 'text',
        label is 'First name',
        is mandatory;

    param 'last_name' =>
        type is 'text',
        label is 'Last name',
        is mandatory;

    param 'address' =>
        type is 'text',
        label is 'Address',
        is mandatory;

    param 'city' =>
        type is 'text',
        label is 'City',
        is mandatory;

    param 'state' =>
        type is 'text',
        label is 'State / Province';

    param 'zip' =>
        type is 'text',
        label is 'Postal Code',
        is mandatory;

    param 'country' =>
        type is 'text',
        label is 'Country',
        default is 'US',
        valid_values are \@countries,
        render as 'Select',
        is mandatory;

    param 'card_number' =>
        type is 'text',
        label is 'Card number',
        sticky is 0,
        is mandatory,
        disable_autocomplete is 1;

    param 'cvv2' =>
        type is 'text',
        label is 'Security code',
        sticky is 0,
        is mandatory,
        disable_autocomplete is 1;

    param 'expiration_month' =>
        type is 'text',
        label is 'Expires',
        valid_values are ( "01".."12" ),
        is mandatory,
        render as 'Select';

    param 'expiration_year' =>
        type is 'text',
        label is '&nbsp;',
        valid_values are ( DateTime->now->year .. DateTime->now->add( years => 10 )->year ),
        is mandatory,
        render as 'Select';

    param 'coupon' =>
        type is 'text',
        label is 'Coupon code';

};

=head2 _validate_arguments

We override this so that in the case of FREE coupons, we don't require
the user to submit any extra, useless information like a billing address
and credit card number.

=cut

sub _validate_arguments {
    my $self = shift;

    $self->_validate_argument( $_ )
        for qw( user_id coupon );

    return 1 if $self->result->success and $self->_calculate_price == 0;

    return $self->SUPER::_validate_arguments( @_ );
}

sub _get_user
{
    my $id = shift;

    $id = Jifty->web->current_user->user_object->email_address
        if lc($id) eq 'me';

    my $user = BTDT::Model::User->new( current_user => BTDT::CurrentUser->superuser );

    if ( $id =~ /\D/ ) {
        $user->load_by_cols( email => $id );
    } else {
        $user->load( $id );
    }

    return $user;
}

=head2 validate_user_id

Must be an arrayref or a single user's id or email address.

=cut

sub validate_user_id {
    my $self  = shift;
    my $ids   = shift || [];

    if ( not ref $ids ) {
        $ids = [$ids];
    }

    for my $value ( @$ids ) {
        # the value can be an ID or email address
        unless ( $value =~ /^\d+$/ || $value =~ /\S\@\S/ ) {
            return $self->validation_error(user_id => "Are you sure that's an email address?" );
        }

        my $user = _get_user($value);

        if ( not $user->id ) {
            $self->canonicalization_note( user_id => ' ' );
            return $self->validation_error( user_id => <<"            EOT" );
                We don't know of anyone by the address $value.  If it's the correct address,
                please invite them to Hiveminder first.
            EOT
        }
        else {
            $self->canonicalization_note( user_id => 'Name: ' . $user->name );
        }
    }
    return $self->validation_ok('user_id');
}

=head2 validate_coupon

Looks up the coupon to make sure it exists.

=cut

sub validate_coupon {
    my $self  = shift;
    my $value = shift;

    return $self->validation_ok('coupon') if not defined $value or not length $value;

    my $coupon = BTDT::Model::Coupon->new( current_user => BTDT::CurrentUser->superuser );

    if ( $coupon->valid($value) ) {
        $self->canonicalization_note( coupon => $coupon->discount . "% discount" );
        return $self->validation_ok('coupon');
    }

    $self->canonicalization_note( coupon => " " );
    return $self->validation_error( coupon => 'Invalid coupon code.' );
}

=head2 validate_expiration_year

Makes sure that the expiration date is in the future.

=cut

sub validate_expiration_year {
    my $self  = shift;
    my $value = shift;

    my $expired = 'The credit card you gave us seems to be expired.  Please check your information or try another card.';

    if ( $value > DateTime->now->year ) {
        return $self->validation_ok('expiration_year');
    }
    elsif ( $value == DateTime->now->year ) {
        my $month = $self->argument_value('expiration_month');

        if ( $month < DateTime->now->month ) {
            return $self->validation_error( expiration_year => $expired );
        }
    }
    else {
        return $self->validation_error( expiration_year => $expired );
    }

    return $self->validation_ok('expiration_year');
}

=head2 validate_state

State/province is required only in some countries.

Right now we force state to be a value only in the US -- what other countries
need it?

=cut

my %requires_state = (
    US => 1,
);

sub validate_state {
    my $self = shift;
    my $state = shift;

    if ($requires_state{ $self->argument_value('country') }) {
        if ($state =~ /^\s*$/) {
            return $self->validation_error( state => "You need to fill in the 'state' field" );
        }
    }

    return $self->validation_ok('state');
}

=head2 take_action

Charges the crdit card (if there's a non-zero cost) and upgrades the
account(s) to pro.

=cut

sub _calculate_price {
    my $self = shift;
    my %args = ( use_coupon => 0, @_ );

    my @recipients = $self->_setup_recipients;
    return if not @recipients;

    my $price = 30;
    my $quant = scalar @recipients;
    my $total = $price * $quant;

    if ( defined $self->argument_value('coupon') ) {
        my $coupon = BTDT::Model::Coupon->new( current_user => BTDT::CurrentUser->superuser );
        $coupon->load_by_cols( code => $self->argument_value('coupon') );

        if ( $coupon->id and $coupon->valid ) {
            $total = $coupon->apply_to( $total );
            $coupon->increment_use_count
                if $args{'use_coupon'};
        }
        else {
            $self->argument_value( 'coupon' => undef );
        }
    }

    $total = 0 if $total < 0;
    return $total;
}

sub _setup_recipients {
    my $self = shift;

    my $user_id = $self->argument_value('user_id');
    my @recipients;
    my @ids = ( ref $user_id eq 'ARRAY' ) ? @$user_id : ( $user_id );

    for my $id ( @ids ) {
        my $user = _get_user($id);

        if ( not $user->id ) {
            $self->result->error("We can't find the user ".$user->email.".");
            return;
        }

        push @recipients, $user;
    }
    return @recipients;
}

sub take_action {
    my $self = shift;

    # Clear out any users saved in the session
    Jifty->web->session->set( giftusers => undef );
    Jifty->web->session->remove('giftusers');

    # Setup recipients
    my @recipients = $self->_setup_recipients;
    return if not @recipients;

    my $gift = ( @recipients > 1 or $recipients[0]->id != Jifty->web->current_user->id )
                    ? 1 : 0;

    # Calculate price
    my $total = $self->_calculate_price( use_coupon => 1 );

    # If we're not actually charging anything, set a bunch of dummy data to
    # satisfy FinancialTransaction and not require the user to provide info.
    if ( $total == 0 ) {
        my %dummy = (
            first_name  => 'Queen',
            last_name   => 'Bee',
            address     => '123 Honeycomb Way',
            city        => 'Hivetown',
            state       => 'Yonder',
            zip         => '00000',
            country     => 'US',
            card_number => '4222222222222',
            cvv2        => '123',
            expiration_month => '01',
            expiration_year  => ( DateTime->now->year + 2 ),
        );

        $self->argument_value( $_ => $dummy{$_} )
            for keys %dummy;
    }

    # Setup data
    my %data;
    $data{$_} = $self->argument_value($_) for $self->argument_names;

    $data{'description'} = $gift ? 'Gift of Hiveminder Pro for 1 year to '
                                   . join(', ', map { sprintf "%s (%s)", $_->name, $_->email } @recipients )
                                 : 'Upgrade to Hiveminder Pro for 1 year';

    $data{'expiration'}  = $data{'expiration_month'}.'/'.$data{'expiration_year'};
    $data{'user_id'}     = Jifty->web->current_user->id; # User who made the *purchase*

    delete $data{$_} for qw(expiration_month expiration_year);

    my $tx     = BTDT::Model::FinancialTransaction->new( current_user => BTDT::CurrentUser->superuser );
    my $result = $tx->create_and_submit( $total, %data );

    if ( not $result ) {
        my $try_again = "We're sorry, there was an error processing the "
                      . "transaction likely through no fault of your own.  "
                      . "Please try again in 10 minutes or contact support.";

        my %errors = (
            8   => "The credit card you gave us seems to be expired.  Please "
                 . "check your information or try another card.",

            11  => "It looks like you accidentally submitted a duplicate "
                 . "transaction and we prevented it from going through.  If "
                 . "you meant to submit this transaction, please wait a few "
                 . "minutes and try again.",

            27  => "The billing address you gave us doesn't seem to match.  "
                 . "Please check the address and try again.",

            # Lots of error codes mean the same thing on our end
            map { $_ != 24 ? ( $_ => $try_again ) : () } ( 19..26, 57..63 )
        );

        if ( not $tx->id ) {
            $self->result->error("We were unable to process the transaction.  Please try again later.");
        }
        elsif ( defined $errors{$tx->result_code} ) {
            $self->result->error($errors{$tx->result_code});
        }
        else {
            $self->result->error("There was an error processing the transaction.  Please check your information and try again in 10 minutes or contact support.");
        }

        # Don't count this use of the coupon -- if coupon is set at this point,
        # then we already know that it's valid and was used
        if ( defined $self->argument_value('coupon') ) {
            my $coupon = BTDT::Model::Coupon->new( current_user => BTDT::CurrentUser->superuser );
            $coupon->load_by_cols( code => $self->argument_value('coupon') );
            $coupon->decrement_use_count if $coupon->id;
        }

        return;
    }

    # if this is not a gift, then update the buyer's account to at least
    # a full user's account. this is to facilitate going pro at signup
    if (!$gift) {
        my $user = $recipients[0];
        $user->set_email_confirmed(1);
    }

    # Now we do the user updates to actually give them pro features
    my $already_was_pro = 0;
    for my $user ( @recipients ) {
        my $renewal = $user->was_pro_account;
        my $extension = $user->pro_account;
        ++$already_was_pro if $extension;

        $user->set_pro_account(1);

        # If paid_until is in the future, then use it as the base.
        # Otherwise, use today's date.
        my $base = ($user->paid_until and $user->paid_until > DateTime->today)
                        ? $user->paid_until->clone
                        : DateTime->today;

        $user->set_paid_until( $base->add( years => 1 ) );
        $user->set_was_pro_account(1);

        my $purchase = BTDT::Model::Purchase->new( current_user => BTDT::CurrentUser->superuser );
        $purchase->create(
            owner_id        => $user->id,
            transaction_id  => $tx->id,
            description     => 'Hiveminder Pro',
            gift            => ( $user->id != Jifty->web->current_user->id ),
            renewal         => $renewal,
        );

        # Send purchase notice
        BTDT::Notification::Purchase->new( purchase => $purchase )->send;
    }

    my $orders = _(<<"    EOT");
        You can find <a href="/account/orders/@{[$tx->order_id]}">your receipt</a>
        anytime in your <a href="/account/orders">order history</a>.
    EOT

    $orders = "" if not $tx->amount;

    if ( not $gift ) {
        if ($already_was_pro) {
            $self->result->message(
                _(qq(Congratulations, you now have more Hiveminder Pro goodness!))
                . $orders
            );
        }
        else {
            $self->result->message(
                _(qq(Congratulations, you now have a Hiveminder Pro account!))
                . $orders
            );
        }
    } else {
        my $message = @recipients > 1
                    ? "%1 now have Hiveminder Pro accounts!"
                    : "%1 now has a Hiveminder Pro account!";

        $self->result->message(
            _(
                $message,
                join(', ', map { sprintf "%s (%s)", $_->name, $_->email } @recipients ),
            )
            . $orders
        );
    }

    return 1;
}

=head2 validate_card_number

Validates that card_number is a plausible number (checks checksum) and
makes sure it is a card type we accept.

=cut

sub validate_card_number {
    my $self    = shift;
    my $number  = shift;

    return $self->validation_error( 'card_number' => 'Invalid card number.  Please double check it.' )
        if not Business::CreditCard::validate( $number );

    return $self->validation_error( 'card_number' => 'Sorry, we only accept Visa, MasterCard, and Discover.' )
        if not Business::CreditCard::cardtype( $number ) =~ /(?:VISA|MasterCard|Discover)/;

    return $self->validation_ok('card_number');
}

1;
