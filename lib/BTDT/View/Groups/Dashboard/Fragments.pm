use warnings;
use strict;

package BTDT::View::Groups::Dashboard::Fragments;
use Jifty::View::Declare -base;

use List::Util qw(sum max first);
use List::MoreUtils qw(uniq mesh pairwise);
use Scalar::Util qw(blessed looks_like_number);
use Time::Duration qw(from_now concise);

our $LOCATOR = Number::RecordLocator->new;

# Standard colors
our %COLOR = (
    worked      => 'ff9900', # 003300
    left        => 'ffc266', # ffff88
    estimate    => 'a26100', # 660000
);

=head2 get_group

Gets a L<BTDT::Model::Group> object, based on the C<group_id> parameter.

=cut

sub get_group {
    my $group_id = get 'group_id';
    my $group = BTDT::Model::Group->new;
    $group->load($group_id);
    return $group;
}

=head2 get_owner

Returns a L<BTDT::Model::User> object, based on the C<owner> parameter (which can be an email address or an id).

=cut

sub get_owner {
    my $owner = get 'owner';
    my $user = BTDT::Model::User->new;
    return $user if !defined($owner);

    if ($owner =~ /^\d+$/) {
        $user->load($owner);
    }
    else {
        $user->load_by_cols(email => $owner);
    }

    return $user;
}

=head2 limited_tokens

Returns a list of tokens for by parameters group_id, project, milestone, owner,
and tokens.

=cut

sub limited_tokens {
    my @tokens;

    my $group_id = get 'group_id';
    push @tokens, group => $group_id if defined($group_id);

    push @tokens, grep { defined and length }
                  BTDT::Model::TaskCollection->split_tokens(get('tokens')||'');

    for my $type (qw(project milestone owner)) {
        my $value = get($type) or next;
        push @tokens, $type => $value;
    }

    return @tokens;
}

=head2 limited_transactions

Returns a L<BTDT::Model::TaskTransactionCollection> for the current group,
limited by any project, milestone, and/or owner parameters available.

=cut

sub limited_transactions {
    my $group = get_group;
    my $txns  = $group->transactions;

    for my $type (qw(project milestone owner)) {
        my $raw = get($type) or next;
        my $col = $type eq 'owner' ? 'created_by'  : $type;
        my $val = $type eq 'owner' ? get_owner->id : $LOCATOR->decode($raw);
        $txns->limit( column => $col, value => $val );
    }

    return $txns;
}

=head2 limited_tasks

Returns a L<BTDT::Model::TaskCollection> limited by L</limited_tokens>.

=cut

sub limited_tasks {
    my @tokens = limited_tokens;
    my $tasks = BTDT::Model::TaskCollection->new;
    $tasks->from_tokens(@tokens);

    return $tasks;
}

template 'overview' => sub {
    my $type   = get 'type';
    my $class  = 'BTDT::' . ($type eq 'owner' ? 'Model::User' : ucfirst $type);
    my $record = $class->new;
    $record->load( get 'id' );
    my $id = $record->id;

    my $extra = get 'extra';
    my $hide_actions = get('hide_actions') ? 1 : 0;

    div {{ class is 'overview yui-g' };
        div {{ class is 'yui-u first' };
             form {
                 div {{ class is 'type' };
                     ucfirst $type;
                 };
                 h1 {{ class is 'name' };
                     if ( $type eq 'owner' ) {
                         outs $record->name_or_email;
                     }
                     else {
                         my $status = $record->complete ? 'complete' : 'incomplete';
                         span {{ class is $status };
                             render_region(
                                 name     => "editable-$type",
                                 path     => '/groups/dashboard/fragments/editable_prop',
                                 arguments => {
                                     class   => 'BTDT::'.ucfirst($type),
                                     action  => 'UpdateTask',
                                     id      => $id,
                                     prop    => 'summary',
                                     edit    => 0,
                                 },
                             );
                         };
                     }
                 };
                 div {{ class is 'properties' };
                     if ( $type eq 'owner' ) {
                         div {{ class is 'email' };
                             outs $record->email;
                         } if $record->email ne $record->name_or_email;
                     }
                     else {
                         div {{ class is 'owner' };
                             span {{ class is 'property' }; _("Owner").": " };
                             render_region(
                                 name     => "editable-$type-owner",
                                 path     => '/groups/dashboard/fragments/editable_prop',
                                 arguments => {
                                     class   => 'BTDT::'.ucfirst($type),
                                     action  => 'UpdateTask',
                                     id      => $id,
                                     prop    => 'owner_id',
                                     edit    => 0,
                                 },
                             );
                         };
                         div {{ class is 'due' };
                             span {{ class is 'property' }; _("Due").": " };
                             render_region(
                                 name     => "editable-$type-due",
                                 path     => '/groups/dashboard/fragments/editable_prop',
                                 arguments => {
                                     class   => 'BTDT::'.ucfirst($type),
                                     action  => 'UpdateTask',
                                     id      => $id,
                                     prop    => 'due',
                                     edit    => 0,
                                 },
                             );
                         };
                     }
                 };
             };
             if ( $type ne 'owner' and not $hide_actions ) {
                div {{ class is 'actions' };
                    form {
                        my $complete = Jifty->web->form->add_action(
                            class   => 'UpdateTask',
                            record  => $record,
                            moniker => "complete-$type",
                        );

                        render_param(
                            $complete     => 'complete',
                            default_value => ($record->complete ? 0 : 1),
                            render_as     => 'Hidden'
                        );

                        outs_raw(
                            $complete->button(
                                label   => ( $record->complete ? 'Not complete' : 'Complete' ),
                                onclick => [{
                                    submit       => $complete,
                                    refresh_self => 1,
                                }]
                            )
                        );
                    };

                    form {
                        # XXX TODO Should this go to somewhere else?
                        Jifty->web->form->next_page( url => '/groups/'.get('group_id').'/dashboard' );

                        my $delete = Jifty->web->form->add_action(
                            class   => 'DeleteTask',
                            record  => $record,
                            moniker => "delete-$type"
                        );

                        form_submit(
                            submit  => $delete,
                            label   => 'Delete',
                            class   => 'delete',
                            onclick => qq{return confirm('Do you really want to delete this $type?');}
                        );
                    };
                };
            }
        };
        div {{ class is 'yui-u' };
            if ( $extra ) {
                div {{ class is 'overview-extra' };
                    $extra = url_base("/$extra") unless $extra =~ /^\//;
                    render_region(
                        name => 'overview-extra',
                        path => $extra
                    );
                };
            }

            div {{ class is 'links' };
            };

            if ( 0 and $type ne 'owner' ) {
                my $tasks = limited_tasks;

                my $due_in = $record->due_in;
                my $time   = $tasks->group_time_tracked( by => "owner", left => 1, worked => 0, estimate => 0);

    #            table {
    #                row {
    #                    cell { $time->{'left'} };
    #                    cell { $due_in / (60*60*24) };
    #                    cell { $record->business_seconds_until_due / 3600 };
    #                };
    #            };

                if ( $record->due and not $record->overdue and $due_in ) {
                    div {{ class is 'graph time' };
                        Jifty->web->chart(
                            renderer    => 'Google',
                            type        => 'stackedhorizontalbars',
                            width       => 350,
                            height      => (20 + 40 * scalar keys %{$time->{'owner'}}),
                            legend      => ['Time left'],
                            colors      => [qw( ffc266 )],
                            axes        => 'x,x,y',
                            labels      => [
                                'RANGE',
                                ['', 'Clock hours until due', ''],
                                [map    { $_->{'object'}->name_or_email }
                                 values %{ $time->{'owner'} } ]
                            ],
                            bar_width   => [10],
                            max_plus    => '20%',
                            markers     => [
                                {
                                    type     => 'h',
                                    color    => 'a26100',
                                    dataset  => 0,
                                    position => (round( $due_in ) / 3600),
                                    size     => 1,
                                },
                                {
                                    type  => 'r',
                                    color => 'f5f5f5',
                                    start => 'MIN',
                                    end   => (round( $due_in ) / 3600),
                                },
                            ],
                            data => [[
                                map     { round($_->{'left'}) / 3600 }
                                values %{ $time->{'owner'} }
                            ]],
                        );
                    };
                }
            }
            ""; # Fix TD bug
        };
    };
};

template 'editable_prop' => sub {
    my $class  = get('class');
    my $action = get('action');
    my $id     = get('id');
    my $prop   = get('prop');
    my $edit   = get('edit') || 0;

    my $record = $class->new;
    $record->load( $id );
    return unless $record->id;

    span {{ class is 'editable-inline' };
        if ( $edit ) {
            my $update = Jifty->web->new_action(
                class   => $action,
                moniker => "edit-property-$prop-" . Jifty->web->serial,
                record  => $record
            );

            my $run = {
                submit       => $update,
                refresh_self => 1,
                args         => { edit => 0 },
            };

            # Show the field
            outs_raw(
                $update->form_field(
                    $prop,
                    class => 'disable_enter_handler',
                    focus => 1,
                    onkeypress => [
                        # If any modifiers are pressed or the key is not
                        # enter, then don't run the region update
                        'if ( event.ctrlKey || event.metaKey || event.altKey || event.shiftKey || event.keyCode != 13 ) { return true; }',
                        $run,
                    ],
                    onchange => [ $run ],
                    onblur   => [{
                        refresh_self => 1,
                        args         => { edit => 0 },
                    }],
                )->render_widget
            );
        }
        else {
            my $label;
            if ( $prop eq 'owner_id' ) {
                $label = $record->owner->name_or_email;
            }
            elsif ( $prop eq 'due' ) {
                if ( defined $record->$prop ) {
                    $label  = $record->$prop;
                    $label .= " (". ( $record->due_in ? concise(from_now( $record->due_in )) : 'today' ).")";
                }
                else {
                    $label = 'never';
                }
            }
            else {
                $label = $record->$prop || '(none)';
            }

            hyperlink(
                label => $label,
                class => 'editable',
                onclick   => [{
                    refresh_self => 1,
                    args         => { edit => 1 },
                }]
            );
        }
    };
};

