use warnings;
use strict;

=head1 NAME

BTDT::Report::User::Groups

=head1 DESCRIPTION

Generates reports for a user's group tasks

=cut

package BTDT::Report::User::Groups;
use base qw/BTDT::Report::User/;

=head1 METHODS

=head2 _get_metrics

=cut

sub _get_metrics {
    my $self = shift;
    my $user = $self->user;
    my $UID  = $user->id;

    my $results = {};

    my $fetched = $self->count_aggregate_values(
        group_by => 'group_id',
        query    => qq(requestor_id = $UID or owner_id = $UID),
    );

    my $names = {};

    if ( grep { defined $_->[0] } @$fetched ) {
        my $query = qq( SELECT id, name FROM groups WHERE )
                    . join(' or ', map { "id = ".$_->[0] } grep { defined $_->[0] } @$fetched);

        my $rv    = $self->_handle->simple_query( $query );
        $names = $rv->fetchall_hashref('id');
    }

    $names->{''}->{'name'} = 'Personal';

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
