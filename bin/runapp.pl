#!/usr/bin/env hmperl
# HIVEMINDER OPTIONAL
use strict;
use warnings;
use Cwd;
use Config;
use File::Spec::Functions qw(catfile catdir);
use Sys::Hostname;
use Getopt::Long;

no warnings 'once';
my $config = { cwd => cwd(),
	       perl => $Config{perlpath},
	       webmaster => 'webmaster@'.hostname,
	       hostname => hostname,
	       mode => 'fastcgi',
	       port => 8080,
	     };

die unless GetOptions ("cover"   => \$config->{cover},
		       "debug"   => \$config->{debug},
		       "reset"   => \$config->{reset},
		       "port=i"  => \$config->{port},
		       "mode=s"  => \$config->{mode},
		       "profiler"=> \$config->{profiler});


my %apache_config = ( fastcgi => q{
FastCgiIpcDir /tmp/fastcgi-foo

FastCgiServer [% cwd %]/bin/jifty -initial-env JIFTY_COMMAND=fastcgi
ScriptAlias /  [% cwd %]/bin/jifty/

 <Location />
# Insert filter
SetOutputFilter DEFLATE

# Netscape 4.x has some problems...
BrowserMatch ^Mozilla/4 gzip-only-text/html

# Netscape 4.06-4.08 have some more problems
BrowserMatch ^Mozilla/4\.0[678] no-gzip

# MSIE masquerades as Netscape, but it is fine
# BrowserMatch \bMSIE !no-gzip !gzip-only-text/html

# NOTE: Due to a bug in mod_setenvif up to Apache 2.0.48
# the above regex won't work. You can use the following
# workaround to get the desired effect:
BrowserMatch \bMSI[E] !no-gzip !gzip-only-text/html

# Don't compress images
SetEnvIfNoCase Request_URI \
\.(?:gif|jpe?g|png)$ no-gzip dont-vary

# Make sure proxies don't deliver the wrong content
Header append Vary User-Agent env=!dont-vary
</Location>
});


die "unsupported mode" unless exists $apache_config{$config->{mode}};

my $cmd = shift;
$cmd ||= 'development';

use RunApp::Apache;
use RunApp;

my $apxs  = `which apxs` or die "need apxs";
my $httpd = `which httpd` or die "need httpd";

# use array to retain the order
my @arg = ( apache_fastcgi => RunApp::Apache->new
	    (root => catfile (cwd, 'apache_'.$config->{mode}),
	     report => 1,
	     documentroot => catfile (cwd, 'html'),
	     CTL => 'RunApp::Control::ApacheCtl',
	     required_modules => ["log_config", "alias", "mime", "headers", "setenvif", "deflate", $config->{mode}],
	     config_block => $apache_config{$config->{mode}},
	     apxs => $apxs,
	     httpd => $httpd),
	  );

RunApp->new(@arg)->$cmd ($config);
