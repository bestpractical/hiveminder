use warnings;
use strict;

=head1 NAME

BTDT::Model::TaskTag

=head1 DESCRIPTION

Represents a tag on a single task. Task tags consist of the a string,
the tag, and the task which it is on.

=cut

package BTDT::Model::TaskTag;
use Jifty::DBI::Schema;
use BTDT::Model::Task;

use base qw( BTDT::Record );

sub is_protected {1}
use Jifty::Record schema {

column tag =>
  type is 'varchar',
  label is 'Tag',
  is immutable;
column task_id =>
  refers_to BTDT::Model::Task,
  label is 'Task',
  is immutable;
};

use Jifty::RightsFrom column => 'task';

1;
