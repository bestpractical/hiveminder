package BTDT::IMAP::Message::TaskSummary;

use warnings;
use strict;

use Email::MIME;
use Email::MIME::Header;
use DateTime::Format::Mail;
use base 'BTDT::IMAP::Message::TaskEmail';

__PACKAGE__->mk_accessors(qw(_mime_header));

=head1 NAME

BTDT::IMAP::Message::TaskSummary - Provides a summary of the task

=head1 METHODS

=head2 memcached_key

Returns the key used to look up this task in the memcached server; a
product of the task associated with this, as well as the user looking
at it.

=cut

sub memcached_key {
    my $self = shift;
    return join("-", "IMAP", $self->task_email->task_id, $Net::IMAP::Server::Server->connection->auth->user);
}

=head2 expunge

When this task is expunged, expunge it from the memcache;

=cut

sub expunge {
    my $self = shift;
    BTDT->memcached->delete($self->memcached_key) if BTDT->memcached;
    return $self->SUPER::expunge();
}

=head2 mime_header

Returns the header.  This is factored out as a slight performance
optimization, as some queries do not require us to know the full body,
which is expensive to generate.

=cut

sub mime_header {
    my $self = shift;
    return $self->_mime_header if $self->_mime_header;

    my $task = $self->task_email->task;
    $task->_is_readable(1);

    my $header = Email::MIME::Header->new( "", {crlf => "\r\n"} );
    $header->{mycrlf} = "\r\n";
    my %headers = ();
    $task->set_header_on( $header, "Subject"      => $task->summary );
    $task->set_header_on( $header, "From"         => $task->requestor->formatted_email );
    $task->set_header_on( $header, "To"           => $task->owner->formatted_email );
    $task->set_header_on( $header, "Date"         => DateTime::Format::Mail->format_datetime($task->created));
    $task->set_header_on( $header, "Reply-To"     => $task->comment_address );
    $task->set_header_on( $header, "X-Priority"   => $task->text_priority);
    $task->set_header_on( $header, "Message-Id"   => $self->task_email->message_id );
    $task->set_header_on( $header, "Content-Type" => "text/plain; charset=utf-8");
    $task->set_headers_on($header);
    $self->_mime_header($header);
    return $header;
}

=head2 mime

Generates the body of the summary message.

=cut

sub mime {
    my $self = shift;

    if (BTDT->memcached) {
        my $memcached = BTDT->memcached->get($self->memcached_key);
        return $memcached if $memcached;
    }

    my $task = $self->task_email->task;
    $task->_is_readable(1);

    my $email = Email::MIME->new( "" );
    $email->header_obj_set($self->mime_header);
    $email->{mycrlf} = "\r\n";

    my $body = "Task #" . $task->record_locator . " - " . $task->url;
    $body .= "\n" . ("=" x length $body) . "\n";
    $body .= "      Tags: " . $task->tags . "\n" if $task->tags;
    $body .= "  Priority: " . $task->text_priority . "\n";
    $body .= "\n";
    $body .= " Requestor: " . $task->requestor->formatted_email . "\n";
    $body .= "     Owner: " . $task->owner->formatted_email . "\n";
    $body .= "     Group: " . $task->group->name . "\n" if $task->group->id;
    $body .= "   Project: " . $task->project->summary . "\n" if $task->project->id;
    $body .= " Milestone: " . $task->milestone->summary . "\n" if $task->milestone->id;
    $body .= "\n";
    $body .= "Created at: " . $task->created . "\n";
    $body .= "       Due: " . $task->due->ymd . "\n" if $task->due;
    $body .= "Hide until: " . $task->starts->ymd . "\n" if $task->starts;
    $body .= "\n";

    my $depends = $task->incomplete_depends_on;
    if ($depends->count) {
        $body .=        "    Depends on: ";
        $body .= join("\n                ",
                      map {$_->summary . " ( " . $_->url . " )"} @{$depends->items_array_ref}
                     );
        $body .= "\n";
    }

    my $depend_on = $task->incomplete_depended_on_by;
    if ($depend_on->count) {
        $body .=        "Depended on by: ";
        $body .= join("\n                ",
                      map {$_->summary . " ( " . $_->url . " )"} @{$depend_on->items_array_ref}
                     );
        $body .= "\n";
    }
    $body .= "\n" if $depends->count or $depend_on->count;

    $body .= "=== History ===\n";
    my $txns = $task->transactions;
    $txns->prefetch_common( task => 0 );
    while (my $t = $txns->next) {
        next unless $t->summary;
        $body .= " * " . $t->summary . " at " . $t->modified_at . "\n";
        my $changes = $t->visible_changes;
        if ($t->type eq "update" and $changes->count > 1) {
            while (my $c = $changes->next) {
                next unless ($c->as_string);
                $body .= "   - " . $c->as_string . "\n";
            }
        }

        unless ($Net::IMAP::Server::Server->connection->auth->options->{threaded}) {
            my $comments = $t->comments;
            while (my $email = $comments->next) {
                if (my $sub = $email->header('Subject')) {
                    $body .= "Subject: ".Encode::decode('MIME-Header', $sub)."\n";
                }
                $body .= $email->body;
                $body .= "\n" while $body !~ /\n\n$/;
            }
        }
    }
    $body .= "\n";

    if (defined $task->description and length $task->description ) {
        $body .= "===== Notes =====\n" . $task->description . "\n\n";
    }

    $email->body_set($body);

    my $duration = Jifty->config->app('IMAP')->{memcache} || 60*30;
    BTDT->memcached->set($self->memcached_key => $email, $duration) if BTDT->memcached;

    return $email;
}

=head2 is_task_summary

Returns true because the message is a summary of the task that
should be updated when the task changes.

=cut

sub is_task_summary { 1; }

1;
