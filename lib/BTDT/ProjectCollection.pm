use warnings;
use strict;

=head1 NAME

BTDT::ProjectCollection

=cut

package BTDT::ProjectCollection;
use base qw/BTDT::TaskTypeCollection/;

our $LOCATOR = Number::RecordLocator->new;

=head2 task_type

Projects

=cut

sub task_type { 'project' }

=head2 for_milestone ID

Limit this collection to projects of milestone ID.  This method
also updates tokens to include "milestone LOCATOR" so that calls
to new_defaults and create_from_defaults Just Work.

=cut

sub for_milestone {
    my $self      = shift;
    my $milestone = shift;
    my $alias     = shift || $self->new_alias( BTDT::Model::Task->table );

    # Projects of tasks which are for this milestone
    $self->join(
        alias1  => 'main',
        column1 => 'id',
        alias2  => $alias,
        column2 => 'project'
    );
    $self->limit(
        alias   => $alias,
        column  => 'milestone',
        value   => $milestone,
    );

    # Push tokens so new_defaults Just Works
    my @scrubbed = $self->scrub_tokens( milestone => $LOCATOR->encode( $milestone ) );

    push @{ $self->{'tokens'} }, @scrubbed;
    push @{ $self->{'arguments'} }, @scrubbed;
}

1;
