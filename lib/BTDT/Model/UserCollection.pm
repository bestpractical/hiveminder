use warnings;
use strict;

=head1 NAME

BTDT::Model::UserCollection

=cut

package BTDT::Model::UserCollection;
use base qw/BTDT::Collection/;


=head2 implicit_clauses

Attempt to merge secondary accounts with primary accounts, unless the
find_alternate_emails flag is passed.

=cut

sub implicit_clauses {
    my $self = shift;
    my %args = (@_);

    $args{'alias'} ||= 'main';
    if ($args{'find_alternate_emails'}) {
        $self->log->warn("find_alternate_emails support isn't yet properly implemented.");
    } else {
        #     $self->limit(alias => $args{'alias'}, column => 'primary_account', value => $args{'alias'}.'.id', quote_value => 0);
    }

}


=head2 in_group GROUP_ID

Limit this collection to users who are members of group C<GROUP_ID>.

=cut

sub in_group {
    my $self    = shift;
    my $groupid = shift;

    unless ($groupid =~ /^\d+$/)  {
        Carp::cluck("Called in_group with a group_id of '$groupid'");
        return;
    }

    my $group_alias = $self->join(
        alias1  => 'main',
        column1 => 'id',
        table2  => 'group_members',
        column2 => 'actor_id',
        type    => 'left',
        is_distinct => 1,
    );

    $self->limit(
        alias            => $group_alias,
        column           => 'group_id',
        value            => $groupid,
        entry_aggregator => 'OR',
        subclause        => 'group'
    );
}

=head2 in_group_or_invited GROUP_ID

Limit this collection to users who are members of group C<GROUP_ID>,
or are invited into said group.

=cut

sub in_group_or_invited {
    my $self    = shift;
    my $groupid = shift;

    $self->in_group($groupid);

    my $invited_alias = $self->join(
        alias1  => 'main',
        column1 => 'id',
        table2  => 'group_invitations',
        column2 => 'recipient_id',
        type    => 'left',
        is_distinct => 1,
    );
    $self->open_paren('group');
    $self->limit(
        alias            => $invited_alias,
        column           => 'group_id',
        value            => $groupid,
        entry_aggregator => 'OR',
        subclause        => 'group'
    );
    $self->limit(
        alias            => $invited_alias,
        column           => 'cancelled',
        value            => 0,
        entry_aggregator => 'AND',
        subclause        => 'group'
    );
    $self->close_paren('group');
}

=head2 can_email

Returns a set of people which is is possible to email, for whatever
reason.

=cut

sub can_email {
    my $class = shift;
    my $self = $class->new( current_user => BTDT::CurrentUser->superuser );
    $self->limit(
        column      => 'access_level',
        value       => 'guest',
        case_sensitive => 1,
    );
    $self->limit(
        column      => 'never_email',
        value       => 0
    );
    $self->limit(
        column      => 'email_confirmed',
        value       => 1
    );
    $self->limit(
        column      => 'accepted_eula_version',
        operator    => '>=',
        value       => Jifty->config->app('EULAVersion')
    );
    return $self;
}

=head2 announce_to

Returns the set of people that announcements should be sent to.  This
is a subset of L</can_email>.

=cut

sub announce_to {
    my $class = shift;
    my $self = $class->can_email;
    $self->limit(
        column      => 'email_service_updates',
        value       => 1
    );
    $self->join(
        column1 => 'id',
        table2  => 'tasks',
        column2 => 'requestor_id',
        is_distinct => 1,
    );
    my @columns = qw/id name email access_level never_email primary_account/;
    $self->columns(@columns);
    $self->group_by(map {column => $_}, @columns);
    return $self;
}

1;
