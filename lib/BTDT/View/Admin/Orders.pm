use warnings;
use strict;

=head1 NAME

BTDT::View::Admin::Orders

=cut

package BTDT::View::Admin::Orders;

use Business::OnlinePayment::AuthorizeNet::AIM::ErrorCodes 'lookup';

use Jifty::View::Declare -base;
use base 'Jifty::View::Declare::CRUD';
__PACKAGE__->use_mason_wrapper;

sub object_type        { 'FinancialTransaction' }
sub fragment_base_path { '/admin/orders' }
sub display_columns    { qw(id user_id amount coupon first_name last_name country error_message) }

# Order descending by created for all collections
sub _current_collection {
    my $self = shift;
    my $collection = $self->SUPER::_current_collection();
    $collection->order_by( column => 'created', order => 'desc' );
    return $collection;
}

template 'no_items_found'  => sub { outs(_("No orders found.  :(")) };
template 'update'          => sub {''};
template 'new_item_region' => sub {''};
template 'edit_item'       => sub {''};
template 'new_item'        => sub {''};
template 'sort_header'     => sub {''};

template 'view' => sub {
    my $self   = shift;
    my $order  = $self->_get_record( get('id') );
    my $failed = ( not defined $order->authorization_code and $order->amount )
                    ? 1 : 0;
    span {{ class is 'transaction-'.( $failed ? 'failed' : 'successful' ) };
        hyperlink(
            url   => '/admin/orders/' . $order->order_id,
            label => $order->created
        );
        outs_raw(" &mdash; ");
        outs( _("%1 (%2)", $order->user->name, $order->user->email) );
    };
};

template 'index.html' => page { title => 'Admin', subtitle => 'Orders' } content {
    my $orders = BTDT::Model::FinancialTransactionCollection->new;
    $orders->unlimit;
    $orders->order_by( column => 'created', order => 'desc' );
    set( search_collection => $orders );
    form {
        render_region(
            name     => 'orderslist',
            path     => '/admin/orders/list',
            defaults => { page => 1, id => 'xxx' }
        );
    };
};

template 'one_order' => page {
    title    => "Order #: " . get('record')->order_id,
    subtitle => get('record')->description
} content {
    render_region( name => 'orderview', path => '/admin/orders/view_order', defaults => {id => get('record')->id} );
};

template 'view_order' => sub {
    my $record = BTDT::Model::FinancialTransaction->new;
    $record->load( get('id') );
    my $failed = ( not defined $record->authorization_code and $record->amount )
                    ? 1 : 0;
    div {{ class is 'receipt' };
        div {{ class is 'form_field' };
            span {{ class is 'label' }; _('Order Time'); };
            div  {{ class is 'value' };
                outs( $record->created );
            };
        };

        div {{ class is 'form_field' };
            span {{ class is 'label' }; _("Status"); };
            div  {{ class is 'value' };
                outs( $failed ? 'FAILURE' : 'SUCCESS' );
            };
        };

        if ( $failed ) {
            div {{ class is 'form_field' };
                span {{ class is 'label' }; _("Result Code"); };
                div  {{ class is 'value' };
                    outs( $record->result_code );
                };
            };
            div {{ class is 'form_field' };
                span {{ class is 'label' }; _("Error"); };
                div  {{ class is 'value' };
                    my $result = lookup( $record->result_code );
                    outs( $result->{'reason'} );
                    outs( "(".$result->{'notes'}.")" )
                        if $result->{'notes'};
                };
            };
        }

        div {{ class is 'form_field' };
            span {{ class is 'label' }; _("User"); };
            div  {{ class is 'value' };
                outs( _("%1 (%2)", $record->user->name, $record->user->email) );
            };
        };

        div {{ class is 'form_field' };
            span {{ class is 'label' }; _('Description'); };
            div  {{ class is 'value' };
                outs( $record->description );
            };
        };

        div {{ class is 'form_field' };
            span {{ class is 'label' }; _('Amount'); };
            div  {{ class is 'value' };
                outs( $record->formatted_amount );
            };
        };

        div {{ class is 'form_field' };
            span {{ class is 'label' }; _('Coupon'); };
            div  {{ class is 'value' };
                outs( $record->coupon->code );
            };
        };

        if ( $record->amount ) {
            for my $field (qw(card_type last_four expiration first_name last_name address city state zip)) {
                div {{ class is 'form_field' };
                    span {{ class is 'label' }; outs( $record->column($field)->label ); };
                    div  {{ class is 'value' };
                        outs( $record->$field );
                    };
                };
            }

            use Locale::Country qw(code2country);
            div {
                { class is 'form_field' };
                span {{ class is 'label' }; _('Country'); };
                div  {{ class is 'value' };
                    outs( $record->country_name );
                };
            };
        }
    };
};

1;
