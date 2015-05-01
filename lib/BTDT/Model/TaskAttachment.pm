use strict;
use warnings;

package BTDT::Model::TaskAttachment;

=head1 NAME

BTDT::Model::TaskAttachment

=head1 DESCRIPTION

An attachment for a task.  Attachments are stored as base64 and have a
task transaction and optional task email.

=cut

use File::Spec;

use Jifty::DBI::Schema;
use BTDT::Record schema {
    column task_id =>
        references BTDT::Model::Task,
        label is 'Task',
        is mandatory,
        is immutable;

    column transaction_id =>
        references BTDT::Model::TaskTransaction,
        label is 'Transaction',
        is immutable,
        is protected;

    column email_id =>
        references BTDT::Model::TaskEmail,
        label is 'Email',
        is immutable,
        is protected;

    column content =>
        label is 'Content',
        type is 'bytea',
        filters are qw/ Jifty::DBI::Filter::base64 /,
        render_as 'Upload',
        is immutable,
        is mandatory;

    column content_type =>
        label is 'Content type',
        type is 'text',
        is immutable;

    column size =>
        label is 'Size',
        is immutable,
        since '0.2.63',
        is protected;

    column user_id =>
        references BTDT::Model::User,
        label is 'User',
        is immutable,
        is private;

    column filename =>
        type is 'text',
        label is 'Filename',
        is immutable;

    column name =>
        type is 'text',
        label is 'Name';

    column hidden =>
        is boolean,
        since '0.2.75',
        is private;
};

=head2 since

0.2.62

=cut

sub since { '0.2.62' }

=head2 current_user_can

Non-pro users can only read attachments.  Only the name can be updated.
Otherwise, the rights are delegated by the task associated with the
attachment.

=cut

use Jifty::RightsFrom column => 'task';

sub current_user_can {
    my $self  = shift;
    my $right = shift;
    my %args  = @_;

    # Only pro users can see hidden attachments once they're created
    return 0 if $self->__value('hidden')
        and not  ( $self->current_user->is_superuser
                or $self->current_user->pro_account );

    if (    $self->current_user->id
        and not $right =~ /^(?:read|create)$/
        and not $self->current_user->pro_account )
    {
        return 0;
    }

    if ( $self->current_user->id and $right eq 'update' ) {
        if ( not defined $args{'column'} ) {
            return 1;
        }
        else {
            return $args{'column'} eq 'name' ? 1 : 0;
        }
    }

    return $self->SUPER::current_user_can( $right, @_ );
}

=head2 create

Creates a new attachment; non-pro users always create hidden
attachments.  May fail if the attachment is too big, or would put the
user over quota.

=cut

