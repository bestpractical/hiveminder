package BTDT::HTML::Truncate;

use strict;
use warnings;

use HTML::TokeParser;
use HTML::Entities ();
use Carp;

=head1 NAME

BTDT::HTML::Truncate - (beta software) truncate HTML by percentage or character count while preserving well-formedness.

=head1 VERSION

0.11

=cut

our $VERSION = '0.11';

=head1 ABSTRACT

When working with text it is convenient and common to want to truncate
strings to make them fit a desired context. E.g., you might have a
menu that is only 100px wide and prefer text doesn't wrap so you'd
truncate it around 15-30 characters, depending on preference and
typeface size. This is trivial with plain text using C<substr> but
with HTML it is somewhat difficult because whitespace has fluid
significance and open tags that are not properly closed destroy
well-formedness and can wreck an entire layout.

BTDT::HTML::Truncate attempts to account for those two problems by padding
truncation for spacing and entities and closing any tags that remain
open at the point of truncation.

=head1 SYNOPSIS

 use strict;
 use BTDT::HTML::Truncate;

 my $html = '<p><i>We</i> have to test <b>something</b>.</p>';
 my $readmore = '... <a href="/full-article">[readmore]</a>';

 my $html_truncate = BTDT::HTML::Truncate->new();
 $html_truncate->chars(20);
 $html_truncate->ellipsis($readmore);
 print $html_truncate->truncate($html), $/;

 # or

 my $ht = BTDT::HTML::Truncate->new(utf => 1,
                              chars => 1_000,
                              );
 print $ht->truncate($html), $/;

=head1 XHTML

This module is designed to only work on XHTML-style nested tags. More
below.

=head1 WHITESPACE & ENTITIES

Repeated natural whitespace (i.e., "\s+" and not " &nbsp; ") in HTML
-- with rare exception (pre tags or user defined styles) -- is not
meaningful. Therefore it is normalized when truncating. Entities are
also normalized. The following is only counted 14 chars long.

  \n<p>\nthis     is   &#8216;text&#8217;\n\n</p>
  ^^^^^^^12345----678--9------01234------^^^^^^^^

=head1 METHODS

=head2 BTDT::HTML::Truncate->new

Can take all the methods as hash style args. "percent" and "chars" are
incompatible so don't use them both. Whichever is set most recently
will erase the other.

 my $ht = BTDT::HTML::Truncate->new(utf8 => 1,
                              chars => 500, # default is 100
                              );

=cut

sub new {
    my $class = shift;

    my %stand_alone = map { $_ => 1 } qw( br img hr input link base
                                          meta area param );

    my %skip = map { $_ => 1 } qw( head script form iframe object
                                   embed title style base link meta );

    my $self = bless
    {
        _chars    => 100,
        _percent  => undef,
        _utf8     => undef,
        _style    => 'text',
        _ellipsis => '&#8230;',
        _raw_html => '',
        _repair   => undef,
        _skip_tags => \%skip,
        _stand_alone_tags => \%stand_alone,
    }, $class;

    while ( my ( $k, $v ) = splice(@_, 0, 2) )
    {
        next unless exists $self->{"_$k"};
        $self->$k($v);
    }
    return $self;
}

=head2 $ht->utf8

Set/get, true/false. If utf8 is set, entities will be transformed with
C<HTML::Entity::decode> and the default ellipsis will be a literal
ellipsis and not the default of C<&#8230;>.

=cut

sub utf8 {
    my $self = shift;
    if ( @_ )
    {
        $self->{_utf8} = shift;
        return 1; # say we did it, even if untrue value
    }
    else
    {
        return $self->{_utf8};
    }
}

=head2 $ht->chars

Set/get. The number of characters remaining after truncation,
including the C<ellipsis>. The C<style> attribute determines whether
the chars will only count text or HTML and text. Only "text" is
supported currently.

Entities are counted as single characters. E.g., C<&copy;> is one
character for truncation counts.

Default is "100." Side-effect: clears any C<percent> that has been
set.

=cut

sub chars {
    my ( $self, $chars ) = @_;
    return $self->{_chars} unless defined $chars;
    $chars =~ /^(?:[1-9][_\d]*|0)$/
        or croak "Specified chars must be a number";
    $self->{_percent} = undef; # no conflict allowed
    $self->{_chars} = $chars;
}

