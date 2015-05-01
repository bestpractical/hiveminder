package BTDT::IMAP::Mailbox::News;

use warnings;
use strict;

use BTDT::IMAP::Message::News;
use base qw/BTDT::IMAP::Mailbox/;

__PACKAGE__->mk_accessors( qw/last_polled/ );

=head1 NAME

BTDT::IMAP::Mailbox::News - View of the news feed

=head1 METHODS

=head2 init

We establish a 1-to-1 mapping of UIDs to News object ids.

=cut

sub init {
    my $self = shift;
    $self->SUPER::init;
    $self->uidnext(1);
}

=head2 name

The name of the mailbox is always "News"

=cut

sub name { "News" }

=head2 load_original

Loads the L<BTDT::Model::News> messages into the system when it is
first polled.

=cut

sub load_original {
    my $self = shift;

    my $max = 0;
    my $news = BTDT::Model::NewsCollection->new( current_user => $self->current_user );
    $news->unlimit;

    my $flags = $news->join(
        type    => 'left',
        alias1  => 'main',
        column1 => 'id',
        table2  => "BTDT::Model::IMAPFlagCollection",
        column2 => 'uid',
        is_distinct => 1,
    );
    $news->limit( leftjoin => $flags, column => 'path', value => $self->full_path );
    $news->limit( leftjoin => $flags, column => 'user_id', value => $self->current_user->id );
    $news->prefetch( alias => $flags,
                     class => 'BTDT::Model::IMAPFlag',
                     name  => "flags" );

    $self->SUPER::messages([]);
    while ( my $obj = $news->next ) {
        $self->add_news($obj);
        $max = $obj->id if $obj->id > $max;
    }
    $self->last_polled($max);

    return $self->SUPER::messages;
}

=head2 status

Make sure that messages get purged from memory on a STATUS operation

=cut

sub status {
    my $self = shift;
    my $loaded = defined $self->last_polled;
    my %keys = $self->SUPER::status(@_);
    $self->unload unless $loaded;
    return %keys;
}

=head2 poll

Looks for new news messages and adds them.

=head2 last_polled [ID]

Gets or sets the highest id L<BTDT::Model::News> object that has been seen.

=cut

sub poll {
    my $self = shift;
    return $self->load_original unless defined $self->last_polled;

    # Flush JDBI caches
    require Jifty::DBI::Record::Cachable;
    Jifty::DBI::Record::Cachable->flush_cache;


    my $news = BTDT::Model::NewsCollection->new( current_user => $self->current_user );
    $news->limit( column => 'id', operator => '>', value => $self->last_polled );

    my $flags = $news->join(
        type    => 'left',
        alias1  => 'main',
        column1 => 'id',
        table2  => "BTDT::Model::IMAPFlagCollection",
        column2 => 'uid',
        is_distinct => 1,
    );
    $news->limit( leftjoin => $flags, column => 'path', value => $self->full_path );
    $news->limit( leftjoin => $flags, column => 'user_id', value => $self->current_user->id );
    $news->prefetch( alias => $flags,
                     class => 'BTDT::Model::IMAPFlag',
                     name  => "flags" );

    my $max = $self->last_polled;
    while ( my $obj = $news->next ) {
        $self->add_news($obj);
        $max = $obj->id if $obj->id > $max;
    }
    $self->last_polled($max);
}

=head2 add_news NEWS

Takes the givel L<BTDT::Model::News> object, and adds it as a message.

=cut

sub add_news {
    my $self = shift;
    my $obj = shift;

    $self->add_message( BTDT::IMAP::Message::News->new(news => $obj) );
}

=head2 unload

When no users are observing the mailbox, drop all of the messages.

=cut

sub unload {
    my $self = shift;
    $self->last_polled(undef);
    $self->uidnext(1000);
    my @messages = @{$self->messages || []};
    $self->messages( [] );
    $self->uids( {} );
    $_->prep_for_destroy for @messages;
}

1;
