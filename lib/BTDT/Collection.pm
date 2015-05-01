package BTDT::Collection;
use strict;
use warnings;
use base qw/Jifty::Collection/;

=head1 NAME

BTDT::Collection - Base class for all collections

=head1 METHODS

=head2 task_search_on ALIAS C<tokens> TOKENS

=head2 task_search_on ALIAS C<arguments> ARGUMENTS

Given either a list of C<tokens>, or a already-parsed set of
C<argument> pairs, and a sensical join to the
L<BTDT::Model::TaskCollection> on the given C<ALIAS>, limits the
search using the given C<TOKENS> or C<ARGUMENTS>.

=cut

sub task_search_on {
    my $self = shift;
    my ($alias, $type, @rest) = @_;

    my $old_class = ref $self;
    unless ($self->isa("BTDT::Model::TaskCollection")) {
        # The hacky hacky bless stupidity here is because ->search
        # calls methods on $self which only exist in
        # BTDT::Model::TaskCollection.
        $self = bless $self, "BTDT::Model::TaskCollection";
        $self->default_limits(
            collection  => $self,
            tasks_alias => $alias,
        );
    }
    my @args = $type eq "arguments" ? @rest : $self->scrub_tokens(@rest);
    $self->search($alias, @args);
    $self = bless $self, $old_class;
}

1;
