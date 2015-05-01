package BTDT::IMAP::Message::News;

use warnings;
use strict;

use Email::MIME;
use HTML::FormatText::WithLinks;
use DateTime::Format::Mail;
use base 'BTDT::IMAP::Message';

__PACKAGE__->mk_accessors(qw(news));

=head1 NAME

BTDT::IMAP::Message::TaskEmail - Provides message interface for tasks

=head1 METHODS

=head2 new PARAMHASH

The one required argument is C<news>, which should be a
L<BTDT::Model::News>.  If it has prefetched C<flags>, that saves
additional queries.

=head2 news [NEWS]

Gets or sets the L<BTDT::Model::News> associated with this message.

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    my %args = @_;

    $self->news( $args{news} );
    $self->_flags( {} );

    $self->uid($self->news->id);
    $self->internaldate(
        $self->news->created
    );

    return $self;
}

=head2 load_db_flags

If there is a prefetched C<flags> L<BTDT::Model::IMAPFlag> object,
pulls the flags from that.  Otherwise, defers to
L<BTDT::IMAP::Message/load_db_flags>.

=cut

sub load_db_flags {
    my $self = shift;

    if ($self->news->prefetched("flags") and $self->news->prefetched("flags")->id) {
        my $flags = {};
        $flags->{$_} = 1 for @{$self->news->prefetched("flags")->value};
        $self->_flags( $flags );
    }
}

=head2 mime

The MIME object is based on the news body.

=cut

sub mime {
    my $self = shift;

    my $email = Email::MIME->new("");
    # XXX This is a horrible hack

    my %attrs = ( charset => 'UTF-8' );

    my $html = $self->news->content;
    my $text = HTML::FormatText::WithLinks->format_string($html);

    $email = Email::MIME->create_html(
        header => [
            From       => $self->news->author->formatted_email,
            Subject    => Encode::encode( 'MIME-Header', $self->news->title ),
            "Reply-To" => 'hiveminders@hiveminder.com',
            Date       => DateTime::Format::Mail->format_datetime(
                $self->news->created
            ),
        ],
        attributes           => \%attrs,
        text_body_attributes => \%attrs,
        body_attributes      => \%attrs,
        text_body            => Encode::encode_utf8($text),
        body                 => Encode::encode_utf8($html),
        embed                => 0,
        inline_css           => 0
    );

    # Since the containing messsage will still be us-ascii otherwise
    $email->charset_set( $attrs{'charset'} );
    $email->{mycrlf} = "\r\n";
    $email->header_obj->{mycrlf} = "\r\n";

    return $email;
}

1;
