package BTDT::IM::Command::Unowned;
use strict;
use warnings;
use base 'BTDT::IM::Command';
use BTDT::IM::Command::Filter;

# XXX: instantiate command objects so we don't need to resort to globals for
# passing state into methods called by others :(
my $group;

=head2 run

Runs the 'unowned' command, which lists incomplete tasks in a group

=cut

sub run
{
    my $im = shift;
    my %args = @_;

    my $input = $args{message};

    return "List the up-for-grabs tasks of which group?"
        if $input !~ /\S/;

    my ($group_name, $group_id) = __PACKAGE__->canonicalize_group($input);
    return "I don't know the '$input' group."
        if !defined($group_id);

    $group = BTDT::Model::Group->new(current_user => $im->current_user);
    $group->load($group_id);

    return "I don't know the '$input' group."
        if !defined($group->id);

    $im->_list(%args,
        header1 => "unowned task in $group_name",
        header => "unowned tasks in $group_name",
        apply_tokens => sub {
            my ($tasks, $args) = splice @_, 0, 2;
            __PACKAGE__->apply_tokens($im, $tasks, $args, @_),
        },
        post_tokens => sub {
            my ($im, $tasks) = @_;
            return "No unowned tasks in $group_name."
                if $tasks->count == 0;
            return;
        },
        post_filter => sub {
            my ($im, $tasks, $filters) = @_;
            return if $tasks->count;

            return "Every unowned tasks in $group_name is filtered out. (Remember that you can clear filters with <b>filter clear</b>)";
        },
        # no searching, since the only input is group name
        search => sub { },
    );
}

=head2 ok_to_apply

Returns a hash of arrays mapping column to tokens, for our regular todo lists.

=cut

sub ok_to_apply {
    return (
        owner     => [qw/owner nobody/],
        complete  => [qw/not complete/],
        starts    => [qw/starts before tomorrow/],
        accepted  => [qw/accepted/],
        but_first => [qw/but_first nothing/],
        group     => [group => $group->id],
    );
}

=head2 apply_token_callback

If the user has an owner filter, then they probably don't care about whether
tasks are accepted.

=cut

sub apply_token_callback {
    my $self = shift;
    my $ok_to_apply = shift;
    my $field = shift;

    $ok_to_apply->{accepted} = [] if $field eq 'owner';
}

1;

