package BTDT::IM::Command::Search;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'search' command, which searches all tasks a user can see.

=cut

sub run
{
    my $im = shift;
    my %args = @_;

    if (!defined($args{message}) || $args{message} eq '')
    {
        return "I didn't understand that. For help with search, type <b>help search</b>";
    }

    $im->_list(%args,
        header1 => 'search result',
        header  => 'search results',
        tokens  => [],
    );
}

1;
