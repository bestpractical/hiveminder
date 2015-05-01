use warnings;
use strict;

=head2 NAME

BTDT::Action::ChangeListTokens

=cut

package BTDT::Action::ChangeListTokens;
use base qw/ BTDT::Action::UpdateList /;

use Jifty::Param::Schema;
use Jifty::Action schema {
    param id =>
        label is 'Lists',
        valid are defer {
            my $user = Jifty->web->current_user->user_object;
            return [] unless $user;
            my $lists = $user->lists;
            [{
                display_from => 'name',
                value_from   => 'id',
                collection   => $lists,
            }];
        },
        render as 'Select';
};

1;

