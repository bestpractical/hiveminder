use warnings;
use strict;

=head1 NAME

BTDT::Action::EmailDispatch

=cut

package BTDT::Action::EmailDispatch;
use base qw/BTDT::Action Jifty::Action/;

use BTDT::Notification::EmailError;

=head2 arguments

address

email

envelope_sender '--sender' => 'gooduser@example.com'

=cut

sub arguments {
    {   address         => {},
        email           => {},
        envelope_sender => {},
    };
}

=head2 setup

Parse the email, and always provide a C<Message-ID> property in the
content of the L<Jifty::Result>.  This is not in L</take_action>,
because we want the message-id even if validation fails.

=cut

sub setup {
    my $self = shift;
    my $email = Email::MIME->new( $self->argument_value('email') || '' );
    $self->result->content("Message-ID" => $email->header("Message-ID"));
    return 1;
}

=head2 validate_address

Make sure the email address looks sane

=cut

sub validate_address {
    my $self  = shift;
    my $email = shift;

    my $pa = BTDT::Model::PublishedAddress->new(
        current_user => BTDT::CurrentUser->superuser );
    $pa->load_by_cols( address => $email );
    if (   $pa->id
        or $email =~ /^comment-\d+-\w+\@.+$/
        or $email =~ /^.+\@.+\.with\.hm$/ )
    {
        return $self->validation_ok('address');
    } else {
        return $self->validation_error(
            address => "Address '$email' didn't match a published address" );
    }

}

=head2 take_action

Dispatches the C<email> based on the C<address> by looking up the
appropriate L<BTDT::Model::PublishedAddress>.  The only currently
supported action for specifically published addresses is
L<BTDT::Action::CreateTask>.  Other email addresses (comment,
.with.hm, etc) have different effects.

=cut

sub take_action {
    my $self = shift;

    my $email = Email::MIME->new( $self->argument_value('email') );
    my $to = Encode::encode('MIME-Header',$self->argument_value('address'));
    $email->header_set('X-Hiveminder-delivered-to', $to);

    # Load the sending address, making it a user if need be
    my ($from) = Email::Address->parse( $email->header("From") );
    return unless $from;

    if ( $from->address eq 'postmaster@hiveminder.com' ) {
        # If we're looping, drop it in the floor.
        $self->result->error("Postmaster loop");
        return;
    }

    if (    $from->address eq 'mail@vodafone-sms.de'
        and $email->header('Subject') =~ /^\s*Zustellbenachrichtigung \/ Delivery Notification\s*$/ )
    {
        # Drop a loop-making delivery notification on the floor
        $self->result->error("Preventing loop with Vodafone's mail-to-SMS gateway");
        $self->log->warn( $self->result->error );
        return;
    }

    if ( ( $email->header('X-Hiveminder') || '' ) eq
        Jifty->config->framework('Web')->{BaseURL} )
    {
        $self->send_bounce( 'BTDT::Notification::EmailError::Loop', $self );
        $self->result->error("Self-loop");
        return unless $email->header('X-Hiveminder-Requestor') and $email->header('X-Hiveminder-Id');
        my ($requestor) = Email::Address->parse($email->header('X-Hiveminder-Requestor'));
        return unless $from and $from->address;
        my $current = BTDT::CurrentUser->new(email => $requestor->address );
        return unless $current->id;
        my $task = BTDT::Model::Task->new( current_user => $current );
        $task->load( $email->header('X-Hiveminder-Id') );
        return unless $task->id and $task->current_user_can('update');
        $task->start_transaction( "mailloop" );
        $task->end_transaction;
        return;
    }

    # Make sure this isn't a dup
    if (defined $email->header("Message-ID")) {
        my $already = BTDT::Model::TaskEmailCollection->new;
        $already->limit( column => "message_id",   value => $email->header("Message-ID"));
        $already->limit( column => "delivered_to", value => $self->argument_value('address'));
        if ($already->count) {
            $self->result->error("Duplicate message-ID");
            return;
        }
    }

    my $sender = BTDT::Model::User->new(
        current_user => BTDT::CurrentUser->superuser );
    $sender->load_or_create( email => $from->address );

    # Load that as a CurrentUser
    my $current = BTDT::CurrentUser->new( id => $sender->id );
    Jifty->web->temporary_current_user($current);

    # See if this is a published address
    my $address = $self->argument_value('address');
    my $pa      = BTDT::Model::PublishedAddress->new(
        current_user => BTDT::CurrentUser->superuser );
    $pa->load_by_cols( address => $address );

    my $action;
    if ( $address =~ /^comment-(\d+)-(\w+)\@.+$/ ) {
        my $task = BTDT::Model::Task->new( current_user => $current );
        $task->load($1);
        unless ($task->id and $task->auth_token eq $2) {
            $self->result->error("Wrong token or no task");
            return;
        }

        $action = Jifty->web->new_action(
            class     => "CreateTaskEmail",
            moniker   => "email_dispatch",
            arguments => {
                message => $email->as_string,
                task_id => $task->id,
            },

            # Clobber the current user -- knowing the auth token is
            # enough to let you comment on the task, no matter what
            # address you're sending from.
            current_user => BTDT::CurrentUser->superuser
        );
    } elsif ( $address =~ /^(.+\@.+)\.(\w{3,})\.with\.hm$/ ) {
        my $owner  = $1;
        my $secret = $2;

        my $recipient = BTDT::Model::User->new(
            current_user => BTDT::CurrentUser->superuser );
        $recipient->load_by_cols( email => $owner );
        my $pro_recipient
            = ( $recipient->id and $recipient->pro_account ? 1 : 0 );

        # Only let Pro users use with.hm
        if ( not $sender->pro_account ) {
            $self->log->debug("Sender @{[$sender->email]} is not a pro user");
            $self->send_bounce( 'BTDT::Notification::EmailError::ProOnly',
                $self );
            Jifty->web->temporary_current_user(undef);
            $self->result->error("Non-pro used with.hm");
            return;
        }

        # Make sure we have a sender who knows his secret
        if ( $sender->email_secret ne $secret ) {
            $self->log->warn(
                "Sender @{[$sender->email]} did not provide the secret");
            $self->send_bounce( 'BTDT::Notification::EmailError::WrongSecret',
                $self );
            Jifty->web->temporary_current_user(undef);
            $self->result->error("Used wrong secret on with.hm");
            return;
        }

        $action = Jifty->web->new_action(
            class     => 'CreateTask',
            moniker   => 'email_dispatch',
            arguments => {
                requestor_id  => $current->id,
                owner_id      => $owner,
                summary       => $email->header('Subject') || '',
                email_content => $email->as_string,
            },
            current_user => Jifty->web->current_user,
        );
    } elsif ( $pa->id ) {
        # This is a published address

        # XXX Do threading here?  Look at In-Reply-To and References
        # headers, look up TaskEmails by (decoded) ID until they
        # match, add a TaskEmail to that task

        if ( $pa->action eq "CreateTask" ) {

            my $attrs = $self->task_attributes($pa, $email);
            $action = Jifty->web->new_action(
                class     => $pa->action,
                moniker   => "email_dispatch",
                arguments => {
                    %$attrs,
                    requestor_id  => $current->id,
                },

                # We clobber the current_user so anyone can create
                # group tasks or accepted tasks, which is not usually
                # the case
                current_user => BTDT::CurrentUser->superuser
            );
        }
    }

    if ($action) {
        $action->run;
        if ( $action->result->failure ) {
            $self->send_bounce( 'BTDT::Notification::EmailError', $action );
            $self->log->warn("$action failed");
            $self->result->error("Sub-action failed");
            $self->result->content( result => $action->result );
        } else {
            $self->result->message("Dispatched to an action $action");
            $self->result->content( result => $action->result );
        }

    }
    Jifty->web->temporary_current_user(undef);
}

