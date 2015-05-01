package BTDT::IM::Command::Milestone;
use strict;
use warnings;
use base 'BTDT::IM::Command::Move';

=head2 run

Runs the 'milestone' command, which sets the milestone of tasks.

=head2 type

This command works with milestones.

=head2 preposition

C<milestone of foo IS bar> (not C<milestone foo TO bar>).

=cut

sub type { 'milestone' }
sub preposition { 'is' }

sub run {
    my $im = shift;
    return "Nothing to see here." unless $im->current_user->has_group_with_feature('Projects');
    BTDT::IM::Command::Move::run($im, @_);
}

1;

