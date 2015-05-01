package BTDT::Action::TwitterFollow;
use warnings;
use strict;
use base qw/BTDT::Action/;

use Net::Twitter::Lite;

=head2 NAME

BTDT::Action::TwitterFollow

=cut

use Jifty::Param::Schema;
use Jifty::Action schema {
    param 'name' =>
        label is 'Twitter account',
        is mandatory,
        documentation is "The Twitter ID of the person to begin following";
};

=head2 take_action

Follow the user with the given name.

=cut

sub take_action {
    my $self = shift;

    require BTDT::IM::TwitterREST;
    my $twitter = BTDT::IM::TwitterREST->create_twitter_handle;

    my $ok = eval {
        $twitter->create_friend({id => $self->argument_value('name')});
        1;
    };

    if ($ok) {
        $self->result->message("See you on Twitter!");
        return 1;
    }

    warn "Error in Net::Twitter create_friend: $@";
    $self->result->error("Something went wrong! Please try again later.");
    return 0;
}

1;

