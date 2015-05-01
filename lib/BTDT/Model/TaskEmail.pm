use warnings;
use strict;

=head1 NAME

BTDT::Model::TaskEmail

=head1 DESCRIPTION

An email related to an existing task.  This is displayed as a comment
on the task.  Emails have a C<sender>, which is a L<BTDT::Model::User>
object, and a C<message>, which is a C<RFC 2822>-formatted email
message, including both headers and body.

=cut


package BTDT::Model::TaskEmail;
use BTDT::Model::User;
use BTDT::Model::TaskTransaction;
use Encode;
use Email::MIME::ContentType 'parse_content_type';
use Email::MIME::Attachment::Stripper;
use Text::Quoted qw();
use List::Util qw(reduce);

use base qw( BTDT::Record );


use Jifty::DBI::Schema;

use Jifty::Record schema {

column task_id        =>
  refers_to BTDT::Model::Task,
  label is 'Task',
  is immutable;
column transaction_id =>
  refers_to BTDT::Model::TaskTransaction,
  label is 'Transaction',
  since '0.2.9',
  is immutable,
  is protected;
column message        =>
  type is 'bytea',
  render_as 'Textarea',
  is immutable,
  label is 'Message';
column sender_id      =>
  refers_to BTDT::Model::User,
  label is 'Sender',
  is immutable,
  is protected;
column message_id     =>
  type is 'varchar',
  label is 'Message ID',
  since '0.2.30',
  is immutable,
  is protected,
  is case_sensitive;
column delivered_to   =>
  type is 'varchar',
  label is 'Delivered to',
  since '0.2.89',
  is immutable,
  is protected,
  is case_sensitive;

    column attachments =>
        references BTDT::Model::TaskAttachmentCollection by 'email_id',
        since '0.2.62';
};

use Jifty::RightsFrom column => 'task';

sub _set {
    my $self = shift;
    my %args = (@_);
    Carp::cluck if $args{column} eq 'message_id';
    return $self->SUPER::_set(%args);
}

=head2 create

create takes two named arguments: a C<message>, and either a
L<BTDT::Model::Task> id C<task_id>, or a
L<BTDT::Model::TaskTransaction> id C<transaction_id>.  If a task id s
provided, a new transaction of type "email" is added to the task, and
this email is attached to it.  If a transaction id is passed,
C<message> is expected to be a C<RFC 2822> email message.

Perhaps in the future, we'll have a clever way to read out the
task_id from the message itself.

=cut

sub create {
    my $self = shift;
    my %args = (
        task_id        => undef,
        transaction_id => undef,
        message        => undef,
        sender_id      => undef,
        @_);


    my $email = Email::Simple->new($args{'message'});
    return(undef, "No message given") unless $args{'message'};
    my @sender_objects = Email::Address->parse($email->header('From'));
    my $sender_address = '';
    if (my $obj = shift @sender_objects) {
        $sender_address = $obj->address;
    }
    my $sender_user = BTDT::Model::User->new();
    if ($args{sender_id}) {
        $sender_user->load_by_cols( id => $args{sender_id} );
    } else {
        $sender_user->load_by_cols( email => $sender_address);
    }

    my $transaction = BTDT::Model::TaskTransaction->new();
    if ($args{'transaction_id'}) {
        $transaction->load($args{'transaction_id'});
    } else {
        return (undef, "No task given") unless $args{'task_id'};
        my $task = BTDT::Model::Task->new();
        $task->load($args{'task_id'});
        return (undef, "No task with id $args{task_id}") unless $task->id;
        $transaction->create(task_id    => $args{'task_id'},
                             type       => "email",
                             created_by => $sender_user->id);
    }

    unless ($transaction->id and $transaction->current_user_can("update")) {
        return (undef, "You don't have permissions to do that!");
    }

    # References: and In-Reply-To munging
    $email->header_set( "Message-ID", BTDT::Notification->new_message_id )
        unless $email->header("Message-ID");
    if ( $email->header("In-Reply-To") or $email->header("References") ) {
        BTDT::Notification->decode_references($email);
    } else {
        my $reply = $transaction->task->transactions->last->comments->first;
        BTDT::Notification->reply_headers( $email, $reply ) if $reply;
    }

    my ( $id, $msg ) = $self->SUPER::create(
        task_id        => $transaction->task->id,
        transaction_id => $transaction->id,
        message        => $email->as_string,
        sender_id      => $sender_user->id,
        message_id     => $email->header('Message-ID'),
        delivered_to   => ($email->header('X-Hiveminder-delivered-to') || undef),
    );

    unless ($self->id) {
        return(undef, $msg);
    }

    $transaction->task->flip_next_action_by($sender_user);

    # Commit it if we made it
    $transaction->commit unless $args{'transaction_id'};

    # Add attachments if we have them
    my $mime = Email::MIME::Attachment::Stripper->new( $args{'message'} );
    my @attachments = $mime->attachments;

    if (($mime->message->content_type || 'text/plain') !~ m{^(text|multipart)/}) {
        my $content_type = parse_content_type($mime->message->content_type);
        push @attachments, {
            content_type => join(
                                 '/',
                                 @{$content_type}{qw[discrete composite]}
                                ),
            payload      => $mime->message->body,
            filename     => $mime->message->filename(1),
        }
    }
    for my $attached ( @attachments ) {
        # Does it look like an alternative part?
        next if     $attached->{'content_type'} eq 'text/html'
                and not length $attached->{'filename'};

        # Does it look like a PGP signature?
        next if $attached->{'content_type'} eq 'application/pgp-signature';

        # Skip multipart/* parts
        next if $attached->{'content_type'} =~ m{^multipart/};

        # Skip if it has no content; even if we didn't do this, the
        # attachment create would fail, as 'content' is a mandatory
        # field, and "" isn't good enough.
        next unless defined $attached->{'payload'} and length $attached->{'payload'};

        my $file = BTDT::Model::TaskAttachment->new;
        my ($ret, $msg) = $file->create(
            task_id         => $transaction->task->id,
            transaction_id  => $transaction->id,
            email_id        => $self->id,
            user_id         => $sender_user->id,
            content         => $attached->{'payload'},
            content_type    => $attached->{'content_type'},
            filename        => $attached->{'filename'},
            hidden          => ( ! $sender_user->pro_account )
        );
        if ( not $file->id ) {
            $self->log->warn("Couldn't create attachment for TaskEmail " . $self->id . ": $msg");
            BTDT::Notification::EmailError::Attachment->new(
                to       => $sender_user,
                filename => $attached->{'filename'},
                email    => $args{'message'},
                error    => $msg
            )->send;
        }
    }

    return ($self->id, "Task email created");
}

