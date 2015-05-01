package BTDT::ScheduleRepeats;
use warnings;
use strict;

use base qw/Jifty::Object/;
use BTDT::Model::TaskCollection;

=head1 NAME

BTDT::ScheduleRepeats

=cut

=head1 METHODS

=head2 new

Create a new repeat scheduler

=cut


sub new { my $class = shift; my $self = {}; bless $self=>$class; return $self; }

=head2 run PARAMHASH

Possible C<PARAMHASH> values:

=over

=item skip_time_zone

For testing, sometimes, it's best to skip the timezone check

=item adjust

Hours forward or back to run the scheduling for

=back

=cut

sub run {
    my $self = shift;
    my %args = @_;
    my $skip_time_zone = $args{'skip_time_zone'};

    my $user_time = DateTime->now->set_time_zone("UTC");
    $user_time->add( hours => -$args{adjust} ) if $args{adjust};

    my $users = BTDT::Model::UserCollection->new(current_user => BTDT::CurrentUser->superuser);
    $users->limit(
        column   => 'id',
        operator => '!=',
        value    => BTDT::CurrentUser->nobody->id,
    );

    while (my $user = $users->next) {
        eval {
            $user_time->set_time_zone($user->time_zone || "UTC");
            $self->schedule_tasks($user)
                if $skip_time_zone
                || $user_time->hour == 0;
        };
        warn "Unable to schedule tasks for " . $user->email . " (" . $user->id . ") because: $@" if $@;
    }

    return 1;
}

=head2 schedule_tasks USEROBJ

Schedule repeating tasks that I requested and are unowned or that I'm teh owner of.

=cut

sub schedule_tasks {
    my $self = shift;
    my $user = shift;

    $self->log->info("Scheduling tasks for user " . $user->email);

    my $current_user = BTDT::CurrentUser->new(id => $user->id);

    my $i_own = BTDT::Model::TaskCollection->new(current_user => $current_user);
    $i_own->from_tokens(qw(repeat_next_create before tomorrow owner me));
    while (my $task = $i_own->next) {
        $task->schedule_next_repeat;
    }

    my $unowned_requests = BTDT::Model::TaskCollection->new(current_user => $current_user);
    $unowned_requests->from_tokens(qw(repeat_next_create before tomorrow owner nobody requestor me));
    while (my $task = $unowned_requests->next) {
        $task->schedule_next_repeat;
    }
}

1;