=head2 $ht->percent

Set/get. A percentage to keep while truncating the rest. For a
document of 1,000 chars, percent('15%') and chars(150) would be
equivalent. The actual amount of character that the percent represents
cannot be known until the given HTML is parsed.

Side-effect: clears any C<chars> that has been set.

=cut

sub percent {
    my ( $self, $percent ) = @_;

    return unless $self->{_percent} or $percent;

    return sprintf("%d%%", 100 * $self->{_percent})
        unless $percent;

    my ( $temp_percent ) = $percent =~ /^(100|[1-9]?[0-9])\%$/;

    $temp_percent and $temp_percent != 0
        or croak "Specified percent is invalid '$percent' -- 1\% - 100\%";

    $self->{_chars} = undef; # no conflict allowed
    $self->{_percent} = $1 / 100;
}

=head2 $ht->ellipsis

Set/get. Ellipsis in this case means--

 The omission of a word or phrase necessary for a complete syntactical
 construction but not necessary for understanding.
                            http://www.answers.com/topic/ellipsis

What it will probably mean in most real applications is "read more."
The default is C<&#8230;> which if the utf8 flag is true will render
as a literal ellipsis, C<chr(8230)>.

The reason the default is C<&#8230;> and not "..." is this is meant
for use in HTML environments, not plain text, and "..." (dot-dot-dot)
is not typographically correct or equivalent to a real horizontal
ellipsis character.

=cut

sub ellipsis {
    my $self = shift;
    if ( @_ )
    {
        $self->{_ellipsis} = shift;
    }
    elsif ( $self->utf8() )
    {
        return HTML::Entities::decode($self->{_ellipsis});
    }
    else
    {
        return $self->{_ellipsis};
    }
}

=head2 $ht->truncate($html)

Also can be called with arguments--

 $ht->truncate( $html, $chars_or_percent, $ellipsis );

No arguments are strictly required. Without HTML to operate upon it
returns undef. The two optional arguments may be preset with the
methods C<chars> (or C<percent>) and C<ellipsis>.

Valid nesting of tags is required (alla XHTML). Therefore some old
HTML habits like E<lt>pE<gt> without a E<lt>/pE<gt> are not supported
and will cause a fatal error.

Certain tags are omitted by default from the truncated output. There
will be a mechanism to custom tailor these--

=over 4

=item skipped tags

 <head>...</head> <script>...</script> <form>...</form>
 <iframe></iframe> <title>...</title> <style>...</style>
 <base/> <link/> <meta/>

=item tags allowed to self-close (stand alone)

 <br/> <img/> <hr/> <input/> <link/> <base/>

=back

=cut