=head2 header STRING

Manipulates the C<header> of an L<Email::Simple> object.

=cut

sub header {
    my $self = shift;
    my $message = Email::Simple->new($self->message);
    return $message->header(@_);
}

=head2 body

Extracts the C<message> into an L<Email::Simple> object, and returns
the body.

=cut

sub body {
    my $self = shift;
    my $email = Email::MIME->new( $self->message  ||'' ) ;

    my $body = $self->extract_body($email);
    return undef unless defined $body;

    $body = $self->_remove_quoted($body);
    return $body;
}

=head2 extract_body EMAIL

Class method to extract the textual body from an Email::MIME email,
and to attempt to guess the encoding appropriately

=cut

sub extract_body {
    my $self = shift;
    my $email = shift;

    my $body = ( grep { ($_->content_type || '') =~ m'^text/plain'i } $self->_flatten($email->parts) )[0]
      || $email;

    my $charset = $body->content_type
      ? parse_content_type( $body->content_type )->{charset}
      : '';

    if (($body->content_type || 'text/plain') !~ m|^text/|i) {
        return undef;
    }

    $body = $body->body;
    Encode::_utf8_off($body);
    $body = Jifty::I18N->promote_encoding($body, $charset);
    $body =~ s/\s*\r?\n-- \r?\n.*$//s;

    return $body;
}

sub _flatten {
    my $self = shift;
    my @result;
    for (@_) {
        if ( ( $_->content_type || '' ) =~ m'^multipart/'i ) {
            my @parts = $_->parts;
            if (@parts > 1 or $parts[0] ne $_) {
                push @result, $self->_flatten( $_->parts );
            }
        } else {
            push @result, $_;
        }
    }
    return @result;
}

=head2 _remove_quoted

Removes quoted text.

=cut

sub _remove_quoted {
    my ($self, $text) = @_;

    my $non_empty   = ".+";
    my $newline     = "\\n";
    my $quote_char  = "(?: > | \\| )";
    my $quoted_intro = qr/(?! $quote_char ) $non_empty (?: said | wrote | writes? ) :?/ox;

    # trim body
    $text =~ s/^\s*//;
    $text =~ s/\s*$//;

    # Figure out the structure of the message
    my @structure;
    my $parts = Text::Quoted::extract( $text );
    my %types = ( HASH => 'unquoted', ARRAY => 'quoted' );

    for my $part ( @$parts ) {
        push @structure,
            ( ref $part eq 'HASH' and $part->{empty} )                    ? 'empty' :
            ( ref $part eq 'HASH' and $part->{raw} and  $part->{raw} =~ /^$quoted_intro$/ ) ? 'intro' : $types{ ref $part };
    }

    # Combines equal adjacent elements into one so we can compare
    # against simple basic structures
    my @simplified;
    reduce { push @simplified, $a if $a ne $b; return $b; }
      grep { $_ !~ /^(?:empty|intro)$/ } @structure, 'END';

    my $simple = join ' ', @simplified;

    # if it's not one of these two cases, it's probably an interleaved
    # reply and there's not much we can do
    my $remove_quoted = $simple eq 'unquoted quoted'                ? 'before' :
                        $simple =~ m/^quoted unquoted(?: quoted)?$/ ? 'after'  :
                                                                      0;

    if ( $remove_quoted ) {
        $text = '';
        for my $part ( @$parts ) {
            if ( ref $part eq 'ARRAY' ) {
                if    ( $remove_quoted eq 'before' ) { last }
                elsif ( $remove_quoted eq 'after' )  { next }
            }
            next if $part->{raw} =~ /^$quoted_intro$/;
            $text .= $part->{raw}."\n";
        }
    }

    # trim again, just in case
    $text =~ s/^\s*//;
    $text =~ s/\s*$//;

    return $text;
}

=head2 formatted_body

Format the body using L<BTDT/format_text>.

=cut

sub formatted_body {
    my $self = shift;
    my $body = $self->body;
    return defined $body
              ? BTDT->format_text( $body, @_ )
              : "<i>This message contains no readable content.</i>";
}

=head2 since

This table first appeared in 0.2.3

=cut

sub since { '0.2.3' }

=head2 autogenerate_action

Only generate Search and Create actions for this model.

=cut

sub autogenerate_action {
    my $class = shift;
    my $right = shift;
    return($right eq "Search" or $right eq "Create");
}

=head2 is_autogenerated

Returns true if the message looks to have been automatically generated.

=cut

sub is_autogenerated {
    my $self = shift;
    my $message = Email::Simple->new($self->message);
    return 1 if ($message->header("Precedence") || "") =~ /^(bulk|junk)$/;
    return 1 if ($message->header("Auto-submitted") || "no") ne "no";
    return 1 if ($message->header("X-FC-Machinegenerated") || "") =~ /^true/;
    return;
}

1;
