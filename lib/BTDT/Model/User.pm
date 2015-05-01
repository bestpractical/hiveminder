use warnings;
use strict;

=head1 NAME

BTDT::Model::User

=head1 DESCRIPTION

Describes a user of the system.

=cut

package BTDT::Model::User;
use Jifty::DBI::Schema;
use DateTime;
use DateTime::TimeZone;
use Digest::MD5 qw(md5_hex);
use BTDT::Model::GroupInvitationCollection;
use BTDT::Model::PublishedAddressCollection;
use BTDT::Model::GroupMemberCollection;
use BTDT::Notification::ConfirmAddress;
use base qw( BTDT::Record );
use Scalar::Defer;
use Scalar::Util ();
use Text::Password::Pronounceable;
use List::Util qw(shuffle);

=head2 formatted_timezones

Returns a listref of hashrefs with display set to "offset from gmt timezone"
but value to the normal "timezone".  This way we show "-0500 America/New York"
but still work with the "America/New York" timezone we expect to be saved in the DB.

=cut

sub formatted_timezones {
    my @positive;
    my @negative;
    for my $tz ( DateTime::TimeZone->all_names ) {
        my $now = DateTime->now( time_zone => $tz );
        my $offset = $now->strftime("%z");
        my $zone_data = { offset => $offset, name => $tz };
        if ($offset =~ /^-/) {
            push @negative, $zone_data;
        } else {
            push @positive, $zone_data;
        }
    }


    @negative = sort { $b->{offset} cmp $a->{offset} ||
                       $a->{name} cmp $b->{name} } @negative;
    @positive = sort { $a->{offset} cmp $b->{offset} ||
                       $a->{name} cmp $b->{name} } @positive;;

    return [ map { { display => "$_->{offset} $_->{name}",
                    value => $_->{name}
                  }
               } (@negative,@positive)];

}


use Jifty::Record schema {

column email =>
  is mandatory,
  label is 'Email Address',
  type is 'varchar';

column name =>
  is mandatory,
  label is 'Name',
  type is 'varchar';

column password =>
  is mandatory,
  is unreadable,
  label is 'Password',
  type is 'varchar',
  hints is 'Your password should be at least six characters',
  render_as 'password',
  filters are 'Jifty::DBI::Filter::SaltHash';

column auth_token =>
  render_as 'unrendered',
  type is 'varchar',
  default is '',
  label is 'Authentication token',
  since '0.2.34',
  is protected;

column access_level =>
  is mandatory,
  default is 'guest',
  type is 'varchar',
  since '0.1.2',
  label is 'Access level',
  valid_values are qw(nonuser guest customer staff administrator),
  is protected;

column time_zone =>
  label is 'Time zone',
  type is 'text',
  since '0.2.24',
  default is 'America/New_York',
  valid_values are lazy { formatted_timezones()};


column email_confirmed =>
  is boolean,
  label is 'Email confirmed?',
  since '0.1.5',
  is protected;

column accepted_eula_version =>
  is mandatory,
  default is 0,
  type is 'integer',
  label is 'Accepted EULA version',
  since '0.1.5';

column never_email =>
  is boolean,
  label is 'Should we never send you email at all?',
  since '0.2.2';

column notification_email_frequency =>
  default is 'never',
  type is 'varchar',
  since '0.2.15',
  label is 'Email reminders',
  valid_values are qw(never daily weekly);

column email_service_updates =>
  is boolean,
  default is 't',
  label is 'Can we email you service updates?',
  hints is q{We <b>promise</b> we won't spam you, but if you want, we'll send you email when we make big changes to Hiveminder},
  since '0.2.16';

column likes_ticky_boxes =>
  is boolean,
  since '0.2.16',
  label is 'Like ticky boxes?',
  hints is '(Like this one!)';

column beta_features =>
  is boolean,
  since '0.2.17',
  label is 'Want beta features?',
  hints is q{Do you like to live on the edge? Click this box to try out Hiveminder features that are still in development.};

column created_on =>
  type is 'date',
  filters are 'Jifty::DBI::Filter::Date',
  label is 'Created on',
  since '0.2.29',
  is protected;

column number_of_invites_sent =>
  type is 'integer',
  default is 0,
  label is 'Invites sent',
  since '0.2.31',
  is protected;

column invited_by =>
  refers_to BTDT::Model::User,
  label is 'Invited by',
  since '0.2.32',
  is protected;

column last_visit =>
  type is 'timestamp',
  label is 'Last login time',
  since '0.2.19',
  is protected;

column published_addresses =>
  refers_to BTDT::Model::PublishedAddressCollection by 'user_id',
  label is 'Published email addresses';

column group_memberships =>
  refers_to BTDT::Model::GroupMemberCollection by 'actor_id',
  label is 'Group memberships';

column primary_account =>
  since '0.2.39',
  refers_to BTDT::Model::User,
  label is 'Primary address',
  is protected;

column pro_account =>
  since '0.2.60',
  is boolean,
  is protected;

# If this account was *ever* a pro account
column was_pro_account =>
  since '0.2.60',
  is boolean,
  is protected;

column paid_until =>
  type is 'date',
  label is 'Paid Until',
  filters are 'Jifty::DBI::Filter::Date',
  since '0.2.60',
  is protected;

column email_secret =>
  type is 'text',
  label is 'Email Secret',
  ajax validates,
  since '0.2.64';

column per_page =>
  type is 'integer',
  since '0.2.92',
  label is "Tasks per page",
  default is 20,
  valid_values are 10, 20, 50, {display => "All", value => 0};

column lists => references BTDT::Model::ListCollection by 'owner';

column financial_transactions =>
  refers_to BTDT::Model::FinancialTransactionCollection by 'user_id';

column calendar_starts_monday =>
  is boolean,
  since '0.2.98',
  label is 'Calendar starts on Monday?';

column taskbar_on_bottom =>
  is boolean,
  since '0.3.0',
  label is '"New Task" bar at the bottom?';
};