template 'breakdowns' => sub {
    my $group = get_group;

    my $display = get('display') || 'project';
    my $prefix  = get('prefix')  || '';

    my $class = 'BTDT::'.ucfirst($display).'Collection';
    my $collection = $class->new;

    #$collection->set_page_info(
    #    current_page => ( get('page') || 1 ),
    #    per_page     => 10,
    #);

    # Limit to group
    my @tokens = ( group => $group->id );
    push @tokens, grep { defined and length } $collection->split_tokens(get('tokens') || '');

    $collection->from_tokens( @tokens );

    limit_tasks_to_params($collection, display => $display);

    dl {{ class is "${display}s" };
        my @base    = ( @tokens, qw(not complete) );
        my @context = ( @base );

        for my $type (qw( project milestone owner )) {
            next if $display eq $type;
            next if not get($type);
            push @context, $type => get($type);
        }

        # Get the tracking information
        my $tasks = BTDT::Model::TaskCollection->new;
        $tasks->from_tokens( @context, 'complete' );
        my $timetracking = $tasks->group_time_tracked( by => $display );

        while ( my $i = $collection->next ) {
            my $class = $i->complete ? 'complete' : 'incomplete';

            my $base    = $i->tasks( @base );
            my $context = $i->tasks( @context );
            my $total   = $i->tasks( @context, 'complete' );

            dt {{ class is $class };
                span {{ class is 'graph' };
                    Jifty->web->chart(
                        renderer => 'Google',
                        type   => 'pie',
                        width  => 40,
                        height => 40,
                        colors => [qw( ff9900 ffc266 )],
                        data   => [[ $total->count - $context->count, $context->count ]],
                    );
                };
                hyperlink(
                    label => $i->summary,
                    url   => '/groups/'.$group->id."$prefix/$display/".$i->record_locator,
                );
            };
            dd {
                show 'item_status',
                    type    => 'open',
                    base    => $base,
                    context => $context,
                    total   => $total,
                    stats   => $timetracking->{$display}{$i->id},
            };
        }

        my $none = BTDT::Model::TaskCollection->new;
        $none->from_tokens( @context, $display => 'none' );

        if ( $none->count ) {
            my $total = BTDT::Model::TaskCollection->new;
            $total->from_tokens( @context, $display => 'none', 'complete' );

            dt {
                span {{ class is 'graph' };
                    Jifty->web->chart(
                        renderer => 'Google',
                        type   => 'pie',
                        width  => 40,
                        height => 40,
                        colors => [qw( ff9900 ffc266 )],
                        data   => [[ $total->count - $none->count, $none->count ]],
                    );
                };
                hyperlink(
                    label => _("(No %1)", $display),
                    url   => $none->search_url,
                );
            };
            dd {
                show 'item_status',
                    type    => 'open',
                    context => $none,
                    total   => $total,
                    stats   => $timetracking->{$display}{0},
            };
        }
        ""; # work around TD bug
    };

    #show 'paging', $collection;
    show 'create-record' => (
        collection => $collection,
        display    => $display,
        group      => $group->id,
    )
};

template 'create-record' => sub {
    my $self = shift;
    my %args = @_;

    my $display = $args{display};

    my $create = $args{collection}->create_from_defaults("new$display");
    div {{ class is "new-$display inline" };
        form {
            render_param(
                $create => 'summary',
                hints   => '',
                label   => ucfirst($display)
            );
            render_param( $create => 'type', render_as => 'Hidden', default_value => $display );
            render_param( $create => 'group_id', render_as => 'Hidden', default_value => $args{group});
            render_param( $create => $_, render_as => 'Hidden' )
                for qw(tags due starts owner_id priority project milestone requestor_id);
            outs_raw(
                $create->button(
                    label   => '+',
                    onclick => [{
                        submit       => $create,
                        refresh_self => 1
                    }]
                )
            );
        }
    }
};

template 'members' => sub {
    my @tokens;
    for my $type (qw(project milestone)) {
        push @tokens, $type => get($type)
            if defined get($type);
    }

    my $group = get_group;
    my $group_id = $group->id;

    dl {{ class is 'people' };
        my $members = $group->group_members;

        my $overall = BTDT::Model::TaskCollection->new;
        $overall->from_tokens( group => $group->id, not => complete => @tokens );
        my $tracking = $overall->group_time_tracked( by => "owner" );

        my @members = map {
            my ($base, $context, $total) = _owner_status_collections(
                group => $group->id,
                owner => $_->actor,
                @tokens
            );

            {
                member   => $_,
                base     => $base,
                context  => $context,
                total    => $total,
                left     => ($tracking->{owner}{$_->actor->id}{left} || 0),
            }
        } @{ $members->items_array_ref };

        if ((get('order_by')||'') eq 'time_left') {
            @members = sort { $a->{left} <=> $b->{left} } @members;
        }

        for (@members) {
            my $member = $_->{member};
            my ($base, $context, $total) = @{$_}{qw/base context total/};

            dt {
                span {{ class is 'graph' };
                    Jifty->web->chart(
                        renderer => 'Google',
                        type   => 'pie',
                        width  => 40,
                        height => 40,
                        colors => [qw( ff9900 ffc266 )],
                        data   => [[ $total->count - $context->count, $context->count ]],
                    );
                };
                hyperlink(
                    label => $member->actor->name_or_email,
                    class => "group_member group_role_".$member->role,
                    url   => "/groups/$group_id/owner/".$member->actor->email
                );
            };
            dd {
                show 'owner_status' => (
                    $base, $context, $total,
                    $tracking->{owner}{$member->actor->id} || {},
                );
            };
        }
        if ( $group->current_user_can('manage') ) {
            form {
                my $invites = $group->invitations;
                while ( my $invite = $invites->next ) {
                    my $cancel = Jifty->web->new_action(
                        class   => "UpdateGroupInvitation",
                        moniker => "invite".$invite->id,
                        arguments => { id => $invite->id }
                    );
                    dt {{ class is 'invited' };
                        hyperlink(
                            label => $invite->recipient->name_or_email,
                            class => 'group_member group_role_invited',
                            url   => "/groups/$group_id/owner/".$invite->recipient->email
                        );
                    };
                    dd {
                        outs( _("Pending...") );
                    };
                }
            };
        }
    };

    my $hide_invite = get('hide_invite');

    if ( !$hide_invite && $group->current_user_can("manage") ) {
        div {{ class is 'invite inline' };
            my $invite = Jifty->web->new_action(
                class       => 'InviteToGroup',
                moniker     => 'invite',
                arguments   => { group => $group->id }
            );
            form {
                render_param( $invite => 'email' );
                outs_raw(
                    $invite->button(
                        label   => '+',
                        onclick => [{
                            submit       => $invite,
                            refresh_self => 1
                        }]
                    )
                );
            }
        }
    }
};

template 'owners' => sub {
    my $group  = get('group_id');
    my $prefix = get('prefix') || '';

    my $people     = BTDT::Model::UserCollection->new;
    my $task_alias = $people->new_alias( BTDT::Model::Task->table() );

    $people->order_by({ column => 'name', order => 'asc' });

    # Limit to owners
    $people->join(
        alias1  => 'main',
        column1 => 'id',
        alias2  => $task_alias,
        column2 => 'owner_id',
    );

    # Limit to group tasks
    $people->limit(
        alias   => $task_alias,
        column  => 'group_id',
        value   => $group
    );
    $people->limit(
        alias   => $task_alias,
        column  => 'type',
        value   => 'task'
    );

    my @tokens = ( group => $group );
    # Limit to a specific project and/or milestone
    for my $type (qw( project milestone )) {
        next unless defined get($type);
        $people->limit(
            alias  => $task_alias,
            column => $type,
            value  => $LOCATOR->decode( get($type) )
        );
        push @tokens, $type => get($type);
    }

    # Join with group members to prefetch each user's role
    # if they are a group member
    my $member_alias = $people->join(
        type    => 'left',
        alias1  => 'main',
        column1 => 'id',
        table2  => BTDT::Model::GroupMember->table,
        column2 => 'actor_id'
    );
    $people->limit(
        leftjoin => $member_alias,
        column   => 'group_id',
        value    => $group
    );
    $people->prefetch(
        alias => $member_alias,
        name  => 'membership',
        class => 'BTDT::Model::GroupMember'
    );

    if ( not $people->count ) {
        p {{ class is 'note' };
            _("To add owners, give them new tasks below or assign them to existing ones.");
        };
    }

    my $tasks = BTDT::Model::TaskCollection->new;
    $tasks->from_tokens( @tokens );
    my $tracking = $tasks->group_time_tracked( by => "owner" );

    dl {{ class is 'people' };
        while ( my $owner = $people->next ) {
            my $membership = $owner->prefetched('membership');
            my $role = $membership->id ? $membership->role : 'invited';

            my @tokens = (
                group => $group,
                owner => $owner,
            );

            for my $type (qw(project milestone)) {
                push @tokens, $type => get($type)
                    if defined get($type);
            }

            my ( $base, $context, $total ) = _owner_status_collections(@tokens);

            dt {
                span {{ class is 'graph' };
                    Jifty->web->chart(
                        renderer => 'Google',
                        type   => 'pie',
                        width  => 40,
                        height => 40,
                        colors => [qw( ff9900 ffc266 )],
                        data   => [[ $total->count - $context->count, $context->count ]],
                    );
                };
                hyperlink(
                    label => $owner->name,
                    class => "group_member group_role_$role",
                    url   => "/groups/$group$prefix/owner/".$owner->email
                );
            }
            dd {
                show 'owner_status' => (
                    $base, $context, $total,
                    $tracking->{owner}{$owner->id} || {},
                );
            };
        }
    };
};

