package BTDT::IMAP::Mailbox::SavedList;

use warnings;
use strict;

use base qw/BTDT::IMAP::Mailbox::TaskEmailSearch/;

__PACKAGE__->mk_accessors( qw/list/ );

=head1 NAME

BTDT::IMAP::Mailbox::SavedList - Show a pro user's saved lists in IMAP

=head1 METHODS

=head2 new HASHREF

The name of the mailbox is pulled from the C<list> parameter, as are
the search tokens.

=cut

sub new {
    my $class = shift;
    my $args = shift;
    $args->{name} = $args->{list}->name;
    my $self = $class->SUPER::new($args);
    $self->tokens([$args->{list}->tokens_as_list]);
    return $self;
}

1;
