use warnings;
use strict;

=head1 NAME

BTDT::Model::List - describes a saved list

=cut

package BTDT::Model::List;

use base  qw( BTDT::Record );
use Jifty::DBI::Schema;
use Jifty::Record schema {

    column owner =>
        refers_to BTDT::Model::User,
        is mandatory,
        is protected;

    column name =>
        type is 'text',
        label is 'Name',
        is mandatory;

    column tokens =>
        type is 'text',
        label is 'Search tokens',
        is mandatory;

    column created =>
        type is 'timestamp',
        filters are qw( Jifty::Filter::DateTime Jifty::DBI::Filter::DateTime),
        default is defer { DateTime->now->iso8601 },
        is protected;

};


=head2 since

This first appeared in version 0.2.65

=cut

sub since { '0.2.65' }

=head2 create

Forces the owner to be the current user

=cut

sub create {
    my $self = shift;
    return $self->SUPER::create(@_, owner => $self->current_user->id);
}

=head2 current_user_can

If the user is the owner of the search, let them do what they want.  Only
pro users can create searches.

=cut

sub current_user_can {
    my $self  = shift;
    my $right = shift;
    my %args  = @_;

    if (     $self->__value('owner')
         and $self->__value('owner') == $self->current_user->id )
    {
        return 1
            unless  $right eq 'update'
                and defined $args{'column'}
                and $args{'column'} !~ /^(?:tokens|name)$/;
    }

    return 1 if $right eq 'create' and $self->current_user->pro_account;

    return 1 if $self->current_user->is_superuser;
    return 0;
}

=head2 tokens_as_url

Returns the tokens as a token URL

=cut

sub tokens_as_url {
    my $self = shift;
    return BTDT::Model::TaskCollection->join_tokens_url( $self->tokens_as_list );
}

=head2 tokens_as_list

Returns the tokens as a list

=cut

sub tokens_as_list {
    my $self = shift;
    return split ' ', $self->tokens;
}

=head2 default_lists [Pro]

Returns the default lists as an array of hashes. Pass in a boolean to indicate
whether you want pro-only lists or not (default: no). Each list will have the
following keys set:

=over 4

=item label

The short name of the list

=item url

The URL to the list as a search

=item token_url

The URL but with the leading "/list/" stripped

=item summary (optional)

The long name of the list

=item pro

Whether this list uses pro-only features

=back

=cut

sub default_lists {
    my $self = shift;
    my $include_pro = shift;

    my @lists = (
        {
            label   => 'To Do',
            url     => '/todo',
            # /todo gets it's tokens from here
            token_url => 'not/complete/owner/me/starts/before/tomorrow/accepted/but_first/nothing',
        },
        {
            label   => 'Overdue!',
            url     => '/list/owner/me/not/complete/due/before/today',
        },
        {
            label   => 'Due today',
            url     => '/list/owner/me/not/complete/due/today',
        },
        {
            label   => 'Due tomorrow',
            url     => '/list/owner/me/not/complete/due/tomorrow',
        },
        {
            label   => 'Later',
            url     => '/list/owner/me/not/complete/hidden/until/after/today',
            summary => 'All your tasks which are hidden until after today',
        },
        {
            label   => 'Unaccepted',
            url     => '/list/owner/me/unaccepted/not/complete',
            summary => "Everything new somebody else wants you to do",
        },
        {
            label   => 'My requests',
            url     => "/list/requestor/me/not/owner/me/not/complete",
            summary => "All the tasks you've asked others to complete",
        },
        {
            label   => 'Done',
            url     => '/list/owner/me/complete/sort_by/completed_at',
            summary => "All the tasks you've completed",
        },
        {
            label   => 'Repeating tasks',
            url     => '/list/owner/me/not/repeat_period/once',
            summary => "All of your repeating tasks",
        },
        {
            label   => "Hidden forever",
            url     => "/list/owner/me/hidden/forever",
            summary => "All tasks hidden forever",
        },
    );

    # pro lists
    if ($include_pro) {
        my @ranges = ( undef, '15m', '15m' => '1h', '1h' => '4h', '4h' => '8h', '8h' => undef );
        while ( my ($start, $end) = splice @ranges, 0, 2 ) {
            my $label;
            my $url = '/list/but/first/nothing/not/complete/owner/me/hidden/until/before/tomorrow';

            $url .= "/time/left/gt/$start" if defined $start;
            $url .= "/time/left/lte/$end"  if defined $end;

            if    ( not defined $start and defined $end ) { $label = "Time left < $end" }
            elsif ( defined $start and not defined $end ) { $label = "Time left > $start" }
            else                                          { $label = "Time left $start-$end" }

            push @lists, {
                label => $label,
                url   => $url,
                pro   => 1,
            };
        }

        push @lists, (
            {
                label   => 'No estimate',
                summary => 'Incomplete tasks with no time estimate',
                url     => '/list/not/complete/owner/me/time/estimate/none',
                pro     => 1,
            },
            {
                label   => 'Waiting on',
                url     => '/list/not/next/action/by/me/not/complete',
                summary => 'Collaborative tasks that you made the last comment on',
                pro     => 1,
                openloop => 1,
            },
            {
                label   => 'Needs reply',
                url     => '/list/next/action/by/me/not/complete',
                summary => 'Collaborative tasks that someone else made the last comment on',
                pro     => 1,
                openloop => 1,
            },
            {
                label   => "Needs reply, others' tasks",
                url     => '/list/next/action/by/me/not/requestor/me/not/complete',
                summary => "Collaborative tasks someone else created that you made the last comment on",
                pro     => 1,
                openloop => 1,
            },
            {
                label   => "Needs reply, my tasks",
                url     => '/list/next/action/by/me/requestor/me/not/complete',
                summary => "Collaborative tasks that you made the last comment on, that you created",
                pro     => 1,
                openloop => 1,
            },
        );
    }

    for (@lists) {
        ($_->{token_url} = $_->{url}) =~ s{^/list/}{}
            unless defined $_->{token_url};
    }

    return @lists;
}

1;
