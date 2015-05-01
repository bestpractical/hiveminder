use warnings;
use strict;
use BTDT::Test 'no_plan';

my $static_handler = Jifty->handler->view('Jifty::View::Static::Handler');
my $js = "";

for my $file ( @{ Jifty::Web->javascript_libs } ) {
    my $include = $static_handler->file_path( File::Spec->catdir( 'js', $file ) );

    ok( defined $include, "Found $file" );

    my $fh;
    ok( open($fh, '<', $include), "Opened $file" );
    $js .= $_ while <$fh>;
    close $fh;
}

my $plugin = Jifty->find_plugin("Jifty::Plugin::CompressedCSSandJS");
if ($plugin and $plugin->jsmin) {
    $plugin->minify_js(\$js);
    ok($js, "Minified JS happily");
}
