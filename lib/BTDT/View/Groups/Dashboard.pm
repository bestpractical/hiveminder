use warnings;
use strict;

=head1 NAME

BTDT::View::Groups::Dashboard

=cut

package BTDT::View::Groups::Dashboard;
use Jifty::View::Declare -base;
__PACKAGE__->use_mason_wrapper;

use List::MoreUtils qw(mesh pairwise);

require BTDT::View::Groups::Dashboard::Fragments;
alias BTDT::View::Groups::Dashboard::Fragments under 'fragments/';

###
### First version of dashboard views
###

template 'index.html' => page {
    title    => 'Group ' . get('group')->name,
    subtitle => 'Dashboard'
} content {
    my $group = get('group');

    div {{ class is 'links' };
        ul {
            li {
                hyperlink(
                    label => 'Group Management',
                    url   => "/groups/".$group->id."/dashboard/group-management",
                );
            }
        }
    };

    div {{ class is 'projects-dashboard' };
        div {{ class is 'yui-gb' };
            div {{ class is 'yui-u first' };
                h2 { _('Projects') };
                render_region(
                    name     => 'projectlist',
                    path     => '/groups/dashboard/fragments/breakdowns',
                    defaults => {
                        group_id => $group->id,
                        display  => 'project',
                    }
                );
            };
            div {{ class is 'yui-u' };
                h2 { _('Milestones') };
                render_region(
                    name     => 'milestonelist',
                    path     => '/groups/dashboard/fragments/breakdowns',
                    defaults => {
                        group_id => $group->id,
                        display  => 'milestone',
                    }
                );
            };
            div {{ class is 'yui-u people' };
                h2 { _('Members') };
                render_region(
                    name     => 'owners',
                    path     => '/groups/dashboard/fragments/members',
                    defaults => { group_id => $group->id }
                );
            };
        };
    };
};

template 'breakdown' => page {
    title    => 'Group ' . get('group')->name,
    subtitle()
} content {
    my $group     = get('group');
    my $type      = get('type');
    my $breakdown = get('record');
    my $locator   = get('locator');

    my %displaymap = (
        project   => 'milestone',
        milestone => 'project',
    );

    div {{ class is 'projects-dashboard' };
        render_region(
            name     => 'overview',
            path     => '/groups/dashboard/fragments/overview',
            defaults => {
                type     => $type,
                id       => $breakdown->id,
                group_id => $group->id,
                $type    => $locator,
            }
        );

        div {{ class is 'yui-gb' };
            div {{ class is 'yui-u first' };
                h2 { _(ucfirst($displaymap{$type})."s") };
                render_region(
                    name     => "${type}list",
                    path     => '/groups/dashboard/fragments/breakdowns',
                    defaults => {
                        group_id  => $group->id,
                        display   => $displaymap{$type},
                        $type     => $locator,
                        prefix    => "/$type/$locator"
                    }
                );
            };
            div {{ class is 'yui-u people' };
                h2 { _('Owners') };
                render_region(
                    name => 'owners',
                    path => '/groups/dashboard/fragments/owners',
                    defaults => {
                        group_id => $group->id,
                        $type    => $locator,
                        prefix   => "/$type/$locator",
                    }
                );
            };
            div {{ class is 'yui-u' };
                render_region(
                    name => 'dashboardstatus',
                    path => '/groups/dashboard/fragments/status',
                    defaults => {
                        group_id => $group->id,
                        $type    => $locator,
                    }
                );
            };
        };

        show(
            '/groups/dashboard/fragments/tasklist',
            tokens => [
                group   => $group->id,
                $type   => $locator,
                sort_by => $displaymap{$type},
            ],
        );
    };
};

