use warnings;
use strict;

=head1 NAME

BTDT::View::Admin

=cut

package BTDT::View::Admin;
use Jifty::View::Declare -base;
__PACKAGE__->use_mason_wrapper;

require BTDT::View::Admin::Coupons;
alias BTDT::View::Admin::Coupons under 'coupons';

require BTDT::View::Admin::Performance;
alias BTDT::View::Admin::Performance under 'performance';

require BTDT::View::Admin::Usage;
alias BTDT::View::Admin::Usage under 'usage';

require BTDT::View::Admin::Orders;
alias BTDT::View::Admin::Orders under 'orders';

require BTDT::View::Admin::IMAP;
alias BTDT::View::Admin::IMAP under 'imap';

require BTDT::View::Admin::Users;
alias BTDT::View::Admin::Users under 'users';

require BTDT::View::Admin::Locations;
alias BTDT::View::Admin::Locations under 'locations';

template 'index.html' => page { title => 'Admin' } content {
    p { _("Administer carefully, grasshopper."); };
    p {
        my $pull_time = Jifty::DateTime->from_epoch( epoch => BTDT->pull_time );
        _( "We last pulled live at %1 %2 (%3).", $pull_time->hms, $pull_time->ymd, $pull_time->time_zone->name );
    };
};

1;
