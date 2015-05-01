use warnings;
use strict;

=head1 NAME

BTDT::View::Account

=cut

package BTDT::View::Account::CRUD;
use Jifty::View::Declare -base;
use base 'Jifty::View::Declare::CRUD';
sub object_type        {'FinancialTransaction'}
sub fragment_base_path {'/account/fragments'}

sub _current_collection {
    my $self = shift;
    my $payments
      = Jifty->web->current_user->user_object->financial_transactions;
    $payments->limit(
        column   => 'authorization_code',
        operator => 'is not',
        value    => 'null'
    );
    $payments->order_by( column => 'created', order => 'desc' );
    return $payments;
};

template 'search'          => sub {''};
template 'update'          => sub {''};
template 'search_region'   => sub {''};
template 'new_item_region' => sub {''};
template 'edit_item'       => sub {''};
template 'new_item'        => sub {''};
template 'sort_header'     => sub {''}; # uses nonexistent create action
template 'no_items_found'  => sub { outs( _("No orders found.") ) };
template 'view' => sub {
    my $self    = shift;
    my $payment = $self->_get_record( get('id') );
    hyperlink(
        url   => '/account/orders/' . $payment->order_id,
        label => $payment->created->ymd
    );
    outs_raw(" &mdash; ");
    outs( _( $payment->description ) );
};

package BTDT::View::Account;
use Jifty::View::Declare -base;
__PACKAGE__->use_mason_wrapper;

alias BTDT::View::Account::CRUD under '/fragments';

template 'index.html' => page { title => 'Hiveminder Store' } content {
    my $user = Jifty->web->current_user->user_object;
    p {
        if ( $user->pro_account ) {
            outs( _("You have a ") );
            hyperlink(
                label => _("Hiveminder Pro"),
                url   => '/pro'
            );
            outs( _(" account that expires on ") );
            b { $user->paid_until ? $user->paid_until->ymd : "the heat death of the universe" };
            outs( _(".  ") );
        } else {
            outs( _("You have a free, basic Hiveminder account.  ") );
        }
    };

    my $quota = $user->disk_quota;
    if ( $quota->id and $user->pro_account ) {
        p {
            outs( _("You are currently using %1 (%3%) of your %2 attachment quota.",
                    BTDT->english_filesize($quota->usage),
                    BTDT->english_filesize($quota->cap),
                    sprintf("%0.1f",$quota->usage / $quota->cap)) );
        };
    }

    p {
        outs( _("You can ") );
        if ( $user->pro_account ) {
            hyperlink(
                label => _('extend your account'),
                url   => '/account/upgrade'
            );
        } else {
            hyperlink(
                label => _('upgrade to a Pro account'),
                url   => '/account/upgrade'
            );
            outs(" (");
            hyperlink(
                label => _("what's a Pro account?"),
                url   => '/pro'
            );
            outs(")");
        }
        outs( _(" for a year, ") );
        hyperlink(
            label => _("give the gift of Hiveminder Pro"),
            url   => '/account/gift'
        );
        outs( _(", or ") );
        hyperlink(
            label => _("view your order history"),
            url   => '/account/orders'
        );
    };
};

template 'upgrade' =>
    page { title => 'Hiveminder Store', subtitle => 'Upgrade to Hiveminder Pro!' }
    content {
    render_region(
        name => 'payment_form',
        path => '/account/fragments/payment_form'
    );
    };

template 'gift' => page { title => 'Give the Gift of Hiveminder Pro!' }
    content {
    render_region(
        name     => 'payment_form',
        path     => '/account/fragments/payment_form',
        defaults => { choose_user => 1, }
    );
    };