template 'owner' => page {
    title    => 'Group ' . get('group')->name,
    subtitle(),
} content {
    my $group   = get('group');
    my $type    = get('type');
    my $owner   = get('record');
    my $email   = get('locator');

    div {{ class is 'projects-dashboard' };
        render_region(
            name     => 'overview',
            path     => '/groups/dashboard/fragments/overview',
            defaults => {
                type     => $type,
                id       => $owner->id,
                group_id => $group->id,
                $type    => $email,
            }
        );

        div {{ class is 'yui-gb' };
            div {{ class is 'yui-u first' };
                h2 { _("Projects") };
                render_region(
                    name     => "project-list",
                    path     => '/groups/dashboard/fragments/breakdowns',
                    defaults => {
                        group_id    => $group->id,
                        display     => 'project',
                        $type       => $email,
                        prefix      => "/$type/$email"
                    }
                );
            };
            div {{ class is 'yui-u' };
                h2 { _("Milestones") };
                render_region(
                    name     => "milestone-list",
                    path     => '/groups/dashboard/fragments/breakdowns',
                    defaults => {
                        group_id    => $group->id,
                        display     => 'milestone',
                        $type       => $email,
                        prefix      => "/$type/$email"
                    }
                );
            };
            div {{ class is 'yui-u' };
                render_region(
                    name => 'dashboardstatus',
                    path => '/groups/dashboard/fragments/status',
                    defaults => {
                        group_id => $group->id,
                        $type    => $email,
                    }
                );
            };
        };

        show(
            '/groups/dashboard/fragments/tasklist',
            tokens => [
                group   => $group->id,
                $type   => $email,
                sort_by => 'progress',
            ],
        );
    };
};

template 'two-of-three' => page {
    title    => 'Group ' . get('group')->name,
    subtitle()
} content {
    my $group = get('group');

    my @conditions = mesh @{ get('views') }, @{ get('locators') };
    my $prefix     = '/' . join '/', @conditions;

    my ($left) = grep { not exists { @conditions }->{$_} }
                 qw( project milestone owner );

    # Poor man's pluralization
    my $class = $left.'s';
    my $title = ucfirst $class;

    div {{ class is 'projects-dashboard' };
        render_region(
            name     => 'overview',
            path     => '/groups/dashboard/fragments/overview',
            defaults => {
                type     => get('type'),
                id       => get('record')->id,
                group_id => $group->id,
                @conditions,
            }
        );

        div {{ class is 'yui-g' };
            div {{ class is "yui-u first $class" };
                h2 { $title };
                if ( $left eq 'owner' ) {
                    render_region(
                        name => 'owners',
                        path => '/groups/dashboard/fragments/owners',
                        defaults => {
                            group_id => $group->id,
                            prefix   => $prefix,
                            @conditions,
                        }
                    );
                } else {
                    render_region(
                        name     => $left.'list',
                        path     => '/groups/dashboard/fragments/breakdowns',
                        defaults => {
                            group_id    => $group->id,
                            display     => $left,
                            prefix      => $prefix,
                            @conditions,
                        }
                    );
                }
            };
            div {{ class is 'yui-u' };
                render_region(
                    name => 'dashboardstatus',
                    path => '/groups/dashboard/fragments/status',
                    defaults => {
                        group_id => $group->id,
                        @conditions,
                    }
                );
            };
        };

        show(
            '/groups/dashboard/fragments/tasklist',
            tokens => [
                group   => $group->id,
                sort_by => $left,
                @conditions,
            ],
        );
    };
};

template 'project-milestone-owner' => page {
    title    => 'Group ' . get('group')->name,
    subtitle(),
} content {
    my $group  = get('group');
    my @views  = mesh @{ get('views') }, @{ get('locators') };
    my $prefix = '/' . join '/', @views;

    div {{ class is 'projects-dashboard' };
        render_region(
            name     => 'overview',
            path     => '/groups/dashboard/fragments/overview',
            defaults => {
                type     => get('type'),
                id       => get('record')->id,
                group_id => $group->id,
                @views,
            }
        );

        render_region(
            name => 'dashboardstatus',
            path => '/groups/dashboard/fragments/status',
            defaults => {
                group_id => $group->id,
                @views,
            }
        );

        show(
            '/groups/dashboard/fragments/tasklist',
            tokens => [
                group   => $group->id,
                sort_by => 'progress',
                @views,
            ],
        );
    };
};