sub _owner_status_collections {
    my %args = (@_);

    my @base = (
        'group'  => $args{'group'},
        'not'    => 'complete',
        'owner'  => $args{'owner'}->email,
    );

    my @context = ( @base );

    for my $type (qw( project milestone )) {
        next unless defined $args{$type};
        push @context, $type, $args{$type};
    }

    my $base = BTDT::Model::TaskCollection->new;
    $base->from_tokens( @base );

    my $context = BTDT::Model::TaskCollection->new;
    $context->from_tokens( @context );

    my $total = BTDT::Model::TaskCollection->new;
    $total->from_tokens( @context, 'complete' );

    return ( $base, $context, $total );
}

private template 'owner_status' => sub {
    my $self    = shift;
    my $base    = shift;
    my $context = shift;
    my $total   = shift;
    my $stats   = shift;

    show 'item_status',
        type    => 'open',
        base    => $base,
        context => $context,
        total   => $total,
        stats   => $stats,
};

private template 'item_status' => sub {
    my $self = shift;
    my %args = ( @_ );

    my $type    = $args{'type'};
    my $base    = $args{'base'};
    my $context = $args{'context'};
    my $total   = $args{'total'};

    show 'time-graph', $args{stats};

    hyperlink(
        label => _("%1 $type", $context->count),
        url   => $context->search_url,
    );

    if ( defined $total and $context->count != $total->count ) {
        outs(_(" of "));
        hyperlink(
            label => _("%1 total", $total->count),
            url   => $total->search_url,
        );
    }

    if ( defined $base and $context->count < $base->count ) {
        outs(" ");
        hyperlink(
            label => _("(%1 $type elsewhere)",
                       $base->count - $context->count ),
            url   => $base->search_url,
        );
    }
};

