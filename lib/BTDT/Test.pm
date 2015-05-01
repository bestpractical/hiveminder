use warnings;
use strict;


package BTDT::Test;

=head2 NAME

BTDT::Test

=head2 DESCRIPTION

This class defines helper functions for testing BTDT.

=cut

use base qw/Jifty::Test/;
use BTDT::Test::WWW::Mechanize;
use IPC::Open3;
use BTDT::CurrentUser;
use DateTime::Format::ISO8601 ();

# Notes about testing with unicode: ->messages returns body that
# are byte strings.

=head2 setup

Sets up the test suite. In addition to what L<Jifty::Test/setup> does,
also calls L</setup_db>.

=cut

sub setup {
    my $class = shift;
    $class->SUPER::setup(@_);
    $class->setup_db;
}

=head2 test_config

We override the test config to supply a custom testing log4perl file

=cut

sub test_config {
    my $class = shift;
    my ($config) = @_;

    my $hash = $class->SUPER::test_config($config);
    $hash->{framework}{LogConfig}  = "t/btdttest.log4perl.conf";
    $hash->{framework}{DevelMode}  = 0;
    $hash->{application}{SkipSSL}  = 1;
    $hash->{application}{AuthorizeNet} = {
        LiveMode        => 0,
        login           => 'DLfLEN7Z',
        transaction_key => '94Mf22Pg6wu73GMK',
    };
    $hash->{application}{IMAP}{port}         = ($$ % 1000) + 15000;
    $hash->{application}{IMAP}{ssl_port}     = ($$ % 1000) + 16000;
    $hash->{application}{IMAP}{monitor_port} = ($$ % 1000) + 17000;
    $hash->{application}{IMAP}{poll_every}   = -1;
    $hash->{application}{IMAP}{log}          = 0;
    return $hash;
}

=head2 setup_db

Sets up a test user, a test task, etc.  Please keep C<t/0-test-database> up
to date with this.

=cut

sub setup_db {
    my $class = shift;

    my $ADMIN = BTDT::CurrentUser->superuser;
    my $gooduser = BTDT::Model::User->new(current_user => $ADMIN);

    $gooduser->create (
        email => 'gooduser@example.com',
        name => 'Good Test User',
        password => 'secret',
        beta_features => 1,
        email_confirmed => 1,
        created_on => DateTime::Format::ISO8601->parse_datetime('2006-01-01'),
    );

    my $new_user1= BTDT::Model::User->new(current_user => $ADMIN);
    $new_user1->create(
        email => 'otheruser@example.com',
        name => 'Other User',
        password => 'something',
        email_confirmed => 1,
        notification_email_frequency => 'daily',
    );

    my $new_user2= BTDT::Model::User->new(current_user => $ADMIN);
    $new_user2->create(
        email => 'onlooker@example.com',
        name => 'Onlooking User',
        password => 'something',
        email_confirmed => 1,
    );


    my $group1= BTDT::Model::Group->new(current_user => $ADMIN);
    $group1->create(
        name => 'alpha',
        description => 'test group 1'
    );
    $group1->add_member($gooduser, 'organizer');


    my $GOODUSER = BTDT::CurrentUser->new(id => $gooduser->id);
    my $task1 = BTDT::Model::Task->new(current_user => $GOODUSER);
    $task1->create(
        summary => "01 some task",
        description => '',
        requestor_id => $gooduser->id,
        owner_id => $gooduser->id,
    );

    my $task2 = BTDT::Model::Task->new(current_user => $GOODUSER);
    $task2->create (
        summary => "02 other task",
        description => 'with a description',
        requestor_id => $gooduser->id,
        owner_id => $gooduser->id,
    );
}

=head2 get_logged_in_mech URL [USERNAME, PASSWORD]

Sets up a Test::WWW::Mechanize and attempts to log into a BTDT instance at URL.

Returns the Test::WWW::Mechanize object.

Uses C<gooduser@example.com/secret> by default, but you can pass in another username and password.

On failure returns undef.

=cut

sub get_logged_in_mech {
    my $class = shift;
    my $URL = shift;
    my $username = shift || 'gooduser@example.com';
    my $password = shift || 'secret';

    my $mech = BTDT::Test::WWW::Mechanize->new;
    $mech->get("$URL/");

    unless ($mech->content =~ /Login/) {
        $mech->follow_link( text => "Logout" );
    }
    return unless $mech->content =~ /Login/;

    my $login_form = $mech->form_name('loginbox');
    return unless $mech->fill_in_action('loginbox', address => $username, password => $password);
    $mech->submit;

    if ($mech->uri =~ m{accept_eula}) {
        # Automatically accept the EULA
        $mech->fill_in_action('accept_eula');
        $mech->click_button(value => 'Accept these terms and make our lawyers happy');
    }

    die $mech->content unless $mech->content =~ /Logout/;
    return unless $mech->content =~ /Logout/i;

    return $mech;
}



=head2 mailgate --url URL --address ADDRESS --message MESSAGE

