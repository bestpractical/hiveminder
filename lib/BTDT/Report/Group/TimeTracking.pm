use warnings;
use strict;

=head1 NAME

BTDT::Report::Group::TimeTracking

=head1 DESCRIPTION

Generates a report for the estimated time vs. actual time

=cut

package BTDT::Report::Group::TimeTracking;
use base qw/BTDT::Report::Group/;

__PACKAGE__->mk_accessors(qw(labels));

=head2 _get_metrics

=cut

sub _get_metrics {
    my $self = shift;
    my $GID  = $self->group->id;

    my @results;
    my $max = 0;

    for my $member ( sort { $a->actor->name cmp $a->actor->name } @{ $self->group->group_members } ) {
        my $owner = $member->actor;
        my $id    = $owner->id;

        my $query = <<"        SQL";
            SELECT time_estimate, time_worked
              FROM tasks
             WHERE
                   group_id = $GID
               and owner_id = $id
               and time_estimate is not null
               and time_estimate != 0
               and time_worked is not null
               and time_worked != 0
               and complete is true
        SQL

        my $rv      = $self->_handle->simple_query( $query );
        my $results = $rv->fetchall_arrayref();

        my @data;
        # Convert seconds into hours
        for my $task (@$results) {
            push @data, map { $_ / 3600 } @$task;
        }

        $max = @data if @data > $max;

        push @results, \@data;
    }

    $self->labels([qw(x y) x ($max / 2)]);
    $self->results( \@results );
}

=head2 legend

=cut

sub legend {
    my $self = shift;
    return [map { $_->actor->name } sort { $a->actor->name cmp $b->actor->name } @{ $self->group->group_members }];
}

1;
