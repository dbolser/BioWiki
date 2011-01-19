#!/usr/bin/perl -w

## Prototype script to collect and summarise a months worth of edits
## from a given MW.

## For information, see:
## http://search.cpan.org/dist/MediaWiki-API/lib/MediaWiki/API.pm
## http://www.mediawiki.org/wiki/API:Query_-_Lists#recentchanges_.2F_rc

use strict;

use Data::Dumper;

use DateTime;

use MediaWiki::API;



## CONNECT TO AN API

#my $api_url = 'http://en.wikipedia.org/w/api.php';
#my $api_url = 'http://seqanswers.com/w/api.php';
my $api_url = 'http://pdbwiki.org/api.php';



## Get API object for the given URL
my $mw = MediaWiki::API->
  new({ api_url => $api_url });



## Configure a default error function (saves us checking for errors)
$mw->{config}->{on_error} = \&on_error;

## The error function
sub on_error {
  print "Error code: ", $mw->{error}->{code}, "\n";
  print $mw->{error}->{details}, "\n";
  print $mw->{error}->{stacktrace}, "\n";
  die "err\n";
}



## Print the site name
my $ref = $mw->api( { action => 'query', meta => 'siteinfo' } );
print "Sitename: '", $ref->{query}->{general}->{sitename}, "'\n";





## Grab the recent changes list (object)
my $rcstart =
  DateTime->now->subtract(months => 1)->epoch;

## Debugging
#my $rcstart =
#  DateTime->now->subtract(hours => 7)->epoch;

warn "collecting changes since $rcstart\n";
my $rc_array = $mw->
  list ({
	 action  => 'query',
	 list    => 'recentchanges',
	 
	 ## Get changes since:
	 rcdir   => 'newer',
	 rcstart => $rcstart,
	 
	 ## Number of revisions to collect in each batch of results
	 ## returned by the API
	 rclimit => '500',
	 
	 ## Filters
	 rcshow  => '!minor',
	 rcshow  => '!bot',
	 
	 #rcexcludeuser => '',
	 #rctype => edit / new / log,
	 
	 ## Properties
	 rcprop =>
	   'user|comment|timestamp|title|sizes|flags'
	 
	},
	{
	 ## Config
	 
	 ## Process result as they come in with this function
	 ## (responsible for returning something useful).
	 #hook => \&look_hook,
	 
	 ## Max number of batches to collect (for debugging)
	 max => 1
	 
	}
       );

sub look_hook{
  print "hi\n";
}

warn 'found ', scalar(@$rc_array), " revisions\n";

## Debugging
#print Dumper $rc_array;





## Compile edit statistics for the month

my(%users,
   %pages);

foreach my $rc (@$rc_array){
  
  ## Debugging
  #print Dumper $rc;
  
  $users{$rc->{ user}}++;
  $pages{$rc->{title}}++;
}

warn "OK\n";



print "users:\n";
print "$_\t$users{$_}\n" for sort u keys %users;

print "pages:\n";
print "$_\t$pages{$_}\n" for sort p keys %pages;


sub u { $users{$b} <=> $users{$a} }
sub p { $pages{$b} <=> $pages{$a} }





__END__

# MW's timestamp (ISO8601): '2011-01-18T21:31:02Z'

# 20:06 -!- dbolser [~dmb@bioinformatics.org] has joined #perl
# 20:06 < dbolser> how can I get the current date, minus one month,
# formatted like this "2011-01-18T21:31:02Z"?
# 20:07  * GumbyPAN CPAN Upload: SDL-Tutorial-3DWorld-0.33 by ADAMK
# 20:07 < tm604> dbolser: DateTime->now->subtract(months =>
# 1)->iso8601
# 20:07 < dbolser> tm604: You are better than Google
# 20:07 < ology> dbolser: perldoc POSIX search for strftime
# 20:08 < dbolser> tys
# 20:08 < tm604> might also need to specify the timezone directly to
# get the trailing Z.
