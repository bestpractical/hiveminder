use warnings;
use strict;

package BTDT::Action::AcceptTask;
use base qw/BTDT::Action Jifty::Action::Record::Update/;
use BTDT::Action::ArgumentCacheMixin;

=head1 NAME

BTDT::Action::AcceptTask

=cut

=head2 record_class

This updates C<BTDT::Model::Task> objects.

=cut

sub record_class{'BTDT::Model::Task'}

=head2 arguments

This action takes an 'accepted' and an 'id'

=over

=item accepted

=over

=item accept

=item reject

=item ignore

=back

=back

=cut

sub arguments {
    my $self = shift;

    my $default = '';
    $default = $self->record->accepted if $self->record->id and defined $self->record->accepted;

    my @options = (
                   { display => 'accept', value => '1' },
                   { display => 'decline', value => '0' },
                  );

    push @options, { display => 'ignore', value => '', label => 'still thinking' }
      unless (length $default);

    return
    {   id       => { constructor => 1 },
        accepted => {
            valid_values => \@options,
            default_value => $default,
            render_as     => 'Radio',
            label => 'Take your pick.',
            hints => 'First things first - accept or decline this task.'
        }
    };
}

=head2 report_success

Give them a specific "task accepted" or "task declined".

=cut

sub report_success {
    my $self = shift;
    $self->result->message( $self->record->accepted ? "Task accepted" : "Task declined" );
}

=head2 take_action

Invalidate the argument cache

=cut

sub take_action {
    my $self = shift;
    $self->SUPER::take_action or return;
    BTDT::Action::ArgumentCacheMixin->invalidate_cache($self->record);

    return 1;
}

1;
