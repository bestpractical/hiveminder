use warnings;
use strict;

=head1 NAME

BTDT::Report::Group::DayOfWeek

=head1 DESCRIPTION

Generates a report for the distribution of completed tasks over the week

=cut

package BTDT::Report::Group::DayOfWeek;
use base qw/BTDT::Report::Group/;

__PACKAGE__->mk_accessors(qw/column/);

=head1 METHODS

=head2 new PARAMHASH

=cut

sub new {
    my $class = shift;
    my %args  = (
        column => 'completed_at',
        @_
    );
    return $class->SUPER::new(%args);
}

=head2 _get_metrics

=cut

sub _get_metrics {
    my $self   = shift;
    my $GID    = $self->group->id;
    my $column = $self->pg_timestamp_in_timezone( $self->column );

    $self->_get_date_metrics(
        date_part => 'dow',
        query     => "group_id = $GID and @{[$self->column]} is not null and date_part('year', $column) != 1970",
        count     => 7,
    );
}

=head2 labels

=cut

sub labels {
    my $self = shift;
    return qw( Sun Mon Tues Wed Thurs Fri Sat )
}

1;

