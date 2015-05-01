use warnings;
use strict;

=head1 NAME

BTDT::TaskType

=head1 DESCRIPTION

A base class for subclassing to get classes for dealing with different task types.
This is a subclass of BTDT::Model::Task, but with special loading and creation plus
a few other methods thrown in.

=cut

package BTDT::TaskType;
use base qw( BTDT::Model::Task );

=head2 table

Specify that we still want the table "tasks" even though we're a different class

=cut

sub table { 'tasks' }

=head2 task_type

You must override this method in your subclass to return the value of the type
column that your subclass represents.

=cut

sub task_type {
    my $self  = shift;
    my $class = ref $self;
    my $hint  = $class eq __PACKAGE__ ? "" : " (did you forget to override task_type in $class?)";
    $self->log->fatal("BTDT::TaskType must be subclassed to be used" .  $hint);
}

=head2 new_type TYPE [ARGS]

Figures out the class name for TYPE and returns a new object of that type.

=cut

sub new_type {
    my $self  = shift;
    my $type  = shift;
    my $class = "BTDT::" . ucfirst $type;
    return $class->new( @_ );
}

=head2 current_user_can

Don't allow some fields to be set

=cut

sub current_user_can {
    my $self  = shift;
    my $right = shift;
    my %args  = (@_);

    # Don't let anyone set the time tracking fields of projects
    if (    $args{'column'}
        and $args{'column'} =~ /^time_/ )
    {
        return 0;
    }
    return $self->SUPER::current_user_can( $right, %args );
}

=head2 create

Forces creation of specific-type tasks

=cut

sub create {
    my $self = shift;
    return $self->SUPER::create( @_, type => $self->task_type );
}

=head2 load_by_cols

Forces loading of only the specific-type tasks

=cut

sub load_by_cols {
    my $self = shift;
    return $self->SUPER::load_by_cols( @_, type => $self->task_type );
}

=head2 url

Return a useful URL for the object.

=cut

sub url {
    my $self = shift;
    my $url  = $self->group_id
                    ? Jifty->web->url( path =>  '/groups/'.$self->group_id.'/'.$self->type.'/'.$self->record_locator )
                    : Jifty->web->url( path =>  '/'.$self->type.'/'.$self->record_locator );
    return $url;
}

=head2 tasks [TOKENS]

Returns a BTDT::Model::TaskCollection of the tasks for this task type.
Optionally takes a list of tokens to apply to the collection.

=cut

sub tasks {
    my $self  = shift;
    my $tasks = BTDT::Model::TaskCollection->new;
    $tasks->from_tokens(
        $self->type => $self->record_locator,
        @_
    );
    return $tasks;
}

1;

