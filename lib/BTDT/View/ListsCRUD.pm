use warnings;
use strict;

package BTDT::View::ListsCRUD;
use Jifty::View::Declare -base;
use base 'Jifty::View::Declare::CRUD';

sub per_page           { 1000 }
sub object_type        { 'List' }
sub fragment_base_path { '/fragments/lists' }
sub display_columns    { qw( name ) };

template 'no_items_found' => sub { outs(_("No saved lists found.")) };
template 'search' => sub {''};
template 'search_region' => sub {''};
template 'new_item_region' => sub {''};
template 'new_item' => sub {''};
template 'view' => sub {
    my $self = shift;
    my $list = $self->_get_record( get('id') );
    div {{ class is 'list_entry' };
        hyperlink(
            url => '/list/'.$list->tokens_as_url,
            label => $list->name,
            class => 'list_title'
        );
        my $update = new_action(
            class   => 'Update'.$self->object_type,
            moniker => 'update-' . Jifty->web->serial,
            record  => $list
        );
        outs(" ");
        show( 'view_item_controls', $list, $update );
    };
};


