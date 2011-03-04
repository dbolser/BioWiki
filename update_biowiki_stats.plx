#!/usr/bin/perl -w

use strict;

use BioWikiTools
    qw( connect
	get_api_list_from_bifx
	get_rc_list
	get_rc_stats
	grab_page
	grab_page_text
        parse_biowiki_page_text_and_create_new_text
	upload_biowiki_page
     );

use Getopt::Long;

use DateTime;

## We use an 'epoch' format time here, becase it's easy to pass to
## MediaWiki.
my $rcstart =
  DateTime->now->subtract(months => 1)->epoch;

my $verbose = 0;

my $username;
my $password;

GetOptions( "username=s" => \$username,
	    "password=s" => \$password,
	    "verbose"    => \$verbose,
	  )
  or die "failure to communicate\n";





## CONNECT TO BIFX MW API

warn "connecting to bifx mw api\n";

my $bifx_api_url =
  'http://www.bioinformatics.org/w/api.php';

my $bifx_api =
  connect( $bifx_api_url,
	   $username,
	   $password
	 );

unless($bifx_api){
  die "FAILED TO CONNECT\n";
}



## COLLECT THE API LIST

warn "collecting api list\n";

my $api_list =
  get_api_list_from_bifx;
#exit;





## PROCESS THE LIST

warn "\nprocessing\n";

for my $page_name (sort {$a cmp $b} keys %$api_list){
#for my $page_name (sort {$b cmp $a} keys %$api_list){
  warn "\n\nDoing $page_name\n";
  
  my $api_url =
    $api_list->{$page_name};
  
  my $mw =
    connect($api_url);
  
  unless($mw){
    warn "FAILED TO CONNECT!\n";
    next;
  }
  
  my $rc_list =
    get_rc_list( $mw, $rcstart );
  
  unless($rc_list){
    warn "FAILED TO GET RC LIST\n";
    next;
  }
  
  
  
  warn "collecting rc stats\n";
  
  my $rc_stats =
    get_rc_stats($rc_list);
  warn "Note:\t", join("\t", @$rc_stats), "\n";
  
  
  
  warn "updating page\n";
  
  my $page_ref =
    grab_page( $bifx_api, $page_name );
  
  unless($page_ref){
    warn "failed to get page ref!\n";
    next;
  }
  
  my $new_text =
    parse_biowiki_page_text_and_create_new_text(
      grab_page_text($page_ref), $rc_stats
    );
  
  #print $new_text; exit;
  
  upload_biowiki_page( $bifx_api, $page_ref, $page_name, $new_text )
    or warn "failed to upload page... did you log in?\n";
  
  warn "OK\n";
  
  #exit;
}


warn "Done.\n";
