use strict;
use warnings;

package BTDT::Statistics::Performance;
use Jifty::Plugin::Monitoring;

use Time::HiRes qw(gettimeofday tv_interval);
use Hiveminder::Client;

use constant BASE => "http://hiveminder.com";
use constant SIZE_IMAGES => 0;

=head1 NAME

BTDT::Statistics::Performance - Gather performance statistics

=cut

monitor 'performance', every "2", minutes, sub {
    my $t0 = [gettimeofday];
    my $mech = Hiveminder::Client->new(
        url      => BASE,
        username => 'srl+timing@bestpractical.com',
        password => 'mypants');
    die "Connection failed" unless $mech;
    data_point "login" => tv_interval($t0);

    data_point size => todo => length $mech->content;

    data_point "view task"   => timer($mech, BASE."/task/7O8");
    data_point "list tasks"  => timer($mech, BASE."/todo");
    data_point "page 2"      => timer($mech, BASE."/todo?J:V-region-tasklist.page=2");
    data_point "preferences" => timer($mech, BASE."/prefs");

    my $page_data = $mech->content;
    $page_data =~ m|(/__jifty/js/\w{32}\.js)|;
    if ($1) {
        data_point "static javascript" => timer($mech, BASE . $1);
        data_point size => javascript => length $mech->content;
    }

    $page_data =~ m|(/__jifty/css/\w{32}\.css)|;
    if ($1) {
        data_point "static css" => timer($mech, BASE . $1);
        data_point size => CSS => length $mech->content;

        if (SIZE_IMAGES) {
            my $css_data = $mech->content;
            $css_data =~ s|/\*.*?\*/||sg;
            my %images;
            $images{$1}++ while $css_data =~ /url\((.*?)\)/g;
            my $image_size;
            for (sort keys %images) {
                use bytes;
                $mech->get( BASE . $_ );
                $image_size += length $mech->content;
            }
            data_point size => image => $image_size;
        }
    }

    data_point "static image" => timer($mech, BASE."/static/images/hmlogo/default.png");

    data_point "pageregion load" => time_request(
        $mech,
        {   path      => "/__jifty/webservices/xml",
            fragments => {
                item => {
                    name => "item",
                    path => "/fragments/tasklist/edit",
                    args => { id => 5801, brief => 0 },
                },
            }
        }
    );

    data_point "three pageregion loads" => time_request(
        $mech,
        {   path      => "/__jifty/webservices/xml",
            fragments => {
                item => {
                    name => "item",
                    path => "/fragments/tasklist/edit",
                    args => { id => 5801, brief => 0 },
                },
                item2 => {
                    name => "item2",
                    path => "/fragments/tasklist/edit",
                    args => { id => 5802, brief => 0 },
                },
                item3 => {
                    name => "item3",
                    path => "/fragments/tasklist/edit",
                    args => { id => 5803, brief => 0 },
                },
            }
        }
    );

    data_point "validate" => time_request(
        $mech,
        {   path    => "/__jifty/validator.xml",
            actions => {
                moniker => {
                    class  => "BTDT::Action::UpdateTask",
                    fields => {
                        id       => 5801,
                        complete => 0,
                        summary  => "Some task",
                        priority => 3,
                        starts   => "yesterday",
                        due      => "tomorrow",
                    },
                }
            },
            validating => 1,
        }
    );

    my $start = [gettimeofday];
    my $first_data;
    $mech->get(BASE . "/todo", ":content_cb" => sub {
        $first_data = tv_interval($start) unless $first_data;
    });
    my $last = tv_interval($start);
    data_point "start of tasklist data" => $first_data;
    data_point "end of tasklist data"   => $last;

    $mech->follow_link(text => "Logout");
};

=head2 time_request MECH, REQUEST

Makes a YAML post request.  C<REQUEST> should be a data structure
suitable for a Jifty request.

=cut

sub time_request {
    my ($mech, $req) = @_;
    my $request = HTTP::Request->new( POST => BASE,
                                      ["Content-Type" => "text/x-yaml"], YAML::Dump($req));
    my $start = [gettimeofday];
    my $response = $mech->request($request);
    return tv_interval($start);
}


1;
