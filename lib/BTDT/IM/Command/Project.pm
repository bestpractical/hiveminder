package BTDT::IM::Command::Project;
use strict;
use warnings;
use base 'BTDT::IM::Command::Move';

=head2 run

Runs the 'project' command, which sets the project of tasks.

=head2 type

This command works with projects.

=head2 preposition

C<project of foo IS bar> (not C<project foo TO bar>).

=cut

sub type { 'project' }
sub preposition { 'is' }

sub run {
    my $im = shift;
    return "Nothing to see here." unless $im->current_user->has_group_with_feature('Projects');
    BTDT::IM::Command::Move::run($im, @_);
}

1;

