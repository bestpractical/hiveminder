
use warnings;
use strict;

=head1 NAME

BTDT::Action::SendSupportRequest

=cut

package BTDT::Action::SendSupportRequest;
use base qw/BTDT::Action Jifty::Action/;


=head2 arguments

The fields for C<SendSupportRequest> are:

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

Send some mail to support describing the issue

=cut

sub take_action {
    my $self = shift;
    return 1 unless ( $self->argument_value('content') );

    if ( not Jifty->web->current_user->pro_account ) {
        $self->result->error("Only Hiveminder Pro users can submit support requests.");
        return;
    }

    my $user = Jifty->web->current_user->user_object;

    my $debug_info = $self->build_debugging_info();

    my $msg     = $self->argument_value('content') . "\n\n" . $debug_info;
    my $subject = substr( $self->argument_value('content'), 0, 60 );
    $subject =~ s/\n/ /g;

    my $changes = BTDT::Model::Task->parse_summary($subject);
    $subject = $changes->{explicit}->{summary};

    my $mail = Jifty::Notification->new;
    $mail->body($msg);
    $mail->from( Email::Address->new( $user->name => $user->email )->format );
    $mail->recipients('support@hiveminder.com');
    $mail->subject("$subject [HM Support]");

    $mail->send_one_message;

    $self->result->message("Support request sent.  We'll be in touch as soon as we can.");
    return 1;
}

=head2 build_debugging_info

Redispatch to SendFeedback's build_debugging_info.

=cut

sub build_debugging_info {
    return BTDT::Action::SendFeedback::build_debugging_info(@_);
}

1;
