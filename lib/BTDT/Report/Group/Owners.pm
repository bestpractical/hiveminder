use warnings;
use strict;

=head1 NAME

BTDT::Report::Group::Owners

=head1 DESCRIPTION

Generates reports for a group's task owners

=cut

package BTDT::Report::Group::Owners;
use base qw/BTDT::Report::Group/;

__PACKAGE__->mk_accessors(qw/complete/);

=head1 METHODS

=head2 _get_metrics

=cut

sub _get_metrics {
    my $self = shift;
    my $GID  = $self->group->id;

    my $results = {};

    my $complete_query = '';
    if (defined $self->complete && $self->complete ne 'undef') {
        if ($self->complete) {
            $complete_query = "AND complete='t'";
        }
        else {
            $complete_query = "AND complete='f'";
        }
    }

    my $fetched = $self->count_aggregate_values(
        group_by => 'owner_id',
        query    => qq(group_id = $GID $complete_query),
    );

    my $names = {};

    if ( grep { defined $_->[0] } @$fetched ) {
        my $query = qq( SELECT id, name FROM users WHERE )
                    . join(' or ', map { "id = ".$_->[0] } grep { defined $_->[0] } @$fetched);

        my $rv    = $self->_handle->simple_query( $query );
        $names = $rv->fetchall_hashref('id');
    }

    $results->{ $names->{$_->[0]}->{'name'} } = $_->[1] for @$fetched;
    $self->results($results);
}

=head2 labels

=cut

sub labels {
    my $self = shift;
    return ( sort { $a cmp $b } keys %{ $self->results } );
}

=head2 data

=cut

sub data {
    my $self    = shift;
    my $results = $self->results;
    return ([ map { $results->{$_} } $self->labels ]);
}

1;
