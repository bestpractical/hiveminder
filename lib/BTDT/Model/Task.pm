use warnings;
use strict;

=head1 NAME

BTDT::Model::Task

=head1 DESCRIPTION

Describes a task that needs to be done.  This is a very generalized
concept; tasks have descriptions, can be completed, and can be owned
by both users and groups.

A task has a C<summary> and a C<description>, as well as an
C<owner_id>; a C<requestor_id>; and a C<next_action_by>, all of which are
L<BTDT::Model::User>s.  Additionally, tasks may (but are not required to)
belong to a L<BTDT::Model::Group>, C<group_id>.  Tasks may be marked as
C<complete>, and may have C<starts> or C<due> dates.

Each task also has a number of L<BTDT::Model::TaskTag>s associated
with it.  These are user-supplied labels on the task which are used to
searching and grouping.

=cut

package BTDT::Model::Task;

use BTDT::Model::TaskTagCollection;
use Text::Tags::Parser;
use BTDT::Model::User;
use BTDT::Model::Group;
use BTDT::DateTime;
use Data::ICal::Entry::Event;
use Data::ICal::Entry::Todo;
use DateTime::Duration;
use HTML::Scrubber;
use Jifty::DBI::Filter::Duration;
use Business::Hours;
use Scalar::Util qw(blessed);

our $TAGS_PARSER = Text::Tags::Parser->new;

use base qw( BTDT::Record );


