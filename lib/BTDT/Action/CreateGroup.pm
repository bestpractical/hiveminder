use warnings;
use strict;

=head2 NAME

BTDT::Action::CreateGroup

=cut

package BTDT::Action::CreateGroup;
use base qw/BTDT::Action Jifty::Action::Record::Create/;


=head2 record_class

Creates L<BTDT::Model::Group> objects.

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
        return $self->validation_error(name => 'We need you to give your group a name.');
    }

    my $g = BTDT::Model::GroupCollection->new(
                current_user => BTDT::CurrentUser->superuser
            );
    $g->limit( column => 'name', value => $name );

    return $self->validation_error(name => 'Sorry, but someone else beat you to that name.  Get creative and give it another shot.')
        if $g->count;

    return $self->validation_ok('name');
}

1;
