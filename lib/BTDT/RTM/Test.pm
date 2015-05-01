package BTDT::RTM::Test;

use strict;
use warnings;

use base 'BTDT::RTM';

=head1 NAME

BTDT::RTM::Test - Test methods

=head1 METHODS

=head2 method_echo

Echos back the parameters that were passed in.

=cut

sub method_echo {
    my $class = shift;
    $class->send_ok( %{$class->params} );
}

=head2 method_login

Returns information about the user that is logged in.

=cut

sub method_login {
    my $class = shift;
    $class->require_user;

    $class->send_ok(
        user => {
            id       => $class->user->id,
            username => $class->user->email,
        },
    );
}

1;
