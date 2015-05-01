use warnings;
use strict;


=head1 NAME

BTDT::Action::CreateTask

=cut

package BTDT::Action::CreateTask;

use base qw/BTDT::Action Jifty::Action::Record::Create/;
use List::MoreUtils qw/uniq/;

=head2 record_class

This creates L<BTDT::Model::Task> objects.

=cut

sub record_class { 'BTDT::Model::Task' }


=head2 arguments

Overrides the default value of the owner to be the current user.

=cut

sub arguments {
    my $self = shift;

    return $self->{__cached_arguments}
        if ( exists $self->{__cached_arguments} );
    my $args = $self->SUPER::arguments();

    $args->{'depended_on_by'} = { render_as => 'Hidden' };
    $args->{'depends_on'}     = { render_as => 'Hidden' };

    $args->{'summary'}{mandatory}          = 1;
    $args->{'summary'}{ajax_canonicalizes} = 1;
    $args->{'tags'}{ajax_canonicalizes}    = 1;

    $args->{'email_content'}{render_as} = 'Unrendered';

    $args->{'group_id'}{'render_as'} = 'Select';
    if ( Jifty->web->current_user->user_object ) {
        $args->{'group_id'}{'valid_values'} = [
            {   display => 'Personal',
                value   => '',
            },
            {   display_from => 'name',
                value_from   => 'id',
                collection   => Jifty->web->current_user->user_object->groups,
            },
        ];
    } else {
        $args->{'group_id'}{'valid_values'} = [
            {   display => 'Personal',
                value   => '',
            }
        ];
    }

    $args->{'group_id'}{'canonicalizer'} =
        \&BTDT::Model::Task::canonicalize_group_id;

    if ( not $self->argument_value('group_id') ) {
        $args->{'group_id'}{'default_value'} = '';    # "Personal" group
    }

    # XXX TODO: the rest of this code is nearly identical to that of
    # UpdateTask::arguments -- they should be refactored

    $args->{'owner_id'}{'default_value'}
        = Jifty->web->current_user->user_object
        ? Jifty->web->current_user->user_object->email
        : "";
    $args->{'owner_id'}{'ajax_validates'} = 1;
    $args->{'owner_id'}{canonicalizer}
        = \&BTDT::Model::Task::canonicalize_owner_id;
    $args->{'owner_id'}{'render_as'} = 'Text';

    return $self->{__cached_arguments} = $args;
}

=head2 validate_arguments

Verify that at least one of summary and description have something in
them.

=cut

sub validate_arguments {
    my $self = shift;
    return unless $self->argument_value('summary') =~ /\S/ or $self->argument_value('description') =~ /\S/;

    return $self->SUPER::validate_arguments();
}

=head2 validate_owner_id

Ensures the owner is a valid email address

=cut

sub validate_owner_id {
    my ( $self, $value ) = @_;
    return BTDT->validate_user_email( action => $self, column => "owner_id", value => $value, empty => 1, group => $self->argument_value('group_id') );
}

=head2 validate_requestor_id

Ensures the requestor is a valid email address

=cut

sub validate_requestor_id {
    my ( $self, $value ) = @_;
    return BTDT->validate_user_email( action => $self, column => "requestor_id", value => $value, empty => 1 );
}

=head2 take_action

Translates email addresses to user ids, and forces the requestor to be
the current user.  Adds a message noting the success of the action
after it completes.

=cut

