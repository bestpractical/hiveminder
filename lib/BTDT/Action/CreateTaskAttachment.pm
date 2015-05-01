use warnings;
use strict;

=head2 NAME

BTDT::Action::CreateTaskAttachment

=cut

package BTDT::Action::CreateTaskAttachment;
use base qw/BTDT::Action Jifty::Action::Record::Create/;

use Jifty::Param::Schema;
use BTDT::Action schema {
    param content => label is 'File';
};

=head2 record_class

Creates L<BTDT::Model::TaskAttachment> objects.

=cut

sub record_class { 'BTDT::Model::TaskAttachment' }

=head2 take_action

Extracts the file content and content-type, and then creates the
TaskAttachment.

=cut

sub take_action {
    my $self = shift;

    my $attachment = $self->argument_value('content');

    $self->argument_value( filename     => $attachment->filename );
    $self->argument_value( content_type => $attachment->content_type );
    $self->argument_value( content      => $attachment->content );

    $self->argument_value( user_id => $self->current_user->id );

    my $ret = $self->SUPER::take_action( @_ );

    # Kill file handle so it's not in the session or request
    $self->argument_value( content => '' );
    Jifty->web->request->delete('J:A:F-content-'.$self->moniker);

    return $ret;
}

=head2 report_success

Sets the message to "File uploaded!"

=cut

sub report_success {
    my $self = shift;
    $self->result->message("File uploaded!");
}

1;