=head2 current_user

Some shenanagins are required to prevent circular references.

=cut

sub current_user {
    my $self = shift;
    my $rv = $self->SUPER::current_user( @_ );
    if ( @_ ) {
        Scalar::Util::weaken( $self->{'_current_user'} )
            if !Scalar::Util::isweak( $self->{'_current_user'} )
            && $self->{'_current_user'}{'user_object'}
            && $self->{'_current_user'}{'user_object'} == $self;
        $self->{'_resurrect_current_user'} =
            Scalar::Util::isweak( $self->{'_current_user'} )
                ? 1 : 0;
    } elsif ( !$rv && $self->{'_resurrect_current_user'} ) {
        my $cu = $self->{'_current_user'} = new BTDT::CurrentUser;
        $cu->user_object( $self );
        Scalar::Util::weaken( $self->{'_current_user'} )
            unless Scalar::Util::isweak( $self->{'_current_user'} );
        return $cu;
    }

    return $rv;
}

=head2 create HASH

Create a new user. Default them to a random password and name = the part of
the email address before the @

=cut

sub create {
    my $self = shift;
    my %args = (@_);

    if ($args{email} ne "nobody") {
        my ($email) = Email::Address->parse( $args{email} );
        $args{email} = lc $email->address;
        $args{name} ||= $email->name;
    }

    unless ( $args{'password'} ) {
        $args{'password'} .= chr( rand(90) + 32 ) for ( 1 .. 7 );
        $args{'access_level'} ||= "nonuser";
    }

    unless ( $args{'created_on'} ) {
        $args{'created_on'} = DateTime->now();
    }

    my (@ret) = $self->SUPER::create(%args);
    $self->__set(column => 'primary_account', value => $self->id);
    $self->regenerate_auth_token;

    # Setup a quota
    if ( $self->id ) {
        my $quota = Jifty::Plugin::Quota::Model::Quota->new( current_user => BTDT::CurrentUser->superuser );
        $quota->create_from_object( $self, type => 'disk' );
    }

    if ($self->id and $self->access_level ne "nonuser" and not $self->email_confirmed) {
        BTDT::Notification::ConfirmAddress->new( to => $self )->send;
    }

    return (@ret);
}

=head2 load_by_cols

Make sure that, when we load, we lowercase the email address