sub take_action {
    my $self = shift;

    $self->argument_value( owner_id =>
            BTDT::Model::User->resolve( $self->argument_value("owner_id") )
            || BTDT::CurrentUser->nobody->id );
    $self->argument_value( requestor_id => Jifty->web->current_user->id );

    if(    $self->argument_value('summary') =~
           m{\A
             \s*

             # allow #id or task ID, task.hm/ID, hm.com/task/ID
             (
                  \#
                | task
                | (?: http:// )? (?: task\.hm | hiveminder\.com/task )
             )?

             [\s/]*
             ([a-zA-Z0-9]+)
             \s*
             \z}xi
       && ($self->argument_value('depended_on_by') ||
           $self->argument_value('depends_on'))) {
        # We were given something that probably is a record locator,
        # attach the specified task into the dependency tree instead
        # of creating a new one.
        my $taskprefix = $1;
        my $rl = $2;
        my $id = $BTDT::Record::LOCATOR->decode($rl);
        my $task = BTDT::Model::Task->new;
        $task->load($id);
        if ($task->id && $task->current_user_can('read')) {
            my ($ok, $msg);
            my $dep;
            if($dep = $self->argument_value('depends_on')) {
                ($ok, $msg) = $task->add_dependency_on($dep);
            } elsif($dep = $self->argument_value('depended_on_by')) {
                ($ok, $msg) = $task->add_depended_on_by($dep);
            }
            if($ok) {
                $self->result->content(id => $task->id);
                $self->result->message('Link created');
            } else {
                $self->result->error($msg);
            }
            return;
        } elsif (!$task->id && !$taskprefix) {
            # if you used something that looked like a task id (such as a one
            # word task summary) but didn't say #foo or task.hm//foo, be nice
            # and create the task for you.
            return $self->SUPER::take_action(@_);
        } elsif (!$task->id || !$task->current_user_can('read')) {
            # this used to be an error, but instead we're being even nicer
            # and giving you a new task anyway
            return $self->SUPER::take_action(@_);
        }
        return;
    }

   return $self->SUPER::take_action(@_);
}

=head3 report_success

Report success to the user

=cut

sub report_success {
    my $self = shift;
    my $type = $self->record->type;
    $self->result->content(record_locator => $self->record->record_locator);
    $self->result->message("Your $type has been created!");
}

=head3 canonicalize_summary

Wrapper for UpdateTask's summary canonicalizer

We want create to be more aggressive and consider "implicit" data
culled from the summary

=cut

sub canonicalize_summary {
    my $self = shift;
    my $summary = shift;
    my %args = ( implicit => 1 , @_ );

    my $fields = BTDT::Model::Task->parse_summary($summary);
    my %updated_fields;

    foreach my $field (keys %{$fields->{explicit}}) {
        my $value = $fields->{explicit}{$field};
        if ($field eq 'tags') {
            my $parser = Text::Tags::Parser->new;
            my @tags =  $parser->parse_tags($self->argument_value('tags'));
            push @tags, $parser->parse_tags($value);
            @tags = uniq @tags;
            $value = $parser->join_tags(@tags);
        }
        $self->argument_value($field => $value);
        $updated_fields{$field} = $value;
    }

    if ($args{implicit}) {
        foreach my $field (keys %{$fields->{implicit}}) {
            my $value = $fields->{implicit}{$field};
            # XXX: dates can't get unset since we'll reparse "for thursday"
            # we special case priority because ++ and -- should update the
            # priority
            if (($field eq "priority" && $self->argument_value("priority") == 3)
             || !$self->argument_value($field)) {

                $self->argument_value($field => $value);
                $updated_fields{$field} = $value;
            }
        }
    }

    delete $updated_fields{summary};

    # TODO we really need a programmatic way of accessing label
    # and it has to work with Jifty::Param::Schema
    # $action->form_field is not it (it tries to print)
    my @updates;
    my %arguments = %{ $self->arguments };
    foreach my $field (keys %updated_fields) {
        my $new_value = $updated_fields{$field};

        # Show the user group name instead of ID
        if ($field eq 'group_id') {
            my $group = BTDT::Model::Group->new;
            $group->load($new_value);
            my $name = $group->name;
            $new_value = $name
                if defined($name)
                && $group->current_user_can('read');
        }

        push @updates, "$arguments{$field}{label} to $new_value";
    }

    if (@updates) {
        my $fields = join (", ", @updates);
        $self->canonicalization_note(summary => "Set $fields");
    }
    return $fields->{explicit}{summary};

}

1;
