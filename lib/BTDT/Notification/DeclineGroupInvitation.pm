use warnings;
use strict;

package BTDT::Notification::DeclineGroupInvitation;
use base qw/BTDT::Notification/;

=head1 NAME

BTDT::Notification::DeclineGroupInvitation

=head1 ARGUMENTS

C<from>, C<to>, C<group>, C<invite>.

=cut

__PACKAGE__->mk_accessors(qw/invite/);

=head2 setup

Sets up the email.

=cut

sub setup {
    my $self = shift;
    $self->SUPER::setup(@_);

    unless (UNIVERSAL::isa($self->invite, "BTDT::Model::GroupInvitation")) {
        $self->log->error((ref $self) . " called with invalid invite argument");
        return;
    }

    my $from = $self->invite->recipient;
    my $group = $self->invite->group;

    $self->to( $self->invite->sender );
    $self->from ( $from->formatted_email );
    $self->subject("Hiveminder: @{[$from->name]} declined invitation to @{[$group->name]}");

    $self->body(<<"END_BODY");

Sorry, but @{[$self->from]} isn't going to join @{[$group->name]}.

END_BODY

}

1;
