use warnings;
use strict;

=head1 NAME

BTDT::Model::TaskDependency

=head1 DESCRIPTION

Tasks can depend on other tasks.


=cut

package BTDT::Model::TaskDependency;
use BTDT::Model::Task;
use base  qw( BTDT::Record );
use Jifty::DBI::Schema;

use Jifty::Record schema {
column task_id =>
  refers_to BTDT::Model::Task,
  label is 'Task',
  is immutable;

column depends_on =>
  refers_to BTDT::Model::Task,
  label is 'Depends on',
  is immutable;
};

use Jifty::RightsFrom column => 'task';

=head2 since

This class was added in version 0.2.14

=cut

sub since { '0.2.14' }


=head2 create

Create a new task dependency and then update both tasks' dependency
caches. Disallow the creation of duplicate dependencies

=cut

sub create {
    my $self  = shift;

    # Search for another object with these details
    my $other = $self->new;
    $other->load_by_cols(@_);
    if($other->id) {
        return (0, _("That link already exists!"));
    }

    my @ret = $self->SUPER::create(@_);

    $self->task->_update_dependency_cache if ($self->task->id);
    $self->depends_on->_update_dependency_cache if ($self->depends_on->id);

    return @ret;
}

=head2 delete

Remove a task dependency, updating both tasks' dependency caches.

=cut

sub delete {
    my $self = shift;

    my $task = $self->task;
    my $depends_on = $self->depends_on;

    my @ret = $self->SUPER::delete(@_);

    $task->_update_dependency_cache();
    $depends_on->_update_dependency_cache();

    return (@ret);
}

=head2 current_user_can

Dependencies can never be updated, but otherwise pull their rights
from the task.

=cut

sub current_user_can {
    my $self  = shift;
    my $right = shift;

    return 0 if $right eq "update";

    return $self->SUPER::current_user_can( $right, @_ );
}

=head2 autogenerate_action

Don't create an Update action for this model.

=cut

sub autogenerate_action {
    my $class = shift;
    return shift ne "Update";
}

1;
