package DJabberd::Bot::Hiveminder;
use strict;
use warnings;
use base 'DJabberd::Bot';
use DJabberd::Presence; # HIVEMINDER OPTIONAL

use Jifty;
BEGIN { Jifty->new }
use BTDT::IM::LocalJabber;

=head1 NAME

DJabberd::Bot::Hiveminder - DJabberd plugin that serves as a Hiveminder bot

=head1 SYNOPSIS

  <Plugin DJabberd::Bot::Hiveminder>
      NodeName hmtasks
  </Plugin>

=head1 DESCRIPTION

Runs a L<BTDT::IM::LocalJabber> bot inside of L<DJabberd>.

=head1 METHODS

=head2 finalize

Sets up a new L<BTDT::IM::LocalJabber> object to associate with this
bot.

=cut

sub finalize {
    my ($self) = @_;
    $self->{nodename} ||= "hmtasks";
    $self->{bot} = BTDT::IM::LocalJabber->new;
    $self->SUPER::finalize();
}

=head2 process_text TEXT, FROM, CALLBACK

Calls L<BTDT::IM::LocalJabber/received_message> for every message.

=cut

sub process_text {
    my ($self, $text, $from, $cb) = @_;
    $self->{bot}->received_message($from, $text, send_param => $cb);
}

1;
