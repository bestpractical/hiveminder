use warnings;
use strict;

=head1 NAME

BTDT::Model::TaskHistory

=head1 DESCRIPTION

Represents a change of a single value of a task.  It records
information about the state of the task before and after the change.

Task histories include a reference to the task the change was on, the
field that changed, and the old and new values of the field.
Additionally, changes are grouped into L<BTDT::Model::TaskTransaction>
objects, which record a group of changes that happened at once, or are
somehow related.

=cut

package BTDT::Model::TaskHistory;
use BTDT::Model::User;

use base qw( BTDT::Record );
use Jifty::DBI::Schema;
use BTDT::Model::TaskTransaction;

sub is_protected {1}
use Jifty::Record schema {

column task_id        =>
  refers_to BTDT::Model::Task,
  label is 'Task',
  is immutable;
column field          =>
  type is 'varchar',
  label is 'Field',
  is immutable;
column old_value      =>
  type is 'text',
  label is 'Old value',
  is immutable;
column new_value      =>
  type is 'text',
  label is 'New value',
  is immutable;
column transaction_id =>
  refers_to BTDT::Model::TaskTransaction,
  label is 'Transaction',
  is immutable;

};

use Jifty::RightsFrom column => 'task';

=head2 since

This table first appeared in C<0.1.8>.

=cut

sub since { '0.1.8' }

=head2 field_display

Return the display name of the I<field>.  Used in as_string.

=cut

sub field_display {
    my $self  = shift;
    my $field = $self->field;

    if ( $field eq 'time_estimate' ) {
        $field = 'the initial time estimate';
    }
    elsif ( $field =~ /time_(worked|left)/ ) {
        $field = "the time $1";
    }
    elsif ( $field eq 'starts' ) {
        $field = 'hidden until'
    }

    return $field;
}

=head2 new_value_display

Return the display value of the I<new_value>.  Used in as_string.

=cut

sub new_value_display { return shift->_value_display('new_value'); }

=head2 old_value_display

Return the display value of the I<old_value>.  Used in as_string.

=cut

sub old_value_display { return shift->_value_display('old_value'); }

sub _value_display {
    my $self  = shift;
    my $type  = shift;
    my $value = $self->$type;

    if ( $self->field =~ /time_(?:estimate|worked|left)/ ) {
        $value = $self->task->concise_duration( $value );
    }
    elsif ( $self->field =~ /^(?:project|milestone)$/ ) {
        my $class  = "BTDT::".ucfirst($self->field);
        my $record = $class->new;
        $record->load( $value );
        $value = $record->id ? $record->summary : '(none)';
    }
    return $value;
}

=head2 as_string

Return a human readable string for this task update

=cut

sub as_string {
    my $self = shift;
    my %args = @_;

    # Skip transactions "started by the superuser"
    return undef if $self->transaction->__value('created_by') == BTDT::CurrentUser->superuser->id;

    my $type = $self->task->type;
    my $the_task = "the $type";
    if ($args{show_task_locator}) {
        $the_task = "$type #" . BTDT::Record->record_locator($self->task_id);
    }

    if ( $self->field eq "complete" ) {
        return
             ( $self->new_value ? "finished $the_task" : "marked $the_task as incomplete" );

    }
    elsif ( $self->field eq "owner_id" ) {
        my $from = BTDT::Model::User->new();
        $from->load_by_cols( id => $self->old_value );
        my $to = BTDT::Model::User->new();
        $to->load_by_cols( id =>$self->new_value );

        if ($from->id eq BTDT::CurrentUser->nobody->id) {
                if ($to->id eq $self->transaction->created_by->id) {
                    return "took $the_task";
                }
                else {
                    return "gave $the_task to ". ($to->name ||'') . " <" . ($to->email ||''). ">";
                }

        } elsif ($to->id eq BTDT::CurrentUser->nobody->id) {
                if ($from->id eq $self->transaction->created_by->id) {
                    return "gave up $the_task";
                } else {
                    return "took $the_task away from ".$from->name ." <".$from->email."> and gave it up";
                }
        } elsif ($to->id eq $self->transaction->created_by->id) {
            return "took $the_task from " . ( $from->name ||''). " <" . ($from->email ||''). ">";
        } elsif ($from->id eq $self->transaction->created_by->id) {
            return "gave $the_task to " . ( $to->name ||''). " <" . ($to->email ||''). ">";
        }


        return "changed owner of $the_task from "
            . ( $from->name ||''). " <"
            . ($from->email ||''). "> to "
            . ($to->name ||'') . " <"
            . ($to->email ||''). ">";
    }
    elsif ( $self->field eq "priority" ) {
        return "changed priority of $the_task from "
            . $self->task->text_priority($self->old_value)
            . " to "
            . $self->task->text_priority($self->new_value);
    }
    elsif ( $self->field eq "accepted" ) {
        return undef if not defined $self->new_value;
        return "accepted $the_task" if $self->new_value;
        return "declined $the_task";
    }
    elsif ( $self->field eq "tags" ) {
        # Round-trip through parser to remove extra quotes
        my $parser = Text::Tags::Parser->new;
        return "changed tags of $the_task from '"
            . $parser->join_tags( sort $parser->parse_tags( $self->old_value ) )
            . "' to '"
            . $parser->join_tags( sort $parser->parse_tags( $self->new_value ) )
            . "'";
    }
    elsif ( $self->field eq "group_id" ) {
        my $from = "personal tasks";
        if ($self->old_value) {
            my $from_obj = BTDT::Model::Group->new();
            $from_obj->load_by_cols( id => $self->old_value );
            $from = $from_obj->name || $from_obj->id;
        }
        my $to = "personal tasks";
        if ($self->new_value) {
            my $to_obj = BTDT::Model::Group->new();
            $to_obj->load_by_cols( id => $self->new_value );
            $to = $to_obj->name || $to_obj->id;
        }
        return "moved $the_task from $from to $to";
    } elsif ( $self->field =~ /(?:completed_at|(?:depended_on_by|depends_on)_(?:summaries|count|ids))/ ) {
        return undef;
    } elsif ( $self->field eq "description" ) {
        return "updated ${the_task}'s notes";
    } elsif ( $self->field eq "next_action_by" ) {
        return undef;
    } elsif ( $self->field eq "repeat_next_create" ) {
        return undef;
    } elsif ( $self->field eq "last_repeat" ) {
        return undef;
    } elsif ( $self->field eq 'attachment_count' ) {
        return undef;
    } elsif ( $self->field eq 'will_complete' ) {
        return ( ( not $self->new_value or $self->new_value eq 'f' ) ? 'hid' : 'unhid' ) . " $the_task forever";
    } elsif ( $self->field eq 'starts' and not $self->old_value ) {
        return "hid $the_task until " . $self->new_value;
    }
    elsif ( $self->field eq 'time_worked' ) {
        my $worked = $self->new_value;

        if ( $self->old_value ) {
            $worked = $self->task->duration_in_seconds( $self->new_value )
                        - $self->task->duration_in_seconds( $self->old_value );
            $worked .= ' seconds';
        }

        return "worked on $the_task for " . $self->task->concise_duration( $worked );
    }
    else {
        if (!$self->old_value) {  # Prettier display for initial setting of a field
            return "set ". $self->field_display . " of $the_task to '" . $self->new_value_display . "'";
        } else {
            return
                "changed ". $self->field_display
                . " of $the_task from '"
                . ( $self->old_value_display || '')
                . "' to '"
                . ($self->new_value_display || '') . "'";
        }
    }
}

1;
