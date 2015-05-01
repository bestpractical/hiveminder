use warnings;
use strict;

=head1 NAME

BTDT::Report::Group

=head1 DESCRIPTION

Base class for reports which deal with a group

=cut

package BTDT::Report::Group;
use base qw/BTDT::Report/;

=head1 ACCESSORS

=head2 group

Gets/sets the Group object of the report

=cut

__PACKAGE__->mk_accessors(qw/group/);

=head1 METHODS

=head2 new PARAMHASH

Set the timezone to the current user's timezone, if not already set

=cut

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    $self->time_zone( BTDT::DateTime->now->time_zone->name )
        if not defined $self->time_zone;

    return $self;
}

1;