sub truncate {
    my $self = shift;
    my ( $html, $chars_or_perc, $ellipsis ) = @_;

    return unless $html;

    $self->{_renewed}  = '';    # reset
    $self->{_raw_html} = \$html;

    if ( $self->percent() or
         $chars_or_perc and
         $chars_or_perc =~ /\d+\%$/ )
    {
        $self->percent($chars_or_perc);
        $self->_load_chars_from_percent();
    }
    elsif ( $chars_or_perc )
    {
        $self->chars($chars_or_perc);
    }

    $self->ellipsis($ellipsis) if defined $ellipsis;

    my $p = HTML::TokeParser->new( $self->{_raw_html} );

    my ( @tag_q );
    $self->{_renew} = '';
    my $chars = $self->chars();

  TOKENS:
    while ( my $token = $p->get_token() )
    {
        if ( $token->[0] eq 'S' )
        {
            # _callback_for...? 321
            next TOKENS if $self->{_skip_tags}{$token->[1]};
            push @tag_q, $token->[1] unless $self->{_stand_alone_tags}{$token->[1]};
            $self->{_renewed} .= $token->[-1];
        }
        elsif ( $token->[0] eq 'E' )
        {
            next TOKENS if $self->{_skip_tags}{$token->[1]};
            my $open  = pop @tag_q;
            my $close = $token->[1];
            unless ( $open eq $close ) {
                if ($self->{_repair}) {
                    my @unmatched;
                    push @unmatched, $open if defined $open;
                    while (my $temp = pop @tag_q) {
                        if ($temp eq $close) {
                            while (my $add = shift @unmatched) {
                                $self->{_renewed} .= "</$add>";
                            }
                            $self->{_renewed} .= "</$temp>";
                            next TOKENS;
                        }
                        else {
                            push @unmatched, $temp;
                        }
                    }
                    push @tag_q, reverse @unmatched;
                    next TOKENS;        # silently drop unmatched close tags
                }
                else {
                    my $nearby = substr($self->{_renewed},
                                        length($self->{_renewed}) - 15,
                                        15);
                    croak qq|<$open> closed by </$close> near "$nearby"|;
                }
            }
            $self->{_renewed} .= $token->[-1];
        }
        elsif ( $token->[0] eq 'T' )
        {
            next TOKENS if $token->[2];
            my $txt = $token->[1];
            $self->{_renewed} .= $txt and next if $txt =~ /^\s+$/;

            my $length = length($txt);
            for ( $txt =~ /
                           \A(\s+)(?=\S)
                           |
                           (?<=\S)(\s+)\Z
                           |
                           (?<=\&)(\#\d+;)
                           |
                           (?<=\&)([[:alpha:]]{2,5};)
                           |
                           \s(\s+)
                           /gx )
            {
                $length -= length($1) if $1; # padding
            }

            if ( $length > $chars )
            {
                $self->{_renewed} .= substr($txt, 0, ( $chars ) );
                $self->{_renewed} =~ s/\s+\Z//;
                $self->{_renewed} .= $self->ellipsis();
                last TOKENS;
            }
            else
            {
                $self->{_renewed} .= $txt;
                $chars -= $length;
            }
        }
    }
    $self->{_renewed} .= join('', map {"</$_>"} reverse @tag_q);

    return $self->{_renewed} if defined wantarray;
}


=head2 $ht->add_skip_tags( qw( tag list ) )

Put one or more new tags into the list of those to be omitted from
truncated output. An example of when you might like to use this is if
you're thumbnailing articles and they start with C<< <h1>title</h1> >>
or such before the article body. The heading level would be absurd
with a list of excerpts so you could drop it completely this way--

 $ht->add_skip_tags( 'h1' );

=cut

sub add_skip_tags {
    my $self = shift;
    for ( @_ )
    {
        croak "Args to add_skip_tags must be scalar tag names, not references"
            if ref $_;
        $self->{_skip_tags}{$_} = 1;
    }
}


=head2 $ht->dont_skip_tags( qw( tag list ) )

Takes tags out of the current list to be omitted from truncated output.

=cut

sub dont_skip_tags {
    my $self = shift;
    for ( @_ )
    {
        croak "Args to dont_skip_tags must be scalar tag names, not references"
            if ref $_;
        carp "$_ was not set to be skipped"
            unless delete $self->{_skip_tags}{$_};
    }
}

=head2 $ht->repair

Set/get, true/false.  If true, will attempt to repair unclosed HTML tags by
adding close-tags as late as possible (eg. C<< <i><b>foobar</i> >> becomes 
C<< <i><b>foobar</b></i> >>).  Unmatched close tags are dropped 
(C<< foobar</b> >> becomes C<< foobar >>).

=cut

sub repair {
    my $self = shift;
    if ( @_ )
    {
        $self->{_repair} = shift;
        return 1; # say we did it, even if untrue value
    }
    else
    {
        return $self->{_repair};
    }
}

# 

sub _load_chars_from_percent {
    my $self = shift;
    my $p = HTML::TokeParser->new( $self->{_raw_html} );
    my $txt_length = 0;

  CHARS:
    while ( my $token = $p->get_token )
    {
    # don't check padding b/c we're going by a document average
        next unless $token->[0] eq 'T' and not $token->[2];
        $txt_length += _count_visual_chars( $token->[1] );
    }
    $self->chars( int( $txt_length * $self->{_percent} ) );
}


sub _count_visual_chars { # private function
    my $to_count = shift;
    my $count = () =
        $to_count =~
        /\&\#\d+;|\&[[:alpha:]]{2,5};|\S|\s+/g;
    return $count;
}

# Need to put hooks for these or not? 321
#sub _default_image_callback {
#    sub {
#        '[image]'
#    }
#}

=head2 $ht->style

Set/get. Either the default "text" or "html." (N.b.: only "text" is
supported so far.) This determines which characters will counted for
the truncation point. The reason why "html" is probably a poor choice
is that you might set what you believe to be a reasonable truncation
length of 20 chars and get an HTML tag like E<lt>a
href="http://blah.blah.boo/longish/path/to/resource... and end up with
no useful output.

Another problem is that the truncate might fall inside an attribute,
like the "href" above, which means that attribute will necessarily be
excluded, quite probably rendering the remaining tag invalid so the
entire tag must be tossed out to preserve well-formedness.

But the best reason not to use "html" right now is it's not supported
yet. It probably will be sometime in the future but unless you send a
patch to do it, it will be awhile. It would be useful, for example to
keep fixed length database records containing HTML truncated validly,
but it's not something I plan to use personally so it will come last.

=cut

sub style {
    my ( $self, $style ) = @_;
    return $self->{_style} unless defined $style;

    croak "'html' style is not yet supported, sorry!"
        if $style eq 'html';

    croak "Value for style must be either 'text' or 'html'"
        unless $style =~ /^text|html$/;

    $self->{_style } = $style;
}


=head1 COOKBOOK (well, a recipe)

=head2 Template Toolkit filter

For excerpting HTML in your Templates. Note the C<add_skip_tags> which
is set to drop any images from the truncated output.

 use Template; # HIVEMINDER OPTIONAL
 use BTDT::HTML::Truncate;

 my %config =
    (
     FILTERS => {
         truncate_html => [ \&truncate_html_filter_factory, 1 ],
     },
     );

 my $tt = Template->new(\%config) or die $Template::ERROR;

 # ... etc ...

 sub truncate_html_filter_factory {
     my ( $context, $len, $ellipsis ) = @_;
     $len = 32 unless $len;
     $ellipsis = chr(8230) unless defined $ellipsis;
     my $html = shift || return '';
     my $ht = BTDT::HTML::Truncate->new();
     return sub {
         $ht->add_skip_tags(qw( img ));
         return $ht->truncate( $html, $len, $ellipsis );
     }
 }

Then in your templates you can do things like this:


 [% FOR item IN search_results %]
 <div class="searchResult">
 <a href="[% item.uri %]">[% item.title %]</a><br />
 [% item.body | truncate_html(200) %]
 </div>
 [% END %]


See also L<Template::Filters>.

=head1 TO DO

Many more tests. Allow new stand alone tags to be added. Go through
entire dist and make sure everything is kosher (autogenerated with the
lovely L<Module::Starter>). Reorganize POD to read in best learning
order. Make sure the padding check is working across wide range of
cases. "html" style truncating (maybe not?).

=head1 AUTHOR

Ashley Pond V, C<< <ashley@cpan.org> >>.

=head1 LIMITATIONS

There are places where this will break down right now. I'll pad out
possible edge cases as I find them or they are sent to me via the CPAN
bug ticket system.

=head2 This is not an HTML filter

Although this happens to do some crude HTML filtering to achieve its
end, it is not a fully featured filter. If you are looking for one,
check out L<HTML::Scrubber> and L<HTML::Sanitizer>.

=head1 BUGS, FEEDBACK, PATCHES

Please report any bugs or feature requests to
C<bug-html-truncate@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=HTML-Truncate>. I
will get the ticket, and then you'll automatically be notified of
progress as I make changes.

=head1 THANKS TO

Kevin Riggle for the C<repair> function; patch, POD, and tests.

=head1 SEE ALSO

L<HTML::Entities>, L<HTML::TokeParser>, the "truncate" filter in
L<Template>, and L<Text::Truncate>.

L<HTML::Scrubber> and L<HTML::Sanitizer>.

=head1 COPYRIGHT & LICENSE

Copyright 2005-2006 Ashley Pond V, all rights reserved.

This program is free software; you can redistribute it or modify it or
both under the same terms as Perl itself.

=cut

1; # End of BTDT::HTML::Truncate


