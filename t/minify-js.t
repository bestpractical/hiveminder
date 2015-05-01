use warnings;
use strict;

use BTDT::Test;

my $plugin = Jifty->find_plugin('Jifty::Plugin::CompressedCSSandJS')
    or plan skip_all => "Plugin 'CompressedCSSandJS' required";

$plugin->js
    or plan skip_all => "CompressedCSSandJS must be configured to compress JS";

plan tests => 1;

# this is the default only on production
$plugin->jsmin(Jifty::Util->absolute_path('bin/jsmin-closure'));

my $js = $plugin->_generate_javascript_nocache;
ok($js, "generated compressed javascript");

