use warnings;
use strict;

=head1 DESCRIPTION

Test importing todo.txt files

=cut

use BTDT::Test tests => 10;
use BTDT::Sync::TodoTxt;

use Test::Deep;

my $parser = BTDT::Sync::TodoTxt->new;

# Simple tag, no metadata
cmp_deeply(
    [$parser->parse_text('A simple task')],
    [{
        summary => 'A simple task',
        tags    => ""
    }]
);

# Try a priority
cmp_deeply(
    [$parser->parse_text('(A) High Priority')],
    [{
        summary  => 'High Priority',
        tags     => "",
        priority => 5
    }]
);

cmp_deeply(
    [$parser->parse_text('(H) Urgent!')],
    [{
        summary  => 'Urgent!',
        tags     => "",
        priority => 4
    }]
);

# Contexts
cmp_deeply(
    [$parser->parse_text('@work Fix BTDT bugs')],
    [{
        summary  => 'Fix BTDT bugs',
        tags     => '@work',
    }]
);

# Projects
cmp_deeply(
    [$parser->parse_text('p:hiveminder Take over the world')],
    [{
        summary  => 'Take over the world',
        tags     => "p:hiveminder",
    }]
);

# And at the end

cmp_deeply(
    [$parser->parse_text('Get a soda p:lunch')],
    [{
        summary  => 'Get a soda',
        tags     => "p:lunch",
    }]
);

# Mix 'n' match
cmp_deeply(
    [$parser->parse_text('(Z) @work Finish Lunchful p:lunch')],
    [{
        summary  => 'Finish Lunchful',
        tags     => '@work p:lunch',
        priority => 1
    }]
);

#Multiple tasks
cmp_deeply(
    [$parser->parse_text(
        "\@work Placate the lifehackers\n\@home Get more sleep")],
    [
        {
            summary => 'Placate the lifehackers',
            tags    => '@work',
        },
        {
            summary => "Get more sleep",
            tags    => '@home'
        }
    ]
);

# A completed task
cmp_deeply(
    [$parser->parse_text('x Make this thing work')],
    [{
        summary  => 'Make this thing work',
        tags     => '',
        complete => 1
    }]
);

# Completed on a date

cmp_deeply(
    [$parser->parse_text('x 2006-06-06 Kill the antichrist')],
    [{
        summary      => 'Kill the antichrist',
        tags         => '',
        complete     => 1,
        completed_at => '2006-06-06'
    }]
);


1;

