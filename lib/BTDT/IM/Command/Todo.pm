package BTDT::IM::Command::Todo;
use strict;
use warnings;
use base 'BTDT::IM::Command';
use BTDT::IM::Command::Filter;

=head2 run

Runs the 'todo' command, which lists incomplete tasks similar to the main todo
page. Also lets the user search such tasks.

=cut

sub run
{
    my $im = shift;
    my %args = @_;

    $im->_list(%args,
        header1 => 'thing to do',
        header  => 'things to do',
        apply_tokens => sub {
            my ($tasks, $args) = splice @_, 0, 2;
            __PACKAGE__->apply_tokens($im, $tasks, $args, @_),
        },
        post_tokens => sub {
            my ($im, $tasks) = @_;
            return "Nothing to do! Maybe you need to use the braindump command. :)"
                if $tasks->count == 0;
            return;
        },
        post_filter => sub {
            my ($im, $tasks, $filters) = @_;
            return if $tasks->count;

            return "No matches, because all tasks are filtered out. (Remember that you can clear filters with <b>filter clear</b>)";
        },
        post_search => sub {
            my ($im, $tasks) = @_;
            return "No matches."
                if $tasks->count == 0;
            return;
        },
    );
}

=head2 ok_to_apply

Returns a hash of arrays mapping column to tokens, for our regular todo lists.

=cut

sub ok_to_apply {
    return (
        owner     => [qw/owner me/],
        complete  => [qw/not complete/],
        starts    => [qw/starts before tomorrow/],
        accepted  => [qw/accepted/],
        but_first => [qw/but_first nothing/],
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