Runs the mail gateway with the given C<URL> and C<ADDRESS> parameters.
The C<MESSAGE> is fed to the mail gateway on its standard input.
Returns the results of the standard output and the standard error,
concatenated.

=cut

sub mailgate {
    my $class = shift;
    my %args = (@_);
    my $message = delete $args{message} || delete $args{"--message"} || "";
    my ($wtr, $rdr, $err);
    open3($wtr, $rdr, $err, $^X, "bin/mailgate", %args);
    binmode $wtr, ':encoding(UTF-8)';
    print $wtr $message;
    close $wtr;

    # Shortcut if we don't need to return anything
    return unless defined wantarray;

    my $str;
    $str .= join '', <$rdr> if $rdr;
    $str .= join '', <$err> if $err;
    return $str;
}

=head2 trigger_reminders

Runs the daily reminder cronjob.

=cut

sub trigger_reminders {
    my $users = BTDT::Model::UserCollection->new(
                                                 current_user => BTDT::CurrentUser->superuser );
    $users->limit(
                  column   => 'notification_email_frequency',
                  operator => '!=',
                  value    => 'never'
                  );
    while ( my $user = $users->next ) {
    my $notification = BTDT::Notification::DailyReminder->new( to => $user , current_user => BTDT::CurrentUser->new(id => $user->id));
    next unless ($notification->subject);

        $notification->send();
    }
}

=head2 make_pro email | id | User | CurrentUser

Make the given user a pro user.

=cut

sub make_pro {
    my $self = shift;
    my $incoming = shift;
    my $user;

    if (ref $incoming && $incoming->isa('BTDT::CurrentUser')) {
        $user = $incoming->user_object->as_superuser;
    }
    elsif (ref $incoming) {
        $user = $incoming->as_superuser;
    }
    elsif ($incoming =~ /@/) {
        $user = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
        $user->load_by_cols(email => $incoming);
    }
    elsif ($incoming =~ /^\d+$/) {
        $user = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
        $user->load($incoming);
    }
    else {
        Carp::croak "I don't know how to interpret the input '$incoming' (expected currentuser, user, email, or ID)";
    }

    $user->id
        or Carp::croak "No user loaded.";

    $user->__set( column => 'pro_account', value => 1 );

    Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');

    ::ok($user->pro_account, "Upgraded to pro");
}

=head2 setup_hmfeedback_group

Creates the feedback group, "hiveminders feedback" with gooduser and otheruser.
Returns the group object

=cut

sub setup_hmfeedback_group {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $ADMIN = BTDT::CurrentUser->superuser;

    my $gooduser = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
    $gooduser->load_by_cols(email => 'gooduser@example.com');
    Test::More::ok($gooduser->id, "gooduser loads properly");
    my $otheruser = BTDT::Model::User->new(current_user => BTDT::CurrentUser->superuser);
    $otheruser->load_by_cols(email => 'otheruser@example.com');
    Test::More::ok($otheruser->id, "otheruser loads properly");

    my $group = BTDT::Model::Group->new(current_user => $ADMIN);
    $group->create(
        name => 'hiveminders feedback',
        description => 'dummy feedback group'
        );
    $group->add_member($gooduser, 'organizer');
    $group->add_member($otheruser, 'member');

    Test::More::is(scalar @{$group->members->items_array_ref}, 3,
       "Group has 3 members"); # the other one is the superuser

    return $group;
}

=head2 start_imap

Starts the IMAP server; returns a L<Net::IMAP::Simple> object
connected to the server.

=cut

my $imap;
sub start_imap {
    my $class = shift;
    unless ( $imap = fork ) {
        require Net::IMAP::Server;
        require BTDT::IMAP;
        BTDT::IMAP->new->run;
        exit;
    }

    sleep 3;

    require Net::IMAP::Simple::SSL;
    {
        package Net::IMAP::Simple::SSL;

        sub _process_cmd {
            my ( $self, %args ) = @_;
            require Jifty::DBI::Record::Cachable;
            Jifty::DBI::Record::Cachable->flush_cache;
            $args{process} ||= sub { };
            $args{final}   ||= sub { };
            $self->{untagged} = [];
            $self->SUPER::_process_cmd(
                %args,
                process => sub {
                    push @{ $self->{untagged} }, $_[0] if $_[0] =~ m/\* /;
                    $args{process}->(@_);
                },
            );
        }

        sub untagged {
            my $self = shift;
            return $self->{untagged};
        }
    }

    return $class->imap_client();
}

=head2 imap_client

Starts an IMAP client. Expects that there is already a
server running.

=cut

sub imap_client {
    my $self = shift;
    my $port = Jifty->config->app('IMAP')->{ssl_port};
    return Net::IMAP::Simple::SSL->new( "localhost:" . $port );
}

END {
    if ($imap) {
        local $?;
        kill 2, $imap;
        1 while wait > 0;
    }
}

my $gladiator;
BEGIN {
#    $gladiator = eval { require Devel::Gladiator; 1 };
}

END {
    if ($gladiator) {
        my $arena = Devel::Gladiator::arena_table();
        die $1 if $arena =~ m/^(.*(?:Action|Collection).*)$/m;
    }
}

1;
