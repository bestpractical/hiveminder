package BTDT::Action::ArgumentCacheMixin;
use strict;
use warnings;


=head1 NAME

BTDT::Action::ArgumentCacheMixin

=cut

# XXX: this started as a mixin, but it didn't fit some actions for
# various reasons.  Should be renamed or merged into Jifty's
# per-request caching service.

sub __get_cache {
    my $cache = Jifty->handler->stash;
    return {} if !$cache;
    return $cache->{RECORD_ARGUMENTS} ||= {};
}

sub __cache_key {
    my ($self, $record) = @_;
    return ref($record).'-'.(defined $record->id ? $record->id : 'NULL');
}

=head2 invalidate_cache RECORD

Invalidates the cache for the given C<RECORD>.

=cut

sub invalidate_cache {
    my ($self, $record) = @_;
    delete $self->__get_cache->{$self->__cache_key($record)};
}

1;
