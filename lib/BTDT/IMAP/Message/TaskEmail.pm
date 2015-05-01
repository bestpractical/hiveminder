package BTDT::IMAP::Message::TaskEmail;

use warnings;
use strict;

use base 'BTDT::IMAP::Message';

__PACKAGE__->mk_accessors(qw(task_email transaction_id prefetched));

=head1 NAME

BTDT::IMAP::Message::TaskEmail - Provides message interface for tasks

=head1 METHODS

=head2 new PARAMHASH

The one required argument is C<task_email>, which should be a
L<BTDT::Model::TaskEmail>.  If it has prefetched C<uid> or C<flags>,
that saves additional queries.

=head2 task_email [TASKEMAIL]

Gets or sets the L<BTDT::Model::TaskEmail> associated with this message.

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    my %args = @_;

    $self->task_email( $args{task_email} );
    $self->prefetched( $args{prefetched} );
    $self->_flags( {} );

    # Determine the flags on the message
    if ($self->task_email->prefetched("flags") and $self->task_email->prefetched("flags")->id) {
        my $flags = {};
        $flags->{$_} = 1 for @{$self->task_email->prefetched("flags")->value};
        $self->_flags( $flags );
    }

    # Determine the UID
    if ( exists $args{uid} ) {
        # If we're passed an explicit UID, force to that.  This can be
        # undef, which is used to say "get me a new one"
        $self->uid( $args{uid} );
    } elsif ($self->task_email->prefetched("uid") and $self->task_email->prefetched("uid")->id) {
        $self->uid( $self->task_email->prefetched("uid")->uid );
    }

    # The internaldate; this could be wrapped in a Scalar::Defer
    # lazy{}, which saves ~3s over 5k messages, but it means that we
    # close over the DateTime object, which is a fat memory hog.
    $self->internaldate(
        $self->task_email->transaction->modified_at
    );

    # The transaction_id
    $self->transaction_id($self->task_email->transaction->id);

    $self->task_email->unload_value( $_ ) for qw/uid flags transaction message/;

    return $self;
}

=head2 newuid

Returns a new uid for the message, and records it in the database.

=cut

sub newuid {
    my $self = shift;
    my $uid = $self->mailbox->uidnext;
    my $mapping = BTDT::Model::IMAPUID->new( current_user => $self->current_user );
    $mapping->create(
        user_id     => $self->current_user->id,
        path        => $self->mailbox->full_path,
        transaction => $self->transaction_id,
        uid         => $uid,
    );
    return $uid;
}

=head2 load_db_flags

If there is a prefetched C<flags> L<BTDT::Model::IMAPFlag> object,
pulls the flags from that.  Otherwise, defers to
L<BTDT::IMAP::Message/load_db_flags>.

=cut

sub load_db_flags {
    my $self = shift;
    return if $self->prefetched;
    return $self->SUPER::load_db_flags(@_);
}

=head2 uid

Generates a uid and inserts it into the DB if need be; otherwise,
fetches it from memory or the database.

=cut

sub uid {
    my $self = shift;
    if (@_) {
        $self->{uid} = shift;
    } elsif (exists $self->{uid}) {
        return $self->{uid};
    } elsif ($self->prefetched) {
        return $self->{uid} = $self->newuid;
    } else {
        my $mapping = BTDT::Model::IMAPUID->new( current_user => $self->current_user );
        $mapping->load_by_cols(
            user_id     => $self->current_user->id,
            path        => $self->mailbox->full_path,
            transaction => $self->task_email->transaction->id,
        );
        return $self->{uid} = $mapping->uid if $mapping->id;
        return $self->{uid} = $self->newuid;
    }
}

=head2 mime

The MIME object is parsed from the TaskEmail.

=cut

