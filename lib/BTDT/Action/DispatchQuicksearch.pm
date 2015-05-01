use warnings;
use strict;

=head1 NAME

BTDT::Action::DispatchQuicksearch -

=head1 DESCRIPTION

Performs a search over the set of tasks; its results are stored in the
'tasks' key of the associated L<Jifty::Result> object.

=cut

package BTDT::Action::DispatchQuicksearch;
use Jifty::Param::Schema;

=head2 arguments

Quick search takes a single "query" and tries to be smart about what to
do with it. currently, it ANDs all the words and looks for them in
the summary, tags or description of a task.


=over

=item query

=back

See also C<BTDT::Model::TaskCollection>

=cut

use Jifty::Action schema {
    param query =>
        type is 'text',
        label is 'Quick Search',
        placeholder is 'Search...';
};

=head2 take_action

Performs the search.  If there are any parameters that are not in the
tokens, it performs a refirect such that all of the state is in the
tokens.

=cut

sub take_action {
    my $self = shift;

    # template_argument because this is a variable set in the dispatcher
    my $mobile = '';
    if (Jifty->web->request->template_argument('mobile_ua') &&
        Jifty->web->request->path =~ /^\/mobile/ ) {
           $mobile = '/mobile';
    }
    if ($self->argument_value('query')) {
        Jifty->web->request->clear_actions;

        my $query = $self->argument_value('query');
        # If the search is for a single record locator, and the user
        # can see the task in question, go straight to that task's page
        my ($rl, $id);
        $rl = $1 if $query =~ /^#?([\w\d]{0,6})$/;
        if($rl && ($id = $BTDT::Record::LOCATOR->decode($rl))) {
            my $task = BTDT::Model::Task->new();
            $task->load($id);
            if($task->current_user_can('read')) {
                Jifty->web->next_page("$mobile/task/$rl");
                return;
            }
        }

        Jifty->web->next_page("$mobile/search/query/$query");
    }
}

1;
