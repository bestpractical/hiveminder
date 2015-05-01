use warnings;
use strict;

=head1 NAME

BTDT - Been There, Done That

=head1 DESCRIPTION

This file serves mostly to include all of the various modules that
parts of BTDT need.  It may eventually evolve into a singleton with
some additional useful methods on it.

=cut

package BTDT;

use Calendar::Simple;
use Carp;
use Compress::Zlib;
use MIME::Base64;
use Data::ICal::Entry::Todo;
use Data::ICal;
use Date::ICal;
use DateTime;
use Digest::MD5;
use Email::Address;
use Email::MIME;
use Email::MIME::ContentType;
$Email::MIME::ContentType::STRICT_PARAMS = 0; # Be loose in what we accept
use Email::Simple::Creator;
use Email::Simple;
use HTML::Scrubber;
use HTML::TagCloud;
use BTDT::HTML::Truncate;
use String::Koremutake;
use Text::FixEOL;
use Text::Markdown;
use Text::Tags::Parser;
use URI::Escape;
use XML::Atom::Entry;
use XML::Atom::Feed;
$XML::Atom::DefaultVersion = '1.0';
use Regexp::Common qw(URI);
use File::Find::Rule;
use File::Spec;

use base qw/Class::Data::Inheritable/;

__PACKAGE__->mk_classdata( $_ ) for qw/help_toc memcached/;

=head2 start

Handles application specific startup.  Currently this appends the extra
JS libs we use to Jifty->web->javascript_libs and builds the help's table
of contents.

It also loads things like BTDT::Project and BTDT::Milestone.

=cut

sub start {
    my $class = shift;

    # Store away the memcached connection, if any.
    $class->memcached( $Jifty::DBI::Record::Memcached::MEMCACHED );

    Jifty->web->add_javascript(qw(
        jsan/HTTP/Cookies.js
        jsan/Digest/MD5.js
        login_hashing.js
        urchin.js
        jquery.corner.js
        jquery.stopwatch.js
        jquery.simplemodal.js
        pretty_dates.js
    ));

    my $root = Jifty::Util->absolute_path(
                   Jifty->config->framework('Web')->{'TemplateRoot'}
               );

    my $toc = $class->_index_help( $root, Jifty::Web::Menu->new, $root, 'help' );
    $class->help_toc( $toc );

    # Require anything extra that should only be required at run time,
    # like model subclasses
    Jifty::Util->require( 'BTDT::'.$_ )
        for qw( Project Milestone ProjectCollection MilestoneCollection );

    $SIG{USR1} = sub {
        warn "*************** $$ STATE ***************\n";
        warn "Request is: \n" . Jifty::YAML::Dump(Jifty->web->request)
          if Jifty->web and Jifty->web->request;
    };
}

sub _index_help {
    my ($class, $urlbase, $menubase, $base, $file) = @_;

    my @spec = File::Spec->splitpath( $base, 1 );
    my $path = File::Spec->catpath( @spec[0,1], $file );

    my $menu = $menubase->child(
        $file =>
        url   => '/' . File::Spec->abs2rel( $path, $urlbase ),
        label => $class->_file_to_label($file),
    );

    my $rule = File::Find::Rule->not_name( qr/^[_\.]/ )
                               ->not_name( 'index.html' )
                               ->maxdepth( 1 )
                               ->mindepth( 1 )
                               ->relative;
    $rule->not_name( 'IMAP' ) unless Jifty->config->app('FeatureFlags')->{IMAP};
    if (!Jifty->config->app('FeatureFlags')->{TimeTracking}) {
        $rule->not_name( 'time-tracking.html' );
        $rule->not_name( 'estimate.html' );
        $rule->not_name( 'worked.html' );
    }

    my @matches = $rule->in($path);

    for my $match ( sort { $a cmp $b } @matches ) {
        my @mspec = File::Spec->splitpath( $path, 1 );
        my $mpath = File::Spec->catpath( @mspec[0,1], $match );

        if ( -d $mpath ) {
            $class->_index_help( $urlbase, $menu, $path, $match );
        }
        elsif ( -f $mpath ) {
            $menu->child(
                $match,
                url   => $match,
                label => $class->_file_to_label($match),
            );
        }
    }

    return $menu;
}

sub _file_to_label {
    my $class = shift;
    my $name  = shift;

    $name =~ s/\.html$//g;
    $name =~ s/[_-]/ /g;

    return ucfirst $name;
}

=head2 contextual_help STRING [, PARAMHASH]

Returns a L<Jifty::Web::Form::Clickable> using the optional I<PARAMHAS> if
provided.  The I<url> of the link will be automatically generated from
I<STRING> by appending C</help/> and prepending C<.html>.

=cut

