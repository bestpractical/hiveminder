package BTDT::RTM::Contacts;

use strict;
use warnings;

use base 'BTDT::RTM';

=head1 NAME

BTDT::RTM::Contacts - Lists known contacts

=head1 METHODS

=head2 method_getList

Returns the set of contacts the user knows

=cut

sub method_getList {
    my $class = shift;

    $class->require_user;

    my @contacts
        = map { id => $_->id, fullname => $_->name, username => $_->email, },
        $class->user->people_known;

    $class->send_ok(
        contacts => {
            @contacts ? ( contact => \@contacts ) : (),
        }
    );
}

=head2 method_add

Unimplemented.

=head2 method_delete

Unimplemented.

=cut

sub method_add    { shift->send_unimplemented; }
sub method_delete { shift->send_unimplemented; }

1;
