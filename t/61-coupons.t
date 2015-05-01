use warnings;
use strict;

use BTDT::Test;
use Email::Simple;

my %data = (
    first_name  => 'John',
    last_name   => 'Doe',
    address     => '123 Anystreet',
    city        => 'Anycity',
    state       => 'Anyplace',
    zip         => '12345',
    country     => 'US',
);

my %args = (
    %data,
    cvv2                => '123',
    expiration_month    => '01',
    expiration_year     => DateTime->today->year + 1,
);

my $goodcard  = '4007000000027'; # Visa

sub lastfour { "x"x(length($_[0])-4).substr($_[0],-4)}

{
    my $tx = Business::OnlinePayment->new("AuthorizeNet");
    $tx->server('test.authorize.net');
    $tx->test_transaction( 1 );
    my %config  = %{ Jifty->config->app('AuthorizeNet') };
    $tx->content(
        login       => $config{'login'},
        password    => $config{'transaction_key'},
        action      => 'normal authorization',
        type        => 'CC',
        card_number => $goodcard,
        amount      => 30_00,
        expiration  => "$args{expiration_month}/$args{expiration_year}",
        %args,
    );
    $tx->submit;
    plan skip_all => "Payment tests are disabled unless we have network"
        if $tx->error_message and $tx->error_message =~ /destination host not found/;
}

plan tests => 104;

my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL  = $server->started_ok;
my $mech = BTDT::Test->get_logged_in_mech( $URL );
isa_ok($mech, 'Jifty::Test::WWW::Mechanize');
$mech->html_ok;
$mech->content_like(qr/Logout/i, "logged in");

my $gooduser = BTDT::CurrentUser->new( email => 'gooduser@example.com' );
my $user = $gooduser->user_object;

# setup
$mech->get_ok( $URL . '/account' );
$mech->content_contains('free, basic');
$mech->follow_link_ok( text => 'Upgrade to Pro!' );

my @emails = BTDT::Test->messages;
my $emailcount = scalar @emails;

sub apply_coupon {
    my $mech    = shift;
    my $coupon  = shift;

    $mech->fill_in_action_ok(
        $mech->moniker_for('BTDT::Action::ApplyCoupon'),
        coupon  => $coupon
    );
    ok( $mech->click_button( value => 'Apply coupon' ), "Clicked apply coupon" );
}


# non-existant coupon
apply_coupon( $mech, '404' );
$mech->content_contains('Invalid coupon', "got error message");
$mech->content_contains('Apply coupon', "has apply coupon button still");
$mech->content_contains('$30.00 USD', "price hasn't changed");

for my $useless_coupon (
    {
        code     => 'EXPIRED',
        discount => '20',
        expires  => '2000-01-01'
    },
    { code => 'USED', discount => '20', use_limit => 5, use_count => 5 },
    {
        code     => 'LESSTHANMINIMUM',
        discount => '20',
        minimum  => 40,
    },
  )
{

    my $coupon =
      BTDT::Model::Coupon->new( current_user => BTDT::CurrentUser->superuser );
    $coupon->create(%$useless_coupon);
    ok $coupon->id, "Created $useless_coupon->{code} coupon";

    apply_coupon( $mech, $useless_coupon->{code} );

    if ( $useless_coupon->{code} eq 'LESSTHANMINIMUM' ) {
        $mech->content_contains( $useless_coupon->{code},
            'coupon is displayed' );
    }
    else {
        $mech->content_contains( 'Invalid coupon', "got error message" );
        $mech->content_contains( 'Apply coupon',
            "has apply coupon button still" );
    }
    $mech->content_contains( '$30.00 USD', "price hasn't changed" );

}

