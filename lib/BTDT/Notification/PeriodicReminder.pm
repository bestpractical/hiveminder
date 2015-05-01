use warnings;
use strict;

package BTDT::Notification::PeriodicReminder;
use base qw/BTDT::Notification/;

=head1 NAME

BTDT::Notification::PeriodicalReminder

=head1 ARGUMENTS

C<to>, a L<BTDT::Model::User>.

=cut

=head1 METHODS

=head2 setup

Sets up the fields of the message.

=cut

sub setup {
    my $self = shift;
    $self->SUPER::setup(@_);

    unless (UNIVERSAL::isa($self->to, "BTDT::Model::User")) {
        $self->log->error((ref $self) . " called with invalid user argument");
        return;
    }

    my $user_time = Jifty::DateTime->now;
    $user_time->truncate(to => "day");

    # setting to GMT because we're doing date comparisons in the database, where
    # all dates are GMT
    $self->{MIDNIGHT} ||= $user_time->clone->set_time_zone('GMT');
    $self->{STARTING} ||= $self->starting($self->{MIDNIGHT});

    my ($period_text,   $period_html)   = ($self->period);
    my ($tasklist_text, $tasklist_html) = ($self->tasklist);

    my $tasks      = $tasklist_text . $period_text;
    my $tasks_html = $tasklist_html . $period_html;

    if ($tasks !~ /-----/) { # if there are no headings
        return undef;
    } else {
        $self->subject( "Hiveminder: What's new for " .$self->subject_period($user_time) );
    }

    $self->body($self->intro . $tasks . $self->outro);
    $self->html_body( $self->intro_html . $tasks_html . $self->outro_html );
}

=head2 intro

Returns the introductory text.

=cut

sub intro {

return <<EOM;
Good morning!  Here's your Hiveminder update:

EOM

}

=head2 intro_html

Returns the introductory HTML.

=cut

sub intro_html {
    my $self  = shift;
    my $intro = $self->intro;
    $intro =~ s{(Hiveminder)}{<a href="@{[Jifty->web->url(path=>'/')]}">$1</a>};
    #$intro =~ s{\n\n}{</p><p>}g;
    return qq{<p style="padding-bottom: 0;margin-bottom: 0;">$intro</p>};
}

=head2 tasklist

Returns the list of tasks that the current user owns, which are not
complete, as text and HTML formatted lists. It's broken up into one
section for unaccepted tasks and another for accepted tasks.

Returns ($text, $html).

=cut

sub tasklist {
    my $self = shift;

    my @searches = (
        [
            'Tasks other people want you to do (not yet accepted)',
            [qw(owner me not complete unaccepted starts before tomorrow
                but_first nothing)]
        ],
        [
            'Things you should be doing',
            [qw(owner me not complete accepted starts before tomorrow
                but_first nothing)]
        ],
        [
            'Tasks due this week',
            [qw(owner me not complete accepted due before), '7 days']
        ]
    );

    my (@output, @output_html);
    for my $search (@searches) {
        my $tasks = BTDT::Model::TaskCollection->new(
                        current_user => BTDT::CurrentUser->new( id => $self->to->id )
                    );
        $tasks->from_tokens( @{$search->[1]} );

        # Render text
        push @output, $self->_open_tasks(
            tasks => $tasks,
            title => $search->[0]
        );

        # Render HTML
        push @output_html, $self->_open_tasks(
            tasks => $tasks,
            title => $search->[0],
            html  => 1
        );
    }

    my $output      = join "", grep { defined and length } @output;
    my $output_html = join "\n", grep { defined and length } @output_html;

    # If we get nothing, set a message for both output types
    if ( not defined $output or not length $output ) {
        my $url = Jifty->web->url(path => '/braindump/');

        $output = <<"        END";
You have nothing you need to finish today. Either it's time for a well
deserved day off or you're not using Hiveminder to its fullest. Head
on over to $url and jot down some notes
about what needs doing.
        END

        $output_html = "<p>$output</p>";
        $output_html =~ s{\Q$url\E}{a <a href="$url">braindump</a>};
    }

    return ($output, $output_html);

}

