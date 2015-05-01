use warnings;
use strict;

=head1 NAME

BTDT::View::Admin::Users

=cut

package BTDT::View::Admin::Users;
use Jifty::View::Declare -base;
__PACKAGE__->use_mason_wrapper;

template 'edit' => page { title => 'Admin', subtitle => 'Edit User' } content {
    my $action = get 'action';

    if (!$action) {
        p { "Please use /admin/users/edit/EMAILADDRESS" }
    }
    else {
        form {
            # these fields are required, but we really don't want to have to
            # change them
            my %disabled_field = map { $_ => 1 }
                qw/email_secret current_password password password_confirm/;

            my @fields = grep { !$disabled_field{$_} } $action->argument_names;

            render_action($action, \@fields);
            form_submit(label => "Save");
        }
    }
};

1;

