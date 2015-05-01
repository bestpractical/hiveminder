use warnings;
use strict;

=head1 NAME

BTDT::Model::News

=head1 DESCRIPTION

News has a L<BTDT::Model::User> author, a created date, a title, and
content.

=cut

package BTDT::Model::News;

use base  qw( BTDT::Record );
use Jifty::DBI::Schema;

use Jifty::Record schema {
column author_id =>
  refers_to BTDT::Model::User,
  label is 'Author';
column created   =>
  type is 'timestamp',
  filters are qw( Jifty::Filter::DateTime Jifty::DBI::Filter::DateTime),
  label is 'Created on';
column title     =>
  type is 'text',
  label is 'Title';
column content   =>
  type is 'text',
  label is 'Article',
  render_as is 'Textarea';
};


=head2 since

This first appeared in version 0.2.10

=cut

sub since { '0.2.10' }

=head2 create

Defaults the author to be the current user, and the created time to be
now.

=cut

sub create {
    my $self = shift;
    my %args = (
        author_id => $self->current_user->id,
        created   => DateTime->now->iso8601,
        title     => undef,
        content   => undef,
        @_
    );

    $self->SUPER::create(%args);
}

=head2 current_user_can

Anyone can read news articles, only administrators can create, update,
or delete them.

=cut

sub current_user_can {
    my $self = shift;
    my $right = shift;

    # Anyone can read
    return 1 if ($right eq "read");

    # Only admins can do other things
    return $self->current_user->user_object->access_level eq "staff";
}

=head2 as_atom_entry

Returns the task as an L<XML::Atom::Entry> object.

=cut

sub as_atom_entry {
    my $self = shift;

    my $author = XML::Atom::Person->new;
    $author->name($self->author->name);

    my $entry = XML::Atom::Entry->new;
    $entry->author( $author );
    $entry->title( $self->title );
    $entry->content( $self->content);
    return $entry;
}

=head2 author

Override ACLs so you can always see the author of a news post.

=cut

sub author {
    my $self = shift;

    my $obj = $self->_to_record( 'author',
                                 $self->__value('author') );
    $obj->_is_readable(1);
    return $obj;
}

=head2 url

Returns a unique URL for this news item

=cut

sub url {
    my $self = shift;
    my $name = lc $self->title;

    # replace "eat dinner tonight at Joe's Restaurant!
    # with "eat-dinner-tonight-at-joes-restaurant"
    $name =~ s/ /-/g;
    $name =~ tr/a-zA-Z-//cd;

    return "/news/" . $self->id ."-$name";
}

1;
