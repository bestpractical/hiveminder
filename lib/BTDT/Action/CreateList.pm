use warnings;
use strict;

=head2 NAME

BTDT::Action::CreateList

=cut

package BTDT::Action::CreateList;
use base qw/BTDT::Action Jifty::Action::Record::Create/;

use Jifty::Param::Schema;
use Jifty::Action schema {
    param 'name' => ajax validates;
};

=head2 record_class

Creates L<BTDT::Model::List> objects.

=cut

sub record_class { 'BTDT::Model::List' }

=head2 validate_name

Makes sure that you have no other lists with this name.

=cut

sub validate_name {
    my $self = shift;
    my $name = shift;

    my $list = BTDT::Model::List->new;
    $list->load_by_cols(
        owner => $self->current_user->id,
        name  => $name,
    );

    if ($list->id) {
        return $self->validation_error(name => _("You already have a list named %1.", $list->name));
    }

    return $self->validation_ok('name');
}

=head2 take_action

Force list to be saved as current user

=cut

sub take_action {
    my $self = shift;

    $self->argument_value( owner => $self->current_user->id );

    return $self->SUPER::take_action( @_ );
}

=head2 report_success

Sets the message to "List saved."

=cut

sub report_success {
    my $self = shift;
    $self->result->message("List saved.");
}

1;
