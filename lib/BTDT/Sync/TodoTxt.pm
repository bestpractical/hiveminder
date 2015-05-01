use warnings;
use strict;

=head1 NAME

BTDT::Sync::TodoTxt

=head1 DESCRIPTION

An importer for L<http://todotxt.com/> files.

=cut

package BTDT::Sync::TodoTxt;
use base qw/Jifty::Object/;
use BTDT::Sync;

=head2 new

Returns a new C<BTDT::Sync::TodoTxt> object.

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self;
}

=head2 from_text TEXT

Import tasks from the text of a todo.txt file into tasks in the
database. Returns a data structure of the sort returned by
L<BTDT::Sync/sync_data>

=cut

sub from_text {
    my $self = shift;
    my $text = shift;

    my @parsed = $self->parse_text($text);

    return BTDT::Sync->sync_data(tasks => \@parsed);
}

=head2 parse_text TEXT

Parses a todo.txt file into an array of hashes containg data for the
the tasks contained therein.

=cut

sub parse_text {
    my $self = shift;
    my $text = shift;
    my @lines = split /\r?\n/, $text;

    my @tasks = ();
    for my $line (@lines) {
        my %task;

        # Trim whitespace
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;

        next unless $line;

        # Check if the task has been marked as done
        if($line =~ s/^x \s+ ( \d{4} - \d{2} - \d{2} )? \s* //x) {
            $task{complete} = 1;
            $task{completed_at} = $1 if $1;
        }

        # Check for a priority
        if($line =~ s/^[(] ([A-Z]) [)] \s* //x) {
            # Priority is A-Z. For now, just divide the alphabet in 4,
            # put those tasks in priorities 1,2,4,5, and leave
            # unmarked tasks at the default 3. This is possibly not
            # right, but the interpretation of priorities is almost
            # certainly not universal among todo.sh users, anyways
            my $pri = $1;
            $task{priority} =
               ($pri ge 'A' && $pri le 'F') ? 5 :
               ($pri ge 'G' && $pri le 'M') ? 4 :
               ($pri ge 'N' && $pri le 'S') ? 2 :
               ($pri ge 'T' && $pri le 'Z') ? 1 : undef;
        }

        # Now we have a line that is the task summary, possibly
        # containing ``contexts'', marked as @foo, or projects, marked
        # as p:foo. Grab any instances of either of these, and make
        # them tags.
        my @tags = ();
        while( $line =~ s{ \s* (@ | p:) (\w+) \s* }{}x) {
            push @tags, "$1$2 ";
        }
        $task{tags} = Text::Tags::Parser->new->join_tags(@tags);

        $task{summary} = $line;

        push @tasks, \%task;
    }

    return @tasks;
}


1;