###
### End of first version of dashboard views
###

template 'analysis' => page {
    title    => 'Group ' . get('group')->name,
    subtitle()
} content {
    my $group = get('group');
    my @conditions = mesh @{ get('views') || [] }, @{ get('locators') || [] };

    div {{ class is 'group-dashboard' };
        render_region(
            name => 'analysis',
            path => '/groups/dashboard/fragments/analysis',
            defaults => {
                group_id => $group->id,
                @conditions
            },
        );
    }
};

template 'assign' => page {
    title    => 'Group ' . get('group')->name,
    subtitle()
} content {
    my $group = get('group');
    my @conditions = mesh @{ get('views') || [] }, @{ get('locators') || [] };

    div {{ class is 'group-dashboard' };
        render_region(
            name => 'assign',
            path => '/groups/dashboard/fragments/assign',
            defaults => {
                group_id => $group->id,
                @conditions
            },
        );
    };
};

template 'group-management' => page {
    title    => 'Group ' . get('group')->name,
    subtitle()
} content {
    my $group = get('group');
    my %limits = mesh @{ get('views') || [] }, @{ get('locators') || [] };

    div {{ class is 'group-dashboard' };
        render_region(
            name => 'group-management',
            path => '/groups/dashboard/fragments/group-management',
            defaults => {
                group_id => $group->id,
                %limits,
            },
        );
    };
};

template 'project-overview' => page {
    title    => 'Group ' . get('group')->name,
    subtitle()
} content {
    my $group     = get('group');
    my %limits = mesh @{ get('views') || [] }, @{ get('locators') || [] };

    div {{ class is 'group-dashboard' };
        render_region(
            name     => 'overview',
            path     => '/groups/dashboard/fragments/overview',
            defaults => {
                type      => 'project',
                id        => get('record')->id,
                project   => get('locator'),
                group_id  => $group->id,
            }
        );

        render_region(
            name => 'project-overview',
            path => '/groups/dashboard/fragments/project-overview',
            defaults => {
                type      => 'project',
                group_id  => $group->id,
                %limits,
            },
        );
    };
};

template 'milestone-overview' => page {
    title    => 'Group ' . get('group')->name,
    subtitle()
} content {
    my $group     = get('group');
    my %limits = mesh @{ get('views') || [] }, @{ get('locators') || [] };

    div {{ class is 'group-dashboard' };
        render_region(
            name     => 'overview',
            path     => '/groups/dashboard/fragments/overview',
            defaults => {
                type      => 'milestone',
                id        => get('record')->id,
                milestone => get('locator'),
                group_id  => $group->id,
            }
        );

        render_region(
            name => 'milestone-overview',
            path => '/groups/dashboard/fragments/milestone-overview',
            defaults => {
                group_id  => $group->id,
                %limits,
            },
        );
    };
};

template 'schedule-milestone' => page {
    title    => 'Group ' . get('group')->name,
    subtitle()
} content {
    my $group     = get('group');
    my %limits = mesh @{ get('views') || [] }, @{ get('locators') || [] };

    div {{ class is 'group-dashboard' };
        render_region(
            name     => 'overview',
            path     => '/groups/dashboard/fragments/overview',
            defaults => {
                type      => 'milestone',
                id        => get('record')->id,
                milestone => get('locator'),
                group_id  => $group->id,
                hide_actions => 1,
                extra     => '/groups/dashboard/fragments/time-tracking-summary'
            }
        );

        render_region(
            name => 'schedule-milestone',
            path => '/groups/dashboard/fragments/schedule-milestone',
            defaults => {
                group_id  => $group->id,
                %limits,
            },
        );
    };
};

template 'about-member' => page {
    title    => 'Group ' . get('group')->name,
    subtitle(),
} content {
    my $group = get('group');
    my %limits = mesh @{ get('views') || [] }, @{ get('locators') || [] };

    div {{ class is 'group-dashboard' };
        render_region(
            name     => 'overview',
            path     => '/groups/dashboard/fragments/overview',
            defaults => {
                type      => 'owner',
                id        => get('record')->id,
                group_id  => $group->id,
            }
        );

        render_region(
            name => 'about-member',
            path => '/groups/dashboard/fragments/about-member',
            defaults => {
                group_id => $group->id,
                %limits,
            },
        );
    };
};

