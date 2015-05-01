package BTDT::IM::Command::Prev;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'prev' command, which moves to the previous page in a paged listing.

=cut

sub run
{
    my $im = shift;
    my %args = @_;

    return "But I'm not showing you a list!"
        if !defined($args{session}->get('query_header'))
        || $args{session}->get('query_header') eq '';

    $args{session}->set(page => $args{session}->get('page') - 1);
    $im->_show_tasks(%args);
}

1;

