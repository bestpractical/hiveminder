use warnings;
use strict;

=head1 NAME

BTDT::Model::GroupCollection

=cut

package BTDT::Model::GroupCollection;
use base qw/BTDT::Collection/;

=head2 limit_contains_user

Limit this Collection to Groups containing a specific user

=cut

sub limit_contains_user {
    my $self = shift;
    my $user = shift;

    unless ($user && $user->id) {
        Carp::cluck("We were asked to find something that contains a user, but were handed an undef user");
        return undef;
    }

    my $alias = $self->join(
        column1  => 'id',
        table2   => BTDT::Model::GroupMember->table,
        column2  => 'group_id',
        is_distinct => 1,
    );

    $self->limit(alias  => $alias, column => "actor_id", value  => $user->id);
}

1;
