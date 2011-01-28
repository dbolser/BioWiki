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

## Configure the file url (for downloading images)
#$bifx_mw->{config}->{files_url} = 'http://www.exotica.org.uk';

## Configure the upload url (for uploading images)
$bifx_mw->{config}->{upload_url}
  = 'http://www.bioinformatics.org/wiki/Special:Upload';



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



## Log in to the wiki (needed for edits, uploads, etc.)
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

warn "got ", scalar(@$page_list), " pages to migrate\n";





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
  
  
  
  ## Here, we only care about the image
  
  if(! exists $fields{'Has Logo'}){
    warn "no logo\n";
    next;
  }
  
  my $logo_name = $fields{'Has Logo'};
  
  warn "downloading 'Image:$logo_name'\n";
  
  my $logo = $nett_mw->
    download({ title => 'Image:'. $logo_name });
  
  ## It's the raw image data!
  #print $logo;
  
  warn "OK\n";
  
  
  ## The upload fails for some reason, so we just save the downloaded
  ## files...
  
  open FH, '>', "Images/$logo_name"
    or die "failed to open file for writing 'Images/$logo_name' : $!\n";
  
  print FH $logo;
  close FH;
  
  
  
  ### Upload
  #
  #warn "uploading\n";
  #
  #my $new_page_ref = $bifx_mw->
  #  get_page( { title => 'Image:'. $logo_name } );
  #
  #print Dumper $new_page_ref;
  #
  ### Don't trash existing pages
  #unless( exists($new_page_ref->{missing}) ){
  #  warn "image exists, skipping\n";
  #  next;
  #}
  #
  #$bifx_mw->
  #  upload({ title   => $logo_name,
  #           summary => 'BioWiki logo upload',
  #           data    => $logo
  #         });
  #
  #exit;
}

warn "OK\n";

