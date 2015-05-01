use warnings;
use strict;

=head2 NAME

BTDT::Action::UpdateTask

=cut

package BTDT::Action::TakeTask;

use base qw/BTDT::Action Jifty::Action BTDT::Action::ArgumentCacheMixin/;

=head2 arguments

We only have an id

=cut

sub arguments {
    my $self = shift;
    return { id => { constructor => 1 } };
}

=head2 take_action

Makes the current user claim ownership of the L<BTDT::Model::Task>
with the given C<id>.

=cut

sub take_action {
    my $self = shift;
    my $record = BTDT::Model::Task->new;
    $record->load($self->argument_value('id'));
    $record->set_owner_id(Jifty->web->current_user->id);
    delete $self->__get_cache->{$self->__cache_key($record)};
    $self->result->message("Task taken.");
}


1;
