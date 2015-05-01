use warnings;
use strict;

=head2 NAME

BTDT::Action::UpdateGroup

=cut

package BTDT::Action::UpdateGroup;
use base qw/BTDT::Action Jifty::Action::Record::Update/;


=head2 record_class

Updates L<BTDT::Model::Group> objects.

=cut

sub record_class { 'BTDT::Model::Group' }

=head2 arguments

Returns the group name and description fields, with ajax validation

=cut

sub arguments {
    my $self = shift;
    my $args = $self->SUPER::arguments();

    $args->{'name'}{'ajax_validates'} = 1;

    return $args;
}

=head2 validate_name

This validates the name to make sure there aren't existing groups with the
same name.

=cut

sub validate_name {
    my $self = shift;
    my $name = shift;

    if ( not length $name ) {
        return $self->validation_error(name => 'Please give your group a name.');
    }

    my $g = BTDT::Model::GroupCollection->new(
                current_user => BTDT::CurrentUser->superuser
            );
    $g->limit( column => 'name', value => $name );

    return $self->validation_error(name => 'Sorry, but that name is taken.  Get creative and try again.')
        if $g->count and $self->record->id != $g->first->id;

    return $self->validation_ok('name');
}

1;
