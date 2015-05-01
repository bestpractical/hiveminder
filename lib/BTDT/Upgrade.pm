use warnings;
use strict;

package BTDT::Upgrade;

use Jifty::Upgrade;
use base qw/Jifty::Upgrade/;


require BTDT::CurrentUser;
require BTDT::Model::User;

my $bootstrap = BTDT::CurrentUser->new(_bootstrap => '1');

=head1 NAME

BTDT::Upgrade

=head2 Version 0.2.2

Add 'nobody' user.

=cut

since '0.2.2' => sub {
    my $nobody = BTDT::Model::User->new(current_user => $bootstrap);
    my ($id, $msg) = $nobody->create( email => 'nobody@localhost', access_level => 'guest');
    unless ($nobody->id) {
        die "Couldn't create a nobody $id: $msg";
    }

};

=head2 Version 0.2.4

Nobody's name is "Nobody"

=cut

since '0.2.4' => sub {
    my $nobody = BTDT::Model::User->new( current_user => $bootstrap);
    $nobody->load_by_cols( email => 'nobody@localhost' );
    $nobody->user_object->set_name("Nobody");
    unless ($nobody->user_object->name eq "Nobody") {
        die "Name wasn't updated!";
    }
};

=head2 Version 0.2.8

Change the C<task_history> table to be C<task_histories>m and
C<task_transaction> to be C<task_transactions> to standardize on
plural table names.

=cut

since '0.2.8' => sub {
    Jifty->handle->simple_query("ALTER TABLE task_history RENAME TO task_histories");
    Jifty->handle->simple_query("ALTER TABLE task_transaction RENAME TO task_transactions");
};

=head2 Version 0.2.10

The highest access level is "administrator" not "admin".  Update the
superuser accordingly.

=cut

since '0.2.10' => sub {
    my $superuser = BTDT::Model::User->new(current_user => $bootstrap);
    $superuser->load_by_cols( email => 'superuser@localhost' );
    $superuser->set_access_level("administrator");
    unless ($superuser->access_level eq "administrator") {
        die "Access level wasn't updated!";
    }
};

=head2 Version 0.2.13

Due dates and start dates became dates, not timestamps

=cut

since '0.2.13' => sub {
    Jifty->handle->simple_query("ALTER TABLE tasks ALTER COLUMN due TYPE date");
    Jifty->handle->simple_query("ALTER TABLE tasks ALTER COLUMN starts TYPE date");
};

=head2 Version 0.2.18

We started having 'tags' as a real column in the task table, in
addition to the pre-existing TaskTags relation.

=cut

since '0.2.18' => sub {
    my $taskcollection = BTDT::Model::TaskCollection->new( current_user => BTDT::CurrentUser->superuser );
    $taskcollection->unlimit;
    while (my $task = $taskcollection->next) {
        $task->_set( column => 'tags', value => $task->tag_collection->as_quoted_string);
    }
};

=head2 Version 0.2.25

Fix the denormalization of tags, such that '' is stored instead of NULL.

=cut

since '0.2.25' => sub {
    Jifty->handle->simple_query("UPDATE tasks SET tags = '' WHERE tags IS NULL");
};

=head2 Version 0.2.27

We got a dependency cache, so we need to set it for existing tasks

=cut

since '0.2.27' => sub {
    my $taskcollection = BTDT::Model::TaskCollection->new( current_user => BTDT::CurrentUser->superuser );
    $taskcollection->unlimit;
    while (my $task = $taskcollection->next) {
        $task->_update_dependency_cache;
    }
};

=head2 Version 0.2.28

In group context, "watcher" became "guest", and "manager" became
"organizer".

=cut

since '0.2.28' => sub {
    my %mapping = ( watcher => "guest", member => "member", manager => "organizer");

    my $invites = BTDT::Model::GroupInvitationCollection->new( current_user => BTDT::CurrentUser->superuser );
    $invites->unlimit;
    $_->__set( column => 'role', value => $mapping{$_->role} )
      while ($_ = $invites->next);

    my $members = BTDT::Model::GroupMemberCollection->new( current_user => BTDT::CurrentUser->superuser );
    $members->unlimit;
    $_->__set( column => 'role', value => $mapping{$_->role} )
      while ($_ = $members->next);
};

=head2 Version 0.2.29

Added created_on field to BTDT::Model::User.

=cut

since '0.2.29' => sub {
    my $usercollection = BTDT::Model::UserCollection->new( current_user => BTDT::CurrentUser->superuser );
    $usercollection->unlimit;
    while (my $user = $usercollection->next) {
        $user->_set( column => 'created_on', value => '2006-01-01');
    }

};

=head2 Version 0.2.30

Added message_id column to TaskEmails

=cut

since '0.2.30' => sub {
    my $taskemails = BTDT::Model::TaskEmailCollection->new( current_user => BTDT::CurrentUser->superuser );
    $taskemails->unlimit;
    while ( my $taskemail = $taskemails->next ) {
        my $email = Email::Simple->new( $taskemail->message );
        $email->header_set( "Message-ID" => BTDT::Notification->new_message_id )
            unless $email->header("Message-ID");
        $taskemail->set_message_id( $email->header('Message-ID') );
        $taskemail->set_message( $email->as_string );
    }
};

