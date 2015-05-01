package BTDT::IM::Command::Help;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'help' command, which shows help text to the user from
html/help/reference/IM.

=cut

sub run
{
    my $im = shift;
    my %args = @_;

    # required due to the way we look for help files
    $args{message} = 'help'
        if $args{message} eq 'index' || $args{message} eq '';

    # is this another name for the command?
    my $package = ($im->package_of($args{message}))[0] || '';
    $package =~ s/.*:://;

    # all help pages are word-chars only
    $args{message} =~ s/\W+//g;

    # all help pages are lowercase
    for ($args{message}, $package) { $_ = lc }

    # otherwise we get the IM index page which is all Mason
    $args{message} ||= 'NONEXISTENT';

    my $helpfile;
    for ("html/help/reference/IM/commands/$args{message}.html",
         "html/help/reference/IM/$args{message}.html",
         "html/help/reference/IM/$args{message}/index.html",
         "html/help/reference/IM/commands/$package.html")
    {
        if (-e $_ && -r _)
        {
            $helpfile = $_;
            last;
        }
    }

    if (!Jifty->config->app('FeatureFlags')->{TimeTracking}) {
        # hide these for now
        $helpfile = '' if $args{message} =~ /estimate|worked/i;
    }

    my $error = sub
    {
        $im->log->error("[IM] Help command error on input '$args{message}': @_");
        "I'm sorry, I seem to have misplaced my manual. Try again later."
    };

    return "I don't have a help file for '$args{message}'. Sorry!"
        unless $helpfile;

    open my $helphandle, '<', $helpfile
        or return $error->("unable to read file $helpfile");

    my $contents = do { local $/; <$helphandle> };

    if ($im->terse) {
        $contents = $1 if $contents =~ /^%\s*#\s*terse:\s*(.+)/m;
    }
    else {
        # strip all comments
        $contents =~ s/^%\s*#.*//mg;
    }

    # the help pages all have proper HTML tags.. the AIM code will replace all
    # \n with <br> which adds excessive linebreakage
    $contents =~ s{<p>\s+</p>}{<p></p>}g;
    $contents =~ s/\n+/\n/g;

    # strip most list tags because some clients (e.g. Adium) displays them raw
    $contents =~ s{</?[ou]l>}{}gi;
    $contents =~ s{</li>}{}gi;
    $contents =~ s{<li>}{* }gi;

    # remove Mason tags used for the web-help menu
    $contents =~ s/<&.*?&>//g;
    $contents =~ s/<\/&>//g;
    $contents =~ s/<%.*?%>//g;
    $contents =~ s/^\s+//;
    $contents =~ s/\s+$//;

    # break long pages (command index in particular) at desired points
    my @contents = split /<!-- page -->/, $contents;
    return @contents if @contents > 1;

    return length($contents[0]) ? $contents[0] : $error->("file is empty");
}

1;