sub _open_tasks {
    my $self = shift;
    my %args = (
        tasks  => undef,
        title  => undef,
        html   => 0,
        @_
    );

    return if not defined $args{'tasks'};

    my $output;
    while ( my $task = $args{'tasks'}->next ) {
        my $render  = '_render_task';
           $render .= '_html' if $args{'html'};
        $output .= $self->$render($task) . "\n";
    }

    if ($output) {
        my $title  = '_title';

        if ( $args{'html'} ) {
            $title .= '_html';
            $output = qq{ <div style="padding-left: 1.5em;">$output</div> };
        }
        $output = $self->$title( $args{'title'} ) . $output;
    }
    return $output;
}


=head2 outro

Returns the closing statement text.

=cut

sub outro {
    my $self = shift;
    return <<EOM;


 = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

If we missed something, update your list while you're thinking about it:
    @{[Jifty->web->url(path => '/braindump/')]}

Ready to check things off? Your todo list is only a click away:
    @{[Jifty->web->url(path => '/todo/')]}

EOM

}

=head2 outro_html

Returns the closing statement HTML.

=cut

sub outro_html {
    my $self = shift;
    return <<EOM;
<div style="margin-top: 2em; border-top: 1px solid #eee;">
<p>
If we missed something,
<a href="@{[Jifty->web->url(path => '/braindump/')]}">update your list
while you're thinking about it</a>.
</p>

<p>
Ready to check things off?
<a href="@{[Jifty->web->url(path => '/todo/')]}">Your todo list
is only a click away</a>.
</p>
</div>
EOM

}

sub _render_task {
    my $self  = shift;
    my $task  = shift;

    my $line2 = '';
    $line2 .= ( $task->due      ? "  Due: "   . $task->due->ymd    : '' );
    $line2 .= ( $task->group_id ? "  Group: " . $task->group->name : '' );

    my $tags = ( $task->tags ? " [" . $task->tags . "]" : '' );
    return " " . ($task->summary || '(Unnamed task)' ).$tags." # ".$task->url."\n"
        . ( $line2 ? $line2 . "\n" : '' );
}