=cut

sub load_by_cols {
    my $self = shift;
    my %args = @_;
    return $self->SUPER::load_by_cols(%args) unless $args{email};
    return $self->SUPER::load_by_cols(%args) if $args{email} eq "nobody";

    # Parse only the actual email part
    my ($email) = Email::Address->parse($args{email});
    return (0, "Can't parse that as an email address") unless $email;
    my @ret = $self->SUPER::load_by_cols(%args, email => lc $email->address);
    return @ret if $ret[0];

    # Try looking up alexmv+foo@bestpractical.com as alexmv@bestpractical.com
    return @ret unless $email->address =~ /^(.*?)\+.*?(@.*)$/;
    return $self->SUPER::load_by_cols(%args, email => lc "$1$2" );
}


=head2 password_is PASSWORD

Checks if the user's password matches the provided I<PASSWORD>.

=cut

sub password_is {
    my $self = shift;
    my $pass = shift;

    return undef unless $self->_value('password');

    my ($hash, $salt) = @{$self->_value('password')};

    return 1 if ( $hash eq Digest::MD5::md5_hex($pass . $salt) );
    return undef;

}

=head2 hashed_password_is HASH TOKEN

Check if the given I<HASH> is the result of hashing our (already
salted and hashed) password with I<TOKEN>

=cut

sub hashed_password_is {
    my $self = shift;
    my $hash = shift;
    my $token = shift;

    my $password = $self->_value('password');
    return $password && Digest::MD5::md5_hex("$token " . $password->[0]) eq $hash;
}


=head2 validate_email

Makes sure that the email address looks like an email address and is
not taken.

=cut

