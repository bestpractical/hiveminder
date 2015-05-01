use warnings;
use strict;

=head1 NAME

BTDT::Action::UpdateUser

=cut

package BTDT::Action::UpdateUser;

# note the order here: having BTDT::Action first means it gets BTDT's check_authorization
use base qw/BTDT::Action Jifty::Action::Record::Update/;

=head2 record_class

We're updating L<BTDT::Model::User> objects.

=cut

sub record_class { 'BTDT::Model::User' }

=head2 arguments

Pull the generic form fields, but set the labels on to be more readable

Also add a C<regenerate_auth_token> argument, which will cause auth
tokens (feed URLs) to be regenerated if true.

=cut

sub arguments {
    my $self = shift;

    my $args = $self->SUPER::arguments();
    $args->{'password_confirm'}{'label'} = "New password (again)";
    $args->{'password'}{'label'} = "New password";

    $args->{'current_password'} = {
        mandatory => 1,
        label => "Current password",
        render_as => "password",
    };

    $args->{regenerate_auth_token} = {render_as => 'Unrendered'};

    return $args;
}

=head2 validate_password

When validating the password, we ensure that the C<current_password>
argument has the current password.  This validation is on the
C<password> argument instead of the C<current_password> field so that
it gets called even if the C<current_password> argument was not
submitted.

=cut

sub validate_password {
    my $self = shift;

    if ( not $self->record->password_is($self->argument_value('current_password')) ) {
        return $self->validation_error( current_password =>
                "That doesn't match your current password."
        );
    }
    return $self->validation_ok('current_password');
}

=head2 take_action

Regenerate the auth token if so asked, and let the superclass take
care of everything else.

=cut

sub take_action {
    my $self = shift;
    if($self->argument_value('regenerate_auth_token')) {
        $self->record->regenerate_auth_token;
        $self->result->message('Regenerated feed links.  You will need to re-subscribe to any feeds you wish to continue to use.');
    }

    $self->SUPER::take_action(@_);
}

=head2 possible_fields

If the current user is staff, protected and private fields become editable.

=cut

sub possible_fields {
    my $self = shift;

    return $self->SUPER::possible_fields(@_)
        if $self->current_user->access_level ne 'staff';

    Jifty::Action::Record::possible_fields($self, @_);
}

=head2 report_success

Sets the default success message

=cut

sub report_success {
    my $self = shift;

    return if $self->result->message;

    my $pass = $self->argument_value('password');
    if ( defined $pass and length $pass ) {
        $self->result->message('Your new password is now saved.');
    }
    else {
        $self->result->message('Your new preferences are now saved.')
    }
}

1;
