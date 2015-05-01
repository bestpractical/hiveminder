package BTDT::IMAP::Mailbox::DynamicSet;

use warnings;
use strict;

use base qw/BTDT::IMAP::Mailbox/;
__PACKAGE__->mk_accessors( qw/args update collection/ );

=head1 NAME

BTDT::IMAP::Mailbox::DynamicSet - Updates kids dynamically

=head1 METHODS

=head2 args

Gets or sets the array reference of arguments to pass to
L<BTDT::IMAP::Mailbox/add_child>.  The value of each of the elements
in the L</collection> will be appended to this.

=head2 update

Gets or sets the array reference of arguments to pass to
L<BTDT::IMAP::Mailbox/update_from_tree>.  If not defined (the
default), children will not be notified when the client attempts to
list them.

=head2 collection [SUB]

Gets or sets the subref which returns the L<Jifty::DBI::Collection>
whose elements we care about.

=head2 init

When created, adds all of the children from L</collection>.

=cut

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    $self->update_tree;
}

=head2 update_tree

Called every time the client does a LIST; we add new members of the
collection as kids.  Note this doesn't I<remove> members which are no
longer children!

=cut

sub update_tree {
    my $self = shift;

    my $c = $self->collection->();
    my @args = @{ $self->args || [] };
    my $key = @{ $self->args }[-1];

    my %seen;
    $seen{ref $_->$key ? $_->$key->id : $_->$key} = $_ for @{ $self->children };

    while (my $obj = $c->next) {
        if ($seen{$obj->id}) {
            $seen{$obj->id}->update_from_tree( @{$self->update}, $obj ) if $self->update;
        } else {
            $self->add_child( @args, $obj );
        }
    }

    $self->SUPER::update_tree;
}

=head2 prep_for_destroy

As the L</collection> is often a closure, make sure we clean it out
when we're getting ready to DESTROY.

=cut

sub prep_for_destroy {
    my $self = shift;
    $self->collection(undef);
    $self->SUPER::prep_for_destroy;
}

1;
