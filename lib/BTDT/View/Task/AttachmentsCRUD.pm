use warnings;
use strict;

package BTDT::View::Task::AttachmentsCRUD;
use Jifty::View::Declare -base;
use base 'Jifty::View::Declare::CRUD';

sub per_page           {1000}
sub object_type        {'TaskAttachment'}
sub fragment_base_path {'/task/_fragments/attachments'}

sub display_columns {
    my $self   = shift;
    my $action = shift;

    if ( defined $action and ref($action) =~ /Create/ ) {
        return qw( name content );
    } else {
        return qw( name filename );
    }
}

template 'no_items_found' => sub { outs( _("No attachments found.") ) };
template 'search'         => sub {''};
template 'search_region'  => sub {''};

template 'new_item_region' => sub {
    my $self = shift;

    div {
        { class is 'new_item' };
        if ( Jifty->web->current_user->pro_account ) {
            render_region(
                name     => 'new_item',
                path     => $self->fragment_for('new_item'),
                defaults => { object_type => $self->object_type },
            );
        } else {
            p {
                { class is 'note' };
                outs( _("Uploading of attachments is limited to ") );
                hyperlink( url => '/pro', label => 'Hiveminder Pro' );
                outs( _(" users.  Go ") );
                hyperlink(
                    url   => '/account/upgrade',
                    label => 'upgrade now'
                );
                outs( _("!") );
            };
        }
    };
};

sub _current_collection {
    my $self = shift;
    my $collection = $self->SUPER::_current_collection();
    $collection->limit( column => 'task_id', value => get('task_id'));
    return $collection;
};

template 'edit_item' => sub {
    my $self   = shift;
    my $action = shift;
    render_action( $action, [ $self->display_columns($action) ] );
};

template 'create_item' => sub {
    my $self   = shift;
    my $action = shift;
    render_action( $action, [ $self->display_columns($action) ] );
    render_param(
        $action       => 'task_id',
        render_as     => 'Hidden',
        default_value => get('task_id')
    );
};

template 'view' => sub {
    my $self       = shift;
    my $attachment = $self->_get_record( get('id') );

    my $type = $attachment->short_content_type;

    my $update = new_action(
        class   => 'Update' . $self->object_type,
        moniker => 'update-' . Jifty->web->serial,
        record  => $attachment
    );

    div {
        { class is 'crud read item inline content_type_' . $type };
        span {
            { class is 'name' };
            outs( $attachment->name );
            span {
                { class is 'filename' };
                outs( $attachment->filename )
                    if $attachment->filename
                    and $attachment->name ne $attachment->filename;
            };
        };
        outs( $attachment->english_size . ' ' );
        hyperlink( url => $attachment->url, label => _('View') );
        outs( _(", ") );
        hyperlink( url => $attachment->url('download'), label => _('Download') );
        outs( _(", ") )
            if $attachment->current_user_can('update');
        show( 'view_item_controls', $attachment, $update );
    }
};
