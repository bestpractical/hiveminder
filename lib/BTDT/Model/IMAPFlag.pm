use strict;
use warnings;

package BTDT::Model::IMAPFlag;

use BTDT::Model::User;

=head1 NAME

BTDT::Model::IMAPFlag - Stores flags on IMAP messages

=cut

use base  qw( BTDT::Record );
use Jifty::DBI::Schema;
sub is_private {1}
use Jifty::Record schema {

    column user_id =>
        refers_to BTDT::Model::User,
        is mandatory,
        is immutable;

    column path =>
        type is 'text',
        is case_sensitive,
        is immutable;

    column uid =>
        type is 'integer',
        is mandatory,
        is immutable;

    column value =>
        type is 'blob',
        filters are 'Jifty::DBI::Filter::Storable';
};

use Jifty::RightsFrom column => 'user';

=head2 since

This first appeared in version 0.2.81

=cut

sub since { '0.2.81' }

1;
