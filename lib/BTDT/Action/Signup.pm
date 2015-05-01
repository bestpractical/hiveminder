use warnings;
use strict;

=head1 NAME

BTDT::Action::Signup

=cut

package BTDT::Action::Signup;
use BTDT::Action::CreateUser;
use base qw/BTDT::Action::CreateUser/;


use BTDT::Model::User;

=head2 arguments


The fields for C<Signup> are:

=over 4

=item email: the email address

=item password and password_confirm: the requested password

=item name: your full name

=back

=cut

sub arguments {
    my $self = shift;
    return $self->{__cached_arguments} if (exists $self->{__cached_arguments});
    my $args = $self->SUPER::arguments;

    my %fields = (
        beta_features                => 1,
        email                        => 1,
        email_service_updates        => 1,
        name                         => 1,
        never_email                  => 1,
        notification_email_frequency => 1,
        password                     => 1,
        password_confirm             => 1,
    );

    for ( keys %$args ) { delete $args->{$_} unless ( $fields{$_} ); }
    $args->{'email'}{'ajax_validates'} = 1;
    $args->{'password'}{'ajax_validates'} = 1;
    $args->{'password_confirm'}{'label'} = "Type that again?";
    return $self->{__cached_arguments} = $args;
}

=head2 validate_email

Make sure their email address looks sane

=cut

sub validate_email {
    my $self  = shift;
    my $email = shift;

    return unless BTDT->validate_user_email( action => $self, column => "email", value => $email, implicit => 0 );

    my $u = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
    $u->load_by_cols( email => $email );
    return $self->validation_ok('email') unless $u->id;

    if ( $u->access_level eq 'nonuser' or not $u->email_confirmed) {
        return $self->validation_error( email => 'You have an account, but you need to activate it. Do you need a <a href="/splash/resend">new activation link</a>?' );
    } else {
        return $self->validation_error(email => 'You already have an account. Do you want to <a href="/splash">sign in</a> instead?');
    }

    return $self->validation_ok('email');
}

=head2 validate_password

Make sure the password is at least 6 characters long

=cut

sub validate_password {
    my $self = shift;
    my $pass = shift;

    if ( length($pass) < 6 ) {
        return $self->validation_error(password => "Sorry, but your password needs to be at least 6 characters.");
    }

    return $self->validation_ok('password');
}

=head2 take_action

Overrides the virtual C<take_action> method on L<Jifty::Action> to call
the appropriate C<Jifty::Record>'s C<create> method when the action is
run, thus creating a new object in the database.

Makes sure that the user only specifies things we want them to.

=cut

sub take_action {
    my $self   = shift;
    my $record = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);

    my %values;
    $values{$_} = $self->argument_value($_)
      for grep { defined $self->record->column($_) and defined $self->argument_value($_) } $self->argument_names;

    my ($id) = $record->create(%values);
    # Handle errors?
    unless ( $record->id ) {
        $self->result->error("An error occurred.  Try again later");
        $self->log->error("Create of ".ref($record)." failed: ", $id);
        return;
    }


    $self->result->message( "Welcome to Hiveminder, " . $record->name .".");
    $self->result->content( record => $record);


    return 1;
}

1;
