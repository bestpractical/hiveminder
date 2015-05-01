use warnings;
use strict;

=head1 NAME

BTDT::Project

=head1 DESCRIPTION

A class for dealing with projects in Hiveminder.

=cut

package BTDT::Project;
use base qw( BTDT::TaskType );

=head2 task_type

Projects have C<task_type> C<project>.

=cut

sub task_type { 'project' }

1;

