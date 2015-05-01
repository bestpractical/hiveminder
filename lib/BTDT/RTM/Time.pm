package BTDT::RTM::Time;

use strict;
use warnings;

use base 'BTDT::RTM';

use DateTime::Format::ISO8601;

=head1 NAME

BTDT::RTM::Time - Time conversion methods

=head1 METHODS

=head2 method_convert

Convert from one timezoen to another

=cut

sub method_convert {
    my $class = shift;

    my $from_tz = $class->params->{from_timezone} || "UTC";
    my $to_tz = $class->params->{to_timezone}
        or $class->send_error( 300 => "Missing timezone" );

    my $time = DateTime::Format::ISO8601->parse_datetime($class->params->{time})
        || DateTime->now;
    eval {
        $time->set_time_zone( $from_tz );
        $time->set_time_zone( $to_tz );
    } or $class->send_error( 400 => "Can't find timezone!" );
    $class->send_ok(
        time => {
            timezone => $to_tz,
            '$t' => "$time",
        }
    );
}

=head2 method_parse

Parses the given string

=cut

sub method_parse {
    my $class = shift;

    my $str = $class->params->{text}
        or $class->send_error( 300 => "Missing text to parse" );
    my $tz  = $class->params->{timezone} || "UTC";

    $str = BTDT::DateTime->preprocess($str, explicit => 1);

    my $dt = BTDT::DateTime->parse_dtfn($str)
          || BTDT::DateTime->parse_date_manip($str)
          || BTDT::DateTime->parse_date_extract($str)
          || return;

    $dt->set_time_zone($tz);
    $class->send_ok(
        time => {
            precision => 'time',
            '$t' => "$dt",
        }
    );
}

1;
