use warnings;
use strict;

=head1 NAME

BTDT::MilestoneCollection

=cut

package BTDT::MilestoneCollection;
use base qw/BTDT::TaskTypeCollection/;

our $LOCATOR = Number::RecordLocator->new;

=head2 task_type

Milestones

=cut

sub task_type { 'milestone' }

=head2 for_project ID

Limit this collection to milestones of project ID.  This method
also updates tokens to include "project LOCATOR" so that calls
to new_defaults and create_from_defaults Just Work.

=cut

sub for_project {
    my $self    = shift;
    my $project = shift;
    my $alias   = shift || $self->new_alias( BTDT::Model::Task->table );

    # Milestones of tasks which are for this project
    $self->join(
        alias1  => 'main',
        column1 => 'id',
        alias2  => $alias,
        column2 => 'milestone'
    );
    $self->limit(
        alias   => $alias,
        column  => 'project',
        value   => $project,
    );

    # Push tokens so new_defaults Just Works
    my @scrubbed = $self->scrub_tokens( project => $LOCATOR->encode( $project ) );

    push @{ $self->{'tokens'} }, @scrubbed;
    push @{ $self->{'arguments'} }, @scrubbed;
}

1;
