package BTDT::RTM::Tasks::Notes;

use strict;
use warnings;

use base 'BTDT::RTM';

=head1 NAME

BTDT::RTM::Tasks::Notes - Comments on tasks

=head1 METHODS

=head2 note_data TASKEMAIL

Returns a data structure suitable for output.

=cut

sub note_data {
    my $class = shift;
    my $email = shift;

    my $created = $email->transaction->modified_at;
    $created->set_time_zone("UTC");
    $created = $created->ymd . "T" . $created->hms . "Z";

    my $subject = Encode::decode('MIME-Header', $email->header("Subject"));
    $subject .= " " if $subject;
    $subject .= "(from ".$email->sender->email.")\n";

    return {
        id => $email->id,
        created => $created,
        modified => $created,
        title => $subject,
        '$t' => $email->body,
    };
}

=head2 method_add

Adds a comment with the given C<note_text> and C<note_title>

=cut

sub method_add {
    my $class = shift;
    my $task = BTDT::RTM::Tasks->require_task;

    my ($id, $msg) = $task->comment(
        $class->params->{note_text},
        Subject => Encode::encode('MIME-Header',$class->params->{note_title}),
    );
    my $note = BTDT::Model::TaskEmail->new;
    $note->load($id);

    $class->send_ok(
        transaction => { id => $note->transaction->id, undoable => 0 },
        note => $class->note_data($note),
    );
}

=head2 method_delete

Unimplemented, due to comments being permanent.

=head2 method_edit

Unimplemented, due to comments being immutable.

=cut

sub method_delete { shift->send_unimplemented; }
sub method_edit { shift->send_unimplemented; }

1;
