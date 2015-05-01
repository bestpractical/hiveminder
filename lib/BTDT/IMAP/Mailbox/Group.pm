package BTDT::IMAP::Mailbox::Group;

use warnings;
use strict;

use base qw/BTDT::IMAP::Mailbox::TaskEmailSearch/;
__PACKAGE__->mk_accessors( qw/group/ );

=head1 NAME

BTDT::IMAP::Mailbox::Group - Represents a group mailbox

=head1 METHODS

=head2 group [GROUP]

Gets or sets the L<BTDT::Model::Group> associated with this mailbox.

=head2 new HASHREF

The name of the mailbox is forced to be the name of the provided
C<group> object.

=cut

sub new {
    my $class = shift;

    my %args = %{shift || {}};
    $args{name} = $args{group}->name;
    return $class->SUPER::new(\%args);
}

=head2 update_from_tree

Rename ourselves if the group has been renamed.

=cut

sub update_from_tree {
    my $self = shift;
    my %args = ( group => undef, @_ );
    return if $self->name eq $args{group}->name;
    $self->{name} = $args{group}->name;
    $self->full_path(purge => 1);
}

=head2 init

After the mailbox is created, sets the mailbox's search to be tasks
owned by the user in that group.  Adds child mailboxes for each owner
in the group, and every milestone and project, as well as a mailbox
for all uncompleted tasks.

=cut

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->tokens([qw/owner me not complete starts before tomorrow accepted but_first nothing group/, $self->group->id]);
    my $members = $self->group->members;
    $members->limit( column => 'id', operator => '!=', value => $self->group->current_user->id );
    my $users = $self->add_child( name => "Owners" );
    while (my $user = $members->next) {
        $users->add_child( name => $user->email, class => "TaskEmailSearch" )
          ->tokens([owner => $user->email, qw/not complete but_first nothing group/, $self->group->id]);
    }
    $users->add_child( name => "Up for grabs", class => "TaskEmailSearch" )
      ->tokens([qw/owner nobody not complete but_first nothing group/, $self->group->id]);

    if ($self->group->has_feature('Projects')) {
        for my $type (qw/milestone project/) {
            my $class = "BTDT::".ucfirst($type)."Collection";
            my $collection = $class->new;
            $collection->incomplete;
            $collection->group( $self->group->id );

            my $box = $self->add_child( name => ucfirst($type) );
            while (my $item = $collection->next) {
                $box->add_child( name => $item->summary, class => "TaskEmailSearch" )
                    ->tokens([qw/not complete but_first nothing group/, $self->group->id, $type => $item->record_locator]);
            }
            $box->add_child( name => "(No $type)", class => "TaskEmailSearch" )
                ->tokens([qw/not complete but_first nothing group/, $self->group->id, $type => "none"]);
        }
    }

    $self->add_child( name => "All tasks", class => "TaskEmailSearch" )
      ->tokens([qw/not complete but_first nothing group/, $self->group->id]);

    return $self;
}

1;
