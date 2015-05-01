package BTDT::IM::Command::Feedback;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'feedback' command, which sends feedback to the app owner.

=cut

sub run
{
    my $im = shift;
    my %args = @_;

    if ($args{message} =~ /^\s*$/)
    {
        return "Your modal feedback will have to wait until you're done reviewing tasks." if $args{in_review};

        $args{session}->set(modal_state => 'feedback ');

        return "Thanks for feedback. When finished, type done or cancel." if $im->terse;
        return "Thanks for taking the time to send feedback. What would you like to tell us? Type as much as you want, then type <b>done</b> on a line by itself when you're done. Or type <b>cancel</b> on a line by itself if you've changed your mind.";
    }

    my $feedback = BTDT::Action::SendFeedback->new(
        arguments => {
            content => $args{message},
            extra_info => {
                protocol => $im->protocol,
                screenname => $args{screenname},
            }
        }
    );

    $feedback->run;
    my $result = $feedback->result;

    return $result->message;
}

1;
