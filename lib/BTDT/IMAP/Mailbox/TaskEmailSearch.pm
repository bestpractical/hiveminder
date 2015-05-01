package BTDT::IMAP::Mailbox::TaskEmailSearch;

use warnings;
use strict;

use BTDT::IMAP::Message::TaskEmail;
use BTDT::IMAP::Message::TaskSummary;
use base qw/BTDT::IMAP::Mailbox::TaskSearch/;

=head1 NAME

BTDT::IMAP::Mailbox::TaskEmailSearch - Token-based tasks searches, storing TaskEmails

=head1 METHODS

=head2 add_task_email TASKEMAIL

Given a L<BTDT::Model::TaskEmail> object, adds it to the mailbox.  If
it is a create transaction, adds a
L<BTDT::IMAP::Message::TaskSummary>, otherwise adds a
L<BTDT::IMAP::Message::TaskEmail>.

=cut

sub add_task_email {
    my $self = shift;
    my $obj  = shift;
    my @opts = @_;

    my $m;
    $obj->transaction->_is_readable(1);
    $obj->prefetched("uid")->_is_readable(1) if $obj->prefetched("uid");
    $obj->prefetched("flags")->_is_readable(1) if $obj->prefetched("flags");
    if ($obj->transaction->type eq "create") {
        $m = BTDT::IMAP::Message::TaskSummary->new( task_email => $obj, @opts );
    } else {
        $m = BTDT::IMAP::Message::TaskEmail->new( task_email => $obj, @opts );
    }
    $self->add_message($m);

    return $m;
}

=head2 append BODY

When a message is appended to this mailbox, use the tokens to create a
new task.  Except if it's OfflineIMAP being dumb and doing APPEND
instead of COPY.

=cut

sub append {
    my $self = shift;

    my $text  = shift;
    local $Email::MIME::ContentType::STRICT_PARAMS = 0;
    my $email = Email::MIME->new( $text );

    return $self->handle_offlineimap($email) if $self->is_offlineimap($email);

    my $tasks = BTDT::Model::TaskCollection->new( current_user => $self->current_user );
    $tasks->from_tokens(@{$self->tokens});
    my %defaults = $tasks->new_defaults;
    $defaults{requestor_id}  = $self->current_user->user_object->id;
    $defaults{summary}       = $email->header("Subject");
    $defaults{email_content} = $text;
    $defaults{__parse_summary} = 0;

    my $t = BTDT::Model::Task->new( current_user => $self->current_user );
    $t->create( %defaults );
    return unless $t->id;

    return $self->add_task( $t );
}


=head2 copy_allowed

Copying into this mailbox is allowed

=cut

sub copy_allowed { 1 }


=head2 run

When a message is copied into this mailbox, use the tokens to set
properties of it.

=cut

sub run {
    my $self = shift;
    my $message = shift;

    my $tasks = BTDT::Model::TaskCollection->new( current_user => $self->current_user );
    $tasks->from_tokens(@{$self->tokens});
    my %defaults = $tasks->new_defaults;

    my $t = $message->task_email->task;
    $t->start_transaction;
    for my $key (keys %defaults) {
        if ($key eq "tags") {
            $t->set_tags( $t->tags . " " . $defaults{tags} );
        } elsif ($key eq "owner_id") {
            if ($defaults{owner_id} =~ /\@/) {
                my $owner = BTDT::Model::User->new( current_user => BTDT::CurrentUser->superuser );
                $owner->load_or_create( email => $defaults{owner_id} );
                $t->set_owner_id( $owner->id );
            } elsif ( lc $defaults{owner_id} eq 'nobody' ) {
                $t->set_owner_id( BTDT::CurrentUser->nobody->id );
            }
        } else {
            my $method = "set_$key";
            $t->$method($defaults{$key});
        }
    }
    $t->end_transaction;

    return $self->add_task($t, matching => $message->task_email->id);
}


1;
