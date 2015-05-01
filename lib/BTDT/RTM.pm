package BTDT::RTM;

use strict;
use warnings;

use XML::Writer;

use BTDT::RTM::Auth;
use BTDT::RTM::Contacts;
use BTDT::RTM::Groups;
use BTDT::RTM::Lists;
use BTDT::RTM::Locations;
use BTDT::RTM::Reflection;
use BTDT::RTM::Settings;
use BTDT::RTM::Tasks;
use BTDT::RTM::Tasks::Notes;
use BTDT::RTM::Test;
use BTDT::RTM::Time;
use BTDT::RTM::Timelines;
use BTDT::RTM::Timezones;
use BTDT::RTM::Transactions;

use base 'Jifty::Object';

=head1 NAME

BTDT::RTM - Implement a more basic API

=head1 METHODS

=head2 serve

Called from the dispatcher, looks up the C<method> and dispatches to
the appropriate subclass.

=cut

sub serve {
    my $class = shift;

    my $args = $class->params;

    # Clean out the user
    Jifty->web->temporary_current_user( BTDT::CurrentUser->new );

    # Look up the auth_token and load the temporary_current_user
    my $session = Jifty::Web::Session->new();
    $session->load( $class->token ) if $class->token;
    my $id = $session->get('user_id');
    Jifty->web->temporary_current_user(BTDT::CurrentUser->new(id => $id)) if $id;

    $class->send_error( 112 => "No method provided" ) unless $class->method;

    my ($ns, $method) = $class->method =~ /^rtm\.([a-z]+(?:\.[a-z]+)*)\.([a-zA-Z]+)$/
        or $class->send_error( 112 => qq{Method "@{[$class->method]}" not found} );

    $ns = "BTDT::RTM::" . join("::", map {ucfirst lc $_} split /\./, $ns);

    my $sub = $ns->can("method_$method");
    $class->send_error( 112 => qq{Method "@{[$class->method]}" not found} )
        unless defined $sub;

    $class->log->info("RTM request for $ns->$method");
    $class->log->debug("Parameters are ".join(" ", map {"$_=".$class->params->{$_}} keys %{$class->params}));
    $sub->($ns);
}

=head2 require_user

Aborts if the auth token isn't valid

=cut

sub require_user {
    my $class = shift;
    $class->send_error( 98 => "Login failed / Invalid auth token" )
        unless Jifty->web->current_user->id;
}

=head2 send_unimplemented

Aborts with a "method unimplemented"

=cut

sub send_unimplemented {
    my $class = shift;
    $class->send_error( 105 => qq{Method "@{[$class->method]}" unimplemented in Hiveminder} );
}

=head2 send_ok [CONTENT]

Sends the given content

=cut

sub send_ok {
    my $class = shift;
    my @args = @_;
    $class->send_response( { @args, stat => "ok" } );
}

=head2 send_error CODE, MESSAGE

Sends the given error code and message.

=cut

sub send_error {
    my $class = shift;
    my ($code, $msg) = @_;
    $class->send_response(
        { stat => "fail", err => { code => $code, msg => $msg } }
    );
}

=head2 send_response DATA

Sends the data, in the appropriate format, to the client.

=cut

sub send_response {
    my $class = shift;
    my $data = shift;
    my $args = $class->params;
    my $resp = Jifty->web->response;

    if ($args->{format}||"" eq "json") {
        $resp->content_type('text/javascript; charset="utf-8"');
        my $content = "";
        $content .= $args->{callback} . "(" if $args->{callback};
        $content .=
            Jifty::JSON::encode_json(
                { rsp => $data },
            );
        $content .=  ")" if $args->{callback};
        $resp->body($content);
    } else {
        $resp->content_type('text/xml; charset="utf-8"');
        my $content = "";
        my $writer = XML::Writer->new(OUTPUT => \$content, ENCODING => "utf-8");
        $writer->xmlDecl();
        $class->to_xml($writer, rsp => $data);
        $writer->end;
        $class->log->debug("RTM response:\n$content");
        $resp->body(Encode::encode_utf8($content));
    }
    Jifty::Dispatcher::last_rule;
}

=head2 method

