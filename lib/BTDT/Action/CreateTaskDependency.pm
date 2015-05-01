use warnings;
use strict;

=head2 NAME

BTDT::Action::CreateTaskDependency

=cut

package BTDT::Action::CreateTaskDependency;

use base qw/BTDT::Action Jifty::Action::Record::Create/;

=head2 record_class

This creates L<BTDT::Model::TaskDependency> objects

=cut

sub record_class { 'BTDT::Model::TaskDependency' }

=head2 arguments

Delete depends_on's valid values so that we don't iterate over EVERY SINGLE TASK

=cut

sub arguments {
    my $self = shift;

    return $self->{__cached_arguments} if exists $self->{__cached_arguments};
    my $args = $self->SUPER::arguments();

    delete $args->{depends_on}->{valid_values};

    return $self->{__cached_arguments} = $args;
}

=head2 validate_depends_on

You can only depend on tasks you can see. This was handled by valid_values but
that's far too slow.

=cut

sub validate_depends_on {
    my $self = shift;
    my $id = shift;
    my $task;

    if (ref($id)) {
        ($task, $id) = ($id, $id->id);
    }
    else {
        $task = BTDT::Model::Task->new;
        $task->load($id);
    }

    unless ($task->current_user_can('read')) {
        return $self->validation_error(depends_on => "Permission denied");
    }

    return $self->validation_ok('depends_on');
}

1;