sub create {
    my $self = shift;
    my %args = (
        task_id         => undef,
        transaction_id  => undef,
        email_id        => undef,
        user_id         => undef,
        content_type    => undef,
        name            => undef,
        hidden          => 0,
        @_
    );

    $args{'user_id'} = $self->current_user->id
        if not defined $args{'user_id'};

    # Non-pro users can only create hidden attachments
    $args{'hidden'} = 1
        if not BTDT::CurrentUser->new( id => $args{'user_id'} )->pro_account;

    # Set the size
    {
        use bytes;
        $args{'size'} = length $args{'content'};
    }

    # Check the invidivual file size
    my $MAX_SIZE = Jifty->config->app('MaxAttachmentSize');
    if ( $args{'size'} > $MAX_SIZE ) {
        return ( undef, sprintf("Attachment size (%s) is too large (max %s)",
                                BTDT->english_filesize( $args{'size'} ),
                                BTDT->english_filesize( $MAX_SIZE )) );
    }

    # Check the user's total limit
    my $quota = Jifty::Plugin::Quota::Model::Quota->new;
    $quota->load_by_cols(
        object_class => 'User',
        object_id    => $args{'user_id'},
        type         => 'disk'
    );

    unless ( $quota->id and $quota->add_usage( $args{'size'} ) ) {
        return ( undef, sprintf("Attachment size (%s) exceeds user quota (%s of %s)",
                                BTDT->english_filesize( $args{'size'} ),
                                BTDT->english_filesize( $quota->usage ),
                                BTDT->english_filesize( $quota->cap )) );
    }

    # Either load or create our transaction
    my $transaction = BTDT::Model::TaskTransaction->new;
    if ( $args{'transaction_id'} ) {
        $transaction->load( $args{'transaction_id'} );
    }
    else {
        return ( undef, "No task given" ) unless $args{'task_id'};

        my $task = BTDT::Model::Task->new;
        $task->load( $args{'task_id'} );

        return ( undef, "No task with id $args{task_id}" ) unless $task->id;

        $transaction->create(task_id    => $args{'task_id'},
                             type       => "attachment",
                             created_by => $args{'user_id'});
    }

    unless ( $transaction->id and $transaction->current_user_can("update") ) {
        return ( undef, "You don't have permissions to do that!" );
    }

    # Cleanup the filename if we can
    if ( $args{'filename'} ) {
        my $file = File::Spec->splitpath( $args{'filename'} );
        $args{'filename'} = $file if length $file;
    }

    # Set name if there's none
    if ( not defined $args{'name'} and $args{'filename'} ) {
        $args{'name'} = $args{'filename'};
    }

    if ( not defined $args{'name'} ) {
        $args{'name'} = 'Untitled';
    }

    # Set basic content type if there's none
    if ( not defined $args{'content_type'} ) {
         my $is_binary = $args{'content'} =~ /[\x00\x80-\xFF]/;

         $args{'content_type'} = $is_binary ? 'application/octet-stream'
                                            : 'text/plain';
    }

    # Do the actual create
    my ( $id, $msg ) = $self->SUPER::create(
        %args,
        task_id     => $transaction->task->id,
        transaction_id => $transaction->id,
    );

    unless ( $self->id ) {
        return ( undef, $msg );
    }

    # Commit it if we made it
    $transaction->commit unless $args{'transaction_id'};

    if ( not $self->__value('hidden') ) {
        # Increase the attachment_count for the task
        $self->task->__set(
            column => 'attachment_count',
            value  => 'attachment_count + 1',
            is_sql_function => 1
        );
    }

    return ( $self->id, "Task attachment created" );
}

=head2 delete

Subtracts this attachment's size from the user's quota and decreases
the task's attachment_count

=cut

sub delete {
    my $self = shift;

    my $user_id = $self->user_id;
    my $size    = $self->size;
    my $task_id = $self->task_id;
    my $hidden  = $self->__value('hidden') ? 1 : 0;

    my ($ret, $msg) = $self->SUPER::delete;

    if ( $ret ) {
        # Subtract from quota
        my $quota = Jifty::Plugin::Quota::Model::Quota->new;
        $quota->load_by_cols(
            object_class => 'User',
            object_id    => $user_id,
            type         => 'disk'
        );
        $quota->subtract_usage( $size )
            if $quota->id;

        if ( not $hidden ) {
            # Subtract from attachment_count
            my $task = BTDT::Model::Task->new;
            $task->load( $task_id );
            $task->__set(
                column => 'attachment_count',
                value  => 'attachment_count - 1',
                is_sql_function => 1
            );
        }
    }
    return ($ret, $msg);
}

=head2 url [TYPE]

Returns a url that can be used to fetch the attachment.  TYPE is either
'view' or 'download'.  Defaults to 'view'.

=cut

sub url {
    my $self = shift;
    my $type = shift || 'view';
    return '/task/'.$self->task->record_locator.'/attachment/'.$self->id.'/'.$type;
}

=head2 short_content_type

Returns a "short" content_type

=cut

# Evaluated in order
our @TYPES = (
    [ qr'^(image/svg|application/postscript)'       => 'vector' ],
    [ qr'^image/'                                   => 'image' ],
    [ qr'^text/plain'                               => 'text' ],
    [ qr'^(text/html|application/(xhtml\+)?xml)'    => 'html' ],
    [ qr'^application/pdf'                          => 'pdf' ],
    [ qr'^application/(rar|(x-(b|g))?zip|x-g?tar)'  => 'archive' ],
    [ qr'^application/vnd.ms-excel'                 => 'excel' ],
    [ qr'^application/vnd.ms-powerpoint'            => 'ppt' ],
    [ qr'^application/msword'                       => 'msword' ],
    [ qr'^application/octet-stream'                 => 'unknown' ],
    [ qr'.'                                         => 'unknown' ],
);

sub short_content_type {
    my $self = shift;
    my $type = $self->content_type;
    for my $test ( @TYPES ) {
        return $test->[1] if $type =~ $test->[0];
    }
    return;
}

=head2 english_size

Returns the size of the attachment, formatted for human readers.

=cut

sub english_size {
    my $self = shift;
    return BTDT->english_filesize( $self->size );
}

1;

