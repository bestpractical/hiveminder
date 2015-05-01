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
my $badcard   = '4222222222222';
my $goodcard2 = '5424000000000015'; # MasterCard
my $goodcard3 = '6011000000000012'; # Discover
my $goodcard4 = '6011000000000004'; # Discover
my $amexcard  = '370000000000002'; # AmEx

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

plan tests => 199;

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
#$mech->follow_link_ok( text => 'Account' );
$mech->get_ok( $URL . '/account', 'access /account' );
$mech->content_contains('free, basic', 'this account is free');
$mech->follow_link_ok( text => 'Upgrade to Pro!', 'we have Upgrade link' );

my @emails = BTDT::Test->messages;
my $emailcount = scalar @emails;
my $record = BTDT::Model::FinancialTransaction->new( current_user => $gooduser );
my $purchase = BTDT::Model::Purchase->new( current_user => $gooduser );

SKIP: {
    skip( "Can't test expired credit cards in January", 16 * 4 )
        if ( (localtime)[4] == 0 );

    # expired card with valid or invalid locals
    for my $local (
        { state => undef,      country => 'US' },
        { state => 'Anyplace', country => 'CN' },
        { state => undef,      country => 'CN' },
        map {
            { $_ => undef }
        } qw/first_name last_name address city zip/
        )
    {

        my %args = ( %args, %$local );
        my $year = (localtime)[5] + 1900;

        $mech->fill_in_action_ok(
            $mech->moniker_for('BTDT::Action::UpgradeAccount'),
            %args,
            card_number      => $goodcard,
            expiration_month => '01',
            expiration_year  => $year,
        );
        $mech->submit_html_ok();

        if ( $args{country} eq 'CN' ) {
            $mech->content_contains( 'expired', 'card is expired' );
        } else {
            $mech->content_like( qr/You need to fill in the '.*?' field/,
                'lacks some info' );
        }

        $mech->content_lacks( 'Congratulations', 'failed to upgrade' );

        $record->load_by_cols( %data, last_four => lastfour($goodcard) );
        ok !$record->id => 'Did not get record';

        Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
        $user->load( $gooduser->id );
        is $user->pro_account, 0, 'User does not have a pro account';

# XXX we didn't get valid record before, why fill $record->id to transaction_id?
        $purchase->load_by_cols( transaction_id => $record->id );
        ok !$purchase->id, "Don't have a purchase record";

        @emails = BTDT::Test->messages;
        is $emailcount, scalar @emails, "No emails sent";
    }
}


# bad card
$mech->fill_in_action_ok(
    $mech->moniker_for('BTDT::Action::UpgradeAccount'),
    %args,
    card_number => $badcard,
);
$mech->submit_html_ok();
$mech->content_contains('error processing the transaction');
$mech->content_lacks('Congratulations');

$record = BTDT::Model::FinancialTransaction->new( current_user => $gooduser );
$record->load_by_cols( %data, last_four => lastfour($badcard) );
ok $record->id => 'Got record';
is $record->user_id, $gooduser->id => 'Right user';
is $record->result_code, '30' => 'Got proper result code';
is $record->amount, 3000 => 'Got right amount (in cents)';
like $record->server_response, qr/,|30.00|,/ => 'Submitted right amount to processor';
ok $record->submitted => 'Marked as submitted';
like $record->card_type, qr/visa/i => 'Got Visa card type';

Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
$user->load( $gooduser->id );
is $user->pro_account, 0, 'User does not have a pro account';

$purchase->load_by_cols( transaction_id => $record->id );
ok !$purchase->id, "Don't have a purchase record";

@emails = BTDT::Test->messages;
is $emailcount, scalar @emails, "No emails sent";

# Invalid card numbers (random, amex)
$mech->get_ok( $URL . '/account/upgrade' );
$mech->fill_in_action_ok(
    $mech->moniker_for('BTDT::Action::UpgradeAccount'),
    %args,
    card_number => '1234567890',
);
$mech->submit_html_ok();
$mech->content_contains('Invalid card number');
$mech->content_lacks('Congratulations');

$record = BTDT::Model::FinancialTransaction->new( current_user => $gooduser );
$record->load_by_cols( %data, last_four => 'xxxxxx7890' );
ok !$record->id => 'No record';

Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
$user->load( $gooduser->id );
is $user->pro_account, 0, 'User does not have a pro account';

$purchase->load_by_cols( transaction_id => $record->id );
ok !$purchase->id, "Don't have a purchase record";

