use warnings;
use strict;

package BTDT::Notification::GroupInvitation;
use base qw/BTDT::Notification/;

=head1 NAME

BTDT::Notification::GroupInvitation

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

    my $group = $self->invite->group;
    my $from  = $self->invite->sender;
    my $invite_id = $self->invite->id;

    $self->to( $self->invite->recipient );
    $self->from ( $from->formatted_email );
    $self->subject("You're invited to the Hiveminder group '@{[$group->name]}'");

    if ($self->nonuser_recipient) {
        $self->body(<<"END_BODY");
Hiveminder is a new way to keep track of things you need to do, both
for yourself and with other people.

@{[$from->name]} has been using Hiveminder to keep track of tasks for a
group called "@{[$group->name]}" and wants to be able to share tasks with you.

To be able to see (and update) the group, just sign up for an account by
clicking on the link below.  It doesn't cost anything to use Hiveminder, so
go ahead and get busy!
END_BODY
    }
    else {
        $self->body(<<"END_BODY");
@{[$from->name]} has invited you to join the group "@{[$group->name]}".

If you'd like to accept, just click:

@{[Jifty->web->url(path => "/groups/invitation/accept/$invite_id")]}

If you'd rather not join "@{[$group->name]}", click:

@{[Jifty->web->url(path => "/groups/invitation/decline/$invite_id")]}
END_BODY
    }

    my $html = $self->body;
    $html =~ s|"\Q@{[$group->name]}\E"|<strong>@{[$group->name]}</strong>|g;
    $self->html_body( BTDT->text2html( BTDT->autolinkify( $html ) ) );
}

1;
