#!/usr/bin/env hmperl
use warnings;
use strict;

use constant PER_PAGE => 15;

use BTDT::Test tests => 1;
use BTDT::Model::Task;


=head1 DOC

To run this:

JIFTY_TESTSERVER_PROFILE=ungrab.tmon perl -Ilib perf/group-ungrabbed.pl

=cut


my $user;

 my $bootstrap = BTDT::CurrentUser->new(_bootstrap => 1) ;
{ 
 $user = BTDT::Model::User->new( current_user => $bootstrap );
my ($id,$msg) = $user->create( name => 'acl_test_user', email => 'group_test@localhost', password => 'something',         email_confirmed => 1,         beta_features => 't',

 );
ok ($id,$msg);
ok($user->id, "Created our new user just fine");

}

my $group = BTDT::Model::Group->new(current_user => $bootstrap);


$group->create( name => 'Test group');

ok ($group->id, "Created the group");

$group->add_member($user, "member");

other_user_to_group($_) for (90..99);

sub other_user_to_group {
    my $name = shift;
    my $other_user;

    $other_user = BTDT::Model::User->new( current_user => $bootstrap );
    my ($id,$msg) = $other_user->create( name => 'acl_test_user_2', email => 'other_user_'.$name.'@localhost' );
    ok ($id,$msg);
    ok($other_user->id, "Created our new user just fine");

    $group->add_member($other_user, "member");

}



add_task(sprintf("%02d yet another task",$_)) for (1..15);


my $server = Jifty::Test->make_server;
isa_ok($server, 'Jifty::Server');

$SIG{INT} = sub { exit } ;

my $URL = $server->started_ok;

my $mech = Jifty::Test::WWW::Mechanize->new;
$mech->get("$URL/");
my $login_form = $mech->form_name('loginbox');
die unless $mech->fill_in_action('loginbox', address => 'group_test@localhost', password => 'something');
$mech->submit;
die unless $mech->content =~ /Logout/i;

use Time::HiRes 'time';
my $n = shift || 20;
my $t = time();
for (1..$n) {
    $mech->get("$URL/groups/1/unowned_tasks");
#    ok($mech->content);
}
diag( (time() - $t)/$n );

sub add_task {
    # Create the task using the direct API instead of through the
    # server, for speed; you may need to call $mech->reload after.
    my $summ = shift;
    my $desc = shift;
    
    my $task = BTDT::Model::Task->new( current_user => BTDT::CurrentUser->new( id => $user->id )) ;
    my ($ok, $msg) = $task->create(
        group => $group,
	summary => $summ,
	requestor_id => $user->id,
        owner_id => BTDT::CurrentUser->nobody->id,
	defined $desc ? (description => $desc) : ()
    );

    ok($ok, "Created task $summ");
} 
