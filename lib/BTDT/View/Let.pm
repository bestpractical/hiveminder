package BTDT::View::Let;
use strict;
use warnings;
use Jifty::View::Declare -base;

template pro_signup => page {
    render_region(
        name => 'payment_form',
        path => '/account/fragments/payment_form'
    );
};


1;

