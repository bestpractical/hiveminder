use warnings;
use strict;

=head2 NAME

BTDT::Action::CreateUserIM

=cut

package BTDT::Action::CreateUserIM;

use base qw/BTDT::Action Jifty::Action::Record::Create/;

=head2 record_class

This creates  L<BTDT::Model::UserIM> objects

=cut

sub record_class { 'BTDT::Model::UserIM' }

=head2 arguments

Tell the action that we need to get 'action' in our constructor,
otherwise bad things will happen

=cut

sub arguments {
    my $self = shift;

    return $self->{__cached_arguments} if (exists $self->{__cached_arguments});
    my $args = $self->SUPER::arguments();

    $args->{action}{constructor} = 1;
    $args->{user_id}{default_value} = Jifty->web->current_user->user_object->email;

    return $self->{__cached_arguments} = $args;

}

=head2 take_action

Go ahead and make the UserIM

=cut

sub take_action {
    my $self = shift;

    # check to see if the user has an unused token
    my $userim = BTDT::Model::UserIM->new();
    $userim->load_by_cols(user_id => Jifty->web->current_user->id, confirmed => 0);
    if ($userim->id)
    {
        $self->result->error("You already have an unused password.");
        return;
    }

    $self->result->message("Hope to hear from you on IM soon!");
    return $self->SUPER::take_action(@_);
}

1;
