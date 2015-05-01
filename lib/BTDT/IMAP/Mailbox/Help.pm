package BTDT::IMAP::Mailbox::Help;

use warnings;
use strict;

use Email::Simple;
use DateTime::Format::Mail;
use base qw/BTDT::IMAP::Mailbox/;

__PACKAGE__->mk_accessors( qw/loaded/ );

=head1 NAME

BTDT::IMAP::Mailbox::Help - Help messages

=head1 METHODS

=head2 name

The name of the mailbox is always "Help"

=cut

sub name { "Help" }

=head2 poll

The first time the mailbox is polled, load the messages from the
filesystem using L</load_original>.

=cut

sub poll {
    my $self = shift;
    return $self->load_original unless $self->loaded;
}

=head2 load_original

The messages in the help mailbox are loaded from the filesystem.

=head2 loaded [BOOL]

Returns true if the mailbox has been polled before, and the messages
loaded from disk.

=cut

sub load_original {
    my $self = shift;

    my @files = <html/help/reference/IMAP/*.html>;
    $self->add_help($_) for @files;
    $self->loaded(1);

    return $self->SUPER::messages;
}

=head2 add_help FILENAME

Adds the contents of the file provided, as an email mesage.

=cut

my %CACHE;
use LWP::Simple qw//;

sub add_help {
    my $self = shift;
    my $filename = shift;

    unless ($CACHE{$filename}) {
        my $date = DateTime::Format::Mail->format_datetime(DateTime->from_epoch( epoch => (stat($filename))[9]));
        my ($short) = $filename =~ m|.*/(.*)|;
        my $subject = BTDT->_file_to_label($short);
        my $url = Jifty->web->url(path => "/help/reference/IMAP/$1");
        $Net::IMAP::Server::Server->connection->logger->debug("Help URL is $url");
        my $body = LWP::Simple::get($url."?_IMAP_INTERNAL=1");
        $body =~ s|(</head>)|<base href="$url" />$1|i;

        my $email = Email::Simple->new("");
        $email->header_set( "Subject"  => Encode::encode('MIME-Header',$subject) );
        $email->header_set( "From"     => 'hiveminders@hiveminder.com' );
        $email->header_set( "Content-Type" => "text/html; charset=utf-8" );
        $email->header_set( "Date"     => $date );
        $email->body_set( $body );

        $CACHE{$filename} = $email->as_string;
    }

    $self->add_message( BTDT::IMAP::Message->new($CACHE{$filename}) );
}

1;
