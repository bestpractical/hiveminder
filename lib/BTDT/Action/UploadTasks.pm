
use warnings;
use strict;

=head1 NAME

BTDT::Action::UploadTasks

=cut

package BTDT::Action::UploadTasks;
use base qw/BTDT::Action Jifty::Action/;
use BTDT::Sync::TextFile;
use BTDT::Sync::TodoTxt;

=head2 arguments

The fields for C<UploadTasks> are:

=over 4

=item file: The edited tasks file

=back

=cut

sub arguments {
        {
            content => {
                label => 'The text version',
                render_as => 'Textarea',
                documentation => 'The text of the file',
            },
            file    => {
                label     => '',
                render_as => 'Upload',
                documentation => 'Widget for uploading the file directly',
            },
            format => {
                label         => 'Textfile format',
                valid_values  => [qw(sync todo.txt)],
                default_value => 'sync'
            },
            metadata => {
                label => 'List metadata',
                render_as => 'Hidden',
                documentation => "If you split out the textfile format, you might put  metadata here"
            }
        }
}

=head2 take_action

Import the textfile dump

=cut

sub take_action {
    my $self = shift;
    unless( $self->argument_value('file') || $self->argument_value('content') ) {
        $self->result->failure('You must upload something!');
        return 1;
    }
    my $outcome;
    my $content;
    if ( my $fh = $self->argument_value('file') ) {
        local $/;
        $content = <$fh>;

        # This kills the filehandle from the action, so Apache::Session
        # doesn't try to save it away (and fail) when we do the redirect

        $self->argument_value( 'file', "" );
    } elsif (my $meta = $self->argument_value('metadata')) {

        $content = "Bogus header\n---\n".$self->argument_value('content')."\n---\n".$meta;
    } else {
        $content = $self->argument_value('content');
    }

    my $sync;
    if($self->argument_value('format') eq 'sync') {
        $sync = BTDT::Sync::TextFile->new;
    } else {
        $sync = BTDT::Sync::TodoTxt->new;
    }

    $outcome = $sync->from_text($content);

    my $updated   = @{ $outcome->{updated} };
    my $created   = @{ $outcome->{created} };
    my $completed = @{ $outcome->{completed} };

    my $message = sprintf '%d task%s updated, %d task%s created, %d task%s marked completed',
        $updated,   $updated   == 1 ? '' : 's',
        $created,   $created   == 1 ? '' : 's',
        $completed, $completed == 1 ? '' : 's';

    $self->result->content( $_ => $outcome->{$_} ) for keys %{$outcome};
    $self->result->message($message);
    delete Jifty->handler->stash->{RECORD_ARGUMENTS};
}

1;