=head2 send_bounce CLASS ACTION

Sends a bounce message to the envelope sender.  C<CLASS> is the
Notification class to use to send it, and C<ACTION> is provided to it
as an C<action> argument.

=cut

sub send_bounce {
    my $self   = shift;
    my $class  = shift;
    my $action = shift;

    # Generate a bounce with the error message
    my $to = BTDT::Model::User->new(
        current_user => BTDT::CurrentUser->superuser );
    $to->load_or_create( email => $self->argument_value('envelope_sender') );
    $class->new(
        to      => $to,
        address => $self->argument_value('address'),
        result  => $action->result,
        email   => $self->argument_value('email'),
    )->send;
}

=head2 task_attributes PublishedAddress, Email -> hashref

Parses the published address' auto addresses and the email's subject as a task
summary and returns a massaged hashref of task attributes.

=cut

sub task_attributes {
    my $self  = shift;
    my $pa    = shift;
    my $email = shift;

    my $subject = $email->header("Subject");
    my $auto    = $pa->auto_attributes || '';
    my $combined = join(' ', $subject, $auto);

    my ($subject_attr, $auto_attr, $combined_attr) =
        map { BTDT::Model::Task->parse_summary($_) }
            $subject, $auto, $combined;

    # collapse implicit/explicit fields, we're using everything here
    for ($subject_attr, $auto_attr, $combined_attr) {
        %$_ = (%{ $_->{implicit} }, %{ $_->{explicit} });
    }

    # subject cannot ever set owner or group
    delete $subject_attr->{owner_id};
    delete $subject_attr->{group_id};

    # auto attributes have precedence over subject attributes
    # this used to be the other way around
    my %attrs = (%$subject_attr, %$auto_attr);

    # use tags from both parts
    $attrs{tags} = $combined_attr->{tags};

    # more attributes from address and email
    $attrs{owner_id} = $pa->user->email if $pa->user->id;
    $attrs{group_id} = $pa->group->id if $pa->group->id;
    $attrs{accepted} = $pa->user->id && $pa->auto_accept ? 1 : undef;
    $attrs{summary}  = $subject;
    $attrs{email_content} = $email->as_string,

    return \%attrs;
}

1;