template 'time-worked' => page {
    title    => 'Group ' . get('group')->name,
    subtitle()
} content {
    my $group = get('group');
    my %limits = mesh @{ get('views') || [] }, @{ get('locators') || [] };

    div {{ class is 'group-dashboard' };
        render_region(
            name     => 'overview',
            path     => '/groups/dashboard/fragments/overview',
            defaults => {
                type      => get('type'),
                id        => get('record')->id,
                group_id  => $group->id,
                %limits,
            }
        );

        render_region(
            name => 'time-worked',
            path => '/groups/dashboard/fragments/time-worked',
            defaults => {
                group_id => $group->id,
                %limits,
            },
        );
    };
};

template 'weekly-transactions' => page {
    title    => 'Group ' . get('group')->name,
    subtitle()
} content {
    my $group = get('group');
    my %limits = mesh @{ get('views') || [] }, @{ get('locators') || [] };

    div {{ class is 'group-dashboard' };
        render_region(
            name     => 'overview',
            path     => '/groups/dashboard/fragments/overview',
            defaults => {
                type      => get('type'),
                id        => get('record')->id,
                group_id  => $group->id,
                %limits,
            }
        );

        render_region(
            name => 'weekly-transactions',
            path => '/groups/dashboard/fragments/weekly-transactions',
            defaults => {
                type     => get('type'),
                group_id => $group->id,
                %limits,
            },
        );
    };
};

template 'tasks' => page {
    title    => 'Group ' . get('group')->name,
    subtitle(),
} content {
    my $group = get('group');
    my %limits = mesh @{ get('views') || [] }, @{ get('locators') || [] };

    div {{ class is 'group-dashboard' };
        render_region(
            name     => 'overview',
            path     => '/groups/dashboard/fragments/overview',
            defaults => {
                type      => get('type'),
                id        => get('record')->id,
                group_id  => $group->id,
                %limits,
            }
        );

        render_region(
            name => 'tasks',
            path => '/groups/dashboard/fragments/tasks',
            defaults => {
                group_id => $group->id,
                %limits,
            },
        );
    };
};

sub subtitle {
    my $group   = get('group')->id;
    my $views   = get('views') || [];
    my $records = get('records') || [];
    my $ids     = get('locators') || [];
    my $page    = get('dashboard-page') || '';
    my $prev    = "/groups/$group";
    my @crumbs  = (qq(<a href="$prev/dashboard">Dashboard</a>));
    my $title = 'Dashboard';

    my $full = join '/', $prev, mesh @$views, @$ids;

    pairwise {
        my $id   = $b eq 'owner' ? $a->email : $a->record_locator;
        my $name = $b eq 'owner' ? $a->name  : $a->summary;
        my $url  = join '/', $prev, $b, $id;
        $prev = $url;

        my $remove = $full;
           $remove =~ s{/$b/$id}{};

        push @crumbs, join ' ', map { $_->as_string }
             Jifty->web->link(
                 url   => $url,
                 label => $name,
             ),
             Jifty->web->link(
                 url   => $remove,
                 class => 'remove',
                 label => '(x)',
             ),
        ;

        my $prefix = $b eq 'owner' ? '' : uc(substr($b, 0, 1)).': ';
        $title = "$prefix$name &lt; $title";
    } @$records, @$views;

    if ( length $page ) {
        my $name = ucfirst $page;
        $name =~ s/-/ /;
        push @crumbs, qq{<a href="$prev/$page">$name</a> <a href="$prev" class="remove">(x)</a>};
        $title = "$name &lt; $title";
    }

    return (
        subtitle         => $title,
        in_page_subtitle => join(' &gt; ', @crumbs),
        escape_subtitle  => 0,
    );
}

1;
