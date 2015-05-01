package BTDT::IMAP::Model;

use warnings;
use strict;

use BTDT::IMAP::Mailbox;
use base 'Net::IMAP::Server::DefaultModel';

=head1 NAME

BTDT::IMAP::Model

=head1 DESCRIPTION

Provides IMAP model

=cut

my %roots;

=head1 METHODS

=head2 init

Creates the mailbox tree for the user and stores it in L</root>, once
they are auth'd.  If the mailbox tree already exists for them, sets
the L</root> to that.  Returns itself;

=cut

sub init {
    my $self = shift;

    my $user = $self->auth->user;

    if ( $roots{$user} ) {
        $self->root( $roots{$user} );
    } else {
        $self->root( BTDT::IMAP::Mailbox->new() );
        my $user_obj = $self->auth->current_user->user_object;

        # Inbox
        if ($self->auth->options->{noinbox}) {
            $self->root->add_child(
                name     => "INBOX",
            );
            $self->root->add_child(
                name     => "Todo",
                class    => "TaskEmailSearch",
                tokens   => [ qw/not complete owner me starts before tomorrow accepted but_first nothing/ ]
            );
        } else {
            $self->root->add_child(
                name     => "INBOX",
                class    => "TaskEmailSearch",
                tokens   => [ qw/not complete owner me starts before tomorrow accepted but_first nothing/ ]
            );
        }


        # Groups; this makes subfolders under each group, too
        $self->root->add_child(
            name       => "Groups",
            class      => "DynamicSet",
            collection => sub { $user_obj->groups },
            args       => [ class => "Group", group => ],
            update     => [ group => ],
        );

        # News messages
        $self->root->add_child( class => "News" );

        # Action groups
        my $actions = $self->root->add_child( name => "Actions" );
        $actions->add_child( class => "Action::Completed" );
        $actions->add_child( class => "Action::Take" );
        my $hide = $actions->add_child( name => "Hide for" );
        my $days = $hide->add_child( name    => "Days.." );
        $days->add_child( class => "Action::Hide", days => $_ ) for 1 .. 14;
        my $months = $hide->add_child( name => "Months.." );
        $months->add_child( class => "Action::Hide", months => $_ )
            for 1 .. 12;

        # Braindump
        $self->root->add_child(
            name       => "Braindump mailboxes",
            class      => "DynamicSet",
            collection => sub { $user_obj->published_addresses },
            args       => [ class => "Action::Braindump", published_address => ],
        );

        # Saved searches
        $self->root->add_child(
            name       => "Saved searches",
            class      => "DynamicSet",
            collection => sub { $user_obj->lists },
            args       => [ class => "SavedList", list => ],
        );

        # Help
        $self->root->add_child( class => "Help" );

        # Apple Mail ToDo
        if ($self->auth->options->{appleical}) {
            $self->root->add_child( class => "AppleMailToDo", name => "Apple Mail To Do" );
        }

        $roots{$user} = $self->root;
    }

    return $self;
}

=head2 roots

Returns an anonymous hash of the model roots.

=cut

sub roots {
    return \%roots;
}

=head2 close

When the connection is closed, so is the model.  If there are no open
connections to this user's mailbox tree, destroy the mailbox tree
using L<Net::IMAP::Server::Mailbox/prep_for_destroy>.

=cut

sub close {
    my $self = shift;
    unless ($Net::IMAP::Server::Server->concurrent_user_connections($self->auth->user)) {
        return unless delete $roots{$self->auth->user};
        $self->root->prep_for_destroy;
    }
}

1;