for my $once_coupon (
    {
        code          => 'GOOD',
        discount      => '6',
        once_per_user => 1,
    },
    {
        code      => 'GOOD1',
        discount  => '6',
        use_limit => 5,
        use_count => 4,
    },
  )
{

    $mech->back;

    $user->load( $gooduser->id );
    my $old_paid_until = $user->paid_until;

    # good coupon, use_count is less than user_limit
    my $coupon =
      BTDT::Model::Coupon->new( current_user => BTDT::CurrentUser->superuser );
    $coupon->create(%$once_coupon);
    ok $coupon->id, "Created good, limited coupon";

    apply_coupon( $mech, $once_coupon->{code} );
    $mech->content_lacks( 'Invalid coupon', "no error message" );
    $mech->content_lacks( 'Apply coupon',
        "doesn't have apply coupon button still" );
    $mech->content_lacks( '$30.00 USD', "price isn't 30" );
    $mech->content_contains( '$24.00 USD', "price is correct 24\$" );
    $mech->content_contains( $once_coupon->{code}, "coupon is displayed" );

    # let's actually use it to upgrade
    $mech->fill_in_action_ok(
        $mech->moniker_for('BTDT::Action::UpgradeAccount'),
        %args, card_number => $goodcard, );
    $mech->submit_html_ok();
    $mech->content_contains( 'Congratulations', "content has good message" );

    my $record =
      BTDT::Model::FinancialTransaction->new( current_user => $gooduser );
    $record->load_by_cols( %data, last_four => lastfour($goodcard) );
    ok $record->id => 'Got record';
    is $record->user_id,     $gooduser->id => 'Right user';
    is $record->result_code, 1             => 'Got proper result code';
    is $record->amount,      2400          => 'Got right amount (in cents)';
    like $record->server_response,
      qr/,|24.00|,/ => 'Submitted right amount to processor';
    ok $record->submitted => 'Marked as submitted';
    like $record->card_type, qr/visa/i => 'Got VISA card type';

    Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
    $user->load( $gooduser->id );
    is $user->pro_account, 1, 'User has a pro account';
    if ($old_paid_until) {
        $old_paid_until =~ s/^(\d+)/$1+1/e;
        is $user->paid_until, $old_paid_until, 'Paid until is correct';
    }
    else {
        is $user->paid_until, DateTime->today->add( years => 1 )->ymd,
          'Paid until is correct';
    }

    my $purchase = BTDT::Model::Purchase->new( current_user => $gooduser );
    $purchase->load_by_cols( transaction_id => $record->id );
    ok $purchase->id,          "Got a purchase record";
    is $purchase->owner_id,    $gooduser->id, "Correct user";
    is $purchase->description, "Hiveminder Pro", "Right description";

    $coupon->load( $coupon->id );
    is $coupon->use_count,
      $once_coupon->{use_count} ? $once_coupon->{use_count} + 1 : 1,
      "Coupon use_count incremented";

    # good coupon, but already used by us
    $mech->get_ok( $URL . '/account/upgrade' );
    apply_coupon( $mech, $once_coupon->{code} );
    $mech->content_contains( 'Invalid coupon', "got error message" );
    $mech->content_contains( 'Apply coupon', "has apply coupon button still" );
    $mech->content_contains( '$30.00 USD',   "price is 30" );

}

{
    
# test coupon that is once_per_user on another user
    my $coupon =
      BTDT::Model::Coupon->new( current_user => BTDT::CurrentUser->superuser );
    $coupon->load_by_cols( code => 'GOOD' );
    ok $coupon->id, "load GOOD coupon";

    my $mech =
      BTDT::Test->get_logged_in_mech( $URL, 'otheruser@example.com',
        'something' );
    isa_ok( $mech, 'Jifty::Test::WWW::Mechanize' );
    $mech->html_ok;
    $mech->content_like( qr/Logout/i, "logged in" );

    $mech->get_ok( $URL . '/account' );
    $mech->content_contains('free, basic');
    $mech->follow_link_ok( text => 'Upgrade to Pro!' );

    apply_coupon( $mech, 'GOOD' );
    $mech->content_lacks( 'Invalid coupon', "no error message" );
    $mech->content_lacks( 'Apply coupon',
        "doesn't have apply coupon button still" );
    $mech->content_lacks( '$30.00 USD', "price isn't 30" );
    $mech->content_contains( '$24.00 USD', "price is correct 24\$" );
    $mech->content_contains( 'GOOD',       "coupon is displayed" );
}