Returns the name of the API method the client tried to call.

=cut

sub method {
    shift->params->{method};
}

=head2 token

Returns the C<auth_token> provided to the request.

=cut

sub token {
    substr(shift->params->{auth_token}||"", 0, 32);
}

=head2 params

Returns the set of parameters passed to the request.

=cut

sub params {
    return Jifty->web->request->parameters;
}

=head2 user

Returns the current user object, or undef if there is none.

=cut

sub user {
    my $u = Jifty->web->current_user->user_object;
    return undef unless $u->id;
    return $u;
}


# Some data is inexplicably a sub-element, and not an attribute
my %ELEM = map { +( $_ => 1 ) } qw{
    /rsp/auth.perms
    /rsp/auth.token
    /rsp/list/taskseries.url
    /rsp/tasks/list/taskseries.url
    /rsp/user.username
};

=head2 to_xml WRITER, ELEMENT, DATA

Recursively writes the C<DATA> under the C<ELEMENT> using the given
L<XML::Writer> object C<WRITER>, in a manner similar to
C<XML::Simple>.

=cut

sub to_xml {
    my $class = shift;
    my ($writer, $elem, $data) = @_;

    if (not ref $data) {
        if (defined $data and length $data) {
            $writer->dataElement($elem,$data);
        } else {
            $writer->emptyTag($elem);
        }
    } elsif (ref $data eq "ARRAY") {
        if (@{$data}) {
            $class->to_xml($writer, $elem, $_) for @{$data};
        } else {
            $writer->emptyTag($elem);
        }
    } else {
        my $path = ""; my $i = 0;
        $path = "/" . $writer->ancestor($i++) . $path while defined $writer->ancestor($i);
        $path .= "/" . $elem;

        # Assume you're an attribute, unless:
        #  * You're a complex data structure
        #  * You're an exception above
        #  * You're '$t', which is their encoding of "content"
        #  * You're a not-'stat' attr on <rsp> -- this is needed for method.echo
        my %subkeys = %{$data};
        my %attrs;
        my $content = "";
        $attrs{stat} = delete $subkeys{stat} if $path eq "/rsp";
        $content .= delete $subkeys{$_} for grep /^\$/, keys %subkeys;
        $attrs{$_} = delete $subkeys{$_} for grep {not ref $subkeys{$_} and not $ELEM{"$path.$_"} and $path ne "/rsp"} keys %subkeys;
        if (keys %subkeys) {
            $writer->startTag($elem, %attrs);
            $class->to_xml($writer, $_, $subkeys{$_}) for sort keys %subkeys;
            $writer->endTag($elem);
        } elsif (length $content) {
            $writer->dataElement($elem, $content, %attrs);
        } else {
            $writer->emptyTag($elem, %attrs);
        }
    }
}

=head2 default_lists

Return the default lists that make sense for an RTM client.

=cut

sub default_lists {
    my $class = shift;
    return grep { $_->{'label'} =~ /To Do|Later|Unaccepted/ }
                BTDT::Model::List->default_lists;
}

=head2 load_list

Attempts to load a TaskCollection with the tokens of the list specified by the request's C<list_id> parameter.  The list ID may refer to either a default built-in list or a user's saved list.

Returns a L<BTDT::Model::TaskCollection> object, limited by L<BTDT::Model::TaskCollection/from_tokens> if a list was successfully loaded.

=cut

sub load_list {
    my $class = shift;

    my $list_id    = $class->params->{'list_id'};
    my $collection = BTDT::Model::TaskCollection->new;

    return $collection if not $list_id or $list_id =~ /\D/;

    if ( $list_id < 1000 ) {
        $class->log->info("Loading list ($list_id) from built-ins");
        my @lists = $class->default_lists;
        my $list  = $lists[$list_id - 1];
        $collection->from_tokens( split '/', $list->{'token_url'} );
    }
    else {
        $class->log->info("Loading list ($list_id) from the user's saved lists");
        my $list = BTDT::Model::List->new;
        $list->load( $list_id - 1000 );

        if ( $list->id ) {
            $collection->from_tokens( $list->tokens_as_list );
        }
    }
    return $collection;
}


1;
