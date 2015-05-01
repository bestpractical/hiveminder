use strict;
use warnings;

package BTDT::Model::IMAPUID;

use BTDT::Model::User;
use BTDT::Model::TaskTransaction;

=head1 NAME

BTDT::Model::IMAPUID - Stores IMAP UID <=> transaction mappings

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
        is mandatory,
        is case_sensitive,
        is immutable;

    column uid =>
        type is 'integer',
        is mandatory,
        is immutable;

    column transaction =>
        refers_to BTDT::Model::TaskTransaction,
        is mandatory,
        is immutable;

};

use Jifty::RightsFrom column => 'user';

=head2 since

This first appeared in version 0.2.81

=cut

sub since { '0.2.81' }

1;

