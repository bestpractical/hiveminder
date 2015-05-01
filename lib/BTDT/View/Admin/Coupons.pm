use warnings;
use strict;

=head1 NAME

BTDT::View::Admin::Coupons

=cut

package BTDT::View::Admin::Coupons;
use Jifty::View::Declare -base;
use base 'Jifty::View::Declare::CRUD';
__PACKAGE__->use_mason_wrapper;

sub object_type { 'Coupon' }
sub fragment_base_path { '/admin/coupons' }
sub display_columns { qw( code discount minimum expires use_limit use_count once_per_user description ) };

template 'no_items_found' => sub { outs(_("No coupons found.")) };
template 'search' => sub {''};
template 'search_region' => sub {''};

template 'index.html' => page { title => 'Admin', subtitle => 'Coupons' } content {
    my $coupons = BTDT::Model::CouponCollection->new;
    $coupons->unlimit;
    $coupons->order_by( column => 'expires', order => 'desc' );

    p {{ class is 'note' };
        _("Expired coupons should be left around for future reference.");
    };

    set search_collection => $coupons;
    form {
        render_region(
            name => 'coupons-list',
            path => '/admin/coupons/list'
        );
    }
};

1;
