use strict;
use warnings;

=head1 NAME

BTDT::View

=head1 DESCRIPTION

The newer templates for BTDT are written in TD

=cut

package BTDT::View;
use BTDT::View::ListsCRUD;
use Jifty::View::Declare -base;
__PACKAGE__->use_mason_wrapper;

require BTDT::View::Task;
alias BTDT::View::Task under 'task/';

require BTDT::View::Groups;
alias BTDT::View::Groups under 'groups/';

require BTDT::View::Account;
alias BTDT::View::Account under 'account/';

require BTDT::View::Pro;
alias BTDT::View::Pro under 'pro/';

require BTDT::View::Reports;
alias BTDT::View::Reports under 'reports/';

require BTDT::View::Support;
alias BTDT::View::Support under 'support/';

require BTDT::View::Admin;
alias BTDT::View::Admin under 'admin/';

require BTDT::View::Let;
alias BTDT::View::Let under 'let/';

require BTDT::View::Pingdom;
alias BTDT::View::Pingdom under 'pingdom/';


require BTDT::View::RequestInspector;
alias BTDT::View::RequestInspector under 'debugging/';

require BTDT::RTM::View;
alias BTDT::RTM::View under 'services/auth/';

alias BTDT::View::ListsCRUD under 'fragments/lists/';
template 'lists' => page { title => 'Lists' } content {
    my @lists = BTDT::Model::List->default_lists(Jifty->web->current_user->pro_account);
    shift @lists; # shift off "To Do"

    div {{ style is 'float: left; width: 50%;' };
        p {{ style is 'padding-top: 0; margin-top: 0' }; _("Some more ways to slice and dice your list:") };

        dl {{ class is 'lists' };
            for my $list ( @lists ) {
                dt { hyperlink( url => $list->{'url'}, label => $list->{'label'} ) };
                dd { ( defined $list->{'summary'} ? _($list->{'summary'}) : '' ) };
            }
        };
    };
    if ( Jifty->web->current_user->pro_account ) {
        div {{ style is 'float: right; width: 50%;', class is 'lists' };

            p {{ style is 'padding-top: 0; margin-top: 0' };
               outs _("Your saved lists:");
               outs_raw(BTDT->contextual_help("how-to/save-searches"))
            };

            set search_collection => Jifty->web->current_user->user_object->lists;
            form {
                render_region(
                    name => 'savedlists',
                    path => '/fragments/lists/list',
                );
            };
        };
    }
};

1;