sub mime {
    my $self = shift;

    my $task = $self->task_email->task;

    local $Email::MIME::ContentType::STRICT_PARAMS = 0;
    my $email = Email::MIME->new( $self->task_email->message );
    $self->task_email->unload_value( "message" );
    # XXX This is a horrible hack
    $email->{mycrlf} = "\r\n";
    $email->header_obj->{mycrlf} = "\r\n";

    $email->header_set( "Subject" => Encode::encode('MIME-Header',$task->summary) )
        unless $email->header("Subject");

    $email->header_set( "Reply-To" => Encode::encode('MIME-Header',$task->comment_address) );

    return $email;
}

=head2 flag_prefix

The prefix for flags is C<TXN>.  It would be "", except Jifty changes
that to null, which is irritating and inconsistent.  So as long as we
don't have a mailbox called C<TXN>, this will be fine.

=cut

sub flag_prefix {
    return "TXN";
}

=head2 flag_uid

The C<uid> of the flag is the transaction ID.  This ensures that the
message has the same flags across all mailboxes.

=cut

sub flag_uid {
    my $self = shift;
    return $self->transaction_id;
}

=head2 update_db_flags

After updating the database flags, we must update all other mailboxes
that contain this message.  We search for all distinct mailboxes that
have this combination of transaction and user, and update their
versions of the message, as well.

=cut

sub update_db_flags {
    my $self = shift;
    my ($type, @args) = @_;
    my $call = "SUPER::" . $type . "_flag";
    $self->SUPER::update_db_flags(@_);

    # Find other active mailboxes which have this txn in them..
    my $paths = BTDT::Model::IMAPUIDCollection->new( current_user => $self->current_user );
    $paths->limit( column => "user_id",     value => $self->current_user->id );
    $paths->limit( column => "transaction", value => $self->transaction_id );
    $paths->limit( column => "path",        value => $self->mailbox->full_path, operator => '!=' );
    $paths->order_by( {} );
    $paths->group_by( {column => "path"}, {column => "uid"} );
    $paths->columns( "path", "uid" );
    my $sth = Jifty->handle->simple_query($paths->build_select_query);
    while (my $row = $sth->fetchrow_hashref) {
        # ..and update their flags appropriately
        my $mailbox = $Net::IMAP::Server::Server->connection->model->lookup($row->{"main_path"});
        next unless $mailbox;
        $_->$call(@args) for $mailbox->get_uids($row->{"main_uid"});
    }
}

=head2 copy_allowed MAILBOX

Whether we are allowed to copy a message to C<MAILBOX> depends on
L<BTDT::IMAP::Mailbox/copy_allowed>.

=cut

sub copy_allowed {
    my $self = shift;
    my $destination = shift;
    return $destination->copy_allowed;
}

=head2 copy MAILBOX

Copying a message to the C<MAILBOX> calls L<BTDT::IMAP::Mailbox/run>
with this message as its argument.

=cut

sub copy {
    my $self = shift;
    my $mailbox = shift;

    return $mailbox->run($self);
}

=head2 delete_uid_mapping

Removes this UID mapping.

=cut

sub delete_uid_mapping {
    my $self = shift;
    my $mapping = BTDT::Model::IMAPUID->new( current_user => $self->current_user );
    $mapping->load_by_cols(
        user_id     => $self->current_user->id,
        path        => $self->mailbox->full_path,
        transaction => $self->transaction_id,
        uid         => $self->uid,
    );
    $mapping->delete if $mapping->id;
}

=head2 expunge

Calls L<delete_uid_mapping>, in addition to expunging the message.

=cut

sub expunge {
    my $self = shift;
    $self->delete_uid_mapping;
    return $self->SUPER::expunge(@_);
}

=head2 delete_db_flags

Only delete the flags from the database if there are no other
mailboxes which have this transaction.

=cut

sub delete_db_flags {
    my $self = shift;

    my $others = BTDT::Model::IMAPUIDCollection->new( current_user => $self->current_user );
    $others->limit( column => "user_id",     value => $self->current_user->id );
    $others->limit( column => "transaction", value => $self->transaction_id );
    return $self->SUPER::delete_db_flags unless $others->count;
}

=head2 is_task_summary

Returns false because the message is not a summary of the
task, and there should be no change to the message.

=cut

sub is_task_summary { 0; }

1;
