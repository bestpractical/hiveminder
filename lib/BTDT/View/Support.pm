use warnings;
use strict;

=head1 NAME

BTDT::View::Support

=cut

package BTDT::View::Support;
use Jifty::View::Declare -base;
__PACKAGE__->use_mason_wrapper;

template 'index.html' => page { title => 'Customer Support' } content {
    if ( not Jifty->web->current_user->pro_account ) {
        p {
            outs( _("Full support is only available to ") );
            hyperlink( label => 'Hiveminder Pro', url => '/pro' );
            outs(
                _(  " users.  If you need help, please use the feedback box on the left or "
                )
            );
            hyperlink(
                label => 'upgrade to Hiveminder Pro',
                url   => '/account/upgrade'
            );
            outs(".");
        };
        return;
    }
    p {
        outs(
            _(  q(As a Hiveminder Pro user, we'll try to provide you with a level of
            support beyond that of normal users.  If you need help, you can email
            )
            )
        );
        a {
            { href is 'mailto:support@hiveminder.com' }
            'support@hiveminder.com';
        };
        outs(
            _(  " or fill out the form below, and we'll try to get back to you as soon as we can."
            )
        );
    };
    my $action = new_action(
        class   => 'SendSupportRequest',
        moniker => 'supportrequest'
    );
    form {
        render_param( $action => 'content' );
        form_submit( label => 'Send' );
    };
};

1;
