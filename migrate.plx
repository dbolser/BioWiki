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
$nett_mw->{config}->{on_error} = \&on_error;
$bifx_mw->{config}->{on_error} = \&on_error;

## The error function
sub on_error {
  warn "Error code: ", $nett_mw->{error}->{code}, "\n";
  warn $nett_mw->{error}->{details}, "\n";
  warn $nett_mw->{error}->{stacktrace}, "\n";
  die "err\n";
}



## Print the site names
my $ref1 = $nett_mw->api( { action => 'query', meta => 'siteinfo' } );
warn "Sitename: '", $ref1->{query}->{general}->{sitename}, "'\n";

my $ref2 = $bifx_mw->api( { action => 'query', meta => 'siteinfo' } );
warn "Sitename: '", $ref2->{query}->{general}->{sitename}, "'\n";










warn "OK\n";
