use warnings;
use strict;

=head1 NAME

BTDT::Sync::TextFile

=cut

package BTDT::Sync::TextFile;
use base qw/Jifty::Object Class::Accessor/;

use Date::Manip qw();
use Number::RecordLocator;
use BTDT::Sync;
use Time::ParseDate;

our $LOCATOR; # Defer load until later;

our $FORMAT_VERSION = "0.02";

=head2 new

Returns a new L<BTDT::Sync::TextFile> object.

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self;

}

=head2 as_text COLLECTION

Returns the given L<BTDT::Model::TaskCollection> I<COLLECTION>
formatted as a text string.

=cut

sub as_text {
    my $self = shift;
    my ($collection) = (@_);

    my $metadata = {};

    my $str = $self->intro_as_string();

    $str .= $self->body_as_string($collection, $metadata);

    $str .= $self->footer_as_string($metadata);

    return $str;
}

=head2 body_as_string

Returns the tasks portion of the textfile.

=cut

sub body_as_string {
    my $self = shift;
    my $collection = shift;
    my $metadata = shift;
    my @ids;
    my $str = '';
    while (my $t = $collection->next) {
        $str .= $t->summary;
        $str .= " [". $t->tags ."]" if $t->tags;

        $str .= " [due: ". $t->due->ymd ."]" if $t->due;
        $str .= " [group: ". $t->group->name ."]" if $t->group->id;
        $str .= " [priority: ". $t->text_priority ."]" if $t->priority != 3;

        $str .= " (". $t->record_locator . ")" if $t->record_locator;
        if ($t->description) {
            my $desc = $t->description;
            $desc =~ s/^/    /gm;
            $desc =~ s/\s*$//;
            $str .= "\n$desc";
        }
        $str .= "\n";
        push @ids, $t->id;
    }

    $metadata->{ids}    = [ @ids ];
    $metadata->{tokens} = [ $collection->tokens ] if $collection->tokens;
    $metadata->{format_version} = $FORMAT_VERSION;

    return $str;
}

=head2 footer_as_string

Returns the footer of the textfile, which includes the secret code for
reconstructing the tasklist.

=cut

sub footer_as_string {
    my $self = shift;
    my $metadata = shift;
    my $str = "---\n" .

    "The code below this line lets Hiveminder know which tasks are on this list.\n".
    "Be careful not to mess with it, or you might confuse the poor computer.\n\n"
    . MIME::Base64::encode_base64(Compress::Zlib::compress(Jifty::YAML::Dump($metadata)));

    return $str;
}

=head2 intro_as_string

Returns a summary of how textfile sync works.

=cut

sub intro_as_string {
    my $self = shift;
    my $str = <<INTRO;
Your todo list appears below.  If you want to make changes to any of
your existing tasks, just edit them below.  To add new tasks, just add
new lines; to mark tasks as done, just delete them.  Everything else
(priority, tags, and so on) works the same way it does in Braindump.
When you're finished editing the file, point your web browser at
@{[Jifty->web->url(path => '/upload')]} to synchronize any changes you've
made with Hiveminder.

---
INTRO
}

=head2 from_text TEXT

Takes the given text string I<TEXT> and processes any updates or
creates needed based on it.  Tasks that have no ID are created, and
tasks that do have IDs are updated.  Does not return anything.

=cut

sub from_text {
    my $self = shift;

    my $str = shift;
    my ( $header, $data, $tokenlegend, $meta );
    # in the download-upload cycle, LFs sometimes get turned to CRLFs. Be flexible.
    if ( $str =~ /^(.*?)---(.*)---(.*)\r?\n\r?\n(.*)$/s ) {
        ( $header, $data, $tokenlegend, $meta ) = ( $1, $2, $3, $4 );
    }
    else {    # if there's no header and footer, it's an import.
        $data = $str;
    }

    # Grab the metadata
    my %metadata = ('format_version'=> '0.0');
    if ($meta) {
        no warnings;

        %metadata = (%{Jifty::YAML::Load(Compress::Zlib::uncompress MIME::Base64::decode_base64($meta)) });

    }
    my $parsed_tasks =  [$self->parse_tasks( data => $data, format_version => $metadata{'format_version'}) ];
    my $ret = BTDT::Sync->sync_data( %metadata,
                                     tasks => $parsed_tasks);
    return { %metadata, %{ $ret }};
}

=head2 parse_tasks PARAMHASH

Possible arguments include:

=over

=item data

The string parse.  It is parsed as follows

   Summary of the task [I<tags>] (I<ticket id>)
      description of the task
      which may span multiple lines
   Another task

Tags and ticket IDs are optional.

=item ids

A boolean -- if the ticket IDs are parsed.  By default, they are, but
this may not be desired in cases when one is sure that none of the
tasks already exist.

=item format_version

The version of the text format to use. Defaults to '0.0', which contains task
IDs in each line. '0.01' substitutes record locators for IDs. '0.02' will look
more closely at the differences in attributes (upstream).