@emails = BTDT::Test->messages;
is $emailcount, scalar @emails, "No emails sent";

# amex
$mech->fill_in_action_ok(
    $mech->moniker_for('BTDT::Action::UpgradeAccount'),
    %args,
    card_number => $amexcard,
);
$mech->submit_html_ok();
$mech->content_contains('only accept');
$mech->content_lacks('Congratulations');

$record = BTDT::Model::FinancialTransaction->new( current_user => $gooduser );
$record->load_by_cols( %data, last_four => lastfour($amexcard) );
ok !$record->id => 'No record';

Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
$user->load( $gooduser->id );
is $user->pro_account, 0, 'User does not have a pro account';

$purchase->load_by_cols( transaction_id => $record->id );
ok !$purchase->id, "Don't have a purchase record";

@emails = BTDT::Test->messages;
is $emailcount, scalar @emails, "No emails sent";

# good card2
BTDT::Test->setup_mailbox;
$mech->get_ok( $URL . '/account/upgrade' );

$mech->fill_in_action_ok(
    $mech->moniker_for('BTDT::Action::UpgradeAccount'),
    %args,
    card_number => $goodcard2,
);
$mech->submit_html_ok();
$mech->content_contains('Congratulations', "content has good message");

$record = BTDT::Model::FinancialTransaction->new( current_user => $gooduser );
$record->load_by_cols( %data, last_four => lastfour($goodcard2) );
ok $record->id => 'Got record';
is $record->user_id, $gooduser->id => 'Right user';
is $record->result_code, 1 => 'Got proper result code';
is $record->amount, 3000 => 'Got right amount (in cents)';
like $record->server_response, qr/,|30.00|,/ => 'Submitted right amount to processor';
ok $record->submitted => 'Marked as submitted';
like $record->card_type, qr/mastercard/i => 'Got MasterCard card type';

Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
$user->load( $gooduser->id );
is $user->pro_account, 1, 'User has a pro account';
is $user->paid_until, DateTime->today->add( years => 1 )->ymd, 'Paid until is correct';

$purchase->load_by_cols( transaction_id => $record->id );
ok $purchase->id, "Got a purchase record";
is $purchase->owner_id, $gooduser->id, "Correct user";
is $purchase->description, "Hiveminder Pro", "Right description";

# email notification
@emails = BTDT::Test->messages;
is $emailcount+2, scalar @emails, "Two emails sent";

my $email1 = $emails[0] || Email::Simple->new('');

is $email1->header('Subject'), "Hiveminder Receipt: Thank you for your order!", "Mail subject is correct";
is $email1->header('To'), $user->email, "Mail address is correct";
like $email1->body, qr/@{[$record->order_id]}/, "has correct order id";

my $email2 = $emails[1] || Email::Simple->new('');

like $email2->header('Subject'), qr"Your Hiveminder purchase: Hiveminder Pro", "Mail subject is correct -- we're extending";
is $email2->header('To'), $user->email, "Mail address is correct";
like $email2->body, qr/Hiveminder Pro/, "has correct purchase description";

# good card3 -- gift, bad user
$mech->get_ok( $URL . '/account/gift' );

$mech->fill_in_action_ok(
    $mech->moniker_for('BTDT::Action::AddGiftRecipient'),
    user_id => 'xx@xx'
);
ok( $mech->click_button( value => 'Add recipient' ), "Added gift recipient" );
$mech->content_contains('We don\'t know of anyone by', "content has failure message");

# good card3 -- gift
my $otheruser = BTDT::CurrentUser->new( email => 'otheruser@example.com' )->user_object;
my $lookuser = BTDT::CurrentUser->new( email => 'onlooker@example.com')->user_object;

