#!perl
# $Id: sync_outlook_hiveminder.pl 102 2008-08-02 01:29:56Z nvonnahm $

use warnings; use strict;
use Getopt::Long;
#     Getopt::Long::Configure ("bundling");
Getopt::Long::Configure ("bundling_override");
use Pod::Usage;

use Date::Manip;
use Data::Dumper;
use constant DEBUG => 1;

use Net::Hiveminder;
use Win32::OLE; use Win32::OLE::Const 'Microsoft Outlook';


my $man = 0;
my $help = 0;
our $verbose = 0;
my $verbosity = 0;
my $skip_braindump = 0;

## Parse options and print usage if there is a syntax error,
## or if usage was explicitly requested.
GetOptions(
	   'help|?' => \$help, 
	   man => \$man,
	  'verbose|v+' => \$verbose,
	  'verbosity:i' => \$verbosity,
	   'skip-braindump' => \$skip_braindump,
	  ) 
    or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-verbose => 2) if $man;

$verbose = ($verbose > $verbosity ? $verbose: $verbosity);
print "Verbosity level = $verbose\n" if $verbose > 0;

=head1 NAME

sync_outlook_hiveminder.pl

=head1 VERSION

$Id: sync_outlook_hiveminder.pl 102 2008-08-02 01:29:56Z nvonnahm $

=head1 DESCRIPTION

This syncs Microsoft Outlook 2007 (TM) Tasks with Hiveminder (TM).

=head1 SYNOPSIS

./sync_outlook_hiveminder.pl -vvv      # 3 is a nice level of verbosity to start with

=head1 WHY?

I use a Palm (TM) handheld for working all my lists offline, but Palm
is stuck in the 20th century.  Luckily, so is Outlook (TM)!

The Palm knows how to sync with Outlook task list and memos, so this
script syncs them with Hiveminder.  Hopefully, I can use Hiveminder
when I'm near a computer (online) and still have full read/write
access when my Palm is offline.

=head1 OPTIONS

=over 8

=item B<--verbose>, B<-v>, B<-vvvvv>, B<--verbosity 10>

Change verbosity level.  0 to 10 pretty much covers it.  Starting at
level 4 you should see something about each task.

=item B<--skip-braindump>

Skip the braindump step (saves a few seconds)

=item B<-help>

Print a brief help message and exit.

=item B<-man>

Print the manual page and exit.

=back

=head1 REQUIREMENTS

=over 4

=item Net::Hiveminder

Which requires Net::Jifty and half of CPAN.  Hint: With cygwin, `force
install` in the cpan> shell is your friend.

=item Windows and MS Outlook 

Tested with 2007... probably works with earlier versions too.  Almost
140% certain not to work with Outlook Express.

=item Win32::OLE

I tested with Perl and Win32 that came with cygwin.

=back

=head1 HOW IT USE IT

I made some conventions based on how I want things.  I have big
categories based on "contexts" (see David Allen's I<Getting Things
Done>), like B<@work> and <@home>, but I also have smaller 'tags' for
grouping similar tasks together.

I have "project" lists for things that will take more than a couple
steps, and I keep them tagged with B<@WorkProjects> and
B<@HomeProjects>.  So for example, I have one task like this:

    Get Things Done [@WorkProjects gtd]

Then my "next action" for that project goes in my @Work list:

    check stuff off [@work gtd] 

=head1 HOW IT WORKS

=head2 Simulated "tags" in Outlook

In Hiveminder, each task can have multiple tags, for example:

     #AWEF:  check stuff off  [@work meta gtd]

