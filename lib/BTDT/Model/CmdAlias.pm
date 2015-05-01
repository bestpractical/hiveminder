use strict;
use warnings;

package BTDT::Model::CmdAlias;

=head1 NAME

BTDT::Model::CmdAlias - a shell-like command alias for the IM system

=cut

use base  qw( BTDT::Record );
use Jifty::DBI::Schema;
use Jifty::Record schema {

    column owner =>
        refers_to BTDT::Model::User,
        is mandatory,
        is immutable,
        default is defer { Jifty->web->current_user->id },
        is protected;

    column name =>
        type is 'text',
        label is 'Name',
        is mandatory;

    column expansion =>
        type is 'text',
        label is 'Expansion',
        is mandatory;

    column created =>
        type is 'timestamp',
        filters are qw( Jifty::Filter::DateTime Jifty::DBI::Filter::DateTime),
        default is defer { DateTime->now->iso8601 },
        is protected;

};

=head2 since

This first appeared in version 0.2.80

=cut

sub since { '0.2.80' }

=head2 current_user_can

If the user is the owner of the alias, let them do what they want.

=cut

sub current_user_can {
    my $self  = shift;
    my $right = shift;
    my %args  = @_;

    if (     $self->__value('owner')
         and $self->__value('owner') == $self->current_user->id )
    {
        return 1;
    }

    return 1 if $right eq 'create';
    return 1 if $self->current_user->is_superuser;
    return 0;
}

1;

