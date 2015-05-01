
use warnings;
use strict;

=head1 NAME

BTDT::Action::DownloadTasks

=cut

package BTDT::Action::DownloadTasks;
use base qw/BTDT::Action Jifty::Action/;
use BTDT::Sync::TextFile;

use Scalar::Util qw(blessed);

=head2 arguments

The fields for C<DownloadTasks> are:

=over 4

=item query

A slash-separated list of tokens denoting a search to download

=item format

=over 4

=item C<sync>

our text-file sync format

=item C<yaml>

a YAML dump of the tasks

=item C<json>

a JSON dump of the tasks

=back

=back

=cut

sub arguments {
        {
            query  => {
                render_as => 'text',
                documentation => 'The tokens for the tasklist (separated by slashes)',
            },
            format => {
                valid_values => [
                    { label => "Textfile sync", value => 'sync' },
                    { label => "YAML",          value => 'yaml' },
                    { label => "JSON",          value => 'json' },
                  ],
                default_value => 'sync',
            }
        }
}


=head2 take_action

Import the textfile dump

=cut

sub take_action {
    my $self = shift;

    #TODO: default_value should do the || $default for us
    my $format = $self->argument_value('format') || 'sync';
    my $query = $self->argument_value('query') || 'not/complete/owner/me/starts/before/tomorrow/accepted/but_first/nothing';

    my $tasks = BTDT::Model::TaskCollection->new();
    my @tokens = $tasks->split_tokens_url($query);
    $tasks->from_tokens(@tokens);

    if($format eq 'sync') {
        my $sync = BTDT::Sync::TextFile->new;
        $self->result->content( result => $sync->as_text($tasks) );
    } else {
        my @tasks;
        while(my $task = $tasks->next) {
            push @tasks, $self->to_hash($task);
        }

        if ($format eq 'yaml') {
            $self->result->content( result => Jifty::YAML::Dump(\@tasks) );
        }
        elsif ($format eq 'json') {
            $self->result->content( result => Jifty::JSON::encode_json(\@tasks, {utf8 => 0}) );
        }
    }
}

=head2 to_hash TASK

Helper method to convert a task to a hash for serializing and
returning.

=cut

sub to_hash {
    my $self = shift;
    my $task = shift;
    my %hash;
    for my $key ($task->readable_attributes) {
        next if $key =~ /^depend/;      # Skip the dependency cache
        $key = $1 if $key =~ /^(.*)_id$/;

        my $value = $task->$key;

        if(blessed($value)) {
            if($value->isa('DateTime')) {
                $value = "$value";  #Stringify
            } elsif($value->isa('BTDT::Model::User')) {
                $value = $value->formatted_email;
            } elsif($value->isa('BTDT::Model::Group')) {
                $value = $value->id ? $value->name : undef;
            }
            else  {
                next;
            }
        }

        $hash{$key} = $value;
    }

    $hash{record_locator} = $task->record_locator;

    return \%hash;
}



1;
