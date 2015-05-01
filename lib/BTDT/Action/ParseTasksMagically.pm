use warnings;
use strict;

=head1 NAME

BTDT::Action::ParseTasks

=cut

package BTDT::Action::ParseTasksMagically;
use base qw/BTDT::Action Jifty::Action/;

use BTDT::Sync;

=head2 arguments

The fields for C<UploadTasks> are:

=over 4

=item text

=back

=cut

sub arguments {
        {
            text => {
                label         => '',
                render_as     => 'Textarea',
                rows          => 15,
                cols          => 60,
                class         => 'bigbox',
                documentation => "The braindump's text",
            },
            tokens => {
                render_as     => 'Hidden',
                documentation => "The default attributes for created tasks",
            },
        }

}

=head2 take_action

Import the textfile dump

=cut

sub take_action {
    my $self = shift;

    my $parser = BTDT::Sync::TextFile->new();
    my @tasks = $parser->parse_tasks(data => $self->argument_value('text'), ids => 0);

    # This will happen at the model level, and we want from_data to
    # fill in the searched-for owner if appropriate.

    # $_->{owner_id} ||= Jifty->web->current_user->user_object->email for @tasks;
    $_->{requestor_id} = Jifty->web->current_user->user_object->id for @tasks;

    my $ret = BTDT::Sync->sync_data(
        tasks  => \@tasks,
        tokens => [ BTDT::Model::TaskCollection->split_tokens($self->argument_value('tokens') || "" ) ],
    );
    $self->result->content($_ => $ret->{$_}) for keys %{$ret};
    $self->result->content(tokens => $self->argument_value('tokens'));
    my $created = scalar @{ $ret->{created} };

    $self->result->message("$created task" . ($created == 1 ? "" : "s") . " created" );
}

1;