=back

=cut

sub parse_tasks {
    my $self = shift;

    my %args = (
                ids   => 1,
                data  => undef,
                @_
               );

    return map  { $self->parse_task(%args, task => $_) }
           grep { /\S/ }
           split /^(?=\S+)/m,
           $args{data};
}

my %regex;

# The first line is the summary
$regex{summary}     = qr/([^\r\n]+?)             \s*/x;

# The task's id or record locator (if any) is in parens
$regex{id_or_rl}    = qr/(?:\(([A-Za-z0-9]+)\))? \s*/x;

# indented but-first/and-then
$regex{dependency} = qr/
    ^ \s+
    (
        (?:but[-_ ]?)?first
      | (?:and[-_ ]?)?then
    )
    \s* :? \s*
    (.+?)
    \s* $
/ix;

=head2 parse_task ARGS

Parses the given task, which consists of a summary, its description, and any
dependency tasks.

Returns a lists of hashrefs, each a task to create.

=cut

sub parse_task {
    my $self = shift;
    my %args = @_;
    my %task;

    # summary and, if applicable, record locator
    if ( $args{ids} ) {
        $args{task} =~ s/^ $regex{summary} $regex{id_or_rl} $//xm;
        $task{summary} = $1;

        if ( $args{'format_version'} eq '0.0' ) {
            $task{id} = $2;
        }
        else { # that's a record locator
            $LOCATOR ||= Number::RecordLocator->new();
            if ( my $id = $LOCATOR->decode($2) || undef ) {
                $task{id} = $id;
            }
        }

    } else {
        $args{task} =~ s/^ $regex{summary} $//xm;
        $task{summary} = $1;
    }

    $self->expand_task_summary(\%task);
    $task{__dependency_id} = $self->next_dependency_id;

    # indented bits: description and dependencies
    my @dependencies = $self->parse_indented_chunk(\%task, $args{task});

    for my $t (\%task, @dependencies) {
        for (qw/summary description tags/) {
            $t->{$_} ||= '';
            $t->{$_} =~ s/^[ \t]+//gm;
            $t->{$_} =~ s/[ \t]+$//gm;
            1 while chomp $t->{$_};
        }
    }

    return (\%task, @dependencies);
}

=head2 parse_indented_chunk parent_task, chunk_text

This will go through the indented chunk and set up dependencies to later create
and add the lines of description to the parent task.

=cut

sub parse_indented_chunk {
    my $self = shift;
    my $task = shift;
    my $text = shift;
    my $description = '';
    my @dependencies;

    my %tasks_at_indentation = (
        0 => [$task],
    );

    # this will return the most indented task above this one, but not one that's
    # indented further than the (numeric) argument
    my $find_appropriate_task = sub {
        my $indentation = shift;
        my $best = 0;

        for my $try (keys %tasks_at_indentation) {
            $best = $try if $try < $indentation && $try > $best;
        }

        return $tasks_at_indentation{$best}[-1];
    };

    for (grep {/\S/} split /[\r\n]+/, $text) {
        my ($indentation) = map { length } /^(\s*)/;

        if ($_ =~ $regex{dependency}) {
            my $summary = $2;
            my $type = $1 =~ /then/i ? "then" : "first";

            my $dependency_on = $find_appropriate_task->($indentation);

            my ($id_field, $id_value);
            if ($summary =~ m{^\s*#(\w+)\s*$}) {
                ($id_field, $id_value) = ('id', $1);
            }
            else {
                ($id_field, $id_value) = ('summary', $summary);
            }

            my $task = {
                $id_field         => $id_value,
                __dependency_type => $type,
                __dependency_on   => $dependency_on->{__dependency_id},
                __dependency_id   => $self->next_dependency_id,
            };
            $self->expand_task_summary($task);

            push @{ $tasks_at_indentation{$indentation} }, $task;
            push @dependencies, $task;
        }
        else {
            my $task = $find_appropriate_task->($indentation);
            $task->{description} .= "$_\n";
        }
    }

    return @dependencies;
}

=head2 expand_task_summary task

This will look at the given task's summary and use parse_summary on it, to
populate the rest of the fields of the hash.

=cut

sub expand_task_summary {
    my $self = shift;
    my $task = shift;

    my $parsed_task = BTDT::Model::Task->parse_summary($task->{summary});
    $task->{summary} = delete $parsed_task->{explicit}{summary};
    foreach (keys %{$parsed_task->{explicit}}) {
        $task->{$_} ||= $parsed_task->{explicit}{$_};
    }
    foreach (keys %{$parsed_task->{implicit}}) {
        $task->{$_} ||= $parsed_task->{implicit}{$_};
    }
}

=head2 next_dependency_id

Returns a unique identifier (for this object) that is used to give tasks a
temporary later used for setting up dependencies.

=cut

sub next_dependency_id {
    my $self = shift;
    return ++$self->{_dependency_id};
}

1;
