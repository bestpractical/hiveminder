package BTDT::IMAP::Auth;

use warnings;
use strict;

use base 'Net::IMAP::Server::DefaultAuth';
__PACKAGE__->mk_accessors(qw(user current_user options));

=head1 NAME

BTDT::IMAP::Auth - Handles auth for the IMAP server.

=head1 METHODS

=head2 auth_plain USER PASSWORD

Checks that there exists a L<BTDT::Model::User> whose email is C<USER>
and whose password is C<PASSWORD>.  Additionally, at the moment one
must either be staff or a pro user.

=cut

sub auth_plain {
    my $self = shift;
    my ( $user, $pass ) = @_;

    $user =~ s|^(.*?@.*?)(?:/(.*))?$|$1|;
    my @options = split '/', ($2 || '');

    require Jifty::DBI::Record::Cachable;
    Jifty::DBI::Record::Cachable->flush_cache;

    my $obj = BTDT::CurrentUser->new( email => $user );
    return unless $obj->id;
    return unless $obj->password_is($pass);
    return unless $obj->user_object->email_confirmed;
    return unless $obj->user_object->access_level ne 'nonuser';

    # Staff or pro is needed
    unless ($obj->user_object->pro_account or $obj->user_object->access_level eq 'staff') {
        $Net::IMAP::Server::Server->connection->out("* NO [ALERT] Hiveminder IMAP is only available for Pro users!  Sign up today at http://hiveminder.com/pro");
        return;
    }

    $self->options({});
    $self->options->{threaded} = 1
      if grep {lc $_ eq "threaded"} @options;
    $self->options->{noinbox} = 1
      if grep {lc $_ eq "noinbox"} @options;
    $self->options->{appleical} = 1
      if grep {lc $_ eq "appleical"} @options;

    my $rootname = $user;
    $rootname .= "/threaded" if $self->options->{threaded};
    $self->user($rootname);
    $self->current_user($obj);

    return 1;
}

=head2 user [NAME]

Gets or sets the username (email address) of the authorized user.

=head2 current_user [CURRENTUSER]

Gets or sets the L<BTDT::CurrentUser> object for this connection.

=cut

1;
