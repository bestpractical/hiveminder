use warnings;
use strict;

=head1 NAME

BTDT::Report

=head1 DESCRIPTION

A base class for generating reports for BTDT

=cut

package BTDT::Report;
use base qw/Jifty::Object Class::Accessor::Fast/;

=head1 ACCESSORS

=head2 results

=head2 totals

=head2 time_zone

=cut

__PACKAGE__->mk_accessors(qw/results totals time_zone/);

=head1 METHODS

=head2 new [PARAMHASH]

Creates a new BTDT::Report object.  Possible values in the PARAMHASH
include C<results>, C<totals>, and C<time_zone>.

=cut

sub new {
    my $class = shift;
    my %args  = @_;
    return $class->SUPER::new(\%args);
}

=head2 run

Runs the report and gathers the data

=cut

sub run {
    my $self = shift;
    $self->_get_metrics;
}

=head2 as_xml

Convience wrapper around L<XML::Simple/XMLout>.

=cut

sub _get_metrics { die "Override _get_metrics in your subclass.\n" }

sub _pg_offset {
    my $zone = shift;

    # HORRIBLE HACK TO GET A POSTGRES GMT+4:30  style offset
    my $dt     = DateTime->now();
    my $tz     = DateTime::TimeZone->new( name => $zone );
    my $offset = $tz->offset_for_datetime($dt);
    $offset = $offset / 3600;
    $offset = "GMT" . ( $offset > 0 ? "+" : "" ) . $offset;
    $offset =~ s/\.5$/:30/;
    return $offset;
}

=head2 count PARAMHASH

=over 12

=item query

The SQL where clause of the query

=item table

The table of the query.  Defaults to 'tasks'.

=back

Returns a single scalar, the result of the query.

=cut

sub count {
    my $self = shift;
    my %args = (
        query    => undef,
        table    => 'tasks',
        @_
    );

    my $query = "SELECT COUNT(id) FROM ".$args{'table'}." WHERE ".$args{'query'};
    my $rv     = $self->_handle->simple_query($query);
    my $result = $rv->fetchall_arrayref();
    return shift @{shift @$result};
}

=head2 count_aggregate_values PARAMHASH

=over 12

=item group_by

Column to group the query by

=item query

The SQL where clause of the query

=item table

The table of the query.  Defaults to 'tasks'.

=back

Returns an arrayref in the form of [[group_by value, count],...]

=cut

sub count_aggregate_values {
    my $self = shift;
    my %args = (
        group_by => undef,
        query    => undef,
        table    => 'tasks',
        @_
    );

    my $query = join(
        ' ',
        "SELECT", $args{'group_by'} . ",", "COUNT(id)",    'FROM',
        $args{'table'},  'WHERE', $args{'query'}, 'GROUP BY', $args{'group_by'}
    );

    my $rv     = $self->_handle->simple_query($query);
    my $result = $rv->fetchall_arrayref();
    return $result;
}

=head2 count_aggregate_values_in_period PARAMHASH

Takes the following arguments plus any that L<count_aggregate_values> takes.

=over 12

=item group_by

Column to group by which is also used as the date column

=item start

Start date

=item end

End date

=item tz

Timezone to use.  Defaults to the report object's timezone.

=back

Returns an arrayref in the same form as L<count_aggregate_values>

=cut

sub count_aggregate_values_in_period {
    my $self = shift;
    my %args = (
        start   => undef,
        end     => undef,
        tz      => $self->time_zone,
        @_
    );

    $args{'query'} .= qq(
        AND $args{'group_by'} >= @{[$self->_handle->dbh->quote( $args{'start'} )]}
        AND $args{'group_by'} <= @{[$self->_handle->dbh->quote( $args{'end'} )]}
    );

    $args{'group_by'} = "date_trunc('day', "
                        . _pg_timestamp_in_timezone( $args{'group_by'}, _pg_offset( $args{'tz'} ))
                        .')';

    return $self->count_aggregate_values( %args );
}

sub _get_date_metrics {
    my $self = shift;
    my %args = (
        query     => undef,
        date_part => undef,
        count     => 7,
        @_,
    );

    my $column = $self->pg_timestamp_in_timezone( $self->column );

    my $fetched = $self->count_aggregate_values(
        group_by => "date_part('$args{date_part}', $column)",
        query    => $args{query},
        table    => 'tasks'
    );

    my @results = ('0') x $args{count};

    for my $data ( grep { defined $_->[0] } @$fetched ) {
        $results[ $data->[0] ] = $data->[1];
    }

    $self->results( \@results );
}

sub _pg_timestamp_in_timezone {
    my $col    = shift;
    my $offset = shift || '';
    return " $col at time zone '$offset' ";
}

=head2 pg_timestamp_in_timezone COLUMN TIMEZONE

Returns the string necessary to read the given C<COLUMN> in the given
C<TIMEZONE> in postgresql.

=cut

sub pg_timestamp_in_timezone {
    my $self = shift;
    my $col  = shift;
    my $tz   = shift || $self->time_zone;
    return _pg_timestamp_in_timezone( $col, _pg_offset( $tz ) );
}


1;
