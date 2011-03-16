#!/usr/bin/perl -w

use strict;
use MediaWiki::API::helper;

use BioWikiTools
    qw( get_biowiki_api_list_from_bifx
	grab_page
	grab_page_text
        parse_biowiki_page_text_and_create_new_text
	upload_biowiki_page
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

warn "no username or password provided, will not update\n"
  unless defined($username) && defined($password);



## CONNECT TO BIFX MW API
warn "connecting to bifx mw api\n";

my $bifx_api_url =
  'http://www.bioinformatics.org/w/api.php';

my $bifx_api = MediaWiki::API::helper->
  new( api_url => $bifx_api_url );

$bifx_api->test
  or die "FAILED TO CONNECT\n";



## COLLECT THE BIOWIKI API LIST
warn "collecting api list\n";

my %biowiki_api_list =
  get_biowiki_api_list_from_bifx;





## PROCESS THE LIST

warn "\nprocessing\n";

for my $page_name (sort {$a cmp $b} keys %biowiki_api_list){
#for my $page_name (sort {$b cmp $a} keys %biowiki_api_list){
  warn "\n\nDoing $page_name\n";
  
  #next unless $page_name eq 'Bvio';
  next if $page_name eq 'Gene Wiki';
  
  my $biowiki_api_url =
    $biowiki_api_list{$page_name};
  
  my $biowiki_api = MediaWiki::API::helper->
    new( api_url => $biowiki_api_url );
  
  unless($biowiki_api->test){
    warn "FAILED TO CONNECT\n";
    next;
  }
  
  #my $rc_list =
  #  $biowiki_api->get_rc_list({ months => 1 });
  # 
  #unless($rc_list){
  #  die "FAILED TO GET RC LIST\n";
  #  next;
  #}
  
  
  
  warn "collecting rc stats\n";
  
  my $rc_stats =
    $biowiki_api->get_rc_stats({ months => 1 });
  warn "Note:\t", join("\t", @$rc_stats), "\n";
  
  next;
}

__END__

  
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
  
  exit;
}


warn "Done.\n";
