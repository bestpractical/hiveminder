package BTDT::IM::Command::Alias;
use strict;
use warnings;
use base 'BTDT::IM::Command';

=head2 run

Runs the 'alias' command, for alias CRUD.

=cut

sub run
{
    my $im = shift;
    my %args = @_;

    $args{message} =~ s/^\s+//;

    if ($args{message} eq '')
    {
        return show_all($im, %args);
    }
    elsif ($args{message} =~ /^([^=\s]+)\s*$/)
    {
        $args{alias} = $1;
        return show_one($im, %args);
    }
    elsif ($args{message} =~ /^([^=\s]+)\s*=(.*)$/)
    {
        $args{alias} = $1;
        $args{expansion} = $2;
        $args{expansion} =~ s/^\s+//;
        $args{expansion} =~ s/\s+$//;

        if ($args{expansion} eq '')
        {
            return delete_one($im, %args);
        }
        else
        {
            return create_one($im, %args);
        }
    }
    else
    {
        return "I don't understand. Use 'alias', 'alias name=expansion', or 'alias name='" if $im->terse;

        return << "HUH?";
I don't understand.

View your aliases with:
<pre>alias</pre>

Define a new alias with:
<pre>alias name=expansion</pre>

Delete an existing alias with:
<pre>alias name=</pre>

See <pre>help alias</pre> for more information.
HUH?
    }
}

=head2 show_all PARAMHASH

Shows the user all of his aliases. If he has none, then it will give a hint
about how to set one.

=cut

sub show_all
{
    my $im = shift;
    my %args = @_;

    my $aliases = BTDT::Model::CmdAliasCollection->new;
    $aliases->limit(column => 'owner', value => $im->current_user->id);
    $aliases->order_by(column => 'name');

    my $count = $aliases->count;

    if ($count == 0)
    {
        return << 'BASICS';
You currently have no aliases. Here's an example of how to create one:
<pre>alias w=todo @work</pre>
See also <pre>help alias</pre>
BASICS
    }

    my $ret = "You have $count alias" . ($count == 1 ? '' : 'es') . ":\n";

    while (my $alias = $aliases->next)
    {
        $ret .= sprintf "%s=%s\n", $alias->name, $alias->expansion;
    }

    return $ret;
}

=head2 show_one PARAMHASH

Shows the user a specific alias, the one provided by args{alias}. Correctly
handles the case where the user has no such alias.

=cut

sub show_one
{
    my $im = shift;
    my %args = @_;

    my $name = $args{alias};

    my $alias = BTDT::Model::CmdAlias->new;
    $alias->load_by_cols(owner => $im->current_user->id, name => $name);
    if (!$alias->id)
    {
        return << "NOALIAS";
You have no alias '$name'. If you'd like to create one, use
<pre>alias $name=<i>expansion</i></pre>
NOALIAS
    }

    $name = $alias->name; # perhaps a case adjustment
    my $expansion = $alias->expansion;

    return << "ALIAS";
$name=$expansion
If you'd like to remove this alias, use:
<pre>alias $name=</pre>
ALIAS
}

=head2 delete_one PARAMHASH

Deletes a specific alias. Correctly handles the case where the user has no
such alias.

=cut

sub delete_one
{
    my $im = shift;
    my %args = @_;

    my $name = $args{alias};

    my $alias = BTDT::Model::CmdAlias->new;
    $alias->load_by_cols(owner => $im->current_user->id, name => $name);
    if (!$alias->id)
    {
        return << "NOALIAS";
You have no alias '$name'. If you'd like to create one, use
<pre>alias $name=<i>expansion</i></pre>
NOALIAS
    }

    $name = $alias->name; # perhaps a case adjustment
    my $expansion = $alias->expansion;

    my ($ok, $msg) = $alias->delete;
    return $msg if !$ok;

    return "OK. '$name' is no longer an alias for '$expansion'.";
}

=head2 create_one PARAMHASH

Creates a new alias. Correctly handles the case where the user already has
an alias with that name. Changing an alias requires deletion then creation.

=cut

sub create_one
{
    my $im = shift;
    my %args = @_;

    my $name = $args{alias};
    my $expansion = $args{expansion};

    my $alias = BTDT::Model::CmdAlias->new;
    $alias->load_by_cols(owner => $im->current_user->id, name => $name);
    if ($alias->id)
    {
        $name = $alias->name;
        $expansion = $alias->expansion;

    return << "DELETE";
'$name' already expands to '$expansion'. If you want to change this alias, delete it first with
<pre>alias $name=</pre>
DELETE
    }

    my ($package) = $im->package_of($name);
    if ($package) {
        return "We already have a '$name' command. Sorry!";
    }

    my ($ok, $msg) = $alias->create(name => $name,
                                    expansion => $expansion,
                                    owner => $im->current_user->id);
    return $msg if !$ok;

    # again, maybe case adjustment
    $name = $alias->name;
    $expansion = $alias->expansion;

    return "OK! '$name' now expands to '$expansion'.";
}

1;