sub _render_task_html {
    my $self = shift;
    my $task = shift;

    my $line2 = '';
    $line2 .= ( $task->due ? qq{<span style="color: #777; padding-left: 1.5em;"><small>Due: } . $task->due->ymd . "</small></span>" : '' );

    if ( $task->group_id ) {
        my $group = $task->group->name;
        my $url   = Jifty->web->url( path => '/groups/'.$task->group_id );
        $line2 .= qq{<span style="color: #777; padding-left: 1.5em;"><small>Group: <a href="$url">$group</a></small></span>};
    }

    my $tags = ( $task->tags ? qq{ <small>[} . $task->tags . "]</small>" : '' );

    return <<"    END";
<p style="margin: 0;padding: 1em 0 0 0;">
  <a href="@{[$task->url]}">@{[Jifty->web->escape( $task->summary || '(Unnamed task)' )]}</a>
  $tags
  @{[( $line2 ? "<br />" : "")]} $line2
</p>
    END
}


sub _title {
    my $self  = shift;
    my $title = shift;
    return ("\n" . $title."\n".('-' x length($title) )."\n\n");
}

sub _title_html {
    my $self  = shift;
    my $title = shift;
    return qq{<p style="margin: 0;padding: 1.5em 0 0 0;font-weight: bold;">$title</p>};
}

=head2 period

Returns text and HTML of what happened in this period to the user's tasks.

Returns ($text, $html).

=cut

sub period {
    my $self = shift;

    my @entries = (
        [ $self->_format_history(
            title => $self->youdid_title,
            actor => $self->current_user->id
        )],
        [ $self->_format_history(
            title     => $self->othersdid_title,
            requestor => $self->current_user->id
        )]
    );

    my $collection = BTDT::Model::GroupCollection->new();
    $collection->limit_contains_user( $self->current_user);
    $collection->order_by( column => 'name', order => 'asc' );

    while (my $group = $collection->next) {
        push @entries, [ $self->_format_history(
            title => $group->name,
            group => $group
        )];
    }

    return ( join("\n\n", map { $_->[0] } grep { $_->[0] } @entries),
             join("\n\n", map { $_->[1] } grep { $_->[1] } @entries)  );
}

=head2 youdid_title

Returns a short title for "What you did $this_period"

=cut

sub youdid_title { "What you did" }

=head2 othersdid_title

Returns a short title for "What other people did for you $this_period"

=cut

sub othersdid_title { "What other people did for you" }

sub _groups_period {
    my $self = shift;
    my $content = '';
    return $content;
}

sub _format_history {
    my $self = shift;
    my %args = ( title => undef,
                 group => undef,
                 actor => undef,
                 requestor => undef,
                 owner => undef,
                 @_ );

    my $txns_by_date = $self->_txns_period(%args);
    my $text = '';
    my $html = '';

    foreach my $task (values %{ $txns_by_date->{'tasks'} }){
        $text .= $self->_render_task($task);
        $html .= $self->_render_task_html($task);

        foreach my $txn ( sort { $a->modified_at->epoch <=> $b->modified_at->epoch }
                               @{$txns_by_date->{txns}->{$task->id}})
        {
            next unless $txn->summary;
            my $summary = sprintf("  %02d:%02d %s\n",
                                  $txn->modified_at->hour, $txn->modified_at->minute,
                                  $txn->summary );
            $text .= $summary;
            $html .= qq{<p style="margin: 0; padding: 0 0 0 1.5em;"><small>$summary</small></p>};

            my $changes = $txn->visible_changes;
            if ( $txn->type eq "update" and $changes->count > 1 ) {
                my @changes = grep { ref($_) && $_->as_string }
                                   @{ $changes->items_array_ref };

                $text .= join "\n", map  { "      * " . $_->as_string } @changes;
                $text .= "\n";

                $html .= qq{<ul style="margin: 0; padding: 0 0 0 4em; list-style-type: square;">\n};
                $html .= join "\n", map { qq{<li><small>}.$_->as_string."</small></li>\n" } @changes;
                $html .= qq{</ul>\n};
            }
        }
        $text .= "\n";
    }

    if ( $text ) {
        $text = $self->_title( $args{'title'} ) . $text;
        $html = $self->_title_html( $args{'title'} )
                . qq{ <div style="padding-left: 1.5em;">$html</div> };
        return ($text, $html);
    }
    return;
}


sub _txns_period {
    my $self = shift;
    my %args = ( group => undef, actor=> undef, requestor => undef, owner => undef,@_);

    my $txns = BTDT::Model::TaskTransactionCollection->new( current_user => $self->current_user );



    my ( $tasks_alias, $histories_alias ) = $txns->between(
        starting => $self->{STARTING},
        ending   => $self->{MIDNIGHT}
    );



    if (defined $args{'group'}) {
            $txns->limit(alias => $tasks_alias, column => 'group_id', value => $args{'group'});
    }

    if (defined $args{'owner'}) {
            $txns->limit(alias => $tasks_alias, column => 'owner_id', value => $args{'owner'});
            $txns->limit(alias => $tasks_alias, column => 'requestor_id', operator => '!=', value => $args{'owner'});
    }


    if (defined $args{'actor'}) {
            $txns->limit(column => 'created_by', value => $args{'actor'});
    }


    if (defined $args{'requestor'}) {
            $txns->limit(alias => $tasks_alias, column => 'requestor_id', value => $args{'requestor'});
            $txns->limit(column => 'created_by', operator => '!=', value => $args{'requestor'});
    }




    my $txnset = {};
    while ( my $txn = $txns->next ) {
        push @{ $txnset->{'txns'}->{ $txn->task_id } }, $txn;
        $txnset->{'tasks'}->{ $txn->task_id } = $txn->task;
    }
    return $txnset;
}

1;
