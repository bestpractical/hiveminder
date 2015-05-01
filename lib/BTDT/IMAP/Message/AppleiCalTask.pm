package BTDT::IMAP::Message::AppleiCalTask;
use warnings;
use strict;

use Data::Plist::BinaryWriter;
use base 'BTDT::IMAP::Message';

__PACKAGE__->mk_accessors(qw/task ical_uid task_email/);

=head1 NAME

BTDT::IMAP::Message::AppleiCalTask - Provides message interface for Apple iCal tasks.

=cut

=head1 METHODS

=head2 new PARAMHASH

Requires a L<Email::MIME object>, a L<BTDT::Model::Task>,
an identifying uid and a L<BTDT::Model::TaskEmail>.

=cut

sub new {
    my $class = shift;
    my %args  = @_;
    my $self  = $class->SUPER::new();

    $self->mime( $args{mime} );
    $self->task( $args{task} );
    $self->ical_uid( $args{ical_uid} );
    $self->task_email( $args{task_email} );

    return $self;
}

=head2 from_task PARAMHASH

The one required arguments are C<task>, which is a
L<BTDT::Model::Task>, and C<task_email>, which is a
L<BTDT::Model::TaskEmail>. It can also take the optional
parameters of C<original>, an L<Email::MIME> object, and
C<todo>, a L<Data::Plist::Foundation::LibraryToDo> object.

=cut

sub from_task {
    my $class = shift;
    my %args  = @_;

    my $write = Data::Plist::BinaryWriter->new;
    my $task  = $args{task};
    my $todo;
    if ( defined $args{todo} ) {
        $todo = $args{todo};
    } else {
        $todo = $task->as_library_todo;
    }
    my $email;
    if ( defined $args{original} ) {
        $email = $args{original};
    } else {
        my @parts = (
            Email::MIME->create(
                attributes => { content_type => "text/plain", },
                body =>
                    "This is a To Do stored on an IMAP server. It is managed by Mail so please don't modify or delete it."
            ),
            Email::MIME->create(
                attributes => {
                    content_type => "application/vnd.apple.mail+todo",
                    encoding     => "base64"
                },
                body => $write->write($todo),
            ),
        );

        $email = Email::MIME->create( header => [ "X-Uniform-Type-Identifier" => "com.apple.mail-todo",
                                                  "Message-Id" => $todo->id,
                                              ],
                                      parts => [@parts], );

    }
    return $class->new(
        mime       => $email,
        task       => $task,
        ical_uid   => $todo->id,
        task_email => $args{task_email}
    );
}

=head2 delete_allowed

Allows these tasks to be deleted.

=cut

sub delete_allowed {1}

=head2 is_task_summary

Returns true because the message is a summary of the task that
should be updated when the task changes.

=cut

sub is_task_summary {1}

1;