use Jifty::DBI::Schema;
use Jifty::Record schema {
    column created => since '0.2.22',
        type is 'timestamp',
        filters are qw( Jifty::Filter::DateTime Jifty::DBI::Filter::DateTime),
        label is 'Created', is immutable, is protected,
        documentation is 'What time this task was created';

    column complete => is boolean, is mandatory,
        since '0.1.1', label is 'Done?',
        documentation is 'Is this task marked as complete?';

    column completed_at => type is 'timestamp',
        filters are qw( Jifty::Filter::DateTime Jifty::DBI::Filter::DateTime),
        is protected, label is 'Completed at',
        since '0.2.23',
        documentation is 'What time this task was completed, if applicable';

    column summary => type is 'varchar',
        label is 'Task',
        hints is '(Example: <i>Pick up milk at the store</i>)',
        documentation is 'The one-line description of the task';

    column description => type is 'text',
        default is '', render_as 'Textarea', label is 'Notes',
        documentation is 'An expanded description of the task';

    column group_id => refers_to BTDT::Model::Group,
        label is 'Group',
        documentation is 'The group the task is in';

    column owner_id => refers_to BTDT::Model::User,
        label is 'Owner',
        documentation is 'The person responsible for completing the task';

    column requestor_id => label is 'Requestor',
        refers_to BTDT::Model::User,
        documentation is 'The person who wants this task to be completed';

    column next_action_by => label is 'Next action by',
        refers_to BTDT::Model::User, since '0.2.76', is protected,
        documentation is 'The person who is working on the task next';

    column will_complete =>
        is boolean, is mandatory,
        default is 't',
        label is "Will complete?",
        since '0.2.87',
        documentation is 'Whether the owner intends to complete this task';

    column starts => type is 'date',
        filters are qw( Jifty::Filter::DateTime Jifty::DBI::Filter::Date),
        render_as 'Date', label is 'Hide until',
        documentation is 'When the task will appear in your todo list';

    column due => type is 'date',
        render_as 'Date',
        filters are qw( Jifty::Filter::DateTime Jifty::DBI::Filter::Date),
        label is 'Date due',
        documentation is 'The date by which the task must be completed';

    column accepted => is boolean, default is undef,
        label is 'Accepted?', since '0.2.5',
        documentation is 'Whether the owner has decided to do the task';

    column priority => type is 'integer',
        since '0.2.11', default is 3, label is 'Priority',
        valid_values are { display => 'highest', value => 5 },
        { display => 'high',   value => 4 },
        { display => 'normal', value => 3 }, { display => 'low', value => 2 },
        { display => 'lowest', value => 1 },
        documentation is 'How important the task is';

    column tags => since '0.2.18',
        type is 'varchar', default is '', label is 'Tags',
        documentation is 'Labels that help you find tasks';

    # The denormalization makes jesse cry, but the negative performance
    # implications make jesse cry even more
    # The fact that jifty doesn't have a generalized mechanism
    # for this makes jesse cry most of all

    column depends_on_count => type is 'integer',
        documentation is 'Number of incomplete tasks this task depends on',
        is immutable, default is '0', label is 'Depends on count',
        since '0.2.27', is protected;
    column depends_on_ids => type is 'text',
        documentation is 'Tab-separated IDs of the incomplete tasks this task depends on',
        default is '', is immutable, label is 'Depends on tasks',
        since '0.2.27', is protected;
    column depends_on_summaries => type is 'text',
        documentation is 'Tab-separated summaries of the incomplete tasks this task depends on',
        default is '', is immutable, label is 'Depends on summaries',
        since '0.2.27', is protected;
    column depended_on_by_count => type is 'integer',
        documentation is 'Number of incomplete tasks which depend on this task',
        default is '0', is immutable, label is 'Depended on by count',
        since '0.2.27', is protected;
    column depended_on_by_ids => type is 'text',
        documentation is 'Tab-separated IDs of the incomplete tasks which depend on this task',
        default is '', is immutable, label is 'Depended on by tasks',
        since '0.2.27', is protected;
    column depended_on_by_summaries => type is 'text',
        documentation is 'Tab-separated summaries of the incomplete tasks which depend on this task',
        default is '', is immutable, label is 'Depended on by summaries',
        since '0.2.27', is protected;

    column repeat_period => since '0.2.37',
        type is 'text', label is 'Schedule', default is 'once',
        valid_values are { display => 'once', value => 'once' },
        { display => 'daily',    value => 'days' },
        { display => 'weekly',   value => 'weeks' },
        { display => 'monthly',  value => 'months' },
        { display => 'annually', value => 'years' },
        documentation is 'Does this task repeat once, daily, weekly, monthly, or yearly?';

    column repeat_every => since '0.2.37',
        type is 'int', default is '1', label is 'Every how many?',
        # length is database length. we should have another keyword for form field size
        max_length is '4',
        documentation is 'How many days, weeks, months, or years between repeats (see also repeat_period)';

    column repeat_stacking => since '0.2.38',
        is boolean, is mandatory, label is 'Stack up repeats?',
        hints is
        q{Paying the rent stacks up if you skip it. Watering the plants doesn't.},
        documentation is "Do this task's repeats stack up?";

    # how many days before the task is due should we actually create it
    column repeat_days_before_due => since '0.2.35',
        type is 'int',                                label is 'Heads up',
        hints is 'How many days notice do you want?', max_length is '4',
        default is '1',
        documentation is 'How soon before the due date does this task show up?';

    column repeat_next_create => since '0.2.35',
        type is 'date', filters are 'Jifty::DBI::Filter::Date', render as 'Date', is protected;

    column last_repeat => since '0.2.35', refers_to BTDT::Model::Task, is protected;

    column repeat_of => since '0.2.35', refers_to BTDT::Model::Task, is protected;

    column attachments => references BTDT::Model::TaskAttachmentCollection by 'task_id',
        since '0.2.62';

    column attachment_count =>
        type is 'integer',
        is immutable,
        default is 0,
        since '0.2.88', is protected;

    column time_estimate =>
        type is 'integer',
        label is 'Initial estimate',
        filters are 'Jifty::DBI::Filter::Duration',
        since '0.2.90',
        is protected;

    column time_worked =>
        type is 'integer',
        label is 'Time worked',
        filters are 'Jifty::DBI::Filter::Duration',
        ajax canonicalizes,
        ajax validates,
        since '0.2.90';

    column time_left =>
        type is 'integer',
        label is 'Time left',
        filters are 'Jifty::DBI::Filter::Duration',
        ajax canonicalizes,
        ajax validates,
        since '0.2.90';

    column project =>
        label is 'Project',
        references BTDT::Project,
        render as 'Hidden',
        since '0.2.94';

    column milestone =>
        label is 'Milestone',
        references BTDT::Milestone,
        render as 'Hidden',
        since '0.2.94';

    column type =>
        documentation is 'What type of task is this?  Is it a normal task, a project, or a milestone?',
        type is 'text',
        is mandatory,
        default is 'task',
        valid_values are qw(task project milestone),
        render as 'Hidden',
        since '0.2.94';

    column last_modified =>
        type is 'timestamp',
        filters are qw( Jifty::Filter::DateTime Jifty::DBI::Filter::DateTime),
        label is 'Modified', is immutable, is protected,
        documentation is 'What time this task was last modified',
        since '0.2.99';

    column comment_address =>
        is computed,
        is immutable,
        type is 'text',
        documentation is 'Send email to this address to make a comment';
};

=head2 text_priority

Returns the priority as a string, not as a number.

=cut


our %PRIOMAP;
$PRIOMAP{$_->{value}} = $_->{display} for @{__PACKAGE__->column("priority")->valid_values};


sub text_priority {
    my $self = shift;
    my $number = shift || $self->priority || 3;
    return $PRIOMAP{$number};
}

=head2 rounded_duration SECONDS

Returns a concise, rounded duration.

=cut

sub rounded_duration {
    my $self    = shift;
    my $seconds = shift;

    my $extract = sub {
        my $unit  = shift;
        my $secs  = shift;
        $$unit    = int( $seconds / $secs );
        $seconds -= $$unit * $secs;
    };

    my ($h, $m, $s) = ( 0, 0, 0 );
    $extract->(\$h, 3600);
    $extract->(\$m, 60);
    $extract->(\$s, 1);

    # Round seconds to minutes
    if ( $s >= 30 ) {
        $m++;
        $s = 0;
    }

    my $rounded;
    $rounded .= $h . "h" if $h;
    $rounded .= $m . "m" if $m;
    $rounded .= $s . "s" if $s and not $rounded;

    return $rounded || '0m';
}

=head2 concise_duration DURATION/SECONDS

Returns a concise time duration (encodes & decodes using
L<Jifty::DBI::Filter::Duration>)

=cut

sub concise_duration {
    my $self  = shift;
    my $value = shift;

    my $filter = Jifty::DBI::Filter::Duration->new( value_ref => \$value );
    $filter->encode;
    $filter->decode;

    return $value;
}

=head2 time_left_seconds

Calculates the time left in seconds.

=head2 time_estimate_seconds

Calculates the time estimate in seconds.

=head2 time_worked_seconds

Calculates the time worked in seconds.

=cut

sub time_left_seconds     { $_[0]->duration_in_seconds( $_[0]->time_left     ) }
sub time_estimate_seconds { $_[0]->duration_in_seconds( $_[0]->time_estimate ) }
sub time_worked_seconds   { $_[0]->duration_in_seconds( $_[0]->time_worked   ) }

=head2 duration_in_seconds DURATION

Returns the duration as seconds (encodes using L<Jifty::DBI::Filter::Duration>)

=cut

sub duration_in_seconds {
    my $self  = shift;
    my $value = shift;

    my $filter = Jifty::DBI::Filter::Duration->new( value_ref => \$value );
    $filter->encode;

    return $value;
}

=head2 canonicalize_time_estimate VALUE

Though it's not writable, we still canonicalize time estimates in searches ..

=head2 canonicalize_time_worked VALUE

.. as well as time worked ..

=head2 canonicalize_time_left VALUE

.. and time left.

=cut

sub canonicalize_time_estimate { shift->_canonicalize_time(@_) }
sub canonicalize_time_worked   { shift->_canonicalize_time(@_) }
sub canonicalize_time_left     { shift->_canonicalize_time(@_) }

sub _canonicalize_time {
    my $self  = shift;
    my $value = shift;

    return if not defined $value or not length $value;

    # Assume bare numbers are hours.
    # XXX We may want to try to be smart with ranges of numbers
    $value .= ' hours' if $value =~ /^\d+$/;

    my ($concise) = eval { $self->concise_duration( $value ) };
    return $value if $@ or not defined $concise;

    return $concise;
}

=head2 validate_time_worked VALUE

Must be parseable as a duration.

=head2 validate_time_left VALUE

Must be parseable as a duration.

=head2 validate_time_estimate VALUE

Though it's not writable, we still validate time estimates in searches.

=cut

sub validate_time_estimate { shift->_validate_time(@_) }
sub validate_time_worked   { shift->_validate_time(@_) }
sub validate_time_left     { shift->_validate_time(@_) }

sub _validate_time {
    my $self  = shift;
    my $value = shift;

    return 1 if not defined $value or not length $value;

    my ($seconds) = eval { $self->duration_in_seconds( $value ) };

    return ( 0, "Unknown time" )
        if $@ or not defined $seconds;

    return 1;
}

=head2 validate_project

Ensure that we can look up the project for this group.

=head2 validate_milestone

Ensure that we can look up the milestone for this group.

=cut

sub validate_project   { shift->_validate_task_type('project',   @_) }
sub validate_milestone { shift->_validate_task_type('milestone', @_) }

sub _validate_task_type {
    my $self  = shift;
    my $type  = shift;
    my $value = shift;
    my %args  = %{ shift || {} };

    return 1 if not defined $value or not length $value;

    my $class  = 'BTDT::' . ucfirst $type;
    my $record = $class->new;
    $record->load( $value );

    return ( 0, "We can't find that $type." )
        if not $record->id;

    # Use the passed in group id if available, otherwise the current
    # group id, otherwise 0 ("personal", which should always fail).
    my $group = defined $args{'group_id'} ? $args{'group_id'} :
                  defined $self->group_id ? $self->group_id   :
                                                            0 ;

    # Same group?  We're good.  Otherwise, error.
    return $record->group_id == $group
               ? 1
               : ( 0, "That $type is not in the same group as your task." );
}

=head2 create

Sets the default original owner and requestor to be the user creating
the task, as well as dealing with tags (which are not a real column)

In addition to the columns for this sort of record, takes the following optional parameters

=over

=item requestor_email

=item owner_email

=item next_action_by_email

=item depends_on

The id of a task this task depends_on.

=item depended_on_by

The id of a task which depends_on this one.

TODO: Both of these should take arrays

=item __parse_summary

Whether you want the task to automatically figure out implicit/explicit fields.
Defaults to true.

=item parse

This string will be parsed for braindump syntax instead of the subject.
The subject will be passed along unmangled and uninterpreted.

=back

=cut

sub create {
    my $self = shift;
    my %args = (
        owner_id        => $self->current_user->id,
        requestor_id    => $self->current_user->id,
        next_action_by  => undef,
        complete        => 0,
        priority        => 3,
        depended_on_by  => undef,
        depends_on      => undef,
        email_content   => "",
        parse           => "",
        __parse_summary   => 1,
        @_
    );

    my $parsed_task;
    if (delete $args{__parse_summary}) {
        $parsed_task = $self->parse_summary($args{parse} || $args{summary});
        $parsed_task->{explicit}{summary} = $args{summary} if delete $args{parse};
    } else {
        $parsed_task =
        {
            explicit => {summary => $args{summary}},
            implicit => {},
        };
    }

    # after we magically pull data out of the summary, handle
    # the special cases. (stuff with default values, etc)
    $args{summary} = delete $parsed_task->{explicit}{summary};
    my $parsed_priority = $parsed_task->{explicit}{priority}||$parsed_task->{implicit}{priority};
    if ($parsed_priority && $args{priority} == 3) {
        $args{priority} = $parsed_priority;
        delete $parsed_task->{explicit}{priority};
        delete $parsed_task->{implicit}{priority};
    }
    if ($parsed_task->{explicit}{owner_id} && $args{owner_id} == $self->current_user->id) {
        $args{owner_id} = $parsed_task->{explicit}{owner_id};
    }
    foreach my $param (keys %{$parsed_task->{explicit}}) {
        $args{$param} ||= $parsed_task->{explicit}{$param};
    }
    foreach my $param (keys %{$parsed_task->{implicit}}) {
        $args{$param} ||= $parsed_task->{implicit}{$param};
    }

    if ( lc $args{'owner_id'} eq 'nobody' ) {
        $args{'owner_id'} = BTDT::CurrentUser->nobody->id;
    }

    # XXX TODO: this should move to a canonicalize_owner_id routine
    if ($args{'owner_id'} and $args{'owner_id'} =~ /\@/) {
        $args{'owner_email'} = $args{'owner_id'};
        delete $args{'owner_id'};
    }

    # set the default next_action_by to the owner
    if (!$args{next_action_by}
     && !$args{next_action_by_email}) {
            if ($args{owner_email}) {
                $args{next_action_by_email} = $args{owner_email};
                delete $args{next_action_by};
            }
            else {
                my $owner = ref $args{owner} ? $args{owner}->id : $args{owner};
                $owner = $args{owner_id} if !defined $owner;
                $args{next_action_by} = $owner;
            }
    }

    # if we're trying to do owner or requestor by email address,
    # convert them.
    foreach my $type (qw(requestor owner)) {
        if ( $args{ $type . '_email' } ) {
            my $user = BTDT::Model::User->new( current_user => BTDT::CurrentUser->superuser );
            $user->load_or_create( email => $args{ $type . '_email' } );
            $args{ $type . "_id" } = $user->id;
            delete $args{ $type . "_email" };
        } elsif ($args{$type}) {
            $args{ $type . "_id" } = $args{$type}->id;
            delete $args{ $type };

        }
    }

    # if we're trying to do next_action_by by email address,
    # convert them. can't be done above because of differences.
    if ($args{next_action_by_email}) {
        my $user = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
        $user->load_or_create(email => delete $args{next_action_by_email});
        $args{next_action_by} = $user->id;
    }

    if (ref($args{'group'})) {
        $args{'group_id'} = $args{'group'}->id;
        delete $args{'group'};
    } elsif ($args{'group'}) {
        $args{'group_id'} = delete $args{'group'};
    }

    $args{'group_id'} = $self->canonicalize_group_id($args{'group_id'});
    if (not $args{'group_id'}) {
        delete $args{'group_id'};
    }

    # tasks outside of groups should always have owners
    if (not $args{'group_id'} and not $args{'owner_id'}) {
        $args{'owner_id'} = $self->current_user->id;
    }

    if (    $args{'owner_id'} != $self->current_user->id
        and $args{'requestor_id'} != $self->current_user->id
        and  not $self->current_user->is_superuser
        and $self->current_user->user_object->__value('access_level') ne 'administrator'
        )
    {
        die
            "$args{'owner_id'} != @{[$self->current_user->id]} and $args{'requestor_id'} != @{[$self->current_user->id]}";
        return ( undef, "Current user must be requestor or owner" );
    }

    # don't let personal tasks be owned by nobody, give them to the requestor
    if ($args{'owner_id'} == BTDT::CurrentUser->nobody->id
     && !exists($args{'group_id'})) {
        $args{'owner_id'} = $args{'requestor_id'};
    }

    $args{'accepted'} = $self->new_accepted_value( owner_id => $args{owner_id}, current_user => $args{requestor_id} )
      unless exists $args{accepted} and $self->current_user->is_superuser;

    # XXX TODO: DBIx-SB or Jifty::DBI should deal with 'REFERENCES'
    # columns (foreign keys) like this automatically during create
    my $tags = delete $args{tags};

    my $depends_on = delete $args{'depends_on'};
    my $depended_on_by = delete $args{'depended_on_by'};
    $args{created} = Jifty::DateTime->now;
    $args{completed_at} = $args{complete} ? Jifty::DateTime->now : undef;

    # If we don't have a time_estimate (which we shouldn't since we don't
    # expose it on create), then set it from time_left.  Leave time_left
    # intact since it actually does reflect the time left at this point
    $args{'time_estimate'} = $args{'time_left'};

    # For purposes of features, if the current user is the superuser
    # (like from the mail gateway), then look at the requestor.
    my $features_from = $self->current_user->is_superuser ?
        BTDT::CurrentUser->new( id => $args{requestor_id} ) : $self->current_user;

    # Kill time tracking fields if the user doesn't have time tracking
    delete @args{qw/time_estimate time_worked time_left/}
        unless $features_from->has_feature('TimeTracking');

    my $email_content = delete $args{email_content};
    if ($email_content and (not defined $args{description} or not length $args{description})) {
        my $mime = Email::MIME->new($email_content);
        $args{description} = BTDT::Model::TaskEmail->extract_body($mime);
        $args{description} = "" unless defined $args{description};
    }
    Encode::_utf8_on($args{description});
    # Set up the email
    unless ($email_content) {
        my $req = BTDT::Model::User->new;
        $req->load($args{requestor_id});
        $email_content = Email::Simple->create(
            header => [ From => Encode::encode('MIME-Header',$req->formatted_email) ],
            body   => $args{description},
        )->as_string;
    }

    # Only users who have project management can make project
    # and milestone tasks
    my $group = BTDT::Model::Group->new;
    $group->load($args{'group_id'}) if $args{'group_id'};
    unless ( $group->has_feature('Projects') ) {
        $args{'type'}      = 'task';
        $args{'project'}   = undef;
        $args{'milestone'} = undef;
    }

    my ( $id, $msg ) = $self->SUPER::create(%args);
    if ($id) {
        my @for;
        if ( $self->current_user->is_superuser ) {

            # If this task is being created by the superuser, then the
            # create transaction should be done by the requestor
            @for = ( created_by => $self->requestor );
        }
        $self->start_transaction( "create", @for );
        $self->add_dependency_on($depends_on)      if ($depends_on);
        $self->add_depended_on_by($depended_on_by) if ($depended_on_by);
        $self->set_tags($tags);
        $self->set_repeat_of($self->id) unless $args{'repeat_of'};
        $self->set_last_repeat($self->id);

        # Fix the txn's metaproperties for aggregation
        my $txn = $self->current_transaction;
        $txn->set_owner_id($self->owner->id);
        $txn->set_group_id($self->group->id);
        $txn->set_project($self->project->id);
        $txn->set_milestone($self->milestone->id);
        $txn->set_time_left($self->time_left_seconds) if defined $self->time_left;
        $txn->set_time_worked($self->time_worked_seconds) if defined $self->time_worked;
        $txn->set_time_estimate($self->time_estimate_seconds) if defined $self->time_estimate;

        # If this has a milestone, we need to add a milestone txn
        if ($self->milestone->id) {
            my $milestone = BTDT::Model::TaskTransaction->new;
            my %props;
            $props{$_} = $txn->$_ for qw/task_id created_by time_estimate time_worked time_left project milestone group_id owner_id/;
            $milestone->create(
                %props,
                type => "milestone",
            );
        }

        my $taskemail = BTDT::Model::TaskEmail->new();
        $taskemail->create(
            message        => $email_content,
            task_id        => $self->id,
            transaction_id => $txn->id,
            sender_id      => $txn->created_by->id,
        );

        # Projects and milestones are always their own projects and milestones.
        # This facilitates searching.
        if ( $self->type =~ /^(?:project|milestone)$/ ) {
            $self->__set( column => $self->type, value => $self->id );
        }

        $self->set_repeat_next_create if ($self->repeat_period ne 'once' && $self->_value('repeat_of') == $self->id);

        $self->end_transaction();
    }

    return ( $id, $msg );
}

=head2 update_from_braindump

This takes a braindump-style string and updates the current task with each of
its fields, except summary.

=cut

sub update_from_braindump {
    my $self = shift;
    my $str = shift;

    my $parsed = $self->parse_summary($str);
    $self->start_transaction;
    for my $type (qw/implicit explicit/) {
        for my $key (keys %{$parsed->{$type}}) {
            next if $key eq "summary";

            if ($key eq "tags") {
                $self->set_tags( $self->tags . " " . $parsed->{$type}{$key} );
            } else {
                my $update = "set_" . $key;
                $self->$update( $parsed->{$type}{$key} )
            }
        }
    }
    $self->end_transaction;
}

=head2 parse_summary

Takes the summary line from a task and parses it for magic syntax originally
used for Braindump.

returns a hashref containing two hashrefs.

 {explicit => {field => value, field => value},
  implicit => {field => value, field => value}}

The explicit hashref are things the user requested by saying [due: friday]
or [tag1] etc.
The implicit hashref contains fields we "guessed" from the user, such
as "!!" meaning "highest priority" and "for friday" meaning "set the due
date to Friday"

Clobbering data should depend on which set (explicit or implicit) we pulled
the data from.

=cut

sub parse_summary {
    my $self = shift;
    my $summary = shift;

    return { implicit => {}, explicit => {} } if !$summary;

    # we find some things because the user said [due: friday].
    # In that case, the calling routines can consider clobbering other data.
    # However, if we guessed that they want a task due friday because
    # they said "Task for friday" we should let other routines know
    # that we're guessing by returning it in the implicit list
    my %explicit;
    my %implicit;

    my $summary_syntax_regex = qr{
      \[\s*
        (group                            # many magic syntax bits
         |(?:starts|hide\ until|hide)     # captured and called '$key' below
         |due
         |(?:owner|by)
         |(?:priority|prio)
         |(?:every|repeat|repeats)
         |(?:estimate|time)
         |(?:worked|spent)
         |(?:completed?|done)
         |(?:(?:but[-_ ]?)?first|(?:and[-_ ]?)?then)
         |(?:project|milestone)
        )
       (?:\:|\s)                          # require a colon or space so we don't
       \s*                                # eat the tag "priority"
       ([^\]]+?)                          # value from the user, don't parse "[due ] [duefriday]"
      \]
    }xi;

    my @syntax_pairs = ( $summary =~ m/$summary_syntax_regex/g );

    # handle renaming of synonyms and key normalization
    my %key_map = (
        hide         => 'starts',
        'hide until' => 'starts',
        by           => 'owner',
        prio         => 'priority',
        repeat       => 'every',
        repeats      => 'every',
        time         => 'estimate',
        spent        => 'worked',
        then         => 'depended_on_by',
        first        => 'depends_on',
        'and then'   => 'depended_on_by',
        'but first'  => 'depends_on',
        completed    => 'complete',
        done         => 'complete',
    );

    for ( my $i = 0; my $key = $syntax_pairs[$i]; $i += 2 ) {
        $syntax_pairs[$i] = $key_map{lc $key} || lc $key; # clobber mixed case inputs
    }

    my $locator = Number::RecordLocator->new;

    my %syntax_found = @syntax_pairs;
    foreach my $key ( keys %syntax_found ) {
        if ( $key eq 'starts' || $key eq 'due' || $key eq 'every' || $key eq 'complete') {
            $explicit{$key} = $syntax_found{$key};
        } elsif ( $key eq 'group' ) {
            $explicit{group_id} = BTDT::Model::Task->canonicalize_group_id($syntax_found{$key});
        } elsif ( $key eq 'owner' ) {
            $explicit{owner_id} = BTDT::Model::Task->canonicalize_owner_id($syntax_found{$key});
        } elsif ( $key eq 'priority' ) {
            $explicit{'priority'} = BTDT::Model::Task->canonicalize_priority($syntax_found{$key});
        } elsif ( $key eq 'estimate' ) {
            $explicit{'time_left'} = $syntax_found{$key};
        } elsif ( $key eq 'worked' ) {
            $explicit{'time_worked'}   = $syntax_found{$key};
        } elsif ( $key eq 'depends_on' || $key eq 'depended_on_by' ) {
            $explicit{$key} = $locator->decode($1)
                if $syntax_found{$key} =~ /^#([a-zA-Z0-9]+)$/;
        } elsif ( $key eq 'project' or $key eq 'milestone' ) {
            my $value = $syntax_found{$key};
            $value =~ s/(?:^\s+|\s+$)//g;

            # If it looks like a locator, decode it, otherwise leave it
            # for us to try and parse as a project/milestone name later
            $explicit{$key} = $value =~ s/^#//
                                ? $locator->decode( $value )
                                : $value;
        }
    }

    $summary =~ s/$summary_syntax_regex\s*//g;


    my $tag_regex = qr{\[(.*?)\]};
    if (my @tags = ($summary =~ /$tag_regex/g)) {
        $explicit{tags} = join(" ",@tags);
        $summary =~ s/$tag_regex\s*//g;
    }

    if    ( $summary =~ s/^\+\+// ) { $implicit{priority} = 5; }
    elsif ( $summary =~ s/^\+// )   { $implicit{priority} = 4; }
    elsif ( $summary =~ s/^--// )   { $implicit{priority} = 1; }
    elsif ( $summary =~ s/^-// )    { $implicit{priority} = 2; }

    if ( $summary =~ /!!/ ) { $implicit{priority} = 5; }
    elsif ( $summary =~ /!/ )  { $implicit{priority} = 4; }

    # Handle "Project: foo" and "Milestone: bar" syntax
    if    ( $summary =~ s/^Project:\s*//i   ) { $implicit{'type'} = 'project';   }
    elsif ( $summary =~ s/^Milestone:\s*//i ) { $implicit{'type'} = 'milestone'; }

    # Try to convert text project/milestones into IDs
    for my $type (qw( project milestone )) {
        if ( $explicit{$type} and not $explicit{$type} =~ /^\d+$/ ) {
            my $record = BTDT::TaskType->new_type( $type );

            my %cols = ( summary => $explicit{$type} );
            $cols{'group_id'} = $explicit{'group_id'}
                if $explicit{'group_id'};

            $record->load_by_cols( %cols );

            if ( $record->id ) {
                # Set the type ID and set the implicit group so that it'll
                # kick in if we didn't explicitly specify a group
                $explicit{$type}      = $record->id;
                $implicit{'group_id'} = $record->group_id;
            }
            else {
                $explicit{$type} = undef;
            }
        }
    }

    # Due date
    if ($explicit{due}) {
        my $due = BTDT::DateTime->intuit_date_explicit(delete $explicit{due});
        $explicit{due} = $due->ymd if $due;
    }
    else {
        my $due = BTDT::DateTime->intuit_date($summary);
        $implicit{due} = $due->ymd if $due;

        # don't "guess" a date in the past
        if ($implicit{due}) {
            my $today = BTDT::DateTime->today;
            delete $implicit{due} if $due < $today;
        }
    }

    if ($explicit{starts}) {
        if ($explicit{starts} eq 'forever' || $explicit{starts} eq 'never') {
            $explicit{will_complete} = 0;
            delete $explicit{starts};
        }
        else {
            my $starts = BTDT::DateTime->intuit_date_explicit(delete $explicit{starts});
            $explicit{starts} = $starts->ymd if $starts;
        }
    }

    if ($explicit{complete}) {
        # weird case, [done: ] should mean not complete
        $explicit{complete} = 0 if $explicit{complete} =~ /^\s+$/;

        # canonicalize value to 1 or 0 so Jifty::DBI is happy
        $explicit{complete} = $explicit{complete} ? 1 : 0;
    }

    if (my $every = delete $explicit{every}) {
        if ($every =~ m{
                ^ \s*

                # an optional number of periods
                (?:(\d+)\s+)?

                # the period length
                ( days?   | daily
                | weeks?  | weekly
                | months? | monthly
                | years?  | yearly | annually
                )

                \s* $
        }x) {
            $explicit{repeat_every}  = $1 || 1;

            my $period = $2;

            # if someone says [repeat every day] don't penalize them
            $period =~ s/^every\s*//gi;

            # [repeat every other week] should work as well :)
            if ($period =~ s/\s*other\s*//) {
                $implicit{repeat_every} = 2;
            }

               if ($period =~ /^da/)           { $period = 'days'   }
            elsif ($period =~ /^week/)         { $period = 'weeks'  }
            elsif ($period =~ /^month/)        { $period = 'months' }
            elsif ($period =~ /^year|^annual/) { $period = 'years'  }
            else { $self->log->error("Unexpected period: $period") }

            $explicit{repeat_period} = $period;
        }
    }

    $explicit{summary} = $summary;
    foreach my $attr (qw(summary tags)) {
        next unless $explicit{$attr};
        $explicit{$attr} =~ s/^\s*//gm;
        $explicit{$attr} =~ s/\s*$//;
        $explicit{$attr} =~ s/\s+/ /g;
    }

    return {implicit=>\%implicit,explicit=>\%explicit};

}

=head2 set_owner_id OWNER

Sets the task's owner to OWNER.

Owner can be an email address, an id or a L<BTDT::Model::User> object.

But the important thing is that after the fact, if
the task's owner isn't the current user, turn the accepted flag off and update
next_action_by.

=cut

sub set_owner_id {

    my $self = shift;
    my $val  = shift;

    if ( UNIVERSAL::isa( $val, 'BTDT::Model::User' ) ) {
        $val = $val->id;
    }
    elsif ( $val =~ /@/ ) {
        my $user = BTDT::Model::User->new( );
        $user->load_by_cols( email => $val );
        $val = $user->id;
    }

    my $old_owner  = $self->owner->id;
    my $inside_txn = $self->current_transaction;

    if ( not $inside_txn ) { $self->start_transaction }

    my @owner     = $self->_set(column =>'owner_id', value => $val);
    my $new_owner = $self->owner->id;

    if ( $new_owner != $old_owner ) {
        if ( $self->new_accepted_value( owner_id => $new_owner ) ) {
            $self->as_superuser->_set( column => 'accepted', value => 1 );
        }
        else {
            $self->as_superuser->_set( column => 'accepted', value => undef );
            $self->as_superuser->_set( column => 'next_action_by', value => $new_owner );
        }

        # If it's a new owner, assume they will complete it until they say otherwise
        $self->as_superuser->_set( column => 'will_complete', value => 1 );
    }
    if ( not $inside_txn ) { $self->end_transaction }

    return (@owner);
}

=head2 canonicalize_priority

Canonicalizes the priority; strings such as "highest", "higher",
"high", "normal", "low", "lower" and "lowest" are transformed into
their numeric equivilents (5, 4, 4, 3, 2, 2, and 1, respectively).
Additionally, numeric inputs are limited to the range 1..5; anything
else defaults to 3.

=cut

sub canonicalize_priority {
    my $self = shift;
    return unless @_;
    my $priority = lc shift;
    my %map = ( reverse(%PRIOMAP), higher => 4, lower => 2 );
    $priority = $map{$priority} if exists $map{$priority};
    $priority = 3 if $priority =~ /(\D)/ or not defined $priority or $priority eq "";
    $priority = 5 if $priority > 5;
    $priority = 1 if $priority < 1;
    return $priority;
}

=head2 canonicalize_owner_id

Takes a current value for the C<owner> field and returns the canonicalized
version.

The special value of "me" is replaced by the current user's email address.

=cut

sub canonicalize_owner_id {
    my $self  = shift;
    my $value = shift;

    return if not defined $value;

    if ( lc $value eq 'me' ) {
        my $cu = blessed $self ? $self->current_user : Jifty->web->current_user;
        return $cu->user_object->email
    }
    return $value;
}

=head2 canonicalize_group_id

Converts group names to IDs

=cut

sub canonicalize_group_id {
    my $self = shift;
    my $value = shift;

    return undef unless defined $value;

    #``Looks like a number''. Possibly should be improved
    return $value if $value =~ /^\d+$/;

    return undef if $value eq '' || lc $value eq 'personal';

    my $group = BTDT::Model::Group->new;
    $group->load_by_cols(name => $value);
    return $group->id if $group->id;

    # If we don't find a group, wipe out the old value;
    return undef;
}

=head2 canonicalize_starts

Runs the date through BTDT::DateTime->intuit_date_explicit

=head2 canonicalize_due

Runs the date through BTDT::DateTime->intuit_date_explicit

=cut

sub canonicalize_due {
    my $self = shift;
    my $value = shift;

    # anytime is valid for searching
    return $value if $value eq "anytime";

    my $due = BTDT::DateTime->intuit_date_explicit($value);

    return undef if !$due;
    return $due->ymd;
}

*canonicalize_starts = \&canonicalize_due;

=head2 autocomplete_owner_id

Takes a current value for the C<owner> field.  Returns an array of hashes,
each of which contains a C<label> and a C<value>.  The array is ordered
from most likely to least likely.  Uses the C<people_known> method.

=cut

sub autocomplete_owner_id {
    my $self          = shift;
    my $current_value = shift;
    my %args          = @_;
    my @results;

    return if not $self->current_user->id;

    my $user = $self->current_user->user_object;
    my @people;

    # If it's an empty field in group context, show just the group members
    if ( $current_value eq '' and $args{'group_id'} ) {
        my $group = BTDT::Model::Group->new;
        $group->load( $args{'group_id'} );

        if ( $group->id ) {
            my $members = $group->members;
            @people = @$members if $members->count;
        }
    }

    @people = ( $user, $user->people_known ) unless @people;

    for my $person ( @people ) {
        push @results, {
            value => $person->email,
            label => $person->name,
        }
            if    $person->name  =~ /^\Q$current_value\E/i
               or $person->email =~ /^\Q$current_value\E/i
               or (     $person->id == $user->id
                    and lc $current_value =~ /^(?:me?)?$/ );
    }

    push @results, {
        value => BTDT::CurrentUser->nobody->user_object->email,
        label => "Nobody",
    }
        if     ( $args{'group_id'} or not $self->can('group') or $self->group->id )
           and lc $current_value =~ /^(?:n(?:o(?:b(?:o(?:d(?:y)?)?)?)?)?)?$/i;
        # The above regex matches '', 'n', 'no', ..., 'nobody'

    # If there's only one result, and it already matches entirely, don't
    # bother showing it
    return if @results == 1 and $results[0]->{value} eq $current_value;
    return @results;
}


=head2 autocomplete_tags

Takes a current value for the C<tags> field. Returns an array of hashes, each of which
contains a C<label> and a C<value>. The array is ordered from most likely to least likely.

=cut

sub autocomplete_tags {
    my $self          = shift;
    my $current_value = shift;
    my %args          = @_;

    return if not $self->current_user->id;

    return if $current_value eq '';

    my @tags       = $TAGS_PARSER->parse_tags($current_value);
    my $lookup_tag = pop @tags;                             #get the last item
    return unless ($lookup_tag);

    # lookup possible alternative values

    # We need to do this as a superuser as the records we get back aren't really rows 
    # that acl checks can get run against and we're already limiting the query to
    # only rows we know the current user can see.
    my $tags = BTDT::Model::TaskTagCollection->new(
        current_user => BTDT::CurrentUser->superuser,
        acl => 0,
    );
    $tags->limit(
        column           => 'tag',
        operator         => 'like',
        value            => $lookup_tag . "%",
        case_insensitive => 1
    );
    my $tasks = $tags->new_alias('tasks');
    $tags->join(
        alias1  => 'main',
        column1 => 'task_id',
        alias2  => $tasks,
        column2 => 'id',
        is_distinct => 1
    );
    for (qw(owner_id requestor_id)) {
        $tags->limit(
            alias            => $tasks,
            subclause        => 'my_tasks',
            column           => $_,
            value            => $self->current_user->user_object->id,
            entry_aggregator => 'or'
        );
    }
    if ($args{group_id}) {
        $tags->limit(
            alias            => $tasks,
            subclause        => 'my_tasks',
            column           => 'group_id',
            value            => $args{group_id},
            entry_aggregator => 'or'
        );
    }

    $tags->group_by({ column => 'tag'});
    $tags->order_by( function => 'COUNT(main.tag)', order => 'desc' );
    $tags->column(table => 'main', column => 'tag',);
    $tags->column(table => 'main', column => 'tag',function => 'COUNT');

    my %completions;
    my %display;
    for my $result (@{ $tags->items_array_ref }) {
        my $tag = $result->{values}->{'col0'};
        $completions{ lc $tag}=$result->{values}->{'col1'};
        if(!$display{lc $tag} || $tag =~ /^\Q$lookup_tag\E/) {
            $display{lc $tag} = $tag;
        }
    }

    my @results;

    # most common ones first


    foreach my $item ( sort { $completions{$b} <=> $completions{$a} }
        keys %completions )
    {
        push @results,
            {
                value => $TAGS_PARSER->join_tags( @tags, $display{$item} ),
                label => $display{$item}
            };
    }

    return if @results == 1 && lc $results[0]->{label} eq lc $lookup_tag;
    return @results;

}

=head2 set_tags STRING

Set task tags to the tags in "STRING"

=cut

sub set_tags {
    my $self   = shift;
    my $string = shift;

    my @current_tags = $self->tag_collection->as_list;
    my @new_tags     = $self->tag_collection->tags_from_string($string);

    # @new_tags and @current_tags should only have one copy of any given tag.
    my %changeset;
    $changeset{$_}++ for @current_tags;
    $changeset{$_}-- for @new_tags;


    # There's only a change if there are non-zero values
    my $tags_string = $TAGS_PARSER->join_quoted_tags(sort @new_tags);
    return (1, "Tags updated") # maybe we should say "Tags unchanged"
        if defined $string and not grep {$_ != 0} values %changeset;

    # Set the string value
    my ($ok, $msg) = $self->_set( column => 'tags', value => $tags_string);
    return ($ok, $msg) unless $ok;

    # This leaves a value of 1 for things that were deleted and a key of -1 for
    # this that were added.
    for my $tag ( keys %changeset ) {
        my $tag_obj = BTDT::Model::TaskTag->new();
        if ( $changeset{$tag} == 1 ) {
            $tag_obj->load_by_cols( tag => $tag, task_id => $self->id );
            next unless ( $tag_obj->id );
            $tag_obj->delete;
        }
        elsif ( $changeset{$tag} == -1 ) {
            my ($id) = $tag_obj->create( tag => $tag, task_id => $self->id );
        }
        elsif ( $changeset{$tag} != 0 ) {

            # Shouldn't happen.
            $self->log->warn(
                " tag $tag has weird imbalance; tags string $tags_string ",
                " current tags: ",
                { filter => \&Jifty::YAML::Dump, value => \@current_tags }
            );
            return (0, "Task tags contain duplicates");
        }

        # == 0 means no change.
    }

    if ($self->_value('tags') ne $self->tag_collection->as_quoted_string) {
        $self->log->warn("task " . $self->id . " has difference between cached and collection tags:",
                         { filter => \&Jifty::YAML::Dump,
                           value => {cached => $self->_value('tags'),
                                     collection => $self->tag_collection->as_quoted_string}}
                        );
        return (0, "Task tags are confused");
    }

    return (1, "Tags updated") if grep {$_ != 0} values %changeset;
}

=head2 tags

Returns the stringification of the tags on the task.

=cut

sub tags {
    my $self = shift;
    return $TAGS_PARSER->join_tags( $self->tag_array)
}

=head2 tag_array

Returns an alphabetically sorted array of the tags on the task

=cut

sub tag_array {
    my $self = shift;
    my $tags = $self->_value('tags');
    # In case people try to use tag_array in scalar context, assign to
    # a temporary array before returning. ("In scalar context, the
    # behaviour of 'sort()' is undefined." -perldoc)
    my @tags = sort $TAGS_PARSER->parse_tags( $tags || '' );
    return @tags;
}


=head2 tag_collection

Returns the L<BTDT::Model::TaskTagCollection> for the tags of this
task.

=cut

sub tag_collection {
    my $self = shift;
    my $tags = BTDT::Model::TaskTagCollection->new( acl => 0 );
    $tags->limit(column => 'task_id', value => $self->id);
    $tags->results_are_readable(1) if $self->current_user_can( 'read' );
    return $tags;
}

=head2 tagged STRING[, STRING[, ...]]

Returns true if the task is tagged with each specified tag.
Otherwise, returns false.

=cut

sub tagged {
    my $self  = shift;
    my $found = 0;

    for (@_) {
        for my $parsed ( $TAGS_PARSER->parse_tags($_) ) {
            my $tag = $TAGS_PARSER->join_quoted_tags($parsed);
            $found++ if $self->_value('tags') =~ /\Q$tag\E/;
        }
    }
    return $found == @_;
}

=head2 url

Return this task's URL.

=cut

sub url {
    my $self = shift;
    my $url =  Jifty->web->url(path =>  '/task/'.$self->record_locator);
    $url =~ s#^http(s?)://hiveminder\.com/task/#http://task.hm/#;
    return $url;
}

=head2 set_complete BOOLEAN, [TIME]

Sets the task's completeness; this additionally sets the
C<completed_at> column. The optional time argument lets you control
when the task has been completed (defaults to "right now")

=cut

sub set_complete {
    my $self = shift;
    my $value = shift;
    my $at = shift;

    $at = Jifty::DateTime->now if !defined($at);
    $at = undef if !$value;

    my ($cat, $cmsg) = $self->_set(column => 'completed_at', value => $at);
    return unless $cat;

    my ($ok, $msg) = $self->_set( column => 'complete', value => $value);
    return unless $ok;

    $self->_update_dependency_tree;


    # things that repeat by calendar have the repeat date set on create or due date changes
    # things that repeat on completion have the repeat date set on completion
    return ($ok, $msg);
}

=head2 after_set_will_complete

Update the dependency tree when this field is changed

=cut

sub after_set_will_complete {
    my $self = shift;
    $self->_update_dependency_tree;
}

=head2 after_set_time_left

Set time_estimate to the same value as time_left + time_worked if
time_estimate has no value, or if we have no time worked.
time_estimate is not adjusted if we are in a milestone, however.

=cut

sub after_set_time_left {
    my $self = shift;
    my $args = shift;

    # Estimate is pulled from left + worked iff:
    #  * We haven't moved into a milestone yet.
    #  AND
    #    * We have no time worked
    #    OR
    #    * We have no time estimate yet

    return if $self->milestone->id;

    if ( ($self->time_worked_seconds   || 0) == 0 or
         ($self->time_estimate_seconds || 0) == 0) {
        $self->set_time_estimate( $args->{value} . " " . ($self->time_worked_seconds || 0) . " seconds" );
    }
}

=head2 before_delete

Delete all the records that refer to this task

=cut

sub before_delete {
    my $self = shift;

    for my $model (qw( Transaction Email Attachment History Tag Dependency )) {
        my $class   = "BTDT::Model::Task${model}Collection";
        my $records = $class->new;
        $records->limit( column => 'task_id', value => $self->id );
        while ( my $record = $records->next ) { $record->delete }
    }

    # Also kill other dependencies
    my $records = BTDT::Model::TaskDependencyCollection->new;
    $records->limit( column => 'depends_on', value => $self->id );
    while ( my $record = $records->next ) { $record->delete }

    return 1;
}

=head2 after_delete

After delete, make sure we get removed from the dependency caches of
anyone who depends on us or is depended on by us

=cut

sub after_delete {
    my $self = shift;
    $self->_update_dependency_tree;
    # XXX TODO, reset repeat dates?
    return 1;
}

=head2 new_accepted_value PARAMHASH

Compute and return the new value for C<accepted>; C<PARAMHASH> is
examined for C<owner_id> and C<current_user>, which default to the
task's owner, and the current user respectively.

=cut

sub new_accepted_value {
    my $self = shift;
    my %args = @_;

    if (($args{owner_id} || $self->owner_id) == ($args{current_user} || $self->current_user->id)
        or ($args{owner_id} || $self->owner_id) == BTDT::CurrentUser->nobody->id) {
        return 1;
    } else {
        return undef;
    }
}

=head2 after_set_accepted

If someone declines a task, set the owner and next_action_by to the user who
assigned it to that person.

=cut

sub after_set_accepted {
    my $self = shift;
    my $args = shift;

    if(defined($args->{value}) && !$args->{value}) {
        my $transactions = $self->transactions;

        # The changes need to be as the superuser because once we
        # reject the task, we may not have rights to it anymore
        my $super = $self->as_superuser;
        # But we don't want transactions owned by the superuser, if at
        # all possible.  Note that changes belong in the same
        # transaction as the accepted change.
        $self->as_superuser->{transaction} = $self->{transaction};

        while (my $t = $transactions->next) {
            my $changes = $t->visible_changes;
            while (my $c = $changes->next) {  # is this oldest-first or newest-first?
                if ($c->field eq "owner_id" && $c->new_value eq $super->owner_id) {
                    my $old_value = $c->as_superuser->old_value;
                    $super->_set( column => 'owner_id', value => $old_value );
                    $super->_set( column => 'next_action_by', value => $old_value );

                    # XXX reset to "still deciding" -- except if the
                    # old owner was nobody, who always accepts
                    if ($old_value == BTDT::CurrentUser->nobody->id) {
                        $super->_set( column => 'accepted', value => 1 );
                    } else {
                        $super->_set( column => 'accepted', value => undef );
                    }
                    return;
                }
            }
        }

        # If we get here, we never saw a set of owner_id, so it must
        # have been set at create time by the requestor.  So, bounce
        # it back to the requestor.
        $super->_set( column => 'owner_id', value => $super->requestor->id );
        $super->_set( column => 'next_action_by', value => $super->requestor->id );
        # XXX reset to "still deciding"
        if ($super->requestor->id == BTDT::CurrentUser->nobody->id) {
            # This shouldn't be possible -- it implies we now have a
            # task owneed and requested by nobody!
            warn "Task owned and requested by nobody!\n";
        } else {
            $super->_set( column => 'accepted', value => undef );
        }
    }
}

=head2 is_unaccepted

This encapsulates the logic of "is this task unaccepted?" If so, an
accept/decline prompt should appear on task edit pages.

=cut

sub is_unaccepted {
    my $self = shift;
    return 0 if $self->owner_id != $self->current_user->id;
    return 0 if $self->accepted;

    # If you've explicitly declined the task (accepted=0) then it's
    # not "unaccepted"
    return 0 if defined($self->accepted) && length($self->accepted);
    return 1;
}

=head2 set_summary SUMMARY

Sets the summary and updates the dependency caches of any tasks that
depend on us or are depended on by us.

=cut

sub set_summary {
    my $self = shift;
    my $value = shift;

    my ($ok, $msg) = $self->_set( column => 'summary', value => $value);
    return unless $ok;

    $self->_update_dependency_tree;

    return ($ok, $msg);
}

=head2 formatted_description

Format the description using L<BTDT/format_text>.
If C<<short => 1>> is passed, then
truncates the description at 160 characters (by default) before applying
formatting.  The C<chars> option can be used to change the default number
of characters at which to truncate.

=cut

sub formatted_description {
    my $self = shift;
    my $desc = $self->description || '';
    return BTDT->format_text( $desc, @_ );
}

=head2 start_transaction [TYPE], [ARGS]

Returns a L<BTDT::Model::TaskTransaction> object, which can be used to
log actions on this task.  I<TYPE> sets the C<TYPE> of the
L<BTDT::Model::TaskTransaction> object.  The default value is
"update"; other possibilities include "create" and "delete".  Any
additional C<ARGS> are passed to
L<BTDT::Model::TaskTransaction/create>.

=cut

sub start_transaction {
    my $self = shift;
    my $type = shift || "update";
    $self->{'transaction'} = BTDT::Model::TaskTransaction->new;

    my @args = (
        task_id   => $self->id,
        type      => $type,
        project   => $self->project->id,
        milestone => $self->milestone->id,
        group_id  => $self->group->id,
        owner_id  => $self->owner->id,
        @_,
    );

    if ($type eq "update") {
        # If this is an update, note that we do *not* call create on
        # this transaction -- that doesn't happen until the first time
        # that we call current_transaction->add_change
        $self->{'transaction'}->deferred_create(@args);
    } else {
        $self->{'transaction'}->create(@args);
    }

    return $self->{'transaction'};
}

=head2 current_transaction

Returns the current transaction, if any.

=cut

sub current_transaction {
    my $self = shift;
    return $self->{'transaction'};
}

=head2 end_transaction

Ends the current transaction, if there is one.  (Note that the
transaction is not created in the database until the first time that
you call C<add_change> on it.  Thus if there are no changes added to
the transaction between C<start_transaction> and C<end_transaction>,
no transaction row will be created in the database for it.)

Returns the ID of the L<BTDT::Model::TaskTransaction> that was
committed, or C<undef> if no transaction was written.

=cut

sub end_transaction {
    my $self = shift;

    if (my $transaction = delete $self->{'transaction'}) {
        $transaction->commit;
        $self->set_last_modified_to_now;
        return $transaction->id;
    } else {
        return;
    }
}


=head2 transactions

Returns a L<BTDT::Model::TaskTransactionCollection> that has been
limited to this task.

=cut

sub transactions {
    my $self = shift;

    my $transactions = BTDT::Model::TaskTransactionCollection->new();

    $transactions->limit(
        column   => 'task_id',
        operator => '=',
        value    => $self->id
    );
    $transactions->order_by(
        { column => 'modified_at', order => 'DESC' },
        { column => 'id',          order => 'DESC' },
    );
    $transactions->results_are_readable(1) if $self->current_user_can("read");
    return $transactions;
}

=head2 set_last_modified_to_now

Sets the L<last_modified> of this task to the current time.

=cut

sub set_last_modified_to_now {
    my $self = shift;
    $self->__set(
        column => 'last_modified',
        value  => BTDT::DateTime->now,
    );
}


=head2 last_modified

The L<last_modified> column was left unpopulated for old tasks, so it
may be null.  If it is, lazily populate it now.

=cut

sub last_modified {
    my $self = shift;
    my $val = $self->_value('last_modified');
    return $val
        if defined $val
        or not $self->current_user_can('read', column => 'last_modified' );

    my $last = $self->transactions->last;
    my $at = $last ? $last->modified_at : $self->created || Jifty::DateTime->now;
    $self->as_superuser->__set(
        column => 'last_modified',
        value => $at,
    );

    return $at;
}

=head2 flip_next_action_by

Passes the baton between owner/requestor (usually after a comment to the task)

=cut

sub flip_next_action_by {
    my $self = shift;
    my $user = shift;

    if ($user->id == $self->owner_id
     && $self->next_action_by->id == $self->owner_id) {
            $self->set_next_action_by($self->requestor);
    }
    elsif ($user->id == $self->requestor_id
        && $self->next_action_by->id == $self->requestor_id) {
        $self->set_next_action_by($self->owner);
    }
}

=head2 comment BODY [HEADER => VALUE ...]

Adds the given C<BODY> to the comments on the task.

=cut

sub comment {
    my $self = shift;
    my $body = shift;
    my %headers = @_;
    Encode::_utf8_on($body);
    my $user = $self->current_user->user_object;
    my $email = Email::Simple->create(
        header => [ From => Encode::encode('MIME-Header',$user->formatted_email ), %headers ],
        body   => $body,
    );

    my $reply = $self->transactions->first->comments->first;
    if ($reply) {
        $email->header_set(
            "In-Reply-To", $reply->header("Message-ID")
        );
        $email->header_set(
            "References",
            join(
                " ",
                Email::Address->parse(
                           $reply->header("References")
                        || $reply->header("In-Reply-To")
                ),
                $reply->header("Message-ID")
            )
        );
    }

    my $taskemail = BTDT::Model::TaskEmail->new();
    $taskemail->create(
        message => $email->as_string,
        task_id => $self->id,
        (   $self->current_transaction
            ? ( transaction_id => $self->current_transaction->id )
            : ()
        )
    );
}


=head2 comments

Returns a L<BTDT::Model::TaskEmailCollection> of all of the emails on
this task.

=cut

sub comments {
    my $self = shift;
    my $changes = BTDT::Model::TaskEmailCollection->new();
    $changes->limit(column => 'task_id', operator => '=', value => $self->id);
    return $changes;
}


sub _update_dependency_cache {
    my $self = shift;
    Jifty->handle->begin_transaction();
    my $in_txn = $self->current_transaction;
    $self->start_transaction unless $in_txn;

    # this is a rather naive implementation
    foreach my $type (qw(depends_on depended_on_by)) {

        my $method = "incomplete_$type";
        my $tasks = $self->$method();
        $self->__set(
            column => $type . "_ids",
            value => join( "\t", map { $_->id } @{ $tasks->items_array_ref } )
        );
        $self->__set(
            column => $type . "_summaries",
            value  => join(
                "\t", map { $_->summary } @{ $tasks->items_array_ref }
            )
        );
        $self->__set( column => $type . "_count", value => $tasks->count );

    }

    $self->end_transaction unless $in_txn;

    Jifty->handle->commit();
}

=head2 _update_dependency_tree

B<INTERNAL USE ONLY>

Asks all of the tasks that either depend on or are depended on by us
to update their dependency caches

=cut

sub _update_dependency_tree {
    my $self = shift;

    my $depends_on = $self->depends_on;
    while (my $dep = $depends_on->next) {
        $dep->_update_dependency_cache()
    }
    my $depended_on_by = $self->depended_on_by;
    while (my $dep = $depended_on_by->next) {
        $dep->_update_dependency_cache()
    }
}


=head2 add_depended_on_by TASK_ID

Adds a new dependency on the task whose ID is TASK_ID

=cut


sub add_depended_on_by {
    my $self = shift;
    my $task_id = shift;
    $task_id = $task_id->id if ref $task_id;

    my $dep = BTDT::Model::TaskDependency->new();
    return $dep->create( task_id => $task_id, depends_on => $self->id);
}

=head2 depended_on_by

Returns a BTDT::Model::TaskCollection of all the tasks which depend on this one

=cut

sub depended_on_by {
    my $self = shift;
    return BTDT::Model::TaskCollection->new()->depend_on($self->id);
}


=head2 incomplete_depended_on_by

Returns a BTDT::Model::TaskCollection of all the incomplete tasks which depend on this one

=cut

sub incomplete_depended_on_by {
    my $self = shift;

    my $tasks = BTDT::Model::TaskCollection->new();
    $tasks->depend_on($self->id);
    $tasks->incomplete();
    $tasks->will_complete();
    return $tasks

}


=head2 add_dependency_on TASK_ID

Adds a new dependency on the task whose ID is TASK_ID

=cut


sub add_dependency_on {
    my $self = shift;
    my $task_id = shift;
    $task_id = $task_id->id if ref $task_id;

    my $dep = BTDT::Model::TaskDependency->new();
    return $dep->create( task_id => $self->id, depends_on => $task_id);

}

=head2 depends_on

Returns a BTDT::Model::TaskCollection of all the tasks which this one depends on

=cut

sub depends_on {
    my $self = shift;
    return BTDT::Model::TaskCollection->new()->depended_on_by($self->id);
}


=head2 incomplete_depends_on

Returns a BTDT::Model::TaskCollection of all the incomplete tasks which this one depends on

=cut

sub incomplete_depends_on {
    my $self = shift;

    my $tasks = BTDT::Model::TaskCollection->new();
    $tasks->depended_on_by($self->id);
    $tasks->incomplete();
    $tasks->will_complete();
    return $tasks


}

=head2 remove_dependency_on TASK_ID

Removes a dependency on the task whose ID is TASK_ID. This just deletes the
TaskDependency record, it does not delete or complete either task.

=cut


sub remove_dependency_on {
    my $self = shift;
    my $task_id = shift;
    $task_id = $task_id->id if ref $task_id;

    my $dep = BTDT::Model::TaskDependency->new();
    $dep->load_by_cols(
        task_id    => $self->id,
        depends_on => $task_id,
    );
    $dep->delete;
}

=head2 remove_depended_on_by TASK_ID

This just deletes the dependency on the task whose ID is TASK_ID. This just
deletes the TaskDependency record, it does not delete or complete either task.

=cut


sub remove_depended_on_by {
    my $self = shift;
    my $task_id = shift;
    $task_id = $task_id->id if ref $task_id;

    my $dep = BTDT::Model::TaskDependency->new();
    $dep->load_by_cols(
        task_id    => $task_id,
        depends_on => $self->id,
    );
    $dep->delete;
}

=head2 current_user_can RIGHT

Users can see and edit personal tasks and tasks in groups they are
members of.  Admins can see, edit, and delete any task.

=cut

sub current_user_can {
    my $self  = shift;
    my $right = shift;
    my %args  = (@_);

    # Can only CRUD the time tracking fields if pro
    if (     $args{column}
            and $args{column} =~ /time_(?:worked|left|estimate)/
            and not ($self->current_user->has_feature("TimeTracking") or $self->current_user->is_superuser) )
    {
        return 0;
    }

    my $group_id = defined $args{'group_id'} ? $args{'group_id'} : $self->__value('group_id');
    my $group = BTDT::Model::Group->new(current_user => $self->current_user);
    $group->load( $group_id );

    # XXX TODO ACL
    # Can only CRUD the project/milestone fields if you have the feature
    if (     $args{column}
            and $args{column} =~ /project|milestone/i
            and not $group->has_feature('Projects') )
    {
        return 0;
    }

    # If you don't have project management, you can't set type to something
    # other than 'task'
    return 0
        if $right eq 'update'
       and $args{'column'}
       and $args{'column'} eq 'type'
       and $args{'value'}  ne 'task'
       and not $group->has_feature('Projects');

    # only allow creation of personal tasks or tasks in my groups
    if ( $right eq 'create' ) {

        # It's a personal task
        return 1 unless $args{'group_id'};

    # If we're creating a task in a group, we should make sure we can load it.
        my $group = BTDT::Model::Group->new();
        $group->load( $args{'group_id'} );
        return 1 if $group->id and $group->current_user_can('create_tasks');
    }

    #See: is it my personal task or in a group I am a viewer of?
    elsif ( $right eq 'read' ) {

        # I can see tasks I own
        my $owner_id = $self->__value('owner_id');
        return 1 if $owner_id && $owner_id == $self->current_user->id;

        # I can see tasks I requested
        my $requestor_id = $self->__value('requestor_id');
        return 1 if $requestor_id && $requestor_id == $self->current_user->id;

        my $group_id = $self->__value('group_id');
        if ($group_id) {
            # I can see group tasks for groups I'm in
            my $group = BTDT::Model::Group->new;
            $group->load( $group_id );
            return 1
              if $self->group->current_user_can('read_tasks');
        }

        # Stop the 'administrator' right from saying we can read anything
        if (   $self->current_user->user_object
            && $self->current_user->user_object->__value('access_level') eq
            'administrator'
            && !$self->current_user->is_superuser )
        {
            return (0);
        }
    }




    # Edit and delete
    elsif ( $right eq 'update' or $right eq 'delete' ) {
        # I can update tasks I own
        my $owner_id = $self->__value('owner_id');
        return 1 if $owner_id && $owner_id == $self->current_user->id;

        # If I don't own it: Can I see it, and, if it's a group task, does the
        # group say I can update it?
        return 1
          if  (!$args{column} || $args{column} !~ /^(?:accepted|will_complete)$/)
            and $self->current_user_can('read')
            and (    $self->requestor->id == $self->current_user->id
                  or !$self->group->id
                  or  $self->group->current_user_can('update_tasks'));
    }

    # If we don't get a pass, defer to the superclass
    return $self->SUPER::current_user_can( $right, %args );
}

sub __set {
    my $self = shift;
    my %args = (
        column => undef,
        value  => undef,
        @_
    );

    # last_modified should not be recorded as part of the transaction, since
    # it's a cache of the transaction history
    return $self->SUPER::__set(%args) if $args{is_sql_function} || $args{column} eq 'last_modified';

    my $old = $self->__value($args{'column'});

    return ( 0, "That's already the current value" )
        if (not defined $old
        and not defined $args{'value'} )
        or (
            defined $old
        and defined $args{'value'}

        # Stringify to flatten datetimes.
        and ( $args{'value'} . "" eq "" . $old)
        )
    # stop spurious "changed from '2007-01-01 00:00:00' to '2007-01-01'" changes
            or (
    UNIVERSAL::isa($old, "Jifty::DateTime")
           && $old->is_date
           && $old->ymd eq ($args{'value'}||'') );



    my $in_transaction;

    if ($self->current_transaction) {
        $in_transaction = 1;
    } else {
        $self->start_transaction();
        $in_transaction = 0;
    }

    $self->current_transaction->add_change( $args{'column'} => $args{'value'});
    my ($val,$msg) = $self->SUPER::__set(%args);

    # if we change one of the columns relevant to repeating tasks, we need to
    # recalculate the repeat_next_date value of the master task and percolate
    # any changes to this task back to the master task.
    # TODO if tasks stack, there may be other repeated tasks that need metadata
    # updates, but the right fix for that is a new repeating task system
    my @repeat_columns = qw(repeat_days_before_due repeat_every repeat_period repeat_stacking);
    if (grep { $args{column} eq $_ } (@repeat_columns, qw(due complete))) {
        if ( $self->_value('repeat_of') != $self->id ) {
            if ( grep { $args{column} eq $_ } @repeat_columns ) {
                my $column = $args{column};
                my $master_task = $self->repeat_of;
                if ($self->$column ne $master_task->$column) {
                    my $setter = "set_$column";
                    $master_task->$setter($self->$column);
                }
            }
        }
        $self->set_repeat_next_create;
    }
    if (not $in_transaction) {
        $self->end_transaction();
    }

    return ($val,$msg);

}

=head2 due_as_ical_event

Returns the task as a L<Data::ICal::Entry::Event> object.

=cut

sub due_as_ical_event {
    my $self  = shift;
    return undef unless ($self->due);

    my $due = $self->due;

    # an all-day event is specified by day only, and has a DTEND on the next day
    my $due_end = $due + DateTime::Duration->new(days => 1);
    $due = $due->strftime('%Y%m%d');
    $due_end = $due_end->strftime('%Y%m%d');

    my $vevent = Data::ICal::Entry::Event->new();
    # play nicely with google calendar, which doesn't support the URL property
    # in event displays right now. It will preserve URL: through import and
    # export, it just doesn't use URL: anywhere in the GC ui.
    my $description = ($self->description||'') . " " . $self->url;

    $vevent->add_properties(
        # XXX TODO: we should probably be exporting a UID: property.
        summary       => $self->summary,
        description   => $description,
        url           => $self->url,
        organizer     => ["mailto:".$self->requestor->email, {CN => $self->requestor->name}],
        # DTSTAMP is when this iCalendar object was exported, for sync purposes.
        # there are separate CREATED: and LAST-MODIFIED: fields in the iCal
        # standard, but we're not generating them right now.
        dtstamp       => Date::ICal->new( epoch => time )->ical,
        # XXX we should probably be sending these with timezone information
        # for robustness, because they default to floating dates, and we
        # have no control over how iCal implementations will deal with that.
        dtstart       => [$due => {value => 'DATE'}],
        dtend         => [$due_end => {value => 'DATE'}],
        categories    => $self->tags,
        priority      => $self->priority_as_ical_priority,
        uid           => "due-event-".$self->record_locator.'@hiveminder.com',
    );

    return ($vevent);
}


=head2 as_ical_todo

Returns the task as a L<Data::ICal::Entry::Todo> object.

=cut

sub as_ical_todo {
    my $self  = shift;
    my $vtodo = Data::ICal::Entry::Todo->new();

    $vtodo->add_properties(
        summary         => $self->summary,
        url             => $self->url,
        organizer       => ["mailto:".$self->requestor->email, {CN => $self->requestor->name}],
        created         => Date::ICal->new( epoch => $self->created->epoch)->ical,
        "last-modified" => Date::ICal->new( epoch => $self->transactions->last->modified_at->epoch)->ical,
        status          => ( $self->complete ? 'COMPLETED' : 'INCOMPLETE' ),
        ($self->complete
             ? ( completed => Date::ICal->new( epoch => $self->completed_at->epoch)->ical )
             : ()
        ),
        categories      => $self->tags,
        priority        => $self->priority_as_ical_priority,
        uid             => "todo-".$self->record_locator.'@hiveminder.com',
    );

    $vtodo->add_property( dtstart => [$self->starts->strftime('%Y%m%d') => {value => 'DATE'}] )
        if $self->starts;

    $vtodo->add_property( due => [$self->due->strftime('%Y%m%d') => {value => 'DATE'}] )
        if $self->due;

    $vtodo->add_property( completed => $self->completed_at->ymd('').'T'.$self->completed_at->hms('') )
        if $self->completed_at;

    return ($vtodo);
}

=head2 priority_as_ical_priority

Returns the task's priority as a numeric iCal priority

=cut

sub priority_as_ical_priority {
    my $self = shift;
    my %map = (
        1 => 9,
        2 => 7,
        3 => 5,
        4 => 3,
        5 => 1,
    );
    return $map{$self->priority} || 0;
}

=head2 as_atom_entry

Returns the task as an L<XML::Atom::Entry> object.

=cut

sub as_atom_entry {
    my $self = shift;

    my $ns = XML::Atom::Namespace->new('hm', 'http://hiveminder.com/atom/20090603');

    my $link = XML::Atom::Link->new;
    $link->type('text/html');
    $link->rel('alternate');
    $link->href( $self->url );

    my $entry = XML::Atom::Entry->new;
    $entry->add_link($link);
    $entry->id( $self->url );
    $entry->title( $self->summary );

    $entry->content( $self->description || ' ' );
    $entry->updated( $self->created->ymd('-').'T'.$self->created->hms(':').'Z');

    if ($self->complete) {
        $entry->set($ns, 'complete');

        my $completed_at = $self->completed_at;
        $entry->set($ns, 'completed_at', "$completed_at");
    }

    $entry->set($ns, 'due', $self->due->ymd) if !$self->complete && $self->due;
    $entry->set($ns, 'tags', $self->tags) if $self->tags;
    $entry->set($ns, 'group', $self->group->name) if $self->group->id;
    $entry->set($ns, 'priority', $self->text_priority) if $self->priority != 3;

    if ($self->current_user->pro_account) {
        $entry->set($ns, 'time_estimate', $self->time_estimate) if $self->time_estimate;
        $entry->set($ns, 'time_worked', $self->time_worked) if $self->time_worked;
        $entry->set($ns, 'time_left', $self->time_left) if $self->time_left;
    }

    my $owner = XML::Atom::Person->new;
    $owner->name($self->owner->name);
    $owner->email($self->owner->email);
    $entry->set($ns, 'owner', $owner);

    my $author = XML::Atom::Person->new();
    $author->name( $self->requestor->name );
    $author->email( $self->requestor->email );
    $entry->author($author);

    return $entry;
}

=head2 auth_token

Provides an opaque authorization token that can be presented to verify
that the user didn't just guess a task id.  As its name implies, it is
rather insecure.

=cut

sub auth_token {
    my $self   = shift;
    my $digest = Digest::MD5->new();
    # We can't actually change this now, since it would break all task
    # comment emails we've ever sent out
    $digest->add('Internal secret XXX TODO REPLACE');
    $digest->add( $self->id() );

    my $k = String::Koremutake->new;
    return $k->integer_to_koremutake( hex( substr($digest->hexdigest,0,8) ) );
}

=head2 comment_address

Returns the email address that, if mailed to, will result in a comment on the
task.  This method is provided as a computed column for access using the API.

=cut

# We cache this, since apparently it takes noticible time?
__PACKAGE__->mk_accessors('_comment_address');

sub comment_address {
    my $self = shift;

    return undef unless $self->id;

    unless ( $self->check_read_rights('comment_address') ) {
        return (undef);
    }

    unless ( $self->_comment_address ) {
        $self->_comment_address(
            join( '-', 'comment', $self->id, $self->auth_token, )
                . '@tasks.hiveminder.com' );
    }
    return $self->_comment_address;
}


=head3 next_repeat_due

Returns the creation date for the next recurrence as a C<DateTime> object.
If the task isn't currently scheduled to repeat, returns undef.
If the task's repeitition is blocking because the repetitions don't stack, returns undef.

=cut

sub next_repeat_due {
    my $self = shift;
    if ( $self->repeat_period eq 'once'  or !$self->repeat_every) {
        return undef;
    }

    my $due;
    my $interval = DateTime::Duration->new( $self->repeat_period  => $self->repeat_every );
    # For pay the rent
    # Repeat every n periods, due on the same date of the perioud.
    if ( $self->repeat_stacking   && $self->last_repeat->due) {
        # make it due on the same day of the period
        $due = $self->last_repeat->due + $interval;

    } elsif ($self->repeat_stacking && !$self->last_repeat->due && $self->last_repeat->created) {

        # make it due one interval_later
        # Task 1 created on monday, repeating every day with 1 day's notice:
        # Monday + 2 days = due on weds - that's wrong
        $due = $self->last_repeat->created + $interval + DateTime::Duration->new( days => ($self->repeat_days_before_due ||1));

    }
    # do the dishes
    # Repeat every n periods after I check the last one off.
    elsif ( !$self->repeat_stacking && $self->last_repeat and $self->last_repeat->complete and $self->last_repeat->completed_at ) {
        $due = $self->last_repeat->completed_at + $interval;
     }
     else {
         return undef;
    }
    return ($due);

}

=head2 set_repeat_next_create

Schedules the task's next_repeat to be updated (via
L</update_repeat_next_create>) when the transaction is completed.
This ensures that the value is only updated once, even if this is
called multiple times in one transaction.

=cut

sub set_repeat_next_create {
    my $self = shift;

    $self->current_transaction->update_next_repeat(1);
}

=head2 update_repeat_next_create

Figure out when the next repeat of this task is due and sets
repeat_next_ceate to "however many days before it's due that you want
to see it"

=cut

sub update_repeat_next_create {
    my $self = shift;
    my $starts;
    my $master_task = ($self->repeat_of->id == $self->id) ? $self : $self->repeat_of;
    my $due = $master_task->next_repeat_due();

    # Show up m days before it's due
    if ($due) {
        my $days_before_due = DateTime::Duration->new( days => ($master_task->repeat_days_before_due ||1));
        $starts = $due - $days_before_due;
    }

    return $master_task->__set( column => 'repeat_next_create', value => $starts || undef );
}


=head2 schedule_next_repeat

If this task is repeatable, create a new repeat for the task, scheduled at its next due date,
then updates this task's repetition metadata

=cut


sub schedule_next_repeat {
    my $self = shift;
    my $new = BTDT::Model::Task->new();
    my %args;
    return unless ($self->repeat_period ne 'once' && $self->_value('repeat_of') eq $self->id);
    return unless ($self->repeat_next_create);
    return unless ($self->repeat_next_create <= Jifty::DateTime->now());
    foreach my $col (qw( created summary description group_id owner_id requestor_id accepted priority tags repeat_period repeat_every repeat_stacking repeat_days_before_due)) {
        $args{$col} = $self->$col();
    }


    $args{'due'} = $self->next_repeat_due;
    $args{'starts'} = $self->repeat_next_create;
    $args{'repeat_of'} = $self->id;
    my ($ret, $msg) = $new->create( %args );
    warn "Create of repeated event failed: $msg\n".YAML::Dump(\%args) unless $ret;
    $self->start_transaction;
    $self->set_last_repeat($new);
    $self->set_repeat_next_create();
    $self->end_transaction;
    return $ret;
}

=head2 enumerable

Don't ever attempt to provide a drop-down of tasks.

=cut

sub enumerable { 0 }

=head2 time_tracking [hashref] -> hashref

This will calculate the time tracking hashref of the task. You may pass in a
hashref if you want to accumulate over a set of tasks.

The return value will be a hashref with the following keys:

=over 4

=item Worked

A hashref of the person who spent time on the task (potentially "You") mapped
to how many seconds they spent on the task.

=item Total worked

The total time spent working on the task, by all the users.

=item Time left

The number of seconds left before the task can be marked complete. This uses
the "time left" field.

=item Estimate

The initial estimate in seconds.  This uses the time_estimate field.

=item Diff

The difference of the initial estimate and the time worked.

=back

=cut

sub time_tracking {
    my $self     = shift;
    my $tracking = shift || {};
    my $total    = 0;

    my $query = $self->transactions;
    $query->limit( column => "type", value => "update", entry_aggregator => "OR" );
    $query->column( column => "created_by" );
    $query->column( function => 'SUM', column => "time_worked" );
    $query->group_by({ column => "created_by" });
    $query->order_by({});
    while (my $row = $query->next) {
        $tracking->{"Worked"}->{$row->author} += $row->time_worked;
    }

    $tracking->{"Estimate"}     += $self->time_estimate_seconds || 0;
    $tracking->{"Time left"}    += ($self->complete or !$self->will_complete) ? 0 : $self->time_left_seconds || 0;
    $tracking->{"Total worked"} += $self->time_worked_seconds || 0;
    $tracking->{"Diff"}         += ($self->time_estimate_seconds || 0) - ($self->time_worked_seconds || 0);

    return $tracking;
}

=head2 jifty_serialize_format

Add a "record_locator" key so that REST consumers don't have to port
L<Number::RecordLocator>.

=cut

sub jifty_serialize_format {
    my $self = shift;
    my $data = $self->SUPER::jifty_serialize_format(@_);
    $data->{record_locator} = $self->record_locator;
    return $data;
}

=head2 set_header_on MESSAGE HEADER VALUE

Encodes the given VALUE in MIME-Header encoding, and sets it on the
MESSAGE.

=cut

sub set_header_on {
    my $self = shift;
    my ($message, $header, @values) = @_;
    @values = map {Encode::encode('MIME-Header', $_)} @values;
    $message->header_set($header => @values);
}

=head2 set_headers_on MESSAGE

Sets a bunch of C<X-Hiveminder-> email headers on the given MESSAGE,
based on the task's properties.

=cut

sub set_headers_on {
    my $self = shift;
    my ($message) = @_;
    $self->set_header_on( $message, "X-Hiveminder-Id" => $self->id );
    $self->set_header_on( $message, "X-Hiveminder-RecordLocator" => $self->record_locator );
    $self->set_header_on( $message, "X-Hiveminder-Requestor" => $self->requestor->formatted_email );
    $self->set_header_on( $message, "X-Hiveminder-Owner" => $self->owner->formatted_email );
    $self->set_header_on( $message, "X-Hiveminder-Tags" => $self->tags );
    $self->set_header_on( $message, "X-Hiveminder-Group" => $self->group->name )
        if $self->group->id;
    $self->set_header_on( $message, "X-Hiveminder-Project" => $self->project->summary )
        if $self->project->id;
    $self->set_header_on( $message, "X-Hiveminder-Milestone" => $self->milestone->summary )
        if $self->milestone->id;
    $self->set_header_on( $message, "X-Hiveminder-Due" => $self->due->ymd ) if $self->due;
}

=head2 as_library_todo

Returns the task as a C<Data::Plist::Foundation::LibraryToDo> object.

=cut

sub as_library_todo {
    my $self = shift;
    my $todo = Data::Plist::Foundation::LibraryToDo->new;
    $todo->init;
    $todo->title( $self->summary );
    $todo->created( $self->created );
    $todo->due( $self->due );
    $todo->complete( $self->complete );
    $todo->priority( $self->priority );
    $todo->id( "hiveminder-task-".$self->record_locator );
    return $todo;
}

=head2 time_summary

Returns this task's time worked and time left in a human-readable form

=cut

sub time_summary {
    my $self = shift;

    my $worked = $self->time_worked;
    my $left   = $self->time_left;

    my $summary = $worked ? $worked : '0h';
    $summary .= ' / ' . $left if $left;
    $summary = '' if $summary eq '0h';

    return $summary;
}

=head2 overdue

Returns true if the task is overdue, otherwise returns false (including if the
task has no due date).

=cut

sub overdue {
    my $self = shift;
    return 0 if not defined $self->due;
    return $self->due_in < 0 ? 1 : 0;
}

=head2 due_in

Returns a duration (in seconds) until the task is due.  If the task is overdue,
this will be negative.  The duration is calculated in the current user's timezone.

Returns undef if the task does not have a due date.

=cut

sub due_in {
    my $self = shift;
    return if not defined $self->due;
    return $self->due->set_current_user_timezone->epoch
            - BTDT::DateTime->today->set_current_user_timezone->epoch;
}

=head2 business_seconds_until_due

Returns the number of business seconds between now and the due date
of the task type.

Returns 0 if there is no due date or if the task is overdue.

=cut

sub business_seconds_until_due {
    my $self = shift;

    return 0 if not defined $self->due;

    # Business::Hours doesn't handle TZs explicitly, so if we set our TZs
    # to floating right before we ->epoch them, it should Just Work.
    my $now  = BTDT::DateTime->now->set_time_zone('floating')->epoch;
    my $due  = $self->due->set_time_zone('floating')->epoch;

    return 0 if $now >= $due;

    my $hours = Business::Hours->new;
    # Setup our default 8 hour days, 5 days a week
    $hours->business_hours(
        0 => { Name  => 'Sunday',
               Start => undef,
               End   => undef, },
        1 => { Name  => 'Monday',
               Start => '9:00',
               End   => '17:00', },
        2 => { Name  => 'Tuesday',
               Start => '9:00',
               End   => '17:00', },
        3 => { Name  => 'Wednesday',
               Start => '9:00',
               End   => '17:00', },
        4 => { Name  => 'Thursday',
               Start => '9:00',
               End   => '17:00', },
        5 => { Name  => 'Friday',
               Start => '9:00',
               End   => '17:00', },
        6 => { Name  => 'Saturday',
               Start => undef,
               End   => undef, }
    );

    return $hours->between( $now, $due );
}

1;

