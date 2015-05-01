package BTDT::RTM::View;
use strict;
use warnings;
use Jifty::View::Declare -base;

=head1 NAME

BTDT::RTM::View - View pages for RTM authorization

=cut

template 'index.html' => page { title => 'Application Access', detect_mobile => 1 } content {
    if (my $res = Jifty->web->response->result("sessionauth")) {
        p {{ class is 'large' };
            $res->success ? "Access granted!" : "Granting access failed!"
        }
        p {
            $res->success
                ? "You can now go back to the application and see your tasks."
                : "Sorry about that.  Go back to the application and try again.  "
                 ."If that doesn't work, use the feedback box to drop us a note "
                 ."and we'll see what we can do."
        };
    } else {
        my $frob = get 'frob';
        Jifty->web->redirect('/todo') unless $frob;
        my $allow = new_action(
            class => "SessionAuth",
            moniker => "sessionauth",
        );
        p {{ class is 'large' };
            "Do you want to allow the application you came from full access to your tasklist, including personal and group tasks?"
        };
        form {
            render_param( $allow, 'frob' => default_value => get('frob'), render_as => 'hidden' );
            render_param( $allow, 'api_key' => default_value => get('api_key'), render_as => 'hidden' );
            $allow->button(
                label => 'Yep, let them at my tasks',
                class => 'large',
            );
            hyperlink(
                label => 'No, do not allow access',
                url   => '/todo',
                class => 'large attention',
                as_button => 1,
                submit    => [],
            );
        };
    }
};

1;