for my $plural ( 0 .. 1 ) {
    $mech->get_ok( $URL . '/account/gift' );

    BTDT::Test->setup_mailbox();    # clear out the mailbox

    $mech->fill_in_action_ok(
        $mech->moniker_for('BTDT::Action::AddGiftRecipient'),
        user_id => $otheruser->email );

    ok( $mech->click_button( value => 'Add recipient' ),
        "Added gift recipient" );
    $mech->content_lacks( 'We don\'t know of anyone by that',
        "content lacks failure message" );
    $mech->content_contains( $otheruser->email, "Lists correct recipient" );

    if ($plural) {
        $mech->fill_in_action_ok(
            $mech->moniker_for('BTDT::Action::AddGiftRecipient'),
            user_id => $lookuser->email );
        ok( $mech->click_button( value => 'Add recipient' ),
            "Added gift recipient" );
        $mech->content_lacks(
            'We don\'t know of anyone by that',
            "content lacks failure message"
        );
        $mech->content_contains( $lookuser->email, "Lists correct recipient" );
    }

    $mech->fill_in_action_ok(
        $mech->moniker_for('BTDT::Action::UpgradeAccount'),
        %args, card_number => $plural ? $goodcard3 : $goodcard4 );
    $mech->submit_html_ok();

    $mech->content_contains(
        $plural
        ? 'now have Hiveminder Pro accounts'
        : 'now has a Hiveminder Pro account',
        "content has good message"
    );

    Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');

    $record =
      BTDT::Model::FinancialTransaction->new( current_user => $gooduser );
    $record->load_by_cols( %data, last_four => $plural
        ? lastfour($goodcard3)
        : lastfour($goodcard4) );

    ok $record->id => 'Got record';
    is $record->user_id,     $gooduser->id => 'Right user';
    is $record->result_code, 1             => 'Got proper result code';

    is $record->amount, $plural ? 6000 : 3000 => 'Got right amount (in cents)';
    like $record->server_response,
      $plural
      ? qr/,|60.00|,/
      : qr/,|30.00|,/ => 'Submitted right amount to processor';

    ok $record->submitted => 'Marked as submitted';
    like $record->card_type, qr/discover/i => 'Got Discover card type';

    $otheruser->load( $otheruser->id );
    is $otheruser->pro_account, 1, 'User has a pro account';
    is $otheruser->paid_until,
      DateTime->today->add( years => $plural ? 2 : 1 )->ymd,
      'Paid until is correct';

    $purchase =
      BTDT::Model::Purchase->new(
        current_user => BTDT::CurrentUser->new( id => $otheruser->id ) );
    $purchase->load_by_cols( transaction_id => $record->id );
    ok $purchase->id,          "Got a purchase record";
    is $purchase->owner_id,    $otheruser->id, "Correct user";
    ok $purchase->gift,        "Got gift status";
    is $purchase->description, "Hiveminder Pro", "Right description";

    if ($plural) {
        $lookuser->load( $lookuser->id );
        is $lookuser->pro_account, 1, 'User has a pro account';
        is $lookuser->paid_until, DateTime->today->add( years => 1 )->ymd,
          'Paid until is correct';

        my $old_purchase = $purchase->id;
        $purchase =
          BTDT::Model::Purchase->new(
            current_user => BTDT::CurrentUser->new( id => $lookuser->id ) );
        $purchase->load_by_cols(
            transaction_id => $record->id,
            id             => {
                operator => '>',
                value    => $old_purchase
            }
        );
        ok $purchase->id,          "Got a purchase record";
        is $purchase->owner_id,    $lookuser->id, "Correct user";
        ok $purchase->gift,        "Got gift status";
        is $purchase->description, "Hiveminder Pro", "Right description";
    }

    # email notification
    @emails = BTDT::Test->messages;
    is $plural ? 3 : 2, scalar @emails, "Two emails sent";

    $email1 = $emails[0] || Email::Simple->new('');

    is $email1->header('Subject'),
      "Hiveminder Receipt: Thank you for your order!",
      "Mail subject is correct";
    is $email1->header('To'), $user->email, "Mail address is correct";
    like $email1->body, qr/@{[$record->order_id]}/, "has correct order id";

    $email2 = $emails[1] || Email::Simple->new('');

    is $email2->header('Subject'), $user->name . " bought you Hiveminder Pro",
      "Mail subject is correct";
    like $email2->body, qr/Hiveminder Pro/, "has correct purchase description";
    if ( !$plural ) {
        is $email2->header('To'), $otheruser->email, "Mail address is correct";
    }
    else {
        ok(
            ( $email2->header('To') eq $otheruser->email )
              || ( $email2->header('To') eq $lookuser->email ),
            "Mail address is correct"
        );

        my $email3 = $emails[2] || Email::Simple->new('');
        is $email3->header('Subject'),
          $user->name . " bought you Hiveminder Pro", "Mail subject is correct";
        ok(
            ( $email3->header('To') eq $otheruser->email )
              || ( $email3->header('To') eq $lookuser->email ),
            "Mail address is correct"
        );
        like $email3->body, qr/Hiveminder Pro/,
          "has correct purchase description";
    }
}