When a task goes to Outlook, tags beginning with an @ turn to
"Categories" and the rest go as plain text in the beginning of the
title.  The Hiveminder record locator is appended in braces {}:

     categories:  work
     subject:  meta gtd: check stuff off {#AWEF}

=head2 BRAINDUMP note

This script creates a Note (sticky note/memo) in Outlook called
BRAINDUMP.  Each time it runs, if you've typed anything in that note,
it gets braindumped into Hiveminder.

=head2 Secret last_outlook_sync task

This script also makes a hidden forever, completed Hiveminder task
named "last_outlook_sync" to track when it last synced.

=head1 ANNOYANCES

You might want to disable the "external program access" warning
message in Outlook.  Refer to:

http://office.microsoft.com/client/helppreview.aspx?AssetID=HA012299431033&QueryID=mhoDjjXmC&respos=1&rt=2&ns=OUTLOOK&lcid=1033&pid=CH100622191033

=head1 BUGS

Hah!  It's very simplistic and easily confused by colons or fancy
characters in tasks and weird tags like with spaces or whatever.

=head1 AUTHOR

Electronically mail me at nathan dot vonnahme at banner health dot
commercial, or nathan at enteuxis dot organic, or leave a comment at
my blog at http://n8v.enteuxis.org

=head1 COPYRIGHT & LICENSE

Copyright 2008 Nathan Vonnahme.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

my %s;  # statistics collector


my $hm = Net::Hiveminder->new(use_config => 1);

my $outlook;  
# Make sure we have Outlook, and that it is running. Exit if
# either of these is not the case.
eval {$outlook = Win32::OLE->GetActiveObject('Outlook.Application')};
 die "Outlook not installed." if $@;
 die "Outlook needs to be running." unless defined $outlook;


unless ($skip_braindump) {

    # BRAINDUMP

# check for anything in the braindump Outlook Note/memo (from palm) and send it to hm, but ignore the first line.

    my $braindump_header = "BRAINDUMP\n";
    my $braindump_note;
    if ( $braindump_note =
        $outlook->session->GetDefaultFolder(olFolderNotes)->Items("BRAINDUMP") )
    {
        print "raw braindump note contents: [$braindump_note->{Body}]\n"
          if $verbose > 5;

        my $braindump_text = $braindump_note->{Body};
        $braindump_text =~ s/^BRAINDUMP//s;    # remove header

        if ( $braindump_text =~ m/\S/ ) {
            print "braindumping this to hiveminder:\n[$braindump_text]..."
              if $verbose > 0;

            my $result = $hm->braindump($braindump_text);
            print "Braindump result:  $result\n" if $verbose > 0;

            if ( $result =~ /((\d+) task.*)?created/ ) {
		$s{'braindumped into Hiveminder'}+= $2;
                print "resetting BRAINDUMP Note\n" if $verbose > 2;
                $braindump_note->{Body} = $braindump_header;
                $braindump_note->Save;
            }
            else {
                warn
"Something went wrong with the braindump!  Error:  [$result]\n";
            }
        }
        else {
            print
              "BRAINDUMP Note exists but doesn't have anything to dump (OK)\n"
              if $verbose > 2;
        }
    }
    else {
        print
"couldn't find a BRAINDUMP note!  Creating a new one for next time.\n";
        my $new_note = $outlook->CreateItem(olNoteItem)
          or die "Unable to create a new Note: $!\n";
        $new_note->{Body}       = $braindump_header;
        $new_note->{Categories} = 'Hiveminder';
        $new_note->Save;
    }

}

print "Retrieving all your Hiveminder tasks...\n" if $verbose > 1;
# get all my Hiveminder tasks
my $hm_tasks = [
		$hm->get_tasks(accepted => 1)
];


my $last_sync_task = undef;
my $last_sync_date = ParseDate('197001010000');

if ($last_sync_task = ($hm->get_tasks(summary => 'last_outlook_sync'))[0]) {
#     print Dumper $last_sync_task;
    $last_sync_date = ParseDate($last_sync_task->{description});
}
else {
    print "Creating hidden Hiveminder task to track last Outlook sync time...\n" if $verbose > 0;
    $last_sync_task = $hm->create_task('last_outlook_sync', starts => '',  will_complete => 0, complete => 1);
}
print "Last Outlook sync date:  $last_sync_date\n" if $verbose > 3;




my $hm_tasks_by_id;

foreach (@$hm_tasks) {
    $hm_tasks_by_id->{$_->{record_locator}} = $_;
}



## get changes from Outlook


my $outlook_tasks;
my $outlook_tasks_by_hm_id;


# TaskItem Object reference
# http://msdn.microsoft.com/en-us/library/bb177255.aspx

# OlTaskStatus Enumeration
# http://msdn.microsoft.com/en-us/library/bb208147.aspx
# Indicates the task status.

# Name	Value	Description
# olTaskComplete        2       The task is complete.
# olTaskDeferred        4       The task is deferred.
# olTaskInProgress      1       The task is in progress.
# olTaskNotStarted      0       The task has not yet started.
# olTaskWaiting         3       The task is waiting on someone else.

my %ol_status_legend  = (
                      olTaskComplete + 0     => 'Complete',
                      olTaskDeferred + 0     => 'Deferred',
                      olTaskInProgress + 0   => 'In Progress',
                      olTaskNotStarted + 0   => 'Not Started',
                      olTaskWaiting + 0      => 'Waiting',
                     );


# OlImportance Enumeration
# http://msdn.microsoft.com/en-us/library/bb208101.aspx
# Specifies the level of importance for an item marked by the creator of the item.

# Name	Value	Description
# olImportanceHigh	2	Item is marked as high importance.
# olImportanceLow	0	Item is marked as low importance.
# olImportanceNormal	1	Item is marked as medium importance.

my %ol_to_hm_priority = (
			 olImportanceHigh + 0 => 4,
			 olImportanceLow + 0 => 2,
			 olImportanceNormal + 0 => 3,
			);
my %hm_to_ol_priority = (
			 5 => olImportanceHigh,
			 4 => olImportanceHigh,
			 3 => olImportanceNormal,
			 2 => olImportanceLow,
			 1 => olImportanceLow,
			);

# expression.MarkComplete
# Sets PercentComplete  to "100%", Complete  to True, and DateCompleted  to the current date.



# get the Outlook task list object
my $namespace = $outlook->GetNameSpace("MAPI") or die 
	"can't open MAPI namespace\n";

print "Getting your Outlook task list\n" if $verbose > 1;
my $task_list = $namespace->GetDefaultFolder(olFolderTasks)->{Items};

my $i = 0;

# $verbose = 2;

# loop through  Outlook tasks

print "Reviewing Outlook tasks for changes that need to go to Hiveminder...\n" if $verbose > 0;

while ( my $this_outlook_task = $task_list->GetNext ) {
#    next if $this_outlook_task->{Status} == olTaskComplete;
    my $t = {};
    foreach (
        qw(Subject Body Categories Importance EntryID LastModificationTime DateCompleted))
    {
        $t->{$_} = $this_outlook_task->{$_};
    }
    $t->{Status} = $ol_status_legend{ $this_outlook_task->{Status} };

    my $as_string = join ',',
      map { "$_:$t->{$_}" } qw(Subject Categories Importance);
    push @$outlook_tasks, $t;

    # parse tags
    my @tags = get_outlook_tags($t); 
    my $hm_title = simplify_outlook_task_title($t->{Subject});


    # if it does have an hm id, check for changes between them
    if ( $t->{Subject} =~ m/\{\#(\w+)\}/ ) {
	my $id = $1;
        $outlook_tasks_by_hm_id->{$id} = $t;

        # and sync the latest, whichever direction
	print "Comparing task $id ($hm_title)...\n" if $verbose > 3;


	my $ol_lastmod = $t->{LastModificationTime}->Date('yyyyMMdd') . $t->{LastModificationTime}->Time('HHmm');
	print "\tOutlook task lastmod = $ol_lastmod\n" if $verbose > 10;
	my $ol_completed = $t->{DateCompleted}->Date('yyyyMMdd') . $t->{DateCompleted}->Time('HH:mm');
	print "\tOutlook task completed = $ol_completed\n" if $verbose > 10;

# 	print Dumper $t;

	# deleted from HM?  delete also from OL.
	if (! exists  $hm_tasks_by_id->{$id} ) {
	    print "Task $id ($hm_title) is gone from Hiveminder.  Deleting from Outlook.\n" if $verbose > 0;
	    $this_outlook_task->Delete;
	    next;
	}

	my $hmt = $hm_tasks_by_id->{$id};
# 	print Dumper $hmt;

	# completed in either?  complete in the other. (copy completion date)
	if ($this_outlook_task->{Status} == olTaskComplete && ! $hmt->{complete} ) {
	    print "Task $id ($hm_title) is marked done in Outlook.  Completing it in Hiveminder.\n" if $verbose >0;
	    my $result = $hm->done($id);
#		or warn "failed to complete hm task $id";
	    print "Result from Hiveminder:  $result\n" if $verbose > 4;
	    print "Setting completion date to $ol_completed in Hiveminder\n" if $verbose > 3;
	    $hm->update_task($id, completed_at => $ol_completed)
		or warn "failure to update hm task $id";

	}
	elsif ($this_outlook_task->{Status} != olTaskComplete && $hmt->{complete} ) {
	    print "Task $id ($hm_title) is marked done in Hiveminder.  Completing it in Outlook.\n" if $verbose > 0;
	    $this_outlook_task->MarkComplete;
# 	    $this_outlook_task->Save;
	}
	
	# different summary, body, tags?  use the newest.
	
	my $differences = 0;

	if ($hm_title ne $hmt->{summary}) {
	    print "\tTitle (Summary/Subject) of task $id differs. ($hm_title ne $hmt->{summary})\n" if $verbose > 4;
	    $differences++;
	}
	if ($t->{Body} ne $hmt->{description}) {
	    print "\tBody/description of task $id differs.\n" if $verbose > 4;
	    $differences++;
	}
	# priority
	if ($ol_to_hm_priority{ $t->{Importance} }  != $hmt->{priority}) {
	    print "\tPriority  of task $id ($ol_to_hm_priority{$t->{Importance}}  != $hmt->{priority}) differs.\n" if $verbose > 4;
	    $differences++;
	}
	# tags need splitting... ewww.
	my @hm_tags = split / /, $hmt->{tags};  # maybe oversimplistic?
	my @quoted_ol_tags = map {'"'.$_.'"'} @tags;
	my $ol_tag_string = lc join(", ", sort @quoted_ol_tags);
	my $hm_tag_string = lc join(", ", sort @hm_tags);
# 	print "ol tags = $ol_tag_string\n";
# 	print "hm tags = $ol_tag_string\n";

	if ($ol_tag_string ne $hm_tag_string) {
	    print "\tTags of task $id differ ($ol_tag_string ne $hm_tag_string).\n" if $verbose > 4;
	    $differences++;
	}

	if ($differences > 0) {
	    # calculate newest
	    my $ol_lastmod_date = ParseDate($ol_lastmod);
	    $hmt->{modified_at} = get_Hiveminder_task_lastmodified($hmt->{record_locator});
	    my $hm_lastmod_date = ParseDate($hmt->{modified_at});

	    my $flag = Date_Cmp($ol_lastmod_date, $hm_lastmod_date);
	    my $direction  = 'to Outlook';

	    if ($flag <= 0) {
		print "\tThe Hiveminder version is more recent.\n" if $verbose > 4;
		$direction = 'to Outlook';
		#	} elsif ($flag==0) {
		# the two dates are identical
	    } else {
		print "\tThe Outlook version is more recent.\n" if $verbose > 4;
		$direction = 'to Hiveminder';
	    }

	    sync_tasks($outlook, $hm, $this_outlook_task, $hmt, $direction, $ol_tag_string, $hm_tag_string, $verbose);
	    $i++;

	} else {
	    print "\tThis task doesn't need to be synced.\n" if $verbose > 3;
	    $s{"in sync"}++;
	}

    }


    # if it doesn't have an hm id (and it's not completed), add it to hm and add the id in Outlook
    else {
        if ( $this_outlook_task->{Status} != olTaskComplete ) {
            print
              "New task found in Outlook:\n\t[$as_string]\n\tCreating in HM...\n"
              if $verbose > 3;

            my %args = (
                priority => $ol_to_hm_priority{ $t->{Importance} },
                tags     => join( " ", @tags ),
		description => $t->{Body},
            );

            print
              "\tCreating this new task in Hiveminder:\n\t\tsummary: $hm_title\n",
              map { "\t\t$_:  $args{$_}\n" } keys %args
              if $verbose > 4;

            my $new_hm_task = $hm->create_task( $hm_title, %args );
            print "\tNew HM task id = $new_hm_task->{record_locator}\n"
              if $verbose > 4;


            # print "result:  ". Dumper $result;
            print
"\tUpdating Outlook task with HM ID ($new_hm_task->{record_locator})\n"
              if $verbose > 4;
            $this_outlook_task->{Subject} .=
              ' {#' . $new_hm_task->{record_locator} . '}';
            $this_outlook_task->Save;

	    $outlook_tasks_by_hm_id->{$new_hm_task->{record_locator}} = $t;
            $i++;
	    $s{'added to Hiveminder'}++;
        }
    }
    $s{'checked in Outlook'}++;
#     last if $i >= 1;
}


# look through HM tasks again
# if the ID doesn't exist in Outlook (ie, it isn't in the hash we built when we looped through), create a new task in Outlook
# unless it was deleted in Outlook ?!?

$i=0;

print "Reviewing Hiveminder tasks for changes that need to go to Outlook...\n" if $verbose > 0;
foreach (@$hm_tasks) {
    my $id = $_->{record_locator};
    next if $_->{complete};

    if (! exists $outlook_tasks_by_hm_id->{$id} ) {
	print "\tTask $id ($_->{summary}) doesn't exist in Outlook...\n" if $verbose > 3;

	# deletion check - did it exist in Hiveminder before our last sync date?
	my $flag = Date_Cmp( $last_sync_date,  ParseDate($_->{created}) );
	if ($flag <= 0) {
	    print "\tCreation date ($_->{created}) is newer than last sync ($last_sync_date).\n" if $verbose > 4;
	    print "\tCopying task $id ($_->{summary})  to Outlook.\n" if $verbose > 0;

	    my $new_ol_task = $outlook->CreateItem(olTaskItem)
		or die "Unable to create a new Task: $!\n";

# 	    print Dumper $_;
	    my $hm_tag_string = lc join(", ", split / /, $_->{tags});
# 	    print "tagstring = $hm_tag_string\n";
	    sync_tasks($outlook, $hm, $new_ol_task, $_, 'to Outlook', '', $hm_tag_string, $verbose);
	    
	    $i++;
	    $s{'created in Outlook'}++;
	}
	else {
	    print "\tCreated before last sync ($last_sync_date).  Must've been deleted from Outlook.\n"
		if $verbose > 4;
	    print "\tDeleting task $id ($_->{summary}) from Hiveminder.\n" if $verbose > 0;

# 	    print "SKIPPING Hiveminder deletion!\n" if $verbose >0;
	    $hm->delete_task($id);
	    $i++;
	    $s{'deleted from Hiveminder'}++;
	}
    }
    $s{'checked in Hiveminder'}++;
#     last if $i>0;

}


print "updating secret last_outlook_sync task $last_sync_task->{record_locator}...\n" if $verbose > 3;
$hm->update_task(
    $last_sync_task->{record_locator},
    description   => scalar( localtime(time) ),
    starts        => '',
    will_complete => 0,
    complete      => 1
);


print "\nSync successfully completed at ".localtime().".\n";

print map {"\t$s{$_} task".($s{$_}==1?" was":"s were"). " $_\n"} keys %s if $verbose > 0;
print "You have $s{'checked in Hiveminder'} things to do.\n" if $verbose > 0;

# print "Your current To Do list:\n", scalar $hm->todo if $verbose > 0;



#  horrible.  sorry.
sub sync_tasks {
    my ($ol, $hm) = (shift, shift);
    my ($ol_task, $hm_task, $direction, $ol_tag_string, $hm_tag_string) = (shift, shift, shift, shift, shift);
#     our ($verbose);
#    my $verbose = shift;


    print "\tSyncing task $hm_task->{record_locator} ($hm_task->{summary}) $direction...\n" if $verbose > 1;

    if ($direction eq 'to Hiveminder') {
	my $t = {};
	$t->{summary} = simplify_outlook_task_title($ol_task->{Subject});
	$t->{description} = $ol_task->{Body};
	$t->{priority} = $ol_to_hm_priority{ $ol_task->{Importance} } ;
	$t->{tags} = $ol_tag_string;
	$t->{complete} = ($ol_task->{Status} == olTaskComplete);

	print "\tUpdating hiveminder task $hm_task->{record_locator}...\n" , map {"\t\t$_ : $t->{$_}\n"} grep{!/description/} keys %$t
	    if $verbose > 3;
	$hm->update_task( $hm_task->{record_locator}, %$t );
	$s{'synced to Hiveminder'}++;
    }
    elsif ($direction eq 'to Outlook') {
	my @quoteless_hm_tags = map {s/"//g; $_} split /"? "?/, $hm_task->{tags};
	my $ol_categories = join ',', (grep {/^\@/} @quoteless_hm_tags);
	$ol_categories =~ s/\@//g;

	$ol_task->{Categories} = $ol_categories;
	my $pseudotags = join ', ', grep {! /^\@/} @quoteless_hm_tags;
	$pseudotags .= ": " if $pseudotags ne '';
	
	$ol_task->{Subject} = "$pseudotags$hm_task->{summary} {#$hm_task->{record_locator}}";
	$ol_task->{Body} = $hm_task->{description};
	$ol_task->{Importance} = $hm_to_ol_priority{$hm_task->{priority}};
	$ol_task->Complete if $hm_task->{complete};

	print "\tUpdating outlook task...\n", 
	    map {"\t\t$_ : $ol_task->{$_}\n"} qw(Subject Importance Categories)
	    if $verbose > 3;
 	$ol_task->Save;
	$s{'synced to Outlook'}++;
    }
    else {
	die "invalid direction '$direction'";
    }
}


sub get_Hiveminder_task_lastmodified {
    my $record_locator = shift;
#    my $verbose = shift; 

    # Jifty magic to access the TaskTransaction model
    #  see also http://hiveminder.com/=/model/BTDT.Model.TaskTransaction

    print "\tGetting last mod time for $record_locator..." if $verbose > 4;

    # get all the transactions
    my $transactions = $hm->search(
				   'TaskTransaction',
				   task_id => $hm->loc2id($record_locator)
				  );

    # explicitly sort chronologically
    @$transactions = sort {Date_Cmp($a->{modified_at}, $b->{modified_at})} @$transactions;
#     print "sorted transactions = \n", Dumper $transactions;

    my $last_transaction = pop @$transactions;  

#     print  "last_trans = \n", Dumper $last_transaction;
    print "$last_transaction->{modified_at}\n" if $verbose > 4;

    return $last_transaction->{modified_at};
}



sub get_outlook_tags {
    my $t = shift;
    my @tags = split /,\s*/, $t->{Categories};
    @tags = map { m/^\@/ ? $_: '@'.$_ } @tags;
    push @tags, parse_tags_from_outlook_task_title($t->{Subject});
    return @tags;
}


sub simplify_outlook_task_title  {
    my $original = shift;
    my $t = $original;
    $t =~ s/\s*\{\#[^}]+\}//; # strip hm id from title
    $t =~ s/^([^:]+): +//;
    return $t;
}

sub parse_tags_from_outlook_task_title {
    my $original = shift;
    if ( $original =~ m/^([^:]+):(?!:)/ ) {  # but skip paanayim nekudatayim (eg  Net::Hiveminder)!
	return split /[,\s]+/, $1;
    }
    else {
	return ();
    }
}


# print Dumper $outlook_tasks;

sub get_Outlook_task_by_hm_id {

    my $id = shift;
    my $filter = q[@SQL="http://schemas.microsoft.com/mapi/proptag/0x0037001E" like '%]. $id .q[%'];

    my $t = $task_list->Find($filter);
    print "found one for $id!\n",  map {"$_: $t->{$_}\n"} qw(Subject Body Categories Importance);
    return $t;
}





#### what if a task has been deleted in one or the other??!?!?  
# ( if created time < last sync maybe it has been deleted)

