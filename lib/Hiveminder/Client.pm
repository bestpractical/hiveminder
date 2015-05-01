use strict;
use warnings;

package Hiveminder::Client;
use base qw/Jifty::Client/;

$ENV{'http_proxy'} = ''; # Otherwise WWW::Mechanize tries to go through your HTTP proxy

=head1 NAME

Hiveminder::Client --- Subclass of L<Jifty::Client> with extra features
for logging into Hiveminder

=head1 DESCRIPTION

Right now, this is a thin wrapper around L<WWW::Mechanize> and behaves
like it in every way not documented here or in L<Jifty::Client>.

=head1 METHODS

=head2 new

Sets up a Hiveminder client and attempts to login. Parameters, in
addition to the usual C<WWW::Mechanize> options:

=over 4

=item username

Defaults to C<gooduser@example.com>.

=item password

Defaults to C<secret>.

=item url

Defaults to C<hiveminder.com>.

=back


On failure, returns undef.

=cut

sub new {
    my $class = shift;
    my %args = @_;
    my $URL =  delete $args{url} || 'http://www.hiveminder.com';
    my $username = delete $args{username} || 'gooduser@example.com';
    my $password = delete $args{password} || 'secret';
    my $self = $class->SUPER::new(%args);

    $self->get("$URL/");

    return unless $self->content =~ /Login/i;
    return unless $self->fill_in_action('loginbox', address => $username, password => $password);
    $self->submit;

    if ($self->uri =~ m{accept_eula}) {
        # Automatically accept the EULA
        $self->fill_in_action('accept_eula');
        $self->submit;
    }
    if ($self->content =~ m{We do not have an account}) {
        # XXX should we be returning something more Mech-ish?
        warn "No such account $username / $password";
        return undef;
    }
    return unless $self->content =~ /Logout/i;

    return $self;
}

1;
