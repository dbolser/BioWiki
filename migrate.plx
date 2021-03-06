#!/usr/bin/perl -w

## For information, see:
## http://search.cpan.org/dist/MediaWiki-API/lib/MediaWiki/API.pm

use strict;

use Data::Dumper;

use MediaWiki::API;



## CONNECT TO AN API

my $nett_api_url = 'http://nettab.referata.com/w/api.php';
my $bifx_api_url = 'http://www.bifx.org/w/api.php';


## Get API object for the given URL
my $nett_mw = MediaWiki::API->
  new({ api_url => $nett_api_url, retries => 5 });

my $bifx_mw = MediaWiki::API->
  new({ api_url => $bifx_api_url, retries => 5 });



## Configure a default error function (saves us checking for errors)
$nett_mw->{config}->{on_error} = \&nett_on_error;
$bifx_mw->{config}->{on_error} = \&bifx_on_error;

## The error function
sub nett_on_error {
  warn "Error code: ", $nett_mw->{error}->{code}, "\n";
  warn $nett_mw->{error}->{details}, "\n";
  warn $nett_mw->{error}->{stacktrace}, "\n";
  die "nett err\n";
}

sub bifx_on_error {
  warn "Error code: ", $nett_mw->{error}->{code}, "\n";
  warn $bifx_mw->{error}->{details}, "\n";
  warn $bifx_mw->{error}->{stacktrace}, "\n";
  die "bifx err\n";
}



## Print the site names
my $ref1 = $nett_mw->api( { action => 'query', meta => 'siteinfo' } );
warn "Sitename: '", $ref1->{query}->{general}->{sitename}, "'\n";

my $ref2 = $bifx_mw->api( { action => 'query', meta => 'siteinfo' } );
warn "Sitename: '", $ref2->{query}->{general}->{sitename}, "'\n";



## Log in to the wiki
$bifx_mw->
  login({ lgname => 'DanBolser',
	  lgpassword => '000006',
	});



## Get the list of BioWiki pages to migrate from the nettab site

my $page_list = $nett_mw->
    list({ action => 'query',
	   list => 'categorymembers',
	   cmtitle => 'Category:BioWiki',
	 });

print "got ", scalar(@$page_list), " pages to migrate\n";



## Process them and upload to the bifx site

foreach my $page (@$page_list){
  
  my $page_title = $page->{title};

  #print Dumper $page;
  warn "doing page $page_title\n";
  
  $page = $nett_mw->
    get_page({ title => $page_title });
  
  #print Dumper $page;
  
  my $page_text = $page->{'*'};
  
  ## Parse out the 'BioWiki' template from the page text
  die "fail\n"
    unless $page_text =~ /^(.*){{\s*([\w\d\s]+?)\s*\|(.*)}}(.*)$/s;
  
  ## This version is simpler
  die "fail\n"
    unless $page_text =~ /^(.*){{(BioWiki)\s*\|(.*)}}(.*)$/s;
  
  #print "'$1'\n";
  #print "'$2'\n";
  #print "'$3'\n";
  #print "'$4'\n";
  
  my $pre_text       = $1;
  my $template_title = $2; # BioWiki in this case
  my $template_body  = $3;
  my $post_text      = $4;
  
  die "wuh?\n" if $pre_text ne '';
  
  $template_body =~ s/\n//g;
  
  my %fields = split(/\||=/, $template_body);
  
  #print "$_\t$fields{$_}\n" for keys %fields;
  
  
  
  ## Fill in the missing values of the template fields we can expect
  $fields{'Has TagLine'}         ||= '';
  $fields{'Has Create Date'}     ||= '';
  $fields{'Has Logo'}            ||= '';
  $fields{'Has Number of Pages'} ||= '';
  $fields{'Has Number of Users'} ||= '';
  $fields{'Has Page Edits'}      ||= '';
  $fields{'Has URL'}             ||= '';
  $fields{'Has Contact'}         ||= '';
  $fields{'Has Contact Email'}   ||= '';
  $fields{'Has Institution'}     ||= '';
  
  
  ## Sanity check fields
  for(keys %fields){
    # used
    next if /^Has TagLine$/;
    next if /^Has Create Date$/;
    next if /^Has Logo$/;
    next if /^Has Number of Pages$/;
    next if /^Has Number of Users$/;
    next if /^Has Page Edits$/;
    next if /^Has URL$/;
    next if /^Has Contact$/;
    next if /^Has Contact Email$/;
    next if /^Has Institution$/;
    
    # discarded
    next if /^Has Number of Views$/;
    next if /^Has Number of Editors$/;
    next if /^Has Number of Editors is Estimate$/;
    next if /^Is Verified$/;
    next if /^Has Main Page Views$/;
    
    # missed
    die "How did we miss : '$_' ?\n"
  }
  
  
  
  ## Create the new page text;
  
  my $new_page_text = <<EOT
{{BioWiki/Description
 |tag line = $fields{'Has TagLine'}
}}
$post_text


{{BioWiki
 |date created = $fields{'Has Create Date'}
 |logo file    = $fields{'Has Logo'}
 |num pages    = $fields{'Has Number of Pages'}
 |num users    = $fields{'Has Number of Users'}
 |num contribs = $fields{'Has Page Edits'}
 |contribs     = Raw edit count
 |url          = $fields{'Has URL'}
 |people       = $fields{'Has Contact'}
 |email        = $fields{'Has Contact Email'}
 |institutions = $fields{'Has Institution'}
}}

{{Links}}
{{References}}
{{External links box}}

EOT
;
  
  #print $new_page_text, "\n";
  
  
  
  warn "writing\n";
  
  my $new_page_name = $page_title;
  
  my $new_page_ref = $bifx_mw->
    get_page( { title => $new_page_name } );
  
  #print Dumper $new_page_ref;
  #next;
  
  ## Don't trash existing pages
  unless ( exists($new_page_ref->{missing}) ){
    warn "skipping\n";
    next;
  }
  
  ### To avoid edit conflicts
  #my $timestamp = $new_page_ref->{timestamp};
  
  $bifx_mw->
    edit({ action => 'edit',
	   title => $new_page_name,
	   ## To avoid edit conflicts
	   #basetimestamp => $timestamp,
	   text => $new_page_text,
	 });
  
  #exit;
}

warn "OK\n";