private template 'time-graph' => sub {
    my $self  = shift;
    my $tracking = shift;
    my $worked   = $tracking->{'worked'}   || 0;
    my $left     = $tracking->{'left'}     || 0;
    my $estimate = $tracking->{'estimate'} || 0;

    my $diff = $estimate - ( $worked + $left );

    return if not $worked and not $left and not $estimate;

    my @title = (
        rounded_duration( $worked )   . " worked",
        rounded_duration( $left )     . " left",
        rounded_duration( $estimate ) . " estimated",
    );

    # Under estimate or on time
    if ( $diff >= 0 ) {
        unshift @title, ( $diff ? rounded_duration( $diff ) . " under" : "On time" );
    }
    # Over estimate
    else {
        unshift @title, rounded_duration( abs($diff) ) . " over";
    }

    div { attr { class => 'graph time', title => join(' / ', @title) };
        Jifty->web->chart(
            renderer    => 'Google',
            type        => 'stackedhorizontalbars',
            width       => 150,
            height      => 10,
            colors      => [qw( ff9900 ffc266 )],
            bar_width   => [ 4, 0, 2 ],
            max_plus    => '10%',
            data        => [map { [round($_) / 3600] } ($worked, $left)],
            markers     => [
                {
                    type     => 'h',
                    color    => 'a26100',
                    dataset  => 0,
                    position => (round( $estimate ) / 3600),
                    size     => 1,
                },
                {
                    type  => 'r',
                    color => 'f5f5f5',
                    start => 'MIN',
                    end   => (round( $estimate ) / 3600),
                },
            ],
        );
    };
    div {
        outs( shift @title );
        outs( " / " . join(' / ', map { s/ ([wle])\w+$//; uc($1).": $_" } splice(@title, 0, 2)) );
    };
};

template 'status' => sub {
    my $tasks = limited_tasks;
    my @tokens = $tasks->tokens;

    div {{ class is 'status' };
        h2 { _("Status") };

        table {{ class is 'tasks' };
            caption { _("Tasks") };

            my $started = BTDT::Model::TaskCollection->new;
            $started->from_tokens( @tokens, qw(not complete time worked gt 0 ) );

            my $unstarted = BTDT::Model::TaskCollection->new;
            $unstarted->from_tokens( @tokens, qw(not complete time worked none ) );

            my $complete = BTDT::Model::TaskCollection->new;
            $complete->from_tokens( @tokens, qw(complete) );

            my $legend = [
                ( $complete->count  ? 'Complete'     : '' ),
                ( $started->count   ? 'In Progress'  : '' ),
                ( $unstarted->count ? 'Unstarted'    : '' ),
            ];

            thead {
                row {
                    cell {{ colspan is 3 };
                        div {{ class is 'graph tasks' };
                            Jifty->web->chart(
                                renderer => 'Google',
                                type   => 'pie',
                                width  => 200,
                                height => 75,
                                legend => $legend,
                                colors => [qw( ff9900 ffc266 ffebcc )],
                                data   => [[ $complete->count, $started->count, $unstarted->count ]],
                            );
                        };
                    };
                };
                row {
                    cell {{ class is 'in-progress' }; _("In Progress") };
                    cell {{ class is 'unstarted' };   _("Unstarted") };
                    cell {{ class is 'complete'  };   _("Complete") };
                };
            };
            tbody {
                row {
                    cell {{ class is 'open-tasks in-progress-tasks' };
                        hyperlink(
                            label => $started->count,
                            url   => $started->search_url,
                        );
                    };
                    cell {{ class is 'open-tasks unstarted-tasks' };
                        hyperlink(
                            label => $unstarted->count,
                            url   => $unstarted->search_url,
                        );
                    };
                    cell {{ class is 'complete-tasks' };
                        hyperlink(
                            label => $complete->count,
                            url   => $complete->search_url,
                        );
                    };
                };
            };
        };
        my $tracking = $tasks->aggregate_time_tracked;

        table {{ class is 'timetracking' };
            caption { _("Time") };
            thead {
                row {
                    cell {{ colspan is 3 };
                        div {{ class is 'graph time' };
                            Jifty->web->chart(
                                renderer    => 'Google',
                                type        => 'stackedhorizontalbars',
                                width       => 200,
                                height      => 57,
                                colors      => [qw( ff9900 ffc266 )],
                                axes        => 'x,x',
                                labels      => [ 'RANGE', ['','Hours',''] ],
                                bar_width   => [10],
                                max_plus    => '20%',
                                markers     => [
                                    {
                                        type     => 'h',
                                        color    => 'a26100',
                                        dataset  => 0,
                                        position => (round( $tracking->{'Estimate'} ) / 3600),
                                        size     => 1,
                                    },
                                    {
                                        type  => 'r',
                                        color => 'f5f5f5',
                                        start => 'MIN',
                                        end   => (round( $tracking->{'Estimate'} ) / 3600),
                                    },
                                ],
                                data        => [
                                    [ round( $tracking->{'Total worked'} ) / 3600 ],
                                    [ round( $tracking->{'Time left'} )    / 3600 ],
                                ],
                            );
                        };
                    };
                };
                row {
                    cell {{ class is 'worked' };   _("Worked") };
                    cell {{ class is 'left' };     _("Left") };
                    cell {{ class is 'estimate' }; _("Estimated") };
                };
            };
            tbody {
                row {
                    cell {{ class is 'worked' };
                        hyperlink(
                            label => rounded_duration($tracking->{"Total worked"} || 0),
                            url   => '/list/'.BTDT::Model::TaskCollection->join_tokens_url( @tokens, qw(time worked gt 0) )
                        );
                    };
                    cell {{ class is 'left' };
                        hyperlink(
                            label => rounded_duration( $tracking->{"Time left"} || 0 ),
                            url   => '/list/'.BTDT::Model::TaskCollection->join_tokens_url( @tokens, qw(not complete time left gt 0) )
                        );
                    };
                    cell {{ class is 'estimate' };
                        outs(rounded_duration($tracking->{"Estimate"} || 0));
                    };
                }
            };
        };

        div {{ class is 'time-overview' };
            my $diff =   $tracking->{'Time left'}
                       + $tracking->{'Total worked'}
                       - $tracking->{'Estimate'};

            if ( $diff == 0 ) {
                outs(_("Right on the original estimate"));
            }
            else {
                my $verb;

                if ( $diff < 0 ) {
                    $verb = "under";
                    $diff *= -1;
                }
                else {
                    $verb = '<span class="negative">over</span>';
                }

                outs_raw(
                    _("A projected %1 the original estimate",
                      "<strong>".
                      rounded_duration( $diff ).
                      " ".$verb."</strong>" )
                );
            }
        };

        my $none = BTDT::Model::TaskCollection->new;
        $none->from_tokens( @tokens, qw(time estimate none not complete) );

        if ( $none->count ) {
            div {{ class is 'no-estimate' };
                hyperlink(
                    label => _( "%quant(%1,open task has,open tasks have) no estimate", $none->count ),
                    url   => $none->search_url,
                );
                outs(".");
            };
        }

        my $none_complete = BTDT::Model::TaskCollection->new;
        $none_complete->from_tokens( @tokens, qw(time estimate none complete) );

        if ( $none_complete->count ) {
            div {{ class is 'no-estimate-complete' };
                hyperlink(
                    label => _( "%quant(%1,complete task has,complete tasks have) no estimate", $none_complete->count ),
                    url   => $none_complete->search_url,
                );
                outs(".");
            };
        }

        show 'time_left';
    };
};

template 'tasklist' => sub {
    my $self   = shift;
    my %args = (
        tokens => [],
        @_
    );

    # Join the tokens together for the fragment
    $args{'tokens'} = BTDT::Model::TaskCollection->join_tokens( qw(not complete), @{$args{'tokens'}} );

    my $lazy = exists $args{'lazy'} ? delete($args{lazy}) : 1;

    h2 { _(delete($args{header}) || "Tasks") }
    div {{ class is 'tasklist' };
        form {
            render_region(
                name     => (delete $args{name}) || Jifty->web->serial,
                path     => '/fragments/tasklist/list',
                defaults => {
                    page          => 1,
                    item_path     => '/fragments/tasklist/view',
                    new_item_path => '/fragments/tasklist/new_item_expands',
                    refresh_on_create => 'dashboardstatus owners',
                    #hide_actions     => 1,
                    maybe_show_group => 1,
                    show_project     => 1,
                    show_milestone   => 1,
                    show_list_link   => 1,
                    %args,
                },
                lazy => $lazy,
                loading_path => '/fragments/loading'
            );
        }
    };
};

private template 'paging' => sub {
    my $self = shift;
    my $collection = shift;

    div {{ class is 'paging' };
        if ( $collection->pager->previous_page ) {
            span{{ class is 'prev-page' };
                hyperlink(
                    label   => "Previous page",
                    onclick => {
                        args => {
                            page => $collection->pager->previous_page
                        }
                    }
                );
            };
        }
        if ( $collection->pager->next_page ) {
            span{{ class is 'next-page' };
                hyperlink(
                    label   => "Next page",
                    onclick => {
                        args => {
                            page => $collection->pager->next_page
                        }
                    }
                );
            };
        }
    };
};

template 'time_left' => sub {
    my $url = url_base(
        '/fragments/graph/time_left',
        {
            graph       => get('graph'),
            hide_header => get('hide_header'),
        },
    );

    redirect_chart($url);
};

template 'graph/time_left' => sub {
    my $tasks = limited_tasks;

    my %degree;
    for my $type (qw( project milestone owner )) {
        my $value = get($type) or next;
        $degree{$type} = $value;
    }

    my $graph = get 'graph';

    if (!defined($graph)) {
        # we need at least one degree of freedom to be able to graph
        return if keys %degree == 3;

        # if we're missing both project and milestone, which do we graph?
        # neither!
        return if !$degree{project} && !$degree{milestone};

        # what are we going to graph?
        for (qw(project milestone owner)) {
            $graph = $_ and last if !defined($degree{$_});
        }
    }

    # collect data
    my %time_left;
    if ($graph eq 'owner') {
        my %time_tracking = %{ $tasks->group_time_tracked( by => "owner", left => 1, worked => 0, estimate => 0 ) };
        for my $owner_id (keys %{ $time_tracking{owner} }) {
            my $user_time = $time_tracking{owner}{$owner_id};
            my $name = $user_time->{object}->name;
            $time_left{$name} = $user_time->{left};
        }
    }
    elsif ($graph eq 'project' || $graph eq 'milestone') {
        my %time_tracking = %{ $tasks->group_time_tracked( by => $graph, left => 1, worked => 0, estimate => 0 ) };
        for my $id (keys %{ $time_tracking{$graph} }) {
            my $obj = $time_tracking{$graph}{$id}{object};
            my $display = $obj->id ? $obj->summary : 'none';
            $time_left{$display} += $time_tracking{$graph}{$id}{left} || 0;
        }
    }

    # don't display empty slices
    for (keys %time_left) {
        delete $time_left{$_} if !$time_left{$_};
    }

    # %time_left is now a mapping of name to (integer) time left

    return if keys %time_left == 0;

    # graph it!
    h3 { "Time left by $graph" } unless get('hide_header');

    my @keys = sort keys %time_left;
    Jifty->web->chart(
        renderer => 'Google',
        type     => 'pie',
        width    => 250,
        height   => 75,
        colors   => [qw( ff9900 ) x @keys],
        legend   => [ @keys ],
        data     => [[ @time_left{@keys} ]],
        redirect => 1,
    );
};

sub limit_tasks_to_params {
    my $collection = shift;
    my %args = @_;

    my $display = $args{display};

    my %inverse = (
        project   => 'milestone',
        milestone => 'project',
    );

    my $alias;

    # If we want to limit to a certain project/milestone, do that
    for my $type (qw( project milestone )) {
        next if defined($display) && $display ne $inverse{$type};
        next if not get($type);

        # Setup an alias if we don't have one
        $alias = $collection->new_alias( BTDT::Model::Task->table )
            unless defined $alias;

        $collection->task_search_on( $alias, tokens => $type => get($type) );
    }

    # Limit to a certain user if we want
    if (my $owner_id = get_owner->id) {
        if ( not defined $alias ) {
            # Setup an alias since we don't have one
            $alias = $collection->new_alias( BTDT::Model::Task->table );

            # We haven't joined on a specific project or milestone yet either,
            # so limit items to be what we want displayed
            $collection->join(
                alias1  => 'main',
                column1 => 'id',
                alias2  => $alias,
                column2 => $display
            );
        }

        $collection->limit(
            alias   => $alias,
            column  => 'owner_id',
            value   => $owner_id,
        );
    }

    return $collection;
}

template 'analysis' => sub {
    my $group_id = get('group_id');
    my $brief    = get('brief');
    my $size     = get('size');

    my $url = url_base('/fragments/graph/analysis');

    my @args;
    push @args, 'brief=1' if $brief;
    push @args, "size=$size" if defined $size;
    $url .= '?' . join('&', @args) if @args;

    div {{ class is 'graph-container' };
        redirect_chart($url);
    };
};

template 'graph/analysis' => sub {
    my $t = time_tracking_summary();

    date_chart(
        dates  => [short_dates(@{$t->{dates}})],
        graphs => [
            {
                data  => $t->{worked_sum},
                color => $COLOR{worked},
                label => 'Worked',
                type  => 'area',
            },
            {
                data  => $t->{worked_left},
                color => $COLOR{left},
                label => 'Left',
                type  => 'area',
            },
            {
                data  => $t->{estimate},
                color => $COLOR{estimate},
                label => 'Estimate',
                type  => 'lines',
            },
        ],
    );
};

template 'timeline' => sub { analysis_timeline() };

template 'assign' => sub {
    my @tokens = (limited_tokens, qw(owner nobody not complete));

    div {{ class is 'yui-gc' };
        div {{ class is 'yui-u first' };
            show 'tasklist' => (
                tokens => \@tokens,
            );
        };

        div {{ class is 'yui-u people' };
            h2 { _('Members') };
            render_region(
                name     => 'members',
                path     => '/groups/dashboard/fragments/members',
                defaults => {
                    group_id    => get('group_id'),
                    milestone   => get('milestone'),
                    project     => get('project'),
                    hide_invite => 1,
                    order_by    => 'time_left',
                }
            );
        };
    };
};

=head2 time_tracking_summary

Returns a hash of time tracking information by date (C<YYYY-MM-DD>). Group,
project, milestones, owner, and tokens are all taken from the environment.

=cut

sub time_tracking_summary {
    my $tasks = limited_tasks;

    my $time_tracking = $tasks->group_time_tracked(
        by => "modified_date",
    )->{modified};

    my ($start, $end);
    my %args = $tasks->arguments;
    if (my $milestone_id = $args{milestone}) {
        my $milestone = BTDT::Milestone->new;
        $milestone->load_by_locator($milestone_id);

        $start = $milestone->starts;
        $end = $milestone->completed_at
            || $milestone->due;
    }

    if (!$start || !$end) {
        my @txn_dates = sort keys %$time_tracking;
        $start ||= $txn_dates[0];
        $end   ||= $txn_dates[-1];
    }

    my @dates = fill_in_dates($start => $end);

    # worked needs no massaging
    my @worked = map { $time_tracking->{$_}{worked} || 0 } @dates;

    # convert deltas to absolutes
    my @estimate = 0;
    for my $date (@dates) {
        push @estimate, $estimate[-1] + ($time_tracking->{$date}{estimate} || 0);
    }
    shift @estimate;

    my @left = 0;
    for my $date (@dates) {
        push @left, ($time_tracking->{$date}{left} || 0) + $left[-1];
    }
    shift @left;

    # calculate the time worked thus far
    # need to make sure we don't access $worked_sum[-1] when it's empty
    my @worked_sum = 0;
    for (0 .. @worked - 1) {
        $worked_sum[$_+1] = $worked_sum[$_] + $worked[$_];
    }
    shift @worked_sum;

    my @worked_left;
    for my $i (0 .. @worked - 1) {
        push @worked_left, $worked_sum[$i] + $left[$i];
    }

    return {
        dates       => \@dates,
        worked      => \@worked,
        worked_sum  => \@worked_sum,
        left        => \@left,
        estimate    => \@estimate,
        worked_left => \@worked_left,
    };
}

=head2 fill_in_dates first[, ...], last

Returns all the dates between first and last (inclusive). The input and output
are strings of the form C<YYYY-MM-DD>.

=cut

sub fill_in_dates {
    my $first = shift;
    my $last  = pop;

    $first = $first->ymd('-')
        if $first && blessed($first) && $first->isa('DateTime');
    $last = $last->ymd('-')
        if $last && blessed($last) && $last->isa('DateTime');

    # special cases ($first may be undef)
    return if !defined($first) && !defined($last);
    return $first if !defined($last);
    return $last  if !defined($first);

    my ($first_dt, $last_dt) = map {
        my ($y, $m, $d) = split '-', $_;
        my $dt = DateTime->new(
            year      => $y,
            month     => $m,
            day       => $d,
            hour      => 0,
            minute    => 0,
            second    => 0,
            time_zone => 'floating',
        );
    } ($first, $last);

    my @dates;

    # add each day between first and last (inclusive) to @dates
    my $dt = $first_dt->clone;
    while ($dt <= $last_dt) {
        push @dates, $dt->ymd;
        $dt = $dt->add(days => 1);
    }

    return @dates;
}

=head2 date_chart graphs => [...], dates => [...]

Returns the HTML of a time tracking chart. Each graph is a hash of C<type>
(graph type, e.g. lines, bars, area); color (in RRGGBB hex); label; and data.

=cut

sub date_chart {
    my %args = @_;

    my @graphs = @{ $args{graphs} };

    my $brief = get 'brief';
    $args{'size'} = get 'size' if defined get 'size';

    my $size = $brief ? '100x50' : '600x400';
    my $type = $brief ? 'ls' : 'lc';

    # Use the specified size if we're passed one
    $size = $args{'size'} if $args{'size'} and $args{'size'} =~ /\d+x\d+/;

    my $max = max map { grep { defined } @{ $_->{data} } } @graphs;

    # make maximum an integer number of hours
    $max = round_hours($max);

    $max ||= 1; # if all the data is 0 then it's okay if we divide by 1

    my %opts = (
        renderer    => 'Google',
        type        => $type,
        ( mesh @{[qw(width height)]}, @{[split('x', $size, 2)]} ),
        encoding    => 'simple',
        max_value   => $max,
        # For some reason line charts don't respect missing data points as the
        # doc makes it seem they should, so make undef values 0
        data        => [map { [map { defined $_ ? $_ : 0 } @{$_->{'data'}}] } @graphs],
        colors      => [map { $_->{'color'} } @graphs],
    );

    if ( @graphs == 3 ) {
        $opts{'markers'} = [
            { type => 'b', color => $graphs[1]->{'color'}, dataset => 1, position => 3 },
            { type => 'b', color => $graphs[0]->{'color'}, dataset => 0, position => 3 },
        ];
        push @{$opts{'data'}}, [0,0];
    }

    if (!$brief) {
        # label axes
        $opts{'legend'} = [map { $_->{'label'} } @graphs];
        $opts{'axes'} = 'x,r,x';
        $opts{'labels'} = [];

        my $POINTS = 10;
        if (@{ $args{dates} } > 1.5 * $POINTS) {

            # figure out where each tick goes..
            for (my $i = 0; $i < @{ $args{dates} }; ++$i) {
                $args{dates}[$i] = [
                    $i / $#{ $args{dates} },
                    $args{dates}[$i],
                ];
            }

            # remove enough dates so that we have approximately $POINTS
            my $remove_every = int(@{ $args{dates} } / $POINTS);
            my $count = 0;

            for (my $i = 1; $i < @{ $args{dates} } - 1;) {
                if (++$count % $remove_every == 0) {
                    ++$i;
                    next;
                }

                splice @{ $args{dates} }, $i, 1;
            }
        }

        push @{$opts{'labels'}}, [map { ref($_) ? $_->[1] : $_ } @{ $args{dates} }];

        # ten ticks, 10% 20% 30% .. 90% 100%
        push @{$opts{'labels'}}, ['', map { rounded_duration($max * $_ * .1) } 1 .. 10];

        #if ($brief) {
        #    # only the watermark..
        #    $chart .= rounded_duration($max);
        #}

        # Add general axis label
        push @{$opts{'labels'}}, ['', 'Date', ''];

        # add label positions if necessary
        $opts{'positions'} = [[map { int(100 * $_->[0]) } @{ $args{dates} }]]
            if ref $args{dates}[0];
    }

    my $chart = Jifty->web->chart( %opts, want_url => 1 );

    if ( $args{'image'} ) {
        redirect_chart($chart);
    } else {
        Jifty->web->_redirect($chart);
    }
}

template 'group-management' => sub {
    my $group_id = get('group_id');

    div {{ class is 'yui-gb' };
        div {{ class is 'yui-u first' };
            show 'milestone-graphs';
            show 'project-graphs';
        }
        div {{ class is 'yui-u' };
            show 'latest-tasks';

            h2 { "Latest updates" };
            show 'latest-updates';
        }
        div {{ class is 'yui-u' };
            h2 { "Work left by project" };
            show 'work-by-project';

            h2 { "Work completed this week" };
            show 'workweek-by-owner';
        }
    }
};

template 'graph-list' => sub {
    my $graph = get('graph');
    my $group = get_group;
    my $group_id = $group->id;
    my $collection;

    my @objects;
    my $listing;
    my $construct_link = sub { };

    if ($graph eq 'milestones') {
        $listing = 'milestone';

        my $milestones = $group->milestones;
        $milestones->order_by({
                column => 'completed_at',
                order => 'desc',
            },
            {
                column => 'created',
                order  => 'desc',
            },
        );

        @objects = map { [$_, $_->record_locator, $_->summary] } @$milestones;
        $collection = $milestones;

        $construct_link = sub {
            my $milestone = shift;
            my $milestone_id = $milestone->record_locator;

            return "/groups/$group_id/dashboard/milestone/$milestone_id/milestone-overview";
        };
    }
    elsif ($graph eq 'projects') {
        $listing = 'project';

        my $projects = $group->projects;
        $projects->incomplete;
        @objects = map { [$_, $_->record_locator, $_->summary] } @$projects;
        $collection = $projects;

        $construct_link = sub {
            my $project = shift;
            my $project_id = $project->record_locator;

            return "/groups/$group_id/dashboard/project/$project_id/project-overview";
        };
    }
    elsif ($graph eq 'owners') {
        $listing = 'owner';

        my $members = $group->members;
        @objects = map { [$_, $_->email, $_->name] } @$members;
        $collection = $members;

        $construct_link = sub {
            my $user = shift;
            my $email = $user->email;

            return "/groups/$group_id/dashboard/owner/$email/about-member";
        };
    }
    else {
        warn "Invalid graph target '$graph'";
        return;
    }

    my @tokens;
    for my $type (qw( project milestone owner )) {
        next if $type eq $listing;
        next if not get($type);
        push @tokens, $type => get($type);
    }

    h2 { ucfirst $graph };

    if ( my $link_to = get 'link_to' ) {
        my @link_to = split '-', $link_to;

        # avoid an edge case with the current value being at the end and the
        # desired value at the start
        push @link_to, @link_to;

        while (my $find = shift @link_to) {
            if ($find eq $listing) {
                my $link = shift @link_to;

                span {{ class is 'switch-graph-list' };
                    hyperlink(
                        label   => "Show ${link}s",
                        onclick => {
                            replace_with => "/groups/dashboard/fragments/$link-graphs",
                        }
                    );
                };
                last;
            }
        }
    }

    my $old_listing_value = get $listing;

    ul {{ class is "$listing-graphs graph-list" };
        for (@objects) {
            my ($obj, $id, $display) = @$_;

            li {
                my $tasks = BTDT::Model::TaskCollection->new;
                $tasks->from_tokens(@tokens, $listing => $id);

                my $time_tracking = $tasks->aggregate_time_tracked;
                my $worked = duration_in_seconds($time_tracking->{"Total worked"});
                my $estimate = duration_in_seconds($time_tracking->{"Estimate"});

                my $nodata = ($worked or $estimate) ? 0 : 1;

                my $url = $construct_link->($obj);

                span {{ class is 'subject' };
                    if ($url) {
                        outs hyperlink(
                            label => $display,
                            url   => $url,
                        );
                    }
                    else {
                        outs $display;
                    }
                };

                span {{ class is 'time-tracking' };
                    for ($worked, $estimate) {
                        # round times above 1h to hours
                        $_ = round_hours($_) if $_ > 3600;

                        # turn seconds into words
                        $_ = BTDT::Model::Task->concise_duration($_);
                    }

                    outs sprintf ' %s of %s',
                        $worked || '0s',
                        $estimate || '0s';
                };

                set $listing => $id;

                unless ( $nodata ) {
                    set height => '100';
                    set width  => '100%';
                    set brief  => 1;
                    show 'analysis';
                }
            }
        }
    };

    show 'create-record' => (
        collection => $collection,
        display    => $listing,
        group      => $group_id,
    ) unless $listing eq 'owner';

    set $listing => $old_listing_value;
};

template 'milestone-graphs' => sub {
    set graph => 'milestones';
    show 'graph-list';
};

template 'project-graphs' => sub {
    set graph => 'projects';
    show 'graph-list';
};

template 'owner-graphs' => sub {
    set graph => 'owners';
    show 'graph-list';
};

template 'latest-tasks' => sub {
    my $group_id = get('group_id');

    div {{ class is 'dashboard-tasklist' };
        show 'tasklist' => (
            tokens        => [group => $group_id, sort_by => 'created'],
            brief         => 1,
            hide_feeds    => 1,
            hide_actions  => 1,
            hide_sorting  => 1,
            hide_creators => 1,
            per_page      => 5,
            header        => "Latest tasks",
            read_only     => 1,
        );
    }
};

template 'latest-updates' => sub {
    my $show = get('show') || 5;

    render_region(
        name      => "recent_transactions",
        path      => "/groups/dashboard/fragments/recent_transactions",
        arguments => {
            show => $show,
        },
    );
};

template 'recent_transactions' => sub {
    my $txns = limited_transactions;

    $txns->order_by(
        column => 'modified_at',
        order  => 'desc',
    );
    $txns->set_page_info(
        current_page => 1,
        per_page     => 5,
    );

    dl {{ class is 'transactions' };
        while (my $txn = $txns->next) {
            my $summary = $txn->summary;
            next if !$summary;
            my $author = $txn->author;

            div {{ class is "transaction" };
                dt {
                    my $id = $txn->task->record_locator;
                    my $label = sprintf '#%s: %s', $id, $txn->task->summary;

                    hyperlink(
                        label => $label,
                        url   => "/task/$id",
                    );
                };

                if ($txn->type eq "update") {
                    my $changes = $txn->visible_changes;
                    while (my $change = $changes->next) {
                        my $description = $change->as_string;
                        next unless $description;
                        dd { "$author $description" }
                    }
                }
                else {
                    dd { $summary }
                }
            }
        }
    };
};

template 'work-by-project' => sub {
    my $group_id = get('group_id');

    set graph       => 'project';
    set hide_header => 1;

    show('time_left');
};

template 'workweek-by-owner' => sub {
    redirect_chart(url_base('/fragments/graph/workweek-by-actor'));
};

template 'graph/workweek-by-actor' => sub {
    my $tasks = limited_tasks;

    my $start = DateTime->now(time_zone => 'UTC')
                        ->subtract(days => 6)
                        ->truncate(to => 'day');

    my $time_tracking = $tasks->group_time_tracked(
        by       => "owner",
        after    => $start->iso8601,
        worked   => 1,
        left     => 0,
        estimate => 0,
    );

    # we only care about breakdown by user, not the aggregates
    $time_tracking = $time_tracking->{owner};

    my @users  = @{ get_group->members->items_array_ref };
    my @worked = map { $time_tracking->{ $_->id }{worked} || 0 } @users;

    bar_chart(
        data      => { pairwise { $a->name => $b } @users => @worked },
        redirect  => 1,
    );
};

template 'milestone-overview' => sub {
    my $group_id     = get('group_id');
    my $milestone_id = get('milestone');

    my $milestone = BTDT::Milestone->new;
    $milestone->load_by_locator($milestone_id);

    if (!$milestone->complete) {
        p {
            hyperlink(
                label => 'Schedule',
                url   => "/groups/".get('group_id')."/dashboard/milestone/".$milestone->record_locator."/schedule-milestone",
            );
        }
    }

    div {{ class is 'yui-gc' };
        div {{ class is 'yui-u first' };
            render_region(
                name => 'timeline',
                path => '/groups/dashboard/fragments/timeline',
                defaults => {
                    group_id  => $group_id,
                    milestone => $milestone_id,
                },
            );
        }
        div {{ class is 'yui-u' };
            render_region(
                name => 'graph-list',
                path => '/groups/dashboard/fragments/owner-graphs',
                defaults => {
                    group_id  => $group_id,
                    milestone => $milestone_id,
                    link_to   => 'owner-project',
                },
            );
        }
    }
};

template 'schedule-milestone' => sub {
    my $group_id  = get('group_id');
    my $milestone = get('milestone');

    div {{ class is 'yui-g' };
        div {{ class is 'yui-u' };
            render_region(
                name => 'schedule_time_tracking',
                path => '/groups/dashboard/fragments/schedule-time-tracking',
                defaults => {
                    group_id  => $group_id,
                    milestone => $milestone,
                },
            );
        };
        div {{ class is 'yui-u first' };
            div {{ class is 'dashboard-tasklist' };
                my $refresh = join ' ', Jifty->web->qualified_region('schedule_time_tracking'),
                                        # XXX hardcoded for now...
                                        'overview-overview-extra';

                show 'tasklist' => (
                    header => 'Unscheduled tasks',
                    tokens        => [
                        group     => $group_id,
                        not       => 'complete',
                        milestone => 'none',
                        sort_by   => 'project',
                    ],
                    item_path           => '/fragments/tasklist/view_schedule',
                    tasklist_class      => 'tasklist schedule_tasklist',
                    brief               => 1,
                    hide_feeds          => 1,
                    hide_actions        => 1,
                    schedule_for        => $LOCATOR->decode($milestone),
                    refresh_on_schedule => $refresh,
                    lazy                => 0,
                    break_by_sorting    => 1,
                );
            }
        };
    };
};

template 'time-tracking-summary' => sub {
    my $tasks = limited_tasks;
    my $time_tracking = $tasks->aggregate_time_tracked;
    my $worked = duration_in_seconds($time_tracking->{"Total worked"});
    my $estimate = duration_in_seconds($time_tracking->{"Estimate"});

    my $nodata = ($worked or $estimate) ? 0 : 1;
    my $header = get('type') ? ucfirst(get('type').' status') : 'Status';

    h2 { "$header" };

    unless ( $nodata ) {
        set size  => '120x60';
        set brief => 1;
        show 'analysis';
    }

    div {{ class is 'time-tracking' };
        for ($worked, $estimate) {
            # round times above 1h to hours
            $_ = round_hours($_) if $_ > 3600;

            # turn seconds into words
            $_ = BTDT::Model::Task->concise_duration($_);
        }

        outs sprintf '%s of %s',
            $worked || '0s',
            $estimate || '0s';
    };
};

template 'schedule-time-tracking' => sub {
    h2 { "People" };
    redirect_chart(url_base('/fragments/graph/people-timeleft'));
    show 'members-detailed';

    h2 { "Projects" };
    redirect_chart(url_base('/fragments/graph/projects-timeleft'));
    show 'projects-detailed';
};

template 'graph/people-timeleft' => sub {
    my $group = get_group;

    my $tasks = limited_tasks;

    # XXX These should be merged into one query, not two
    my $time_tracking = $tasks->group_time_tracked( by => "owner", left => 1, worked => 0, estimate => 0 );
    my $x_factor      = $tasks->x_factor_by_owner;

    my %time_left_for;

    my $members = $group->members;
    while (my $user = $members->next) {
        my $name = $user->name;
        my $id   = $user->id;
        my $x    = $x_factor->{$id};

        $time_left_for{$name} = $time_tracking->{owner}{$id}{left} || 0;
        $time_left_for{$name} *= $x if $x;
    }

    my @labels = sort keys %time_left_for;
    my @data   = @time_left_for{@labels};

    bar_chart(
        data     => { mesh @labels => @data },
        redirect => 1,
    );
};

template 'graph/projects-timeleft' => sub {
    my $group = get_group;

    my @tokens = limited_tokens;

    my %time_left_for;

    my $projects = $group->projects;
    while (my $project = $projects->next) {
        my $summary = $project->summary;

        my $tasks = BTDT::Model::TaskCollection->new;
        $tasks->from_tokens(@tokens, project => $project->record_locator);

        # XXX These should be merged into one query, not two
        my $time_tracking = $tasks->group_time_tracked( by => "owner", left => 1, estimate => 0, worked => 0 )->{owner};
        my $x_factor      = $tasks->x_factor_by_owner;

        for my $id (keys %{ $time_tracking }) {
            my $time = $time_tracking->{$id}{left};

            if (my $x = $x_factor->{$id}) {
                $time *= $x;
            }

            $time_left_for{$summary} += $time;
        }
    }

    my @labels = sort keys %time_left_for;
    my @data   = @time_left_for{@labels};

    bar_chart(
        data     => { mesh @labels => @data },
        redirect => 1,
    );
};

template 'members-detailed' => sub {
    my $group = get_group;

    my @tokens = limited_tokens;

    my $one_month_ago = BTDT::DateTime->now->subtract(months => 1)->ymd;

    dl {{ class is 'people' };
        my $members = $group->group_members;

        while (my $member = $members->next) {
            my $tasks = BTDT::Model::TaskCollection->new;
            $tasks->from_tokens(@tokens, owner => $member->actor->email);

            my $tracking = $tasks->aggregate_time_tracked;

            my ($worked, $left) =
                map { rounded_duration($_) }
                ($tracking->{'Total worked'}, $tracking->{'Time left'});

            my $x_tasks = BTDT::Model::TaskCollection->new;
            $x_tasks->from_tokens(
                @tokens,
                owner              => $member->actor->email,
                completed => after => $one_month_ago,
            );
            my $x = $x_tasks->x_factor_by_owner->{$member->actor->id};

            div {{ class is 'person' };
                dt {
                    hyperlink(
                        label => $member->actor->name_or_email,
                        class => "group_member group_role_".$member->role,
                        url   => "/groups/".$group->id."/dashboard/owner/".$member->actor->email
                    );
                }
                dd {
                    my $count = $tasks->count;

                    hyperlink(
                        label => $count == 1 ? "1 task" : "$count tasks",
                        url => $tasks->search_url,
                    );

                    outs ',';

                    outs sprintf ' %s / %s, X: %.2f',
                        $worked,
                        $left,
                        $x;
                }
            };
        }
    };
};

template 'projects-detailed' => sub {
    my $group = get_group;

    my @tokens = limited_tokens;

    ul {{ class is 'projects' };
        my $projects = $group->projects;

        while (my $project = $projects->next) {
            my $tasks = BTDT::Model::TaskCollection->new;
            $tasks->from_tokens(@tokens, project => $project->record_locator);

            my $tracking = $tasks->aggregate_time_tracked;

            my ($worked, $left) =
                map { rounded_duration($_) }
                ($tracking->{'Total worked'}, $tracking->{'Time left'});

            li {
                span {{ class is 'subject' };
                    hyperlink(
                        label => $project->summary,
                        url   => "/groups/".$group->id."/dashboard/project/" . $project->record_locator . "/project-overview",
                    );
                }
                span {{ class is 'project-details' };
                    my $count = $tasks->count;

                    hyperlink(
                        label => $count == 1 ? "1 task" : "$count tasks",
                        url => $tasks->search_url,
                    );

                    outs ',';

                    outs sprintf ' %s / %s',
                        $worked,
                        $left,
                }
            };
        }
    };
};

template 'project-overview' => sub {
    my $group_id = get('group_id');
    my $owner = get_owner;

    show 'project-links';

    div {{ class is 'yui-gb' };
        div {{ class is 'yui-u first' };
            show 'milestone-graphs';
            show 'owner-graphs';
        }
        div {{ class is 'yui-u' };
            show 'time-tracking-summary';

            div {{ class is 'dashboard-tasklist' };
                show 'tasklist' => (
                    tokens        => [
                        group     => $group_id,
                        project   => get('project'),
                        not       => 'complete',
                    ],
                    brief             => 1,
                    hide_feeds        => 1,
                    hide_actions      => 1,
                    hide_creators     => 1,
                    read_only         => 1,
                    show_context_menu => 0,
                    reassign          => 0,
                    prioritize_assign => 0,
                );
            };
        }
        div {{ class is 'yui-u' };
            h2 { "Hours worked" };
            set brief => 1;
            a {{ href is 'time-worked' };
                show 'hours-worked' => (
                    since => DateTime->now->subtract(months => 1)
                );
            };

            h2 { "Latest updates" };
            render_region(
                name => 'latest-updates',
                path => '/groups/dashboard/fragments/latest-updates',
                defaults => {
                    show => 15,
                },
            );
        }
    }
};

template 'about-member' => sub {
    my $group_id = get('group_id');
    my $owner = get_owner;

    show 'owner-links';

    div {{ class is 'yui-gb' };
        div {{ class is 'yui-u first' };
            show 'milestone-graphs';
            show 'project-graphs';
        }
        div {{ class is 'yui-u' };
            h2 { "Hours worked" };
            set brief => 1;
            a {{ href is 'time-worked' };
                show 'hours-worked' => (
                    since => DateTime->now->subtract(months => 1)
                );
            };

            div {{ class is 'dashboard-tasklist' };
                show 'tasklist' => (
                    tokens        => [
                        group     => $group_id,
                        owner     => $owner->email,
                        not       => 'complete',
                    ],
                    brief             => 1,
                    hide_feeds        => 1,
                    hide_actions      => 1,
                    hide_creators     => 1,
                    show_context_menu => 0,
                    reassign          => 1,
                    prioritize_assign => 1,
                );
            };
        }
        div {{ class is 'yui-u' };
            h2 { "Estimate accuracy" };
            show 'estimate-accuracy';

            h2 { "Latest updates" };
            render_region(
                name => 'latest-updates',
                path => '/groups/dashboard/fragments/latest-updates',
                defaults => {
                    show => 15,
                },
            );
        }
    }
};

template 'hours-worked' => sub {
    my $self = shift;
    my %args = @_;

    # transactions.. in this group and limited by available tokens
    my $txns = limited_transactions;

    # ..in this interval
    my $since = $args{since} || DateTime->now->subtract(weeks => 1);
    $since->set_time_zone('UTC');
    $txns->between(
        starting => $since,
        ending   => DateTime->now(time_zone => 'UTC'),
    );

    $txns->columns('id', 'time_worked', 'modified_at');

    # XXX: doesn't work for various reasons
    #$txns->group_by({ function => "ymd(main.modified_at)" });

    my %worked;

    while (my $txn = $txns->next) {
        my $date = $txn->modified_at->ymd;
        $worked{$date} += $txn->time_worked || 0;
    }

    my @dates = fill_in_dates($since->ymd, (sort keys %worked)[-1]);

    date_chart(
        dates  => [short_dates(@dates)],
        graphs => [
            {
                data  => [ @worked{@dates} ],
                color => $COLOR{worked},
                label => 'Worked',
                type  => 'area',
            },
        ],
        image  => 1,
        ( get 'brief' ? (size => '200x100') : ()),
    );
};

template 'estimate-accuracy' => sub {
    span { "This is random.  Ignore it for now." };
    ul {
        for my $said_estimate (1, 8, 40) {
            my $adjusted_estimate = int($said_estimate * rand(2)) || 1;
            li {
                my $tasks = limited_tasks;
                outs _("%quant(%1,hour) means %quant(%2,hour)", $said_estimate, $adjusted_estimate);
            }
        }
    }
};

my %day_intervals = (
    7   => 'week',
    30  => 'month',
    60  => '2 months',
    90  => 'quarter',
    365 => 'year',
);

template 'time-worked' => sub {
    my $interval = get('interval') || 30;

    my $name = $day_intervals{$interval} || "$interval days";
    h2 { "Time worked over the past $name " };

    show 'selection' => (
        possibilities => [ sort { $a <=> $b } keys %day_intervals ],
        preamble      => 'Show days: ',
        current       => $interval,
        name          => 'interval',
    );

    set brief => 0;
    show 'hours-worked' => (
        since => DateTime->now->subtract(days => $interval)
    );
};

template 'selection' => sub {
    my $self = shift;
    my %args = @_;

    my @possibilities = @{ $args{possibilities} };
    my $name          = $args{name};
    my $current       = $args{current} || get($name) || $possibilities[0];
    my $preamble      = $args{preamble};

    div {
        outs $preamble;
        my @out;

        for my $linked (@possibilities) {
            if ($linked eq $current) {
                push @out, $linked;
            }
            else {
                push @out, sub {
                    hyperlink(
                        label   => $linked,
                        onclick => {
                            refresh_self => 1,
                            args => {
                                $name => $linked,
                            },
                        },
                    )
                };
            }
        }

        while (my $out = shift @out) {
            if (ref($out)) {
                outs_raw $out->();
            }
            else {
                outs $out;
            }

            outs ' - ' if @out;
        }
    };
};

template 'weekly-transactions' => sub {
    my $type = get 'type';

    show "$type-links" if $type =~ /owner|project/;

    my $now = BTDT::DateTime->now;

    my $date_string = sub {
        my $dt = shift;
        my $hide_year = shift;

        if (!defined($hide_year)) {
            $hide_year = $dt->year == $now->year;
        }

        my $out = sprintf '%s %d', $dt->month_name, $dt->day;
        if (!$hide_year) {
            $out .= ', ' . $dt->year;
        }

        return $out;
    };

    my $start;

    if (get('start')) {
        my ($y, $m, $d) = split '-', get 'start';

        $start = BTDT::DateTime->new(
            time_zone => 'floating',
            year   => $y,
            month  => $m,
            day    => $d,
            hour   => 0,
            minute => 0,
            second => 0,
        );
    }
    else {
        $start = $now->clone;
        $start->truncate(to => 'day');

        # flip back until Monday
        $start = $start->subtract(days => 1) until $start->dow == 1;
    }

    my $start_ymd = $start->ymd;

    my $end = $start->clone->add(days => 6);
    my $end_ymd = $end->ymd;

    p {
        hyperlink(
            label => "Prev week",
            onclick => {
                refresh_self => 1,
                args => {
                    start => $start->clone->subtract(days => 7)->ymd,
                },
            },
        );

        outs " -- ";

        my $hide_year = $start->year == $now->year
                     && $end->year   == $now->year;

        outs $date_string->($start, $hide_year);
        outs " - ";
        outs $date_string->($end, $hide_year);

        outs " -- ";

        hyperlink(
            label => "Next week",
            onclick => {
                refresh_self => 1,
                args => {
                    start => $start->clone->add(days => 7)->ymd,
                },
            },
        );
    };

    my $dt = $start->clone;

    for (1 .. 7) {
        my $txns = limited_transactions;

        my $utc = $dt->clone;
        $utc->set_time_zone('UTC');
        my $utc_end = $utc->clone->add(days => 1)->subtract(seconds => 1);

        $txns->limit(
            column           => 'modified_at',
            case_sensitive   => 1,
            operator         => '>=',
            value            => $utc->iso8601,
            entry_aggregator => 'AND'
        );
        $txns->limit(
            column           => 'modified_at',
            case_sensitive   => 1,
            operator         => '<=',
            value            => $utc_end->iso8601,
            entry_aggregator => 'AND'
        );

        $txns->order_by(
            { column => 'task_id' },
            { column => 'modified_at' },
        );

        my @tasks;
        my %task_transactions;
        my $worked = 0;

        while (my $txn = $txns->next) {
            my $id = $txn->task_id;

            push @tasks, $txn->task
                if !@tasks
                || $tasks[-1]->id != $id;

            $worked += $txn->time_worked || 0;
            push @{ $task_transactions{$id} }, $txn;
        }

        h2 {
            $dt->day_name . ', ' . $date_string->($dt)
            . ' (worked ' . rounded_duration($worked) . ')'
        };

        for my $task (@tasks) {
            h3 {
                my $label = '#' . $task->record_locator
                          . ' - '
                          . $task->summary;

                hyperlink(
                    label => $label,
                    url   => '/task/' . $task->record_locator,
                )
            }

            dl {{ class is 'transactions' }
                for my $txn (@{ $task_transactions{$task->id} }) {
                    my $summary = $txn->summary;
                    next unless $summary;

                    div {{ class is 'transaction' }
                        dt { $summary . ' at ' . $txn->modified_at->hms };
                        if ($txn->type eq 'update') {
                            my $author  = $txn->author;
                            my $changes = $txn->visible_changes;
                            if ($changes->count > 1) {
                                while (my $c = $changes->next) {
                                    my $description = $c->as_string;
                                    next unless $description;
                                    dd { $description }
                                }
                            }
                        }
                    }
                }
            }
        }

        if (@tasks == 0) {
            p { "No changes made." }
        }

        $dt = $dt->clone->add(days => 1);
    }
};

template 'tasks' => sub {
    my $sort = get('sort') || 'default';

    # XXX: make this a dropdown
    show 'selection' => (
        possibilities => [qw/ default due priority milestone project /],
        preamble      => 'Sort by: ',
        current       => $sort,
        name          => 'sort',
    );

    my @tokens = limited_tokens;
    push @tokens, sort_by => $sort unless $sort eq 'default';

    show 'tasklist' => (
        tokens            => \@tokens,
        hide_creators     => 1,
        reassign          => 1,
        prioritize_assign => 1,
    );
};

template 'owner-links' => sub {
    Jifty->log->warn("Not an owner-primary view!")
        unless get('type') eq 'owner';
    show 'subview-links';
};

template 'project-links' => sub {
    Jifty->log->warn("Not a project-primary view!")
        unless get('type') eq 'project';
    show 'subview-links';
};

template 'subview-links' => sub {
    my $type = get 'type';
    my $overview = $type eq 'owner'     ? '/about-member'     :
                   $type eq 'project'   ? '/project-overview' :
                                          ''                  ;

    div {{ class is 'links' };
        ul {
            li {
                hyperlink(
                    label => 'Overview',
                    url   => url_base($overview),
                );
            }
            li {
                hyperlink(
                    label => 'Time Worked',
                    url   => url_base("/time-worked"),
                );
            }
            li {
                hyperlink(
                    label => 'Latest Updates',
                    url   => url_base("/weekly-transactions"),
                );
            }
            li {
                hyperlink(
                    label => 'Tasks',
                    url   => url_base("/tasks"),
                );
            }
        }
    };
};

=head2 bar_chart data => { label1 => value1, label2 => value2, ... }

Sets up all of the defaults for a bar chart

=cut

sub bar_chart {
    my %args = @_;
    my $data = delete $args{data};

    my $height = scalar keys(%$data) * 26 + 30;

    my @markers = sort keys %$data;
    my $max = max values %$data;
    $max ||= 1;

    my @labels = map {
        my $scaled = $max * $_ / 5;

        # only round if we have a lot of hours, to avoid "1h 1h 1h 2h 2h" type
        # graphs
        my $rounded = $max >= 10 * 3600 ? round_hours($scaled) : $scaled;

        [ int(100 * $rounded / $max), rounded_duration($rounded) ]
    } 0 .. 5;

    Jifty->web->chart(
        renderer     => 'Google',
        type         => 'horizontalbars',
        height       => $args{height} || $height,
        width        => $args{width}  || 200,
        bar_width    => [20,3],
        zero_line    => 0,
        data         => [ [ @{$data}{@markers} ] ],
        axes         => 'x',
        labels       => [ [ map { $_->[1] } @labels ] ],
        positions    => [ [ map { $_->[0] } @labels ] ],
        markers      => [
            map { {
                type     => 't',
                position => $_,
                text     => $markers[$_],
                size     => 10,
            } }
            0 .. @markers - 1,
        ],
        %args,
    );
}

=head2 annotated_timeline

Render an annotated timeline

=cut

sub annotated_timeline {
    my %args = @_;

    Jifty->web->chart(
        renderer => 'GoogleViz::AnnotatedTimeline',

        # golden rectangle :)
        width  => '500px',
        height => '309px',

        %args,
    );
}

=head2 pie_chart labels => [...], data => [...]

Sets up all of the defaults for a pie chart

=cut

sub pie_chart {
    my %args = @_;

    Jifty->web->chart(
        type => 'pie',
        width  => get('width')  || '100%',
        height => get('height') || '200',
        options => {
            chart_rect => { x => 50, y => 0, width => 200, height => 200 },
            chart_pref   => { rotation_x => 60 },
            chart_grid_h => { thickness  => 0 },
            legend_label => {
                size   => '11',
                layout => 'horizontal',
                bullet => 'circle',
                color  => '000000'
            },
            legend_rect => {
                x              => 280,
                y              => 10,
                height         => 10,
                width          => 50,
                margin         => '10',
                fill_color     => 'ffffff',
                line_thickness => 0
            },
            chart_value => {
                position      => 'outside',
                size          => '11',
                color         => '808080',
                as_percentage => 'true'
            },
        },
        data => [ $args{labels}, ['', @{ $args{data} }] ],
    );
}

=head2 short_dates YYYY-MM-DD ...

Accepts a list of long dates and shortens them all with L<short_date>.

=cut

sub short_dates {
    map { short_date($_) } @_
}

=head2 short_date YYYY-MM-DD -> M/D

Returns the short form of a date, useful if your graph spans only a few recent
dates

=cut

sub short_date {
    my $date = shift;

    my ($y, $m, $d) = split '-', $date;
    $m =~ s/^0//;
    $d =~ s/^0//;

    return "$m/$d";
}

=head2 rounded_duration SECONDS -> STRING

Returns a concise, rounded duration.

=cut

sub rounded_duration { BTDT::Model::Task->rounded_duration(@_) }

=head2 duration_in_seconds STRING -> SECONDS

Returns the duration as seconds.

=cut

sub duration_in_seconds { BTDT::Model::Task->duration_in_seconds(@_) }

=head2 round SECONDS -> SECONDS

Rounds the number of seconds to the nearest minute.

=cut

sub round { duration_in_seconds(rounded_duration(shift || 0)) }

=head2 round_hours SECONDS -> SECONDS

Rounds the number of seconds to the nearest hour

=cut

sub round_hours { 3600 * int((shift() + 1800) / 3600) }

=head2 url_base fragment

Returns a URL formed from region parameters such as:

/groups/1/dashboard/owner/me/project/foo

You may specify arguments to be appended to this URL base. Any hash reference
will be used to specify query parameters.

=cut

sub url_base {
    my $group_id = get('group_id');
    my $url = "/groups/$group_id/dashboard";

    for my $key (qw(owner project milestone)) {
        my $value = get $key;
        $url .= "/$key/$value" if defined $value;
    }

    $url .= join '/', grep { !ref $_ } @_;

    my %p = map { %$_ } grep { ref $_ } @_;
    $url .= '?' . Jifty->web->query_string(%p) if keys %p;

    return $url;
}

=head2 redirect_chart URL[, class]

Places an image tag to the specified URL (which usually ends with a redirect to
Google charts).

=cut

sub redirect_chart {
    my $url = shift;
    my $class = shift || 'dashboard graph';

    img {
        class is $class;
        src is $url;
        border is '0';
    };
}

=head2 analysis_timeline


=cut

sub analysis_timeline {
    my %args = @_;

    my $t = time_tracking_summary();

    annotated_timeline(
        %args,
        columns => [
            date       => 'date',
            "Hours Worked" => 'number',
            Left       => 'number',
            Estimated  => 'number',
        ],
        options => {
            colors => [ map { "#$_" } @COLOR{qw(worked left estimate)} ],
            displayZoomButtons => 0,
        },
        data => [
            map { {
                date       => $t->{dates}[$_],
                "Hours Worked" => $t->{worked_sum}[$_] / 3600,
                Left       => $t->{worked_left}[$_] / 3600,
                Estimated  => $t->{estimate}[$_] / 3600,
            } } 0 .. @{ $t->{dates} } - 1
        ],
    );
}


1;
