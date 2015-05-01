package BTDT::IM::Command::Page;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'page' command, which moves to the specified page in a paged listing.

=cut

sub run
{
    my $im = shift;
    my %args = @_;
    my $max = $args{session}->get('max_page');

    return "But I'm not showing you a list!"
        if !defined($args{session}->get('query_header'))
        || $args{session}->get('query_header') eq '';

    if ($args{message} =~ /^\s*$/)
    {
        return sprintf 'You are on page %d of %d.',
                   $args{session}->get('page'),
                   $max;
    }

    unless ($args{message} =~ /^\s*(\d+)\s*$/)
    {
        return "I don't understand. Use: page [number]";
    }

    if ($1 == 0 || $1 > $max)
    {
        if ($max == 1)
        {
            return "Invalid page number. Only page 1 is valid.";
        }

        return "Invalid page number. Valid numbers are 1-$max.";
    }

    $args{session}->set(page => $1);
    $im->_show_tasks(%args);
}

1;

