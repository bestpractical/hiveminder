use warnings;
use strict;

=head1 NAME

BTDT::TaskType::Collection

=head1 DESCRIPTION

A base class for subclassing to get classes for dealing with collections of
different task types.  This is a subclass of BTDT::Model::TaskCollection, but with some special methods thrown in.

=cut

package BTDT::TaskTypeCollection;
use base qw( BTDT::Model::TaskCollection );

=head2 task_type

You must override this method in your subclass to return the value of the type
column that your subclass represents.

=cut

sub task_type {
    my $self  = shift;
    my $class = ref $self;
    my $hint  = $class eq __PACKAGE__ ? "" : " (did you forget to override task_type in $class?)";
    $self->log->fatal("BTDT::TaskTypeCollection must be subclassed to be used" .  $hint);
}

=head2 limit_to_type

Limit this collection to L<task_type> type tasks

=cut

sub limit_to_type {
    my $self = shift;
    $self->SUPER::limit_to_type( @_, type => $self->task_type );
}

1;

