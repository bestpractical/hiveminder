use warnings;
use strict;

package BTDT::Notification::TaskComment;
use base qw/BTDT::TaskNotification/;


=head1 NAME

BTDT::Notification::TaskComment - Notification that a task has been commented on

=head1 ARGUMENTS

C<task>

=head2 setup

Set it up.

=cut

sub setup {
    my $self = shift;
    $self->SUPER::setup(@_);
    $self->subject(_('Comment: %1 (#%2)', $self->task->summary, $self->task->record_locator));
}


=head2 send_one_message

Sends a notification of this comment, unless this is a Personal
task and it'd be mailing the creator/owner about the creator/owner's
own comment.

=cut

sub send_one_message {
    my $self = shift;

    unless (defined($self->task->group->id)) {
        # personal tasks never get comments mailed back to sender
        if ($self->to->id == $self->actor->id) {
            return;
        }
    }

    $self->SUPER::send_one_message;

}

=head2 _note

Text at the top of the mail body. It's blank so emailed comments feel more like email

=cut

sub _note {
    my $self = shift;
    return '';
}

=head2 body

Returns the actual comment

=cut

sub body {
    my $self = shift;
    return $self->SUPER::body . @{$self->transaction->comments->items_array_ref}[-1]->body . "\n\n";
}

=head2 html_body

Inclues the usual HTML body, as well as the HTML-formatted comment
which was added.

=cut

sub html_body {
    my $self  = shift;
    my $body  = $self->SUPER::html_body;
       $body .= <<'       HTML';
            <style type="text/css">
              blockquote {
                padding-left: 0.5em;
                border-left: 1px solid #000080;
                color: #666;
              }
            </style>
       HTML
       $body .= @{$self->transaction->comments->items_array_ref}[-1]->formatted_body;
    return $body;
}

=head2 _task_description

Don't show the task description for comment emails

=cut

sub _task_description { '' }

1;
