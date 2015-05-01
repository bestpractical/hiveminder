use strict;
use warnings;

package BTDT::Test::WWW::Mechanize;
use base qw/Jifty::Test::WWW::Mechanize/;

use Test::More;

=head1 NAME

BTDT::Test::WWW::Mechanize - Subclass of L<Jifty::Test::WWW::Mechanize> with
extra BTDT features

=head1 DESCRIPTION

Convenience methods for doing commonly mechanized actions with BTDT,
so you can write tests faster.


=head1 METHODS

=cut

=head2 create_task_ok SUMMARY, (GROUP_ID)

Makes a new task with SUMMARY and optional GROUP_ID, using the "new task" form.

=cut

# XXX it would be great to increment the number of expected tests automatically,
# so we could put more than one test in each of these methods.

sub create_task_ok {
    my $mech = shift;
    my $summ = shift;
    my $group = shift || '';

    $mech->fill_in_action_ok('tasklist-new_item_create',
                             summary => $summ,
                             group_id => $group);
    $mech->submit_html_ok();
}


=head2 assign_task_ok TITLE, USER_EMAIL

Assigns the task with title TITLE to user USER_EMAIL. This method can start
with the mech either on a tasklist or already on the task's edit page.

=cut

sub assign_task_ok {
    my $mech = shift;
    my $title = shift;
    my $owner_email = shift;

    {
        local $Test::Builder::Level = $Test::Builder::Level;
        $Test::Builder::Level++;

        unless ($mech->uri =~ /edit/) {
            $mech->follow_link_ok(text => $title);
        }

        $mech->fill_in_action_ok( $mech->moniker_for('BTDT::Action::UpdateTask'),
                               owner_id => $owner_email,
            );
        $mech->submit_html_ok( value => 'Save' );
        $mech->content_contains( "Task '$title' updated.", "User successfully updated task" );
        is($mech->action_field_value($mech->moniker_for("BTDT::Action::UpdateTask"),
                                     'owner_id'),
           $owner_email,
           "Owner was reassigned properly to owner $owner_email");
    }
}

=head2 accept_task_ok TITLE

Accepts the task with title TITLE.

=cut


sub accept_task_ok {
    my $mech = shift;
    my $title = shift;

    $mech->follow_link_ok( text_regex => qr{unaccepted task(s)?} );
    $mech->content_contains( $title, "$title is on unaccepted-tasks page" );
    $mech->follow_link_ok( text => $title );
    $mech->form_number(2);
    $mech->click_button( value => 'Accept' );
    $mech->content_contains( "accepted", "User successfully accepted task" );
}


=head2 decline_task_ok TITLE

Declines the task with title TITLE.

=cut


sub decline_task_ok {
    my $mech = shift;
    my $title = shift;
    $mech->follow_link_ok( text_regex => qr{unaccepted task(s)?} );
    $mech->content_contains( $title, "$title is on unaccepted-tasks page" );
    $mech->follow_link_ok( text => $title );

    # XXX FIXME: this next test warns now, probably because there's something going
    # on with permissions when users decline a task.
    $mech->form_number(2);
    $mech->click_button(value => 'Decline');
    $mech->content_contains( "don't have permission", "User successfully declined task" );
}

=head2 create_address_ok

Creates a published address with the given mech. In scalar context, will return
the string form of the address (and run two tests). In list context, will
return the string form of the address and the address object (and runs three
tests).

=cut

sub create_address_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $mech = shift;

    $mech->follow_link_ok(text => 'Tasks by Email', "going to Tasks by Email");
    ::ok($mech->action_form($mech->moniker_for('BTDT::Action::CreatePublishedAddress')), "Found published address action");
    $mech->click_button(value => 'Add a new address now!');
    $mech->content_contains("my.hiveminder.com", "New address added to the page");

    my ($address) = $mech->content =~ /(\w+)\@my.hiveminder.com/;
    ::ok($address, "Found an address");

    return $address if !wantarray;

    my $addr_obj = BTDT::Model::PublishedAddress->new;
    $addr_obj->load_by_cols(address => $address);
    ::ok($addr_obj->id, "Loaded an address object");

    return ($address, $addr_obj);
}


1;
