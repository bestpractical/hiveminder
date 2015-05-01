use warnings;
use strict;

use BTDT::Test tests => 11;

use_ok ('Jifty::Web::Form::Field');

can_ok('Jifty::Web::Form::Field', 'new');
can_ok('Jifty::Web::Form::Field', 'name');

my $field = Jifty::Web::Form::Field->new();


# Form::Fields don't work without a framework
is($field->name, undef);
ok($field->name('Jesse'));
is($field->name, 'Jesse');

is($field->class, '');
is($field->class('basic'),'basic');
is($field->class(),'basic');
is($field->name, 'Jesse');

is ($field->type, 'text', "type defaults to text");