sub contextual_help {
    my $self  = shift;
    my $topic = shift;

    my %args  = (
        label   => '?',
        class   => 'help',
        tooltip => 'Get help',
        target  => 'help_system',
        url     => ( $topic =~ m|/$| ? "/help/$topic" : "/help/$topic.html" ),
        onclick => "return BTDT.Util.openHelpWindow(this.href)",
        @_,
    );

    return Jifty::Web::Form::Link->new( %args )->render;
}

=head2 current_eula_version

Returns the version of the current site TOS/privacy policy, as pulled
from the Jifty config.yml

=cut

sub current_eula_version {
    my $self = shift;
    return Jifty->config->app('EULAVersion');
}

=head2 autolinkify STRING

Takes text and returns it with bare URLs automagically made into Markdown-ready
URLs.

=cut

# XXX TODO: is there a better place for this method?
sub autolinkify {
    my $self = shift;
    my $text = shift;
    my $MAX_CHARS = 80;
    my $NL = ' ';

    # work around Regexp::Common::URI::http's non-handling of anchors even
    # though Regexp::Common::URI::RFC2396 supports it
    use Regexp::Common::URI::RFC2396 qw();
    my $fragment = $Regexp::Common::URI::RFC2396::fragment;
    my $abs_path = $Regexp::Common::URI::RFC2396::abs_path;

    # split the link text so it wraps properly and escape characters in the
    # URL text that Markdown would otherwise try to format
    $text =~ s%((?:$RE{URI}{HTTP}{-keep}{-scheme => 'https?'}|evernote://$abs_path)(?:#$fragment)?)%
                my ($link_url, $link_text) = ($1, $1);
                $link_text =~ s/(.{$MAX_CHARS})/$1$NL/g;        # wrapping
                $link_text =~ s/([`\\*_{}\[\]()#.!])/\\$1/g;    # escaping
                $link_url  =~ s/[.,]$//; # be nice when people end a sentence or
                                         # clause with a link followed by punctuation
                "<a href=\"$link_url\" target=\"_blank\">$link_text</a>";
              %eg;

    $text =~ s{(\A|\s+)#([A-Z0-9]+)(\s+|\Z)}
              {$1<a href="http://task.hm/$2" target="_blank">#$2</a>$3}g;

    return $text;
}

=head2 text2html TEXT

Render text (e.g. a task comment) as HTML.

Currently uses Markdown. We may be removing it.

=cut

sub text2html {
    my $self = shift;
    my $text = shift;

    # Markdown chokes on wide characters.
    return
        Encode::decode_utf8(
            Text::Markdown::markdown(
                Encode::encode_utf8($text)));
}

=head2 format_text TEXT [PARAMHASH]

Use C<autolinkify> and C<text2html> to format text appropriately
for task descriptions and comments.

=cut

sub format_text {
    my $self = shift;
    my $text = shift;
    my %args = (short    => 0,          # Truncate the text?
                chars    => 160,        # Length at which to truncate
                ellipsis => chr(8230),  # Raw ellipsis char
                @_,
               );

    return if not defined $text;
    return $text if not length $text;

    my $first_scrub = HTML::Scrubber->new();
    $first_scrub->default( 1, { '*' => 1, });
    $first_scrub->deny(qw{ a });

    my $href_regex = qr{^(?:http:|ftp:|https:|mailto:|evernote:|/)}i;
    my $second_scrub = HTML::Scrubber->new();
    $second_scrub->default(
                       0,
                       {
                        '*' => 0,
                        id  => 1,
                        class => 1,
                        href => $href_regex
                       }
                      );
    $second_scrub->deny('*');
    $second_scrub->allow(qw/b u p br i hr em strong span div ul ol li dl dt dd pre code blockquote/);
    $second_scrub->rules( a => { target => 1,  href => $href_regex} );

    # For truncated text, we don't want to process line breaks
    if ($args{short}) {
        $text =~ s/\n/ /g;
    }
    else {
        # If we have a bare \n that's not part of a larger paragraph break,
        # preformatted block, or mail quote, replace it with <br /> so that
        # we don't lose it.
        $text =~ s/\r\n/\n/g;
        $text =~ s/(?<!\n)\n(?!(?:\n|    |>))/<br class="automatic" \/>\n/g;
    }

    # strip links
    $text = $first_scrub->scrub($text);

    # Restore > so Markdown can parse them as email quotes
    # If Markdown doesn't get to them first, the second scrubber
    # will pick them up and re-encode them as &gt;
    $text =~ s/&gt;/>/g;

    # Trim to 10 times the eventual length, if any -- Markdown can be
    # quite slow with large content, which we can avoid by doing a
    # first pass of shortening before formatting.
    substr($text, $args{chars}*10) = '' if $args{short} and length($text) > $args{chars}*10;

    # add HTML formatting
    $text = BTDT->autolinkify( $text ) if $text;
    $text = BTDT->text2html( $text ) if $text;

    # strip all unwanted HTML formatting
    $text = $second_scrub->scrub($text);

    # Running this, regardless of the length of the input, will close any
    # open tags so the rest of the page doesn't get screwed up.  (Ie. if
    # someone passes just '<i>italics', Truncate will turn it into
    # '<i>italics</i>'.)
    my $ht = BTDT::HTML::Truncate->new(
        utf8      => 1,
        chars     => ( $args{short} ? $args{chars} : length $text ),
        repair    => 1,
        ellipsis  => $args{ellipsis}
    );

    $text = $ht->truncate( $text );

    $text = '' if not defined $text;

    return $text;
}

=head2 english_filesize BYTES [PRECISION]

Nicely formats a number of BYTES into an English description.  Optionally
takes a precision with which to format the result.  Defaults to 1.

=cut

# Need a better place for this...
sub english_filesize {
    my $self = shift;
    my $size = shift;
    my $unit = ' bytes';
    my $precision = ( defined $_[0] ? shift : 1 );

    return '' if not defined $size;

    if ( int( $size / 1024**2 ) > 0 ) {
        $size = $size / 1024**2;
        $unit = 'MB';
    }
    elsif ( int( $size / 1024 ) > 0 ) {
        $size = $size / 1024;
        $unit = 'KB';
    }

    $precision = 0 if $unit eq " bytes";
    return sprintf "%0.${precision}f%s", $size, $unit;
}

=head2 is_production

Returns true if this is running in a production environment; it does
this by examining the C<BaseURL> configration setting.

=cut

sub is_production {
    return Jifty->config->framework('Web')->{BaseURL} =~ /hiveminder\.com/;
}

=head2 validate_user_email PARAMHASH

Does user email validation for actions.  Valid parameters include:

=over

=item action

The L<BTDT::Action> that we're doing validation for

=item column

The name of the argument we're validating

=item value

The value being validated

=item existing

A boolean, defaulting to false -- whether the account must exist

=item implicit

A boolean, defaulting to true -- whether literals such as 'nobody',
'anybody', and 'me' are enabled for this field.

=item empty

A boolean, defaulting to false -- whether the empty string is a valid
option.

=item nobody_ok

A boolean, defaulting to false -- whether 'nobody' is a valid value
in the absence of a group.

=back

=cut

sub validate_user_email {
    my $class = shift;
    my %args  = (
        action    => undef,
        column    => undef,
        value     => undef,
        existing  => 0,
        implicit  => 1,
        empty     => 0,
        nobody    => 1,
        group     => 0,
        nobody_ok => 0,
        @_
    );
    $args{value} ||= '';

    return $args{action}->validation_ok( $args{column} )
        if $args{empty} and $args{value} =~ /^\s*$/;
    return $args{action}->validation_ok( $args{column} )
        if $args{implicit} and lc $args{value} =~ /^(?:anyone|me)$/;

    if ( $args{implicit} and lc $args{value} =~ /^(?:nobody)$/ ) {
        return $args{nobody_ok} || $args{group}
            ? $args{action}->validation_ok( $args{column} )
            : $args{action}->validation_error(
            $args{column} => "This has to be owned by somebody!" );
    }

    unless ( length $args{value} and $args{value} =~ /\S\@\S/ ) {
        return $args{action}->validation_error(
            $args{column} => "Are you sure that's an email address?" );
    }
    my @addresses = Email::Address->parse($args{value});
    unless (@addresses) {
        return $args{action}->validation_error(
            $args{column} => "I can't seem to parse that as an email address",
        );
    }
    if ( @addresses > 1 or $args{value} =~ /[;,]/ or $args{value} =~ /@.*@/ ) {
        my $display = $args{column};
        $display =~ s/_id//;
        return $args{action}->validation_error(
            $args{column} => "Only one $display, please." );
    }

    for my $address (map {$_->address} @addresses) {
        my $user = BTDT::Model::User->new(
            current_user => BTDT::CurrentUser->superuser );
        $user->load_by_cols( email => $address );

        if (   $user
            && $user->id
            && $user->access_level eq "nonuser"
            && $user->never_email )
        {
            return $args{action}->validation_error( $args{column} =>
                    "$address has chosen not to use Hiveminder and asked us not to send them mail."
            );
        }

        if ( $args{existing} and not $user->id ) {
            return $args{action}->validation_error(
                $args{column} => "We can't find an account with that address." );
        }
    }

    return $args{action}->validation_ok( $args{column} );
}

=head2 git_revision

Returns the git revision name of the Hiveminder repository at the time
it was last pulled.

=cut

sub git_revision {
    # Hey! Do not edit the line below without fixing bin/gitupdate!
    return 'exported';
}

=head2 pull_time

Returns the time Hiveminder was pulled in epoch seconds.

=cut

sub pull_time {
    # Hey! Do not edit the line below without fixing bin/gitupdate!
    return time;
}

1;
