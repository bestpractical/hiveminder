package BTDT::IMAP::Mailbox::AppleMailToDo;
use warnings;
use strict;

use Data::Plist;
use Data::Plist::Foundation::LibraryToDo;
use Data::Plist::BinaryReader;
use BTDT::IMAP::Message::AppleiCalTask;
use MIME::Base64;

use base qw/BTDT::IMAP::Mailbox::TaskSearch/;

=head1 NAME

BTDT::IMAP::Mailbox::AppleMailToDo

=head1 METHODS

=head2 add_task_email PARAMHASH

Takes C<$obj>, a L<BTDT::Model::TaskEmail> object,
C<original>, an L<Email::MIME> object and C<todo>, a
C<Data::Plist::Foundation::LibraryToDo> object, and adds a
new L<BTDT::IMAP::Message::AppleiCalTask> object to the
mailbox.

=cut

sub add_task_email {
    my $self = shift;
    my $obj  = shift;
    my %args = @_;

    my $m = BTDT::IMAP::Message::AppleiCalTask->from_task(
        task       => $obj->task,
        task_email => $obj,
        original   => $args{original},
        todo       => $args{todo}
    );
    $self->add_message($m);

    return $m;
}

=head2 tokens

Returns an arrayref that is the basis for the token search,
which is refined in L</task_collection>.

=cut

sub tokens {
    return [qw/owner me starts before tomorrow accepted but_first nothing/];
}

=head2 task_collection COLLECTION ALIAS

Takes the given collection, assuming that C<ALIAS> is the
alias to a L<BTDT::Model::TaskCollection>, and enforces the
token search and task ACLs. Also adds incomplete tasks and
tasks completed within the last week to the search.

=cut

sub task_collection {
    my $self = shift;
    my ( $collection, $alias ) = @_;

    my $old_class;
    unless ( $collection->isa("BTDT::Model::TaskCollection") ) {
        $old_class = ref $collection;
        $collection = bless $collection, "BTDT::Model::TaskCollection";
        $collection->default_limits(
            collection  => $collection,
            tasks_alias => $alias,
        );
    }

    $collection->search( $alias,
        $collection->scrub_tokens( @{ $self->tokens } ) );
    $collection->limit(
        alias            => $alias,
        column           => "complete",
        value            => 0,
        entry_aggregator => "OR",
        subclause        => "Completed",
    );
    $collection->limit(
        alias            => $alias,
        column           => "completed_at",
        operator         => '>',
        value            => BTDT::DateTime->now->subtract( weeks => 1 )->ymd,
        entry_aggregator => "OR",
        subclause        => "Completed",
    );

    if ($old_class) {
        $collection = bless $collection, $old_class;
    }
}

=head2 append $text

Takes the text of an email C<$text> and creates a
C<BTDT::Model::Task> object from it, which is then passed
on to be added to the mailbox. Checks to ensure that the
text contains a plist and that the task is simply an update
of a pre-existing task. If it is an update, the previous
message is deleted and expunged and an identical message is
created, except with the changes made.

=cut

sub append {
    my $self     = shift;
    my $text     = shift;
    my @messages = @{ $self->messages };
    my %ids;
    my $message;
    my $t;
    local $Email::MIME::ContentType::STRICT_PARAMS = 0;
    my $email = Email::MIME->new($text);

    for my $mess (@messages) {
        $ids{ $mess->ical_uid } = $mess;
    }

    my @parts
        = grep { $_->content_type =~ qr/^application\/vnd\.apple\.mail\+todo/ }
        $email->parts;
    return unless @parts;

    my $data = ( shift @parts )->body;
    my $plist = eval { Data::Plist::BinaryReader->open_string($data) };
    return unless "$@" eq '';
    return unless $plist and $plist->is_archive;

    my $todo = $plist->object;
    return unless $todo->isa("Data::Plist::Foundation::LibraryToDo");

    if ( defined $ids{ $todo->id } ) {
        $message = $ids{ $todo->id };
        $t       = $message->task;
        $t->start_transaction;
        $t->set_summary( $todo->title );
        $t->set_created( $todo->created );
        $t->set_due( $todo->due );
        $t->set_complete( $todo->complete );
        $t->set_priority( $todo->priority );
        $self->transaction_exceptions->{$t->current_transaction->id} = 1;
        $t->end_transaction;
        $self->flush($message);
    } else {
        my %defaults;
        $defaults{requestor_id} = $self->current_user->user_object->id;
        $defaults{summary}      = $todo->title;
        $defaults{created}      = $todo->created;
        # XXX TODO: There's something wrong with the due date - it throws
        # this error: Argument "08t00:00:00" isn't numeric in subroutine
        # entry at /usr/local/share/perl/5.8.8/DateTime/Format/Natural.pm line 161.
        $defaults{due}             = $todo->due if ( defined $todo->due );
        $defaults{complete}        = $todo->complete;
        $defaults{priority}        = $todo->priority;
        $defaults{__parse_summary} = 0;

        $t = BTDT::Model::Task->new( current_user => $self->current_user );
        $t->create(%defaults);
        return unless $t->id;
    }

    return $self->add_task($t, original => $email, todo => $todo);
}

=head2 flush $message

Takes a C<BTDT::IMAP::Message> object, sets the "Deleted"
flag and then expunges it.

=cut

sub flush {
    my $self = shift;
    my ($message) = @_;

    $message->set_flag('\Deleted');
    $self->expunge( [ $message->sequence ] );

    return;
}

=head2 threaded

Overrides user preferences and disallows threaded messages.

=cut

sub threaded { 0 }

=head2 trust_append

Automatically trusts messages appended by users.

=cut

sub trust_append { 1 }

1;
