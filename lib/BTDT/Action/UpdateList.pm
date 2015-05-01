use warnings;
use strict;

=head2 NAME

BTDT::Action::UpdateList

=cut

package BTDT::Action::UpdateList;
use base qw/BTDT::Action Jifty::Action::Record::Update/;

=head2 record_class

Updates L<BTDT::Model::List> objects.

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

    # it's OK to rename the list to itself -- e.g. a case adjustment
    if ($list->id && $list->id != $self->record->id) {
        return $self->validation_error(name => _("You already have a list named %1.", $list->name));
    }

    return $self->validation_ok('name');
}

1;