template 'fragments/payment_form' => sub {
    my $self = shift;
    my %args = (
        user_id => ( get('user_id') || Jifty->web->current_user->id ),
        choose_user => ( get('choose_user') ? 1 : 0 ),
    );

    $args{user} = BTDT::Model::User->new;
    $args{user}->load( $args{user_id} );

    my $display_price = '30.00';

    # If we have gift users, multiply the price by them
    my $giftusers = Jifty->web->session->get('giftusers') || [];
    my $giftcount = scalar @$giftusers;

    # if the user goes to /account/gift, adds N people, then goes to
    # /account/upgrade, he sees a cost of N*$30. this fixes that display error
    $giftcount = 1 if not $args{choose_user};

    $display_price *= $giftcount
        if $giftcount;

    my $result = Jifty->web->response->result('applycoupon');

    if (    defined $result
        and $result->success
        and $result->content('coupon') )
    {
        set 'coupon' => $result->content('coupon');
    }

    if ( get('coupon') ) {
        my $coupon = BTDT::Model::Coupon->new(
            current_user => BTDT::CurrentUser->superuser );
        if ( $coupon->valid( get('coupon') ) ) {
            $display_price = $coupon->apply_to($display_price);
        }
    }

    $display_price = sprintf '%.2f', $display_price;
    $display_price = '0.00' if $display_price < 0;

    p {
        { class is 'note' };
        if ( $args{choose_user} ) {

            if ( $giftcount == 0 ) {
                outs(
                    _(  "The accounts associated with the email addresses below will be upgraded to Hiveminder Pro for one year"
                    )
                );
            } elsif ( $giftcount == 1 ) {
                outs(
                    _(  "The account associated with the email address below will be upgraded to Hiveminder Pro for one year"
                    )
                );
            } else {
                outs(
                    _(  "The %1 accounts associated with the email addresses below will be upgraded to Hiveminder Pro for one year",
                        $giftcount
                    )
                );
            }
        } else {
            outs( _("My ") );
            hyperlink(
                label => _('account'),
                url   => '/account'
            );
            b { $args{user}->email; };
            outs(
                _(" will be upgraded to Hiveminder Pro for one year (until ")
            );
            my $base = (    $args{user}->paid_until
                        and $args{user}->paid_until > DateTime->today )
                            ? $args{user}->paid_until->clone
                            : DateTime->today;
            b { $base->add( years => 1 )->ymd };
            outs( _(')') );
        }

        if ( $display_price eq '0.00' ) {
            outs( _(' for ') );
            b { _('free!') };
        } else {
            outs( _(' at the price of ') );
            b { _( '$%1 USD', $display_price ) };
            outs( _('.') );
        }

        outs(" (");
        hyperlink(
            label  => _("What comes with a Pro account?"),
            url    => '/pro',
            target => '_blank',
        );
        outs(")");

    };

    my $action = Jifty->web->new_action(
        moniker => 'upgradeaccount',
        class   => 'UpgradeAccount'
    );

    my $applycoupon = Jifty->web->new_action(
        moniker => 'applycoupon',
        class   => 'ApplyCoupon'
    );

    my $addgiftrecipient = Jifty->web->new_action(
        moniker => 'addgiftrecipient',
        class   => 'AddGiftRecipient',
    );

    div {
        { class is 'cc_form'; }
        form {
            Jifty->web->form->register_action($applycoupon);

            div {
                { class is 'inline' };
                fieldset {
                    legend { _("Discounts") };
                    if ( not get('coupon') ) {
                        p {
                            { class is 'coupon-hint' };
                            _(  "If you have a coupon code, enter it below and apply the coupon first."
                            );
                        };
                        div {
                            { class is 'line' };
                            render_param( $applycoupon => 'coupon' );
                            form_submit(
                                label  => 'Apply coupon',
                                submit => $applycoupon
                            );
                        };
                    } elsif ( BTDT::Model::Coupon->valid( get('coupon') ) ) {
                        div {
                            { class is 'line' };
                            render_param(
                                $action       => 'coupon',
                                default_value => get('coupon'),
                                render_mode   => 'read'
                            );
                            render_param(
                                $action       => 'coupon',
                                default_value => get('coupon'),
                                render_as     => 'Hidden'
                            );
                            render_param(
                                $applycoupon  => 'coupon',
                                default_value => get('coupon'),
                                render_as     => 'Hidden'
                            );
                        };
                    }
                };
            };

            if ( $args{'choose_user'} ) {
                Jifty->web->form->register_action($addgiftrecipient);

                div {
                    { class is 'inline' };
                    fieldset {
                        legend { _("Gift Recipients") };

                        div {
                            { style is 'width: 48%; float: left;' };
                            p {
                                { class is 'cc-hint' };
                                _(  q(If your chosen recipient isn't a Hiveminder user,
                                    please invite them first by using the "Invite a
                                    Friend" form to the left.)
                                );
                            };

                            render_param(
                                $addgiftrecipient => 'user_id',
                                label             => 'Email'
                            );
                            form_submit(
                                label  => 'Add recipient',
                                submit => [ $addgiftrecipient, $applycoupon ]
                            );
                        };
                        div {
                            {
                                class is 'current_recipients',
                                    style is
                                    'width: 48%; float: left; padding-left: 1em;'
                            };
                            p {
                                { class is 'cc-hint' };
                                _("Current recipients:");
                            };
                            my $ids = Jifty->web->session->get('giftusers')
                                || [];

                            # Show the current recipients
                            ul {
                                li {
                                    outs($_);
                                    my $action = Jifty->web->new_action(
                                        class     => 'RemoveGiftRecipient',
                                        arguments => { user_id => $_ }
                                    );
                                    outs_raw(
                                        $action->button(
                                            label => 'Remove',
                                            submit =>
                                                [ $action, $applycoupon ],
                                            arguments => { user_id => $_ },
                                            as_link   => 1
                                        )
                                    );
                                }
                                for @$ids;
                            };

                            # Render the hidden user_id values
                            my $field = $action->form_field(
                                'user_id',
                                render_as => 'Hidden',
                                label     => ''
                            );
                            for (@$ids) {
                                $field->default_value($_);
                                outs_raw( $field->render );
                            }
                        };
                    };
                };
            }

            div {
                { class is 'inline', style is 'clear: both;' };
                if ( $display_price != 0 ) {
                    my @billing = (
                        [qw(first_name last_name)], [qw(address)],
                        [qw(city state zip)],       [qw(country)],
                    );
                    my %defaults;
                    my $transactions = $args{'user'}->financial_transactions;
                    $transactions->limit(
                        column   => 'authorization_code',
                        operator => 'is not',
                        value    => 'null'
                    );
                    $transactions->order_by(
                        column => 'created',
                        order  => 'desc'
                    );
                    if ( $transactions->count ) {
                        my $t = $transactions->first;
                        $defaults{$_} = $t->$_
                            for
                            qw( first_name last_name address city zip country );
                    }
                    fieldset {
                        legend { _("Billing Information") };
                        p {
                            { class is 'cc-hint' };
                            outs(_("Please enter your address exactly as it appears on your credit card statement."));
                        };
                        _render_fields_from_array( $action, \@billing,
                            \%defaults );
                    };
                    fieldset {
                        legend { _("Credit Card") };
                        p {
                            { class is 'cc-hint' };
                            outs(
                                _(  "We accept Visa, MasterCard, and Discover, but don't worry about telling us the credit card type "
                                )
                            );
                            outs_raw("&mdash;");
                            outs( _(" we can figure it out.") );
                        };
                        div {
                            { class is 'line' };
                            render_param( $action => $_ )
                                for qw(card_number cvv2);
                            div {
                                { class is 'security_code_help' };
                                BTDT->contextual_help(
                                    'payments/card-security-code',
                                    label => "Where's the card security code?"
                                );
                            };
                        };
                        div {
                            { class is 'line' };
                            render_param( $action => $_ )
                                for qw(expiration_month expiration_year);
                        };
                        p {
                            { class is 'card_types' };
                            img {
                                {
                                    src is
                                        '/static/images/payments/logo_ccVisa.gif',
                                        width is 37, height is 21,
                                        alt is 'Visa'
                                }
                            };
                            img {
                                {
                                    src is
                                        '/static/images/payments/logo_ccMC.gif',
                                        width is 37, height is 21,
                                        alt is 'MasterCard'
                                }
                            };
                            img {
                                {
                                    src is
                                        '/static/images/payments/logo_ccDiscover.gif',
                                        width is 37, height is 21,
                                        alt is 'Discover'
                                }
                            };
                        };
                    };
                }
                fieldset {
                    div {
                        outs(
                            _(  q(Clicking the "Purchase" button below will charge the credit card above )
                            )
                        );
                        b { _( '$%1 USD today', $display_price ) };
                        outs( _(".  ") );
                    }
                    unless $display_price == 0;

                    div {
                        { class is 'line' };
                        render_param(
                            $action       => 'user_id',
                            render_as     => 'Hidden',
                            default_value => $args{'user'}->id
                        ) if not $args{'choose_user'};
                        Jifty->web->form->next_page( url => '/account' );
                        form_submit(
                            label => (
                                $display_price != 0 ? 'Purchase' : 'Upgrade'
                            )
                        );
                    };
                };
            };
        };
    };
};

sub _render_fields_from_array {
    my $action   = shift;
    my $lines    = shift;
    my $defaults = shift || {};
    my $extra    = shift || {};
    for my $line (@$lines) {
        div {
            { class is 'line' };
            render_param(
                $action => $_,
                (   exists $defaults->{$_}
                    ? ( default_value => $defaults->{$_} )
                    : ()
                ),
                %$extra
            ) for @$line;
        };
    }
}

template 'orders' =>
    page { title => 'Hiveminder Store', subtitle => 'Order History' } content {
    p {
        _("Here's a history of all your orders with Hiveminder.");
    };

    render_region(
        name     => 'orderslist',
        path     => '/account/fragments/list',
        defaults => { page => 1, id => 'xxx' }
    );

    };

template 'one_order' => page {
    title    => "Order #: " . get('record')->order_id,
    subtitle => get('record')->description
    } content {
    my $rec = get('record');
    p {
        { class is 'note' };
        _(  "This is a receipt for your order.  While we show the last four digits of your credit card, we do not store the full number."
        );
    };
    render_region( name => 'orderview', path => '/account/fragments/view_order', arguments => {id => $rec->id} );
    };

template 'fragments/view_order' => sub {
    my $id = get('id');
    my $record = BTDT::Model::FinancialTransaction->new;
    $record->load( $id );
    my $update = new_action(
        class   => 'SearchFinancialTransaction',
        moniker => "update-" . Jifty->web->serial,
        record  => $record
    );

    div {
        { class is 'receipt' };
        form {
            if ( $record->user_id != Jifty->web->current_user->id ) {
                div {
                    { class is 'form_field' };
                    span {
                        { class is 'label' };
                        _("User ID");
                    };
                    div {
                        { class is 'value' };
                        outs( $record->user_id );
                    };
                };
            }

            render_param( $update => 'description', render_mode => 'read' );

            div {
                { class is 'form_field' };
                span {
                    { class is 'label' };
                    _('Amount');
                };
                div {
                    { class is 'value' };
                    outs( $record->formatted_amount );
                };
            };

            div {
                { class is 'form_field' };
                span {
                    { class is 'label' };
                    _('Order Date');
                };
                div {
                    { class is 'value' };
                    outs( $record->created->ymd );
                };
            };

            render_param( $update => $_, render_mode => 'read' )
                for qw( card_type last_four expiration );

            render_param( $update => $_, render_mode => 'read' )
                for qw( first_name last_name address city );

            render_param( $update => 'state', render_mode => 'read' )
                if $record->state;

            render_param( $update => 'zip', render_mode => 'read' );

            use Locale::Country qw(code2country);
            div {
                { class is 'form_field' };
                span {
                    { class is 'label' };
                    _('Country');
                };
                div {
                    { class is 'value' };
                    outs( $record->country_name );
                };
            };
        };
    };
};

template 'delete' =>
    page { title => 'My Account', subtitle => 'Delete account' } content {
    p {
        _(<<END);
If you really want to, you can delete your Hiveminder account.  We'd appreciate
it if you'd let us know why you're deleting your account by using the feedback form
on the left.  Thanks.
END
    };

    p {
        { class is 'note' };
        b {
            _(  "All data associated with your account will be deleted. If you delete your account, it CAN NOT BE RECOVERED."
            );
        };
        outs("  ");
        outs( _("Make SURE this is what you want to do.") );
    };

    render_region(
        name => 'deleteaccount',
        path => '/account/fragments/delete_button',
    );
    };

template 'fragments/delete_button' => sub {
    form {
        hyperlink(
            label     => 'Delete my account',
            onclick   => { replace_with => '/account/fragments/confirm_delete', },
            as_button => 1,
            class     => 'delete'
        );
    };
};

template 'fragments/confirm_delete' => sub {
    my $delete = new_action(
        class   => 'DeleteUser',
        moniker => 'deleteuser',
        record  => Jifty->web->current_user->user_object
    );

    form {
        Jifty->web->form->register_action($delete);
        form_submit(
            submit => $delete,
            label  => "Yes, I'm sure, really delete my account.",
            class  => 'delete',
            url    => '/',
            onclick =>
                qq|return confirm('This is your last chance.  Still want to delete your account?');|
        );
    };
};

1;
