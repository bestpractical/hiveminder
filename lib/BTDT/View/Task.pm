use warnings;
use strict;

=head1 NAME

BTDT::View::Task

=cut

package BTDT::View::Task;
use Jifty::View::Declare -base;
__PACKAGE__->use_mason_wrapper;


require BTDT::View::Task::AttachmentsCRUD;

alias BTDT::View::Task::AttachmentsCRUD under '_fragments/attachments';

template 'attachments' => page {
    title    => 'Attachments for ' . get('task')->summary,
    subtitle => '#' . get('task')->record_locator,
    } content {
    div {
        { class is 'attachment_list' };
        form {
            render_region(
                name            => 'attachmentslist',
                path            => '/task/_fragments/attachments/list',
                defaults        => { page => 1 },
                force_arguments => { task_id => get('task')->id }
            );
        };
    };
    };

template 'attachment/view' => sub {
    my $file = get 'attachment';
    my $type = $file->content_type;

    $type = 'text/plain'
        if $file->short_content_type eq 'html'
            or $type =~ /^application\/vnd\.mozilla\.xul\+xml/;

    Jifty->web->response->content_type($type);
    outs_raw( $file->content );
};

template 'attachment/download' => sub {
    my $file = get 'attachment';
    my $filename = $file->filename;
    $filename =~ s/\\/\\\\/g;
    $filename =~ s/"/\\"/g;
    Jifty->web->response->content_type( $file->content_type );
    Jifty->web->response->header(
        'Content-Disposition' => 'attachment; filename="' . $filename .'"');
    outs_raw( $file->content );
};

1;
