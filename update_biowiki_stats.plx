#!/usr/bin/perl -w

use strict;
use MediaWiki::API::helper;

## Two bulky functions that I put into a 'package' for clarity here
use BioWikiTools
  qw(
      get_biowiki_api_list_from_bifx
      parse_biowiki_page_text_and_create_new_text
   );

use Getopt::Long;

my $verbose = 0;

my $username;
my $password;

GetOptions( "username=s" => \$username,
	    "password=s" => \$password,
	    "verbose"    => \$verbose,
	  )
  or die "failure to communicate\n";





## CONNECT TO BIFX MW API
warn "Connecting to bifx mw api\n";

my $bifx_api_url =
  'http://www.bioinformatics.org/w/api.php';

my $bifx_api = MediaWiki::API::helper->
  new( api_url => $bifx_api_url );

$bifx_api->test
  or die "FAILED TO CONNECT\n";

if( defined($username) && defined($password) ){
  $bifx_api->
    login({ lgname => $username,
	    lgpassword => $password,
	  })
      or die "FAILED TO LOGIN!\n";
}
else{
  warn "
Note : No username (-u --username) and password (-p --password) found,
will not update!\n\n"
}





## COLLECT THE BIOWIKI API LIST
warn "Collecting api list\n";

my %biowiki_api_list =
  get_biowiki_api_list_from_bifx;





## PROCESS THE BIOWIKI API LIST
warn "\nProcessing\n";

for my $page_name (sort {$a cmp $b} keys %biowiki_api_list){
  warn "\n\nDoing $page_name\n";
  
  ## Cant handle Wikipedia projects here!
  next if $page_name eq 'Gene Wiki';
  
  my $biowiki_api_url =
    $biowiki_api_list{$page_name};
  
  my $biowiki_api = MediaWiki::API::helper->
    new( api_url => $biowiki_api_url );
  
  unless($biowiki_api->test){
    warn "FAILED TO CONNECT\n";
    next;
  }
  
  
  
  warn "Collecting rc stats\n";
  
  my $rcstats =
    $biowiki_api->get_rcstats({ months => 1 });
  warn "Note:\t", join("\t", @$rcstats), "\n";
  
  
  
  warn "Updating page\n";
  
  my $page_ref = $bifx_api->
    get_page({ title => $page_name });
  
  unless($page_ref){
    warn "Failed to get page ref!\n";
    next;
  }
  
  my $page_text = $page_ref->{'*'};
  
  my $new_text =
    parse_biowiki_page_text_and_create_new_text(
      $page_text, $rcstats
    );
  
  #print $new_text; exit;
  
  ## To avoid edit conflicts
  my $timestamp = $page_ref->{timestamp};
  
  $bifx_api->upload_page( $page_name, $timestamp, $new_text )
    or warn "Failed to upload page... did you log in?\n";
  
  warn "OK\n";
  
  #exit;
}


warn "Done.\n";
