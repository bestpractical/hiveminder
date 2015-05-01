use warnings;
use strict;

=head2 NAME

BTDT::Model::TaskTagCollection

=cut

package BTDT::Model::TaskTagCollection;
use base qw/BTDT::Collection/;

=head2 implicit_clauses

Calls L</enforce_acls> unless C<<acl => 0>> is passed.

=cut

sub implicit_clauses {
    my $self = shift;
    my %args = (
        acl => 1,
        @_
    );

    $self->enforce_acls if $args{acl};
}

=head2 enforce_acls

Joins to tasks, and enforces ACLs at the SQL level.

=cut

sub enforce_acls {
    my $self = shift;

    my $tasks_alias = $self->join(
        alias1 => 'main',
        column1 => 'task_id',
        table2 => 'tasks',
        column2 => 'id',
        is_distinct => 1,
    );

    $self->BTDT::Model::TaskCollection::enforce_acls(
        collection => $self,
        tasks_alias => $tasks_alias,
    );
    $self->results_are_readable(1);
}


=head2 as_string

Returns a string of this collection's tags, properly quoted and
escaped, suitable for editing or parsing by L</tags_from_string>.

=cut

sub as_string {
    my $self = shift;
    return Text::Tags::Parser->new->join_tags( $self->as_list );
}

=head2 as_quoted_string

As L</as_string>, but B<all> tags will be delimeted by quotes in some
fashion.

=cut

sub as_quoted_string {
    my $self = shift;
    return Text::Tags::Parser->new->join_quoted_tags( $self->as_list );
}


=head2 as_list

Returns the tags in this collection object as an array of strings,
sorted alphabetically.

=cut

sub as_list {
    my $self = shift;

    return sort map $_->tag, @{ $self->items_array_ref };
}

=head2 tags_from_string STRING

Return an array of tags found in STRING; delegates to
L<Text::Tags::Parser/parse_string>.

=cut

sub tags_from_string {
    my $self_or_class = shift;
    my $string = shift;

    $string = "" if not defined $string or $string !~ /\S/;
    return Text::Tags::Parser->new->parse_tags($string);
}

1;