sub validate_email {
    my $self      = shift;
    my $new_email = shift;

    # must actually have an email address
    return ( 0, q{It looks like you didn't fill in an email address.} )
        unless defined $new_email and length $new_email;

    return ( 0, "That $new_email doesn't look like an email address. Try something like <b>joebob\@example.com</b>." )
        if lc $new_email ne 'nobody' and $new_email !~ /\w+\@\w+/;

    my $temp_user = BTDT::Model::User->new();
    $temp_user->load_by_cols( 'email' => $new_email );

    # It's ok if *we* have the address we're looking for
    return ( 0, q{It looks like somebody else is using that address. Is there a chance you have another account?} )
        if $temp_user->id && ( !$self->id || $temp_user->id != $self->id );

    return 1;
}

=head2 validate_password

Makes sure that the password is six characters long or longer.

=cut

sub validate_password {
    my $self      = shift;
    my $new_value = shift;

    return ( 0, q{Passwords need to be at least six characters long} )
        if length($new_value) < 6;

    return 1;
}

=head2 after_set_password

Regenerate auth tokens on password change

=cut

sub after_set_password {
    my $self = shift;
    $self->regenerate_auth_token;
}

=head2 regenerate_auth_token

Generate a new auth_token for this user. This will invalidate any
existing feed URLs.

=cut

sub regenerate_auth_token {
    my $self = shift;
    my $auth_token = '';

    $auth_token .= unpack('H2', chr(int rand(255))) for (1..16);

    $self->set_auth_token($auth_token);
}

=head2 validate_email_secret

Makes sure that the email secret is at least three characters long and
contains only letters and numbers

=cut

sub validate_email_secret {
    my $self    = shift;
    my $value   = shift;

    return ( 0, q{Secret must be at least three characters long.} )
        if length $value < 3;

    return ( 0, q{Secret must only contain letters and numbers.} )
        if $value =~ /\W/;

    return 1;
}

=head2 after_set_pro_account

If we're making a user pro, give them an email secret and reveal their
hidden attachments.

=cut

sub after_set_pro_account {
    my $self = shift;

    if ( $self->pro_account and not defined $self->email_secret ) {
        $self->set_email_secret( $self->_random_email_secret );
    }

    if ( $self->pro_account ) {
        # Unhide any existing attachments
        my $files = BTDT::Model::TaskAttachmentCollection->new( current_user => BTDT::CurrentUser->superuser );
        $files->limit( column => 'user_id', value => $self->id );
        $files->limit( column => 'hidden', value => 1 );

        while ( my $file = $files->next ) {
            my ($ok, $msg) = $file->__set( column => 'hidden', value => 0 );

            $file->task->__set(
                column => 'attachment_count',
                value  => 'attachment_count + 1',
                is_sql_function => 1
            ) if $ok;
        }
    }
}

sub _random_email_secret {
    my $self = shift;
    my $secret;

    if ( open my $fh, '<', Jifty->config->app('EmailSecrets') ) {
        my @data = <$fh>;
        @data = shuffle @data;
        $secret = $data[ rand @data ];
        chomp $secret;
        close $fh;
    }
    else {
        $self->log->warn("Unable to open ".Jifty->config->app('EmailSecrets').": $!");

        # Fallback on Text::Password::Pronounceable
        my $pronounceable = Text::Password::Pronounceable->new(3,3);
        $secret = $pronounceable->generate;
    }
    return $secret;
}

=head2 delete

Deletes more or less everything private associated with the user and
scrubs the user record.  The record isn't actually deleted so that we can
avoid sending the user email in the future.

=cut

sub delete {
    my $self = shift;

    unless ( $self->check_delete_rights(@_) ) {
        $self->log->logcluck("Permission denied");
        return ( 0, _('Permission denied') );
    }

    my $tasks = BTDT::Model::TaskCollection->new;

    # Delete private tasks
    $tasks->limit( column => 'requestor_id', value => $self->id );
    $tasks->limit( column => 'group_id', operator => 'IS', value => 'NULL' );
    while ( my $task = $tasks->next ) { $task->delete }

    # Abandon group tasks
    $tasks->unlimit;
    $tasks->limit( column => 'owner_id', value => $self->id );
    $tasks->limit( column => 'group_id', operator => 'IS NOT', value => 'NULL' );

    my $nobody = BTDT::CurrentUser->nobody->id;
    while ( my $task = $tasks->next ) { $task->set_owner_id( $nobody ) }

    # Delete published addresses
    my $addresses = $self->published_addresses;
    while ( my $address = $addresses->next ) { $address->delete }

    # Delete group memberships
    my $memberships = $self->group_memberships;
    while ( my $member = $memberships->next ) { $member->delete }

    # Delete group invitations
    my $invites = $self->group_invitations;
    while ( my $invite = $invites->next ) { $invite->delete }

    # Delete UserIMs
    my $ims = BTDT::Model::UserIMCollection->new;
    $ims->limit( column => 'user_id', value => $self->id );
    while ( my $im = $ims->next ) { $im->delete }

    # Scrub
    my @keep = qw( id name email created_on invited_by );
    for my $column ( $self->columns ) {
        next if $column->virtual;
        next if grep { $column->name eq $_ } @keep;

        # Get the right "unset" value
        my $value = 'NULL';
        if ( $column->mandatory ) {
            if    ( $column->is_string )  { $value = "''" }
            elsif ( $column->is_numeric ) { $value = '0' }
        }

        my $sql = <<"        SQL";
            UPDATE @{[$self->table]}
               SET @{[$column->name]} = $value
             WHERE id = ?
        SQL

        Jifty->handle->simple_query( $sql, $self->id );
    }
    $self->set_name( $self->name . ' (deleted)' );
    $self->set_never_email( 1 );
    $self->set_notification_email_frequency( 'never' );
    $self->set_email_service_updates( 0 );
    $self->set_email_confirmed( 0 );
    $self->__set( column => 'access_level', value => 'nonuser' );

    return 1;
}

=head2 is_deleted

Does this user account look like it has been deleted?

=cut

sub is_deleted {
    my $self = shift;

    return $self->never_email
        && !$self->email_confirmed
        && $self->access_level eq 'nonuser'
        && $self->name =~ / \(deleted\)$/;
}

# XXX TODO: The caching of all these private rights checking methods is
# really begging to be refactored
#
sub _in_any_same_group {
    my ($self, $other) = @_;
    my $cache = Jifty->handler->stash;
    $cache = $cache->{SAME_GROUP_CACHE} ||= {} if $cache;
    my @id = sort map { $_->id } ($self, $other);
    return $cache->{$id[0]}{$id[1]} if exists $cache->{$id[0]}{$id[1]};

    my $groups = BTDT::Model::GroupCollection->new(current_user => BTDT::CurrentUser->superuser);
    $groups->limit_contains_user($self);
    $groups->limit_contains_user($other);

    $groups->set_page_info(per_page =>1);
    return $cache->{$id[0]}{$id[1]} = $groups->first() ? 1 : 0;
}

# XXX TODO: These next two methods might want to be generally refactored
# since they include very similar code, just with a reversed sender and
# recipient
sub _has_invited_into_group {
    my ($self, $other) = @_;
    my $cache = Jifty->handler->stash;
    $cache = $cache->{INVITED_TO_CACHE} ||= {} if $cache;
    my @id = sort map { $_->id } ($self, $other);
    return $cache->{$id[0]}{$id[1]} if exists $cache->{$id[0]}{$id[1]};

    my $invites = BTDT::Model::GroupInvitationCollection->new( current_user => BTDT::CurrentUser->superuser);
    $invites->limit(column => 'sender_id', value => $self->id);
    $invites->limit(column => 'recipient_id', value => $other->id);
    $invites->set_page_info(per_page =>1);
    return $cache->{$id[0]}{$id[1]} = $invites->first() ? 1 : 0;
}

sub _has_been_invited_into_group_by {
    my ($self, $other) = @_;
    my $cache = Jifty->handler->stash;
    $cache = $cache->{INVITED_BY_CACHE} ||= {} if $cache;
    my @id = sort map { $_->id } ($self, $other);
    return $cache->{$id[0]}{$id[1]} if exists $cache->{$id[0]}{$id[1]};

    my $invites = BTDT::Model::GroupInvitationCollection->new( current_user => BTDT::CurrentUser->superuser);
    $invites->limit(column => 'sender_id', value => $other->id);
    $invites->limit(column => 'recipient_id', value => $self->id);
    $invites->set_page_info(per_page =>1);
    return $cache->{$id[0]}{$id[1]} = $invites->first() ? 1 : 0;
}

sub _has_been_invited_into_group_organized_by {
    my ($self, $other) = @_;
    my $cache = Jifty->handler->stash;
    $cache = $cache->{INVITED_BY_FELLOW_ORGANIZER_CACHE} ||= {} if $cache;
    my @id = sort map { $_->id } ($self, $other);
    return $cache->{$id[0]}{$id[1]} if exists $cache->{$id[0]}{$id[1]};

    my $invites = BTDT::Model::GroupInvitationCollection->new();
    $invites->limit(column => 'recipient_id', value => $self->id);

    my $members = $invites->new_alias( BTDT::Model::GroupMember->table );

    $invites->join( alias1  => "main",
                    column1 => "group_id",
                    alias2  => $members,
                    column2 => "group_id" );

    $invites->limit( alias  => $members,
                     column => "role",
                     value  => "organizer" );

    $invites->limit( alias  => $members,
                     column => "actor_id",
                     value  => $other->id );


    $invites->set_page_info(per_page =>1);
    return $cache->{$id[0]}{$id[1]} = $invites->first() ? 1 : 0;
}

sub _has_accepted_task_of {
    my ($self, $other) = @_;
    my $cache = Jifty->handler->stash;
    $cache = $cache->{ACCEPTED_CACHE} ||= {} if $cache;
    my @id = map { $_->id } ($self, $other);
    return $cache->{$id[0]}{$id[1]} if exists $cache->{$id[0]}{$id[1]};

    my $tasks = BTDT::Model::TaskCollection->new();
    $tasks->limit(column => 'requestor_id', value => $other->id);
    $tasks->limit(column => 'owner_id', value => $self->id);


    $tasks->set_page_info(per_page =>1);
    return $cache->{$id[0]}{$id[1]} = $tasks->first() ? 1 : 0;
}

sub _requested_or_owns_task_in_group_with_member {
    my ($self, $other) = @_;
    my $cache = Jifty->handler->stash;
    $cache = $cache->{GROUP_W_MEMBER_CACHE} ||= {} if $cache;
    my @id = map { $_->id } ($self, $other);
    return $cache->{$id[0]}{$id[1]} if exists $cache->{$id[0]}{$id[1]};
    my $tasks = BTDT::Model::TaskCollection->new();
    my $members = $tasks->new_alias( BTDT::Model::GroupMember->table );
    $tasks->join( alias1  => "main",
                    column1 => "group_id",
                    alias2  => $members,
                    column2 => "group_id" );
    $tasks->limit(alias => $members, column =>'actor_id', value  => $other->id);

    $tasks->limit(subclause => 'otherperson', column => 'requestor_id', value => $self->id, entryaggregator => 'or');
    $tasks->limit(subclause => 'otherperson', column => 'owner_id', value => $self->id, entryaggregator => 'or');



    $tasks->set_page_info(per_page =>1);
    return $cache->{$id[0]}{$id[1]} = $tasks->first() ? 1 : 0;
}

=head2 people_known

Returns a list of users this user "knows."  This equates to users who have
assigned tasks, been assigned tasks, are in the same group, etc.
Essentially the users with which this user has had some sort of contact.

=cut

sub people_known {
    my $self  = shift;

    my $cache = Jifty->handler->stash;
    $cache = $cache->{PEOPLE_KNOWN_CACHE} ||= {} if $cache;
    return @{ $cache->{ $self->id } } if exists $cache->{ $self->id };

    my %seen;

    # Add all the users who have been assigned tasks by this user
    {
        my $users =
          BTDT::Model::UserCollection->new( results_are_readable => 1 );
        my $tasks_alias = $users->join(
            alias1  => 'main',
            column1 => 'id',
            table2  => 'tasks',
            column2 => 'owner_id'
        );
        $users->limit(
            alias  => $tasks_alias,
            column => 'requestor_id',
            value  => Jifty->web->current_user->id,
        );
        $users->limit(
            entry_aggregator => 'and',
            column           => 'id',
            operator         => "!=",
            value            => BTDT::CurrentUser->nobody->id
        );
        while ( my $user = $users->next ) {
            $seen{ $user->id } ||= $user;
        }
    }

    # Add all the members in the same groups as this user
    {
        my $users =
          BTDT::Model::UserCollection->new( results_are_readable => 1 );
        my $group1 = $users->join(
            alias1  => 'main',
            column1 => 'id',
            table2  => 'group_members',
            column2 => 'actor_id'
        );
        my $group2 = $users->join(
            alias1  => $group1,
            column1 => 'group_id',
            table2  => 'group_members',
            column2 => 'group_id'
        );
        $users->limit(
            alias  => $group2,
            column => 'actor_id',
            value  => Jifty->web->current_user->id
        );
        while ( my $user = $users->next ) {
            $seen{ $user->id } ||= $user;
        }
    }

    # Add all the users who have assigned tasks to this user
    {
        my $users =
          BTDT::Model::UserCollection->new( results_are_readable => 1 );
        my $tasks_alias = $users->join(
            alias1  => 'main',
            column1 => 'id',
            table2  => 'tasks',
            column2 => 'owner_id'
        );
        $users->limit(
            alias  => $tasks_alias,
            column => 'owner_id',
            value  => $self->id,
        );
        while ( my $user = $users->next ) {
            $seen{ $user->id } ||= $user;
        }
    }
    my @users = grep { $_->id != $self->id } values %seen;
    # XXX: switch to return ro-object or id, email, name pairs.
    $cache->{ $self->id } = \@users;
    return @users;
}

=head2 current_user_can RIGHT

Returns true if the current_user has the right RIGHT for this user.
Returns false otherwise.

=cut

sub current_user_can {
    my $self  = shift;
    my $right = shift;
    my %args = (@_);

    # XXXX TODO: precache this
    return 1 if $self->SUPER::current_user_can($right, @_);

    if ($right eq 'update' and !$args{'column'}) {
        $args{column} = "";
    }
    unless ( $self->current_user ) {
        $self->log->error(
            "$self -> current_user_can called with no valid currentuser");
        Carp::confess;
        return 0;
    }
    unless ($right) {
        $self->log->error(
            "$self -> current_user_can called with no valid right");
        Carp::confess;
        return 0;
    }

    # Create
    #   - deferred to superclass

    # See
    #   - user can read any column of themselves
    #   - related user can only read email and name
    #
    if (    $right eq 'read'
        and $self->current_user->id
        and $self->id )
    {

        my $other = $self->current_user;

        # Is it me?
        return (1) if $other->id == $self->id;

        # Or is it staff?
        return (1) if $other->access_level eq 'staff';

        if ( not defined $args{'column'} or $args{'column'} =~ /^(?:email|name|pro_account|access_level)$/i ) {
            # Is he in any groups with me?
            return (1) if $self->_in_any_same_group($other->user_object);

            # Has he assigned me any tasks I've accepted?
            return (1) if $self->_has_accepted_task_of($other->user_object);

            # Have I assigned him any tasks?
            my $tasks = BTDT::Model::TaskCollection->new();
            $tasks->limit(column => 'requestor_id', value => $self->id);
            $tasks->limit(column => 'owner_id', value => $other->id);
            $tasks->columns('id');
            $tasks->set_page_info(per_page => 1);
            return (1) if($tasks->first());

            # Have I invited him into a group OR has he invited me?
            return (1)
                if    $self->_has_invited_into_group($other->user_object)
                   or $self->_has_been_invited_into_group_organized_by(
                            $other->user_object
                      );


            return (1) if $self->_requested_or_owns_task_in_group_with_member($self->current_user);
        }
    }

    #Edit: Am I an administrator or is it me?
    if (    $right eq 'update'
        and $self->id
        and $self->current_user->id == $self->id
        and $args{'column'} !~ /^(?:email_confirmed
                                   |last_visit
                                   |access_level
                                   |number_of_invites_sent
                                   |primary_account
                                   |accepted_eula_version
                                   |paid_until
                                   |pro_account
                                   |was_pro_account)$/x )
    {
        # Admin rights are handled by the superclass
        return (1);
    }

    # Delete: Is it me?
    if (    $right eq 'delete'
        and $self->id
        and $self->current_user->id == $self->id )
    {
        return 1;
    }

    # Delete: Or is the current user staff?
    if ( $right eq 'delete' and $self->current_user->access_level eq 'staff' ) {
        return 1;
    }

    # If we don't get a pass, defer to the superclass
    return 0;

}

=head2 set_email ADDRESS

Whenever a user's email is set to a new value, we need to make
sure they reconfirm it.


=cut

sub set_email {
    my $self  = shift;
    my $new_address = shift;
    my $email = $self->__value('email');

    my @ret = $self->_set( column => 'email', value => $new_address);

    unless ( $email eq $self->__value('email') ) {
        $self->__set( column => 'email_confirmed', value => '0' );
        BTDT::Notification::ConfirmAddress->new( to => $self, existing => 1 )->send;
    }

    return (@ret);

}


=head2 publish_address { [address => LOCALPART ], }

Add a new published address for this user.  Returns the results of the
L<BTDT::Model::PublishedAddress/create> call.

=cut

sub publish_address {
    my $self = shift;
    my %args = (
        address => undef,
        @_
    );

    return ( 0, 'Permission denied' )
        unless $self->current_user_can('update', column => "BTDT::Model::PublishedAddress");

    my $address = BTDT::Model::PublishedAddress->new();
    return $address->create(
        user_id => $self->id,
        action  => 'CreateTask',
        address => $args{address},
    );

}

=head2 unpublish_address { [ address => ADDRESS ]}

Remove the address ADDRESS as one of mine.

=cut

sub unpublish_address {
    my $self = shift;
    my %args = ( address => undef,
                 @_ );

    return (0, 'Permission denied') unless $self->current_user_can('update', "BTDT::Model::PublishedAddress");
    my $addr = BTDT::Model::PublishedAddress->new();
    $addr->load_by_cols( user => $self->id,
                         address => $args{'address'});


    return(0, 'Address not found') unless $addr->id;

    my ($val,$msg) = $addr->delete();
    return (0, $msg)    unless ($val);
    return(1, "Address removed");
}

=head2 name_or_email

Returns the name if it is not the same as the first part of the email.
If it is, return the full email address for clarity.

=cut

sub name_or_email {
    my $self = shift;
    return $self->name if $self->email eq 'superuser@localhost';
    return $self->email =~ /^\Q@{[$self->name]}\E@/i
                ? $self->email
                : $self->name;
}

=head2 groups

Returns a L<BTDT::Model::GroupCollection> of the groups that the user
is in.

=cut

sub groups {
    my $self    = shift;
    my $groups = BTDT::Model::GroupCollection->new(
        results_are_readable => ( $self->id == $self->current_user->id ) );
    $groups->limit_contains_user($self);
    $groups->order_by( column => 'name' );
    return $groups
}

=head2 cached_group_ids

Returns an array reference of group IDs that this user is a part of.
This information is stored in memcached, if possible, to efficient
access.

=cut

sub cached_group_ids {
    my $self = shift;
    return [map {$_->id} @{$self->groups}] unless BTDT->memcached;

    my $ret = BTDT->memcached->get($self->_primary_cache_key . ".groups");
    return $ret if $ret;

    my $ids = [map {$_->id} @{$self->groups}];
    BTDT->memcached->set($self->_primary_cache_key . ".groups", $ids, 60*60);
    return $ids;
}

=head2 purge_cached_group_ids

Clears the memcached cache of which groups this user is a part of.

=cut

sub purge_cached_group_ids {
    my $self = shift;
    BTDT->memcached->delete($self->_primary_cache_key . ".groups")
        if BTDT->memcached;
}

=head2 group_invitations

Returns a L<BTDT::Model::GroupInvitationCollection> of outstanding
group invitations to the user

=cut

sub group_invitations {
    my $self = shift;
    my $invites = BTDT::Model::GroupInvitationCollection->new();
    $invites->limit(column => 'recipient_id', value => $self->id);
    $invites->limit(column => 'cancelled', value => 0);
    return $invites;
}

=head2 number_of_invites_left

Returns the number of invites this user has left.

=cut

sub number_of_invites_left {
    my $self = shift;
    return Jifty->config->app('InvitesPerUser') - $self->number_of_invites_sent;
}

=head2 add_to_invites_sent

Increments the number of invites sent by the supplied argument, or 1 by default.

=cut

sub add_to_invites_sent {
    my $self  = shift;
    my $value = shift || 1;
    return $self->__set( column => 'number_of_invites_sent',
                         value  => $self->__value('number_of_invites_sent') + $value );
}

=head2 english_paid_until [PRECISION]

Returns a natural language string describing paid_until

=cut

sub english_paid_until {
    my $self      = shift;
    my $precision = shift || 1;

    use Time::Duration qw(ago);
    my $today = DateTime->today->epoch;
    my $until = $self->paid_until->epoch;
    return $today == $until ? 'today' : ago( $today - $until, $precision );
}

=head2 formatted_email

Returns a string suitible for use in an email client, with the user's
name and email address.

=cut

sub formatted_email {
    my $self = shift;
    return Email::Address->new( $self->name => $self->email )->format;
}

=head2 disk_quota

Returns the user's disk quota object

=cut

sub disk_quota {
    my $self  = shift;
    my $quota = Jifty::Plugin::Quota::Model::Quota->new;
    $quota->load_by_object( $self, type => 'disk' );
    return $quota;
}

=head2 resolve EMAIL

This class method returns the user ID associated with an email
address, creating one if need be.  Returns undef if an undef, empty,
or unparsable string is found.

=cut

sub resolve {
    my $class = shift;
    my ($email) = @_;
    return unless defined $email and length $email;
    if ($email =~ /\@/) {
        my $obj = BTDT::Model::User->new( current_user => BTDT::CurrentUser->superuser );
        $obj->load_or_create( email => $email );
        return $obj->id;
    } elsif (lc $email eq "anyone" or lc $email eq "me" ) {
        return Jifty->web->current_user->id;
    } elsif (lc $email eq "nobody" ) {
        return BTDT::CurrentUser->nobody->id;
    } else {
        return undef;
    }
}

=head2 enumerable

Don't ever attempt to provide a drop-down of tasks.

=cut

sub enumerable { 0 }

1;
