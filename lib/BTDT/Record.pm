use warnings;
use strict;

package BTDT::Record;
use base qw/Jifty::Record/;
use Number::RecordLocator;

our $LOCATOR =  Number::RecordLocator->new();

=head2 record_locator

Return a Number::RecordLocator for this record's id

=cut

sub record_locator {
    my $self = shift;
    my $id = shift || $self->id;
    return($LOCATOR->encode($id));
}

=head2 load_by_locator

Loads the record by record locator

=cut

sub load_by_locator
{
    my $self = shift;
    my $locator = shift;

    # for tasks we usually use "#foo"
    $locator =~ s/^#//;

    my $id = $LOCATOR->decode($locator);

    # Postgres really doesn't like huge integers, which are easy to create with
    # a word that is incorrectly interpreted as a record locator like "tomorrow"
    return (0, "id too large")
        if ($id||0) > 2_000_000_000;

    # wrap in eval in case the locator decodes to 50 digit integer
    my @ret = eval { $self->load($id) };
    warn $@ if $@;

    return wantarray ? @ret : $ret[0];
}


=head2 current_user_can RIGHT

Does the current user have the right "RIGHT" for this object.

If the user is an administrator, return true. otherwise, defer to Jifty::Record

=cut

sub current_user_can {
    my $self  = shift;

    return 1 if $self->SUPER::current_user_can(@_);

    return (1)
        if ($self->current_user->user_object
            and $self->current_user->user_object->id
            and $self->current_user->user_object->__value('access_level') eq 'administrator' );

    return 0;
}

=head2 canonicalize_name

Trim leading and trailing whitespace from the 'name' column

=cut

sub canonicalize_name {
    my $self = shift;
    my $name = shift || '';
    $name =~ s/^\s+//;
    $name =~ s/\s+$//;
    return $name;
}
1;
