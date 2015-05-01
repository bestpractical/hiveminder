package BTDT::IMAP::Message;

use warnings;
use strict;
use bytes;

use base 'Net::IMAP::Server::Message';

=head1 NAME

BTDT::IMAP::Message - Provides message interface, generally  for tasks

=head1 METHODS

=head2 current_user

The current user is pulled from the current connection's auth.
Returns a L<BTDT::CurrentUser>.

=cut

sub current_user {
    return undef unless $Net::IMAP::Server::Server->connection->auth;
    return $Net::IMAP::Server::Server->connection->auth->current_user;
}

=head2 load_db_flags

Loads the current set of flags from the database, and blows it into
L</_flags>.

=cut

sub load_db_flags {
    my $self = shift;
    my $s = BTDT::Model::IMAPFlag->new( current_user => $self->current_user );
    $s->load_by_cols(
        user_id => $self->current_user->id,
        path    => $self->flag_prefix,
        uid     => $self->flag_uid,
    );
    if ($s->id) {
        my $aref = $s->value;
        $self->_flags->{$_} = 1 for @{$aref || []};
    }
}

=head2 store HOW FLAGS

If L</delete_allowed> is not true, filters attempts to store the
C<\Deleted> flag.

=cut

sub store {
    my $self = shift;
    my ( $what, $flags ) = @_;

    $flags = [grep { lc $_ ne lc '\Deleted'} @{$flags}]
        unless $self->delete_allowed;

    return $self->SUPER::store( $what, $flags );
}

=head2 flag_prefix

By default, the "flag prefix" in the database is simply the mailbox's
path.

=cut

sub flag_prefix {
    my $self = shift;
    return $self->mailbox->full_path;
}

=head2 flag_uid

By default, the "flag uid" in the database is simply the message UID
in the mailbox.

=cut

sub flag_uid {
    my $self = shift;
    return $self->uid;
}

=head2 update_db_flags

Saves the current memory state of the message properties to the
database.

=cut

sub update_db_flags {
    my $self = shift;
    return if $self->expunged;
    return unless $self->mailbox; # Skip bogon messages
    my $s = BTDT::Model::IMAPFlag->new( current_user => $self->current_user );
    $s->load_or_create(
        user_id => $self->current_user->id,
        path    => $self->flag_prefix,
        uid     => $self->flag_uid,
    );
    my @flags = $self->delete_allowed ? $self->flags : grep $_ ne '\Deleted', $self->flags;
    $s->set_value(\@flags);
}

=head2 set_flag FLAG

When we change a flag, update the db.  Returns if the flag changed.

=cut

sub set_flag {
    my $self = shift;
    my $ret = $self->SUPER::set_flag(@_);
    $self->update_db_flags(set => @_) if $ret;
    return $ret;
}

=head2 clear_flag FLAG

When we change a flag, update the db.  Returns if the flag changed.

=cut

sub clear_flag {
    my $self = shift;
    my $ret = $self->SUPER::clear_flag(@_);
    $self->update_db_flags(clear => @_) if $ret;
    return $ret;
}

=head2 expunge

When we expunge the message, we can get rid of the stored flags.

=cut

sub expunge {
    my $self = shift;
    $self->delete_db_flags;
    return $self->SUPER::expunge(@_);
}

=head2 delete_db_flags

Deletes the record of the flags from the database.

=cut

sub delete_db_flags {
    my $self = shift;
    my $s = BTDT::Model::IMAPFlag->new( current_user => $self->current_user );
    $s->load_by_cols(
        user_id => $self->current_user->id,
        path    => $self->flag_prefix,
        uid     => $self->flag_uid,
    );
    $s->delete if $s->id;
}

=head2 copy_allowed

Generic messages can't be copied or moved around.

=cut

sub copy_allowed {
    return 0;
}

=head2 delete_allowed

Returns true if the message is allowed to have the C<\Deleted> flag
set on it.  By default, always returns false.

=cut

sub delete_allowed { 0 }

1;
