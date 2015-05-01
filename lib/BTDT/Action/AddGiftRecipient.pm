use strict;
use warnings;

=head1 NAME

BTDT::Action::AddGiftRecipient

=cut

package BTDT::Action::AddGiftRecipient;
use base qw/BTDT::Action Jifty::Action/;

use Jifty::Param::Schema;
use Jifty::Action schema {
    param 'user_id' =>
        ajax validates,
        ajax canonicalizes,
        autocompleter is \&autocomplete_user_id;
};

=head2 validate_user_id

Validates the same as C<BTDT::Action::UpgradeAccount/validate_user_id>
(must be an existing user's email address or id).

=cut

sub validate_user_id {
    my $self  = shift;
    my $value = shift;

    return $self->validation_ok('user_id')
        if not defined $value or not length $value;

    return BTDT::Action::UpgradeAccount::validate_user_id( $self, $value, @_ );
}

=head2 autocomplete_user_id

Autocompletes to the list of people known, including the current user.

=cut

sub autocomplete_user_id {
    my $self          = shift;
    my $current_value = shift;
    my @results;

    my $user = Jifty->web->current_user->user_object;

    # $user->people_known specifically avoids returning $user
    if ($current_value =~ /^me?$/i
     || $user->name =~ /^\Q$current_value\E/i
     || $user->email =~ /^\Q$current_value\E/i) {
            push @results, {
                    value => $user->email,
                    label => $user->name,
                }
    }

    for my $person ( ($user->people_known) ) {
        push @results, {
            value => $person->email,
            label => $person->name,
        }
            if    $person->name  =~ /^\Q$current_value\E/i
               or $person->email =~ /^\Q$current_value\E/i;
    }

    # If there's only one result, and it already matches entirely, don't
    # bother showing it
    return if @results == 1 and $results[0]->{value} eq $current_value;
    return @results;
}

=head2 take_action

Adds the selected user to the session's list of gift users

=cut

sub take_action {
    my $self = shift;
    $self->report_success
        if     not $self->result->failure
           and defined $self->argument_value('user_id');
    return 1;
}

=head2 report_success

Adds the selected user to the session's list of gift users

=cut

sub report_success {
    my $self = shift;

    my $ids = $self->argument_value('user_id') || [];
    $ids    = [$ids] if not ref $ids;

    my $saved = Jifty->web->session->get('giftusers') || [];
    push @$saved, @$ids;

    use List::MoreUtils qw(uniq);
    $saved = [ uniq @$saved ];

    Jifty->web->session->set( giftusers => $saved );
}

1;
