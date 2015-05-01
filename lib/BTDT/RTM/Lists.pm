package BTDT::RTM::Lists;

use strict;
use warnings;

use base 'BTDT::RTM';

=head1 NAME

BTDT::RTM::Lists - List management

=head1 METHODS

=head2 method_getList

Returns the default lists (including pro lists if applicable).  This doesn't
return custom saved lists yet.

=cut

sub method_getList {
    my $class = shift;
    $class->require_user;

    my $position = 0;

    my @lists = map {
        $position++;
        {  id       => $position,
           name     => $_->{'label'},
           deleted  => 0,
           locked   => 1,
           archived => 0,
           position => $position,
           smart    => 1    }
    } $class->default_lists;

    if ( Jifty->web->current_user->pro_account ) {
        my $saved = Jifty->web->current_user->user_object->lists;
        $saved->order_by( column => 'name' );

        while ( my $l = $saved->next ) {
            $position++;
            push @lists, {
                id       => $l->id + 1000,
                name     => $l->name,
                deleted  => 0,
                locked   => 1,
                archived => 0,
                position => $position,
                smart    => 1
            };
        }
    }

    $class->send_ok(
        lists => {
            list => \@lists
        },
    );
}

=head2 method_add

Unimplemented.

=head2 method_archive

Unimplemented.

=head2 method_delete

Unimplemented.

=head2 method_setDefaultList

Unimplemented.

=head2 method_setName

Unimplemented.

=head2 method_unarchive

Unimplemented.

=cut

sub method_add            { shift->send_unimplemented; }
sub method_archive        { shift->send_unimplemented; }
sub method_delete         { shift->send_unimplemented; }
sub method_setDefaultList { shift->send_unimplemented; }
sub method_setName        { shift->send_unimplemented; }
sub method_unarchive      { shift->send_unimplemented; }

1;
