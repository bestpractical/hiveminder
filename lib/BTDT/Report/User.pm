use warnings;
use strict;

=head1 NAME

BTDT::Report::User

=head1 DESCRIPTION

Base class for reports which deal with a user

=cut

package BTDT::Report::User;
use base qw/BTDT::Report/;

=head1 ACCESSORS

=head2 user

Gets/sets the User object of the report

=cut

__PACKAGE__->mk_accessors(qw/user/);

=head1 METHODS

=head2 new PARAMHASH

If the user is not explicitly specified, this method sets it to the current
user. Ditto for time_zone

=cut

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    $self->_get_current_user;
    $self->user( $self->current_user->user_object )
        if not defined $self->user;
    $self->time_zone( $self->user->time_zone || 'GMT' )
        if not defined $self->time_zone;

    return $self;
}

1;
