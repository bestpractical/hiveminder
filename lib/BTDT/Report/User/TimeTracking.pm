use warnings;
use strict;

=head1 NAME

BTDT::Report::User::TimeTracking

=head1 DESCRIPTION

Generates a report for the estimated time vs. actual time

=cut

package BTDT::Report::User::TimeTracking;
use base qw/BTDT::Report::User/;

__PACKAGE__->mk_accessors(qw(labels));

=head2 _get_metrics

=cut

sub _get_metrics {
    my $self = shift;
    my $UID  = $self->user->id;

    my $query = <<"    SQL";
        SELECT time_estimate, time_worked
          FROM tasks
         WHERE
               owner_id = $UID
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

    $self->labels([qw(x y) x (@data / 2)]);
    $self->results( [\@data] );
}

=head2 legend

=cut

sub legend {
    return ['Your completed tasks'];
}

1;