=head2 Version 0.2.33

Nobody's email is now just "nobody"

=cut

since '0.2.33' => sub {
    my $nobody = BTDT::Model::User->new( current_user => $bootstrap);
    $nobody->load_by_cols( email => 'nobody@localhost' );
    $nobody->set_email("nobody");
    unless ($nobody->email eq "nobody") {
        die "Email wasn't updated!";
    }
};

=head2 Version 0.2.34

Passwords are now stored salted and hashed in the database

=cut

since '0.2.34' => sub {
    my $users = BTDT::Model::UserCollection->new(current_user => $bootstrap);
    $users->unlimit;

    while( my $user = $users->next ) {
        #Read the raw password to avoid filtering

        my $val = Jifty->handle->fetch_result('SELECT password FROM ' .
                                              BTDT::Model::User->table .
                                                ' WHERE id = ?', $user->id);
#        die($val->error_message) unless $val;

        my $digest = Digest::MD5->new();

#       $digest->add('Internal secret XXX TODO REPLACE');
#       $digest->add( $self->_value('password') );
#       $digest->add( $self->id() );

        $digest->add('Internal secret XXX TODO REPLACE');
        $digest->add( $val );
        $digest->add( $user->id() );

        # Set the auth token so that old feed links work unless the
        # user regenerates them
        $user->set_auth_token( $digest->hexdigest );

        # The filter will encode the password on set
        $user->set_password($val);
    }
};

since '0.2.36' => sub {
    Jifty->handle->simple_query("UPDATE tasks SET last_repeat = id");
    Jifty->handle->simple_query("UPDATE tasks SET repeat_of = id");

};

since '0.2.39' => sub {
    Jifty->handle->simple_query("UPDATE users SET primary_account = id");
};

=head2 Version 0.2.64

Set default email_secrets for users who are already pro users

=cut

since '0.2.64' => sub {
    my $users = BTDT::Model::UserCollection->new(current_user => $bootstrap);
    $users->limit( column => 'pro_account', value => 1 );
    $users->limit( column => 'email_secret', operator => 'IS', value => 'NULL' );

    use Text::Password::Pronounceable;
    my $secret = Text::Password::Pronounceable->new(3,3);

    while ( my $user = $users->next ) {
        $user->set_email_secret( $secret->generate );
    }
};

=head2 Version 0.2.74

Convert percentage discounts to dollar discounts with minimum prices

=cut

since '0.2.74' => sub {
    Jifty->handle->simple_query("UPDATE coupons SET discount = floor(discount / 100.0 * 30)");
};

=head2 Version 0.2.83

Paths on transactions for flags became 'TXN' instead of null to work
around a jifty annoyance.

=cut

since '0.2.83' => sub {
    Jifty->handle->simple_query("UPDATE imapflags SET path = 'TXN' where path IS NULL");
};

=head2 Version 0.2.86

Collect disk usage stats and create disk quotas for existing users, making
sure to set existing usages

=cut

since '0.2.86' => sub {
    # Collect usage information
    my $files = BTDT::Model::TaskAttachmentCollection->new( current_user => $bootstrap );
    $files->unlimit;

    my %usage;
    while ( my $file = $files->next ) {
        next if not defined $file->size;
        $usage{$file->user_id} += $file->size;
    }

    # Create quota records for each user
    my $users = BTDT::Model::UserCollection->new(current_user => $bootstrap);
    $users->unlimit;

    while ( my $user = $users->next ) {
        my $quota = Jifty::Plugin::Quota::Model::Quota->new( current_user => $bootstrap );
        $quota->create_from_object(
            $user,
            type  => 'disk',
            usage => ( defined $usage{$user->id} ? $usage{$user->id} : 0 )
        );
    }
};

=head2 Version 0.2.88

Count attachments per task and set attachment_count appropriately

=cut

since '0.2.88' => sub {
    # Collect counts
    my $files = BTDT::Model::TaskAttachmentCollection->new( current_user => $bootstrap );
    $files->limit( column => 'hidden', value => 0 );
    $files->unlimit;

    my %count;
    while ( my $file = $files->next ) {
        $count{$file->task_id}++;
    }

    # Set attachment_count for each task
    for my $id ( keys %count ) {
        my $task = BTDT::Model::Task->new( current_user => $bootstrap );
        $task->load($id);
        next if not $task->id;
        $task->__set( column => 'attachment_count', value => $count{$id} );
    }
};

=head2 Version 0.2.97

Move owner, group, project, milestone, as well as time worked,
updated, and estimate into fields on the txn, so we can aggregate
better based on them.  This involves crawling the transactions table
to recreate the relevant history.

=cut

since '0.2.97' => sub {
    warn "Please bin bin/version-0.2.97-upgrade at your earliest convenience.\n";
};

1;
