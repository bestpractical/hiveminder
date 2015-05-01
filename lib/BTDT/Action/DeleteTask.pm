use warnings;
use strict;


=head1 NAME

BTDT::Action::DeleteTask

=cut

package BTDT::Action::DeleteTask;

use base qw/Jifty::Action::Record::Delete/;
use BTDT::Action::ArgumentCacheMixin;

=head2 record_class

This deletes L<BTDT::Model::Task> objects.

=cut

sub record_class { 'BTDT::Model::Task'  }

=head2 report_success

Add a message when we successfully delete a task

=cut

sub report_success {
    my $self = shift;
    my $type = shift;
    $self->result->message("Deleted $type")
        if $type;
}

=head2 take_action

Invalidate the argument cache

=cut

sub take_action {
    my $self = shift;
    my $type = $self->record->type;
    $self->record->start_transaction("delete");
    $self->SUPER::take_action or return;
    $self->record->end_transaction;
    BTDT::Action::ArgumentCacheMixin->invalidate_cache($self->record);
    $self->report_success($type) if not $self->result->failure;
    return 1;
}

1;
