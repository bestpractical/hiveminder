package BTDT::IM::Command::Tags;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'tags' command, which displays tags.

=cut

sub run {
    my $self = shift;
    my %args = @_;

    my $tasks = BTDT::Model::TaskCollection->new;
    $tasks->from_tokens(qw(owner me not complete));
    $self->apply_filters($tasks, %args);
    $tasks->smart_search($args{message}) if $args{message} ne '';

    $tasks->columns('tags', 'owner_id', 'requestor_id', 'group_id');

    my $tag_count = $tasks->tags;
    delete $tag_count->{''}; # untagged tasks

    if (keys %$tag_count == 0) {
        return "You have no tags.";
    }

    return "Tags: " . join ', ', sort { lc($a) cmp lc($b) } keys %$tag_count;
}

1;

