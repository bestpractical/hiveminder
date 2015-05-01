use warnings;
use strict;

=head1 NAME

BTDT::Milestone

=head1 DESCRIPTION

A class for dealing with milestones in Hiveminder.

=cut

package BTDT::Milestone;
use base qw( BTDT::TaskType );

=head2 task_type

Milestones have C<task_type> C<milestone>.

=cut

sub task_type { 'milestone' }

1;

