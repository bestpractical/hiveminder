
use warnings;
use strict;

=head1 NAME

BTDT::Action::SendFeedback

=cut

package BTDT::Action::SendFeedback;
use base qw/BTDT::Action Jifty::Action/;


=head2 arguments

The fields for C<SendFeedback> are:

=over 4

=item content: a big box where the user can type in what eits them

=item extra_info: a place to store extra debugging information

=back

=cut

sub arguments {
        {
            content => {
                    label   => '',
                    render_as => 'Textarea',
                    rows => 5,
                    cols => 60,
                    sticky => 0
            },
            extra_info => {
                    render_as => 'Hidden'
            },
        }

}

=head2 take_action

Send some mail to the hiveminders describing the issue.

=cut

sub take_action {
    my $self = shift;
    return 1 unless ( $self->argument_value('content') && Jifty->web->current_user->id);

    my $debug_info = $self->build_debugging_info();

    my $msg     = $self->argument_value('content') . "\n\n" . $debug_info;
    my $subject = substr( $self->argument_value('content'), 0, 60 );
    $subject =~ s/\n/ /g;

    my $changes = BTDT::Model::Task->parse_summary($subject);
    $subject = $changes->{explicit}->{summary};

    my $group = BTDT::Model::Group->new(
        current_user => BTDT::CurrentUser->superuser );
    $group->load_by_cols( name => "hiveminders feedback" );
    if ( $group->id ) {
        my $task = BTDT::Model::Task->new(
            current_user    => BTDT::CurrentUser->superuser );
        $task->create(
            requestor_id    => Jifty->web->current_user->id
                || BTDT::CurrentUser->nobody->id,
            owner_id        => BTDT::CurrentUser->nobody->id,
            summary         => $subject,
            description     => $msg,
            group_id        => $group->id,
            __parse_summary => 0,
        );

#        $self->result->message(qq[Thanks for the <a href="@{[$task->url]}">feedback</a>. We appreciate it!]);

    } else {

        # Fall back to normal email
        my $mail = Jifty::Notification->new;
        $mail->body($msg);
        $mail->from(
              Jifty->web->current_user->id
            ? Jifty->web->current_user->user_object->email()
            : q[anonymous-guest@hiveminder.com]
        );
        $mail->recipients('hiveminders@bestpractical.com');
        $mail->subject("$subject [HM Feedback]");

        $mail->send_one_message;
    }

    $self->result->message(qq[Thanks for the feedback. We appreciate it!]);
    return 1;
}

=head2 build_debugging_info

Strings together the current environment to attach to outgoing
email. Returns it as a scalar.

=cut

sub build_debugging_info {
    my $self = shift;
    my $message = "-- \nPrivate debugging information:\n\n";

    $message .= "Is a Pro user!\n\n" if $self->current_user->pro_account;

    if ($self->argument_value('extra_info'))
    {
        $message .= "    extra info:\n";
        while (my ($k, $v) = each %{$self->argument_value('extra_info')})
        {
            $message .= "      $k: $v\n";
        }
    }

    my $env = Jifty->web->request->env;
    $message   .= "    $_: $env->{$_}\n"
      for sort grep {/^(HTTP|REMOTE|REQUEST)_/} keys %$env;

    $message   .= "    $_: ".Jifty->web->request->$_."\n"
      for grep {defined Jifty->web->request->$_}
          qw(user_agent referer address);

    return $message."\n";
}

1;
