use warnings;
use strict;

=head1 NAME

BTDT::View::Pro

=cut

package BTDT::View::Pro;
use Jifty::View::Declare -base;
__PACKAGE__->use_mason_wrapper;

template 'index.html' => page {
    title        => 'Hiveminder Pro',
    subtitle     => 'Overview',
    hide_sidebar => 1,
    footer_logo  => 'bp_logo_small.png',
    body_id      => 'protour'
    } content {
    p {
        outs( _("Sure, you're getting stuff done with Hiveminder") );
        outs_raw(" &mdash; ");
        outs( _(<<"        END_PITCH") );
            Get more done with Hiveminder Pro.  For a measly \$30 USD per
            year, you'll have access to features that will make you more
            nimble and thorough as you go about your extremely awesome
            business.
        END_PITCH
    };

    div {{ id is 'col-left' };
    show( './feature', title => 'Reports', help => 'reference/reports.html', text => <<'    END');
        Too busy?  Not busy enough?  Who's tasking you the most?  The least?
        Use our easy-to-understand reports to see just how much (or how
        little!) you're doing.
    END

    show( './feature', title => 'Saved Lists', help => 'how-to/save-searches.html', text => <<'    END');
        Save your custom searches as personal lists. Quick and easy access to
        your complex searches means more time for coffee, and less time in
        your pod!
    END

    show( './feature', title => 'Time tracking', help => 'reference/tasks/time-tracking.html', text => <<'    END');
        Keep tabs on your billable hours or simply how much time you spend
        watering the plants every week. Our time tracking and associated
        reports let you manage a group and see what people are spending
        their time on. Only have 15 minutes to spare Right Now? You can
        easily get a list of all your tasks that can be done in under that.
    END
    };

    div {{ id is 'col-right' };
    show( './feature', title => 'Attachments', help => 'reference/tasks/attachments.html', text => <<'    END');
        Upload files to include in tasks! Once you upload a file, it'll be
        available to anyone able to see the task, and no one will ask what
        file you're talking about.
    END

    show( './feature', title => 'IMAP support', help => 'reference/IMAP/Introduction.html', text => <<'    END')
        Bring Hiveminder into your email client!  Keep track of,
        complete, and organize your tasks without ever looking away
        from your email.  Pro users get access to our custom
        Hiveminder IMAP server, which makes dealing with tasks as easy
        as reshuffling emails.
    END
      if Jifty->config->app('FeatureFlags')->{IMAP};

    show( './feature', title => 'with.hm', text => <<'    END');
        We've made it even easier to assign tasks to people by email if
        you're a pro user!  By using <i>bob@example.com.secret.with.hm</i>,
        <i>bob@example.com</i> will get assigned your task. Add to your own
        todo list the same way!
    END

    show( './feature', title => 'Security', text => <<'    END');
        Your world domination plans will now be completely and utterly safe.
        A pro account will let you use Hiveminder with SSL, making everything
        you do on Hiveminder even more safe and secure.
    END
    };

    p {
        { class is "tour_nav" };
        hyperlink(
            url   => '/account/upgrade',
            label => 'Upgrade now!'
        );
        span { outs_raw("&raquo;") };
    };
    };

private template 'feature' => sub {
    my $self = shift;
    my %args = @_;

    my $name = lc $args{'title'};
    $name =~ s/(?: |\.)/_/g;

    div {
        { id is "feat-$name", class is 'feature' };
        p {
            strong {
                if ($args{'help'}) {
                    hyperlink(
                        label => _( $args{'title'} ),
                        url   => "/help/$args{'help'}",
                    );
                }
                else {
                    outs_raw( _( $args{'title'} ) );
                }
            };
            outs_raw( _( $args{'text'} ) );
        };

        img {
            {
                src is "/static/images/protour/$name.png",
                    alt is "$args{'title'} screenshot"
            }
        }
        unless $name =~ /with_hm|security/;

        hr {
            { class is 'hidden clear' }
        };
    };

};

1;
