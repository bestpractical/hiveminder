use warnings;
use strict;

=head1 DESCRIPTION

This is a template for your own tests. Copy it and modify it.

=cut

use BTDT::Test tests => 43;
my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::TestServer');

my $URL = $server->started_ok;


use_ok('BTDT::Model::Task');
my $task = BTDT::Model::Task->new( current_user => BTDT::CurrentUser->superuser );
$task->create( summary => 'hey. task. woot' );

ok( $task->id, "Created task ".$task->id);

is( $task->tags, "" );
is( $task->tag_collection->count, 0 );

$task->set_tags('foo bar baz');
is( $task->_value('tags'), q{"bar" "baz" "foo"} );
is( $task->tags, q{bar baz foo} );
is( $task->tags, $task->tag_collection->as_string );
is_deeply( [ $task->tag_collection->as_list ], [ qw/bar baz foo/ ]);
is( $task->tag_collection->count, 3, "We now have 3 tags" );

$task->set_tags('foo baz');
is( $task->_value('tags'), q{"baz" "foo"} );
is( $task->tags, q{baz foo} );
is( $task->tags, $task->tag_collection->as_string );
is_deeply( [ $task->tag_collection->as_list ], [ qw/baz foo/ ]);
is( $task->tag_collection->count, 2, "We now have 2 tags" );

$task->set_tags('foo bar baz');
is( $task->_value('tags'), q{"bar" "baz" "foo"} );
is( $task->tags, q{bar baz foo} );
is( $task->tags, $task->tag_collection->as_string );
is_deeply( [ $task->tag_collection->as_list ], [ qw/bar baz foo/ ]);
is( $task->tag_collection->count, 3, "We now have 3 tags" );

my $other_task = BTDT::Model::Task->new( current_user => BTDT::CurrentUser->superuser );
$other_task->create(summary => 'whoa. *two* tasks.');

ok($other_task->id, 'Created another task');
$other_task->set_tags('FOO ZOT');
is($other_task->tags, q{FOO ZOT}, "Preserved case");

my @expected_all = (
    { label => 'foo',
      value => 'foo'},

    {   label => 'bar',
        value => 'bar',
    },
    {   label => 'baz',
        value => 'baz',
    }
);

my @expected = (
    {   label => 'bar',
        value => 'bar',
    },
    {   label => 'baz',
        value => 'baz',
    }
);

{
    my @autocompletions = $task->autocomplete_tags('b');
    is_deeply( \@autocompletions, \@expected, "the array we expected" );

}
{
    my @autocompletions = $task->autocomplete_tags('BA');
    is_deeply( \@autocompletions, \@expected, "Ignore case in autocompletion" );
}
{
    my @expected_bar = ( );  # don't autocomplete fully-typed tags
    my @autocompletions = $task->autocomplete_tags('bar');
    is_deeply( \@autocompletions, \@expected_bar, "the array we expected" );
}
{

my @expected_bourbon = (
    {   value => 'bourbon bar',
        label => 'bar',
    },
    {   value => 'bourbon baz',
        label => 'baz',
    }
);
    my @autocompletions = $task->autocomplete_tags('bourbon ba');
    is_deeply( \@autocompletions, \@expected_bourbon, "the array we expected when we have another tag" );
}
{
    my @autocompletions = $task->autocomplete_tags('');
    is_deeply( \@autocompletions, [], "nothing to go on. no results");
}
{
    my @autocompletions = $task->autocomplete_tags('foo');
    is_deeply( \@autocompletions, [], "Ignore case when completing a full tag");
}
{
    my @expected_foo = ({value => 'FOO', label => 'FOO'});
    my @autocompletions = $task->autocomplete_tags('FO');
    is_deeply( \@autocompletions, \@expected_foo, "Preserve case if it's present in the database");
}
{
    my @expected_foo = ({value => 'foo', label => 'foo'});
    my @autocompletions = $task->autocomplete_tags('fo');
    is_deeply( \@autocompletions, \@expected_foo, "Respect case if both choices exist");
}
{
    my @expected_zot = ({value => 'ZOT', label => 'ZOT'});
    my @autocompletions = $task->autocomplete_tags('ZO');
    is_deeply( \@autocompletions, \@expected_zot, "Change case if we've only seen one option");
}

# test tag inheritance

my $mech = BTDT::Test->get_logged_in_mech($URL);

isa_ok($mech, 'Jifty::Test::WWW::Mechanize');

$mech->form_number(2);
$mech->set_fields('J:A:F-summary-tasklist-new_item_create' => "tags test 1");
$mech->set_fields('J:A:F-tags-tasklist-new_item_create' => "foo bar baz");
$mech->submit_html_ok();
ok($mech->success, "first tags test task submit successful");

ok($mech->find_link(text => "But first...", n => 3),
   "found the 'But first...' link");
$mech->follow_link_ok(text => "But first...", n => 3,
                      "followed the 'But first...' link");

$mech->form_number(2);
# tags seem to be alphabetized
is($mech->value('J:A:F-tags-tasklist-item-5-new_item_create'),
   "bar baz foo", "new task form has the correct tags");
$mech->set_fields('J:A:F-summary-tasklist-item-5-new_item_create' => "tags test 2");
$mech->submit_html_ok();
ok($mech->success, "second tags test task submit successful");

ok($mech->find_link(text => 'bar'), 'found bar tag');
ok($mech->find_link(text => 'baz'), 'found baz tag');
ok($mech->find_link(text => 'foo'), 'found foo tag');

1;

