package BTDT::IMAP::Mailbox;

use warnings;
use strict;

use base 'Net::IMAP::Server::Mailbox';

=head1 NAME

BTDT::IMAP::Mailbox - generic mailbox for BTDT tasks

=head1 METHODS

=head2 new

Make sure no names contain a '/' character.

=cut

sub new {
    my $class = shift;
    my %args = %{shift || {}};
    $args{name} =~ tr|/|-| if defined $args{name};
    $class->SUPER::new(\%args);
}


=head2 uidvalidity

The UIDVALIDITY of a mailbox is controlled by the variable set in L<BTDT::IMAP>.

=cut

sub uidvalidity { $BTDT::IMAP::UIDVALIDITY }

=head2 load_data

Overrides L<Net::IMAP::Server::Mailbox>'s C<load_data>, which loads
messages from files.  Instead, do nohing, leaving the mailbox empty by
default.

=cut

sub load_data {
}

=head2 add_message

When adding a message, load its active flags from the database using
L<BTDT::IMAP::Message/load_db_flags>.

=cut

sub add_message {
    my $self = shift;
    my $message = $self->SUPER::add_message(@_);
    $message->load_db_flags;
    return $message;
}

=head2 current_user

Returns the L<BTDT::CurrentUser> object for this mailbox, as
determined by the current connection.

=cut

sub current_user {
    return undef unless $Net::IMAP::Server::Server->connection->auth;
    return $Net::IMAP::Server::Server->connection->auth->current_user;
}

=head2 append

By default, mailboxes cannot be appended to.

=cut

sub append {
    return 0;
}

=head2 delete

By default, mailboxes cannot be deleted.

=cut

sub delete {
    return 0;
}

=head2 copy_allowed

By default, mailboxes cannot have messages copied into them.

=cut

sub copy_allowed {
    return 0;
}

=head2 add_child PARAMHASH

Creates a sub-mailbox of this mailbox; the class of the mailbox
created is determined by the C<class> value in the paramhash.  In all
other respects, identical to L<Net::IMAP::Server::Mailbox/add_child>.

=cut

sub add_child {
    my $self = shift;
    my %args = @_;

    my $class = $args{class} ? "BTDT::IMAP::Mailbox::$args{class}" : "BTDT::IMAP::Mailbox";
    unless ($class->require) {
        $Net::IMAP::Server::Server->connection->logger->warn("$class: $@");
        $class = "BTDT::IMAP::Mailbox";
    }

    my $node = $class->new( { %args, parent => $self } );
    return unless $node;
    push @{ $self->children }, $node;
    return $node;
}

=head2 create PARAMHASH

Creates a new sub-mailbox of this mailbox; if this is the "Groups"
mailbox, calls L<group_create>; if this is the braindump mailbox,
calls L<braindump_create>; otherwise, permission is denied.

=cut

sub create {
    my $self = shift;
    my $auth = $Net::IMAP::Server::Server->connection->auth;

    my %args = @_;
    return $self->group_create(@_) if $self->full_path eq "Groups";
    return $self->braindump_create(@_) if $self->full_path eq "Braindump mailboxes";
    return $self->apple_todo_create(@_) if $self->full_path eq ""
      and $args{name} eq "Apple Mail To Do" and $auth->options->{appleical};
    return undef;
}

=head2 group_create PARAMHASH

Creates a new group of the given name, if possible.  This will create
a L<BTDT::IMAP::Mailbox::Group> mailbox.

=cut

sub group_create {
    my $self = shift;

    my %args = @_;
    return 0 unless $args{name};
    my $g = BTDT::Model::Group->new( current_user => $self->current_user );
    $g->create( name => $args{name} );

    return 0 unless $g->id;

    return $self->add_child( class => "Group", group => $g );
}

=head2 braindump_create PARAMHASH

Creates a L<BTDT::Model::PublishedAddresss>, with the C<name> as its
C<auto_attributes>.  Creates the appropriate
L<BTDT::IMAP::Mailbox::Action::Braindump> mailbox.

=cut

sub braindump_create {
    my $self = shift;

    my %args = @_;
    return 0 unless $args{name};
    my $i = BTDT::Model::PublishedAddress->new( current_user => $self->current_user );
    $i->create( auto_attributes => $args{name}, user_id => $self->current_user->user_object->id );
    return 0 unless $i->id;

    return $self->add_child( class => "Action::Braindump", published_address => $i );
}

=head2 apple_todo_create PARAMHASH

Creates the magic "Apple Mail To Do" folder

=cut

sub apple_todo_create {
    my $self = shift;
    my %args = @_;
    return $self->add_child( class => "AppleMailToDo", name => $args{name} );
}

=head2 is_offlineimap MESSAGE

Returns true if the given L<Email::Simple> object C<MESSAGE> is an
attempt at OfflineIMAP to APPEND instead of COPY.

=cut

sub is_offlineimap {
    my $self = shift;
    my $email = shift;
    return $email->header("X-Hiveminder-Id") and grep /^X-OfflineIMAP/, $email->header_names;
}

=head2 handle_offlineimap MESSAGE

Loads the task specified by the email, and acts like this was a COPY
of it (calling L</run> on it), instead of an APPEND.

=cut

sub handle_offlineimap {
    my $self = shift;
    my $email = shift;

    # This is OfflineIMAP being Wrong.  Treat this as a COPY rather than an APPEND
    my($id) = $email->header("X-Hiveminder-Id") =~ /(\d+)/;
    my $task = BTDT::Model::Task->new( current_user => $self->current_user );
    $task->load($id);
    return unless $id and $task->current_user_can('update');
    my $message = BTDT::IMAP::Message::TaskSummary->new(task_email => $task->comments->first);
    return $self->run($message);
}


=head2 close

When a session closes a mailbox, call L</unload> unless there are
other active connections to the mailbox.

=cut

sub close {
    my $self = shift;
    return unless $Net::IMAP::Server::Server->connection;
    my @concurrent = grep { $_ ne $Net::IMAP::Server::Server->connection }
        Net::IMAP::Server->concurrent_mailbox_connections($self);
    $self->unload unless @concurrent;
}


=head2 update_from_tree

Called on a mailbox if the parent is a
L<BTDT::IMAP::Mailbox::DynamicSet>.  Should update itself if there are
changes to the object; by default, does nothing.

=cut

sub update_from_tree {
}


=head2 unload

Called when no sessions from this user are observing the mailbox; by
default, does nothing.

=cut

sub unload {
}



1;
