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

use Digest::MD5 qw(md5_hex);



## We use an 'epoch' format time here, because it's easy to pass to
## MediaWiki.
my $rcstart =
  DateTime->now->subtract(months => 1)->epoch;

## Debugging
#my $rcstart =
#  DateTime->now->subtract(minutes => 1)->epoch;





## CONNECT TO AN API

my $api_url = 'http://www.bioinformatics.org/w/api.php';



## CONNECT TO THE BIOWIKI API (as above in this case)



## Get API object for the given URL
my $mw = MediaWiki::API->
  new({ api_url => $api_url, retries => 5 });



## Configure a default error function (saves us checking for errors)
$mw->{config}->{on_error} = \&on_error;

## The error function
sub on_error {
  warn "Error code: ", $mw->{error}->{code}, "\n";
  warn $mw->{error}->{details}, "\n";
  warn $mw->{error}->{stacktrace}, "\n";
  die "err\n";
}



## Print the site name (shows we got a connection) 
my $ref = $mw->api( { action => 'query', meta => 'siteinfo' } );
warn "Sitename: '", $ref->{query}->{general}->{sitename}, "'\n";





## Grab the recent changes list (object)

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
	 
	 ## Filters: Lets post process these (using flags), !filter
	 #rcshow => '!minor|!bot',
	 #rctype => 'edit|new|log',
	 
	 #rcexcludeuser => '',
	 
	 ## Properties to return. See:
	 ## http://www.mediawiki.org/wiki/API:Query_-_Lists#recentchanges_.2F_rc
	 rcprop =>
	   'user|timestamp|title|flags|loginfo'
	 
	},
	{
	 ## MW::API Config
	 
	 ## Process result as they come in with this function
	 ## (responsible for returning something useful).
	 #hook => \&look_hook,
	 
	 ## Max number of batches to collect (for debugging)
	 #max => 1
	 
	}
       );

#sub look_hook{
#  warn "hi\n";
#}

warn 'found ', scalar(@$rc_array), " revisions\n";

## Debugging
#warn Dumper $rc_array;





## Compile edit statistics for the month

## here we collect four counts:

## Number of active users (number of new users)
## Number of pages edited (number of new pages)
## 
## Number of edits


my (%users, $number_of_new_users,
    %pages, $number_of_new_pages,
    $total_edits,
    );

foreach my $rc (@$rc_array){
  
  ## Debugging
  #warn Dumper $rc;
  #warn "paused\n";
  #my $x = <STDIN>;
  
  if($rc->{type} eq 'log'){
    if($rc->{logtype} eq 'newusers'){
      ## Sanity check
      die Dumper $rc unless $rc->{logaction} eq 'create';
      #warn 'new user: ', $rc->{user}, "\n";
      $number_of_new_users++;
    }
    else{
      ## No other logtypes (e.g. delete, block, upload, move, ...)
      ## concern us here.
      
      ## TODO: We could look at the deletion log and see if any of our
      ## new users or new pages for the month should be deleted...
    }
  }
  
  elsif($rc->{type} eq 'new'){
    ## Sanity check
    die Dumper $rc unless defined($rc->{new});
    #warn 'new page: ', $rc->{title}, "\n";
    $number_of_new_pages++;
    $users{$rc->{ user}}++;
    $pages{$rc->{title}}++;
  }
  
  elsif($rc->{type} eq 'edit'){
    ## Filter bots and minor edits
    ## Need a username kill list here?
    next if defined($rc->{minor});
    $total_edits++;
    $users{$rc->{ user}}++;
    $pages{$rc->{title}}++;
  }
  
  else{
    die Dumper $rc;
  }
  
  next;
}

warn "OK\n";

print 'active users = ', scalar keys %users, "\n";
print " new users = $number_of_new_users\n";
print 'active pages = ', scalar keys %pages, "\n";
print " new pages = $number_of_new_pages\n";
print "total edits = $total_edits\n";





## OK, now we have to upload...

# Step 1) parse the existing BioWiki page

## In this simple case we don't need a new MW::API object for upload

my $page_title = 'Bioinformatics.Org Wiki';

my $page_ref = $mw->
  get_page({ title => $page_title });

#print Dumper $page_ref;

my $page_text = $page_ref->{'*'};

## Parse out the (first) 'BioWiki' template from the page text
die "failed to parse page '$page_title'\n"
  unless $page_text =~ /^(.*?){{(BioWiki)\s*\|(.*?)}}(.*)$/s;

#print "'$1'\n";
#print "'$2'\n";
#print "'$3'\n";
#print "'$4'\n";

my $pre_text       = $1;
my $template_title = $2; # BioWiki in this case
my $template_body  = $3;
my $post_text      = $4;

## Strip newlines from the template body
$template_body =~ s/\n//g;

## Parse the template fields
my %fields = split(/\||=/, $template_body);

#print "$_\t$fields{$_}\n" for keys %fields;

## Sanity check fields
for(keys %fields){
  # used
  next if /^date created$/;
  next if /^logo file$/;
  next if /^num pages$/;
  next if /^num users$/;
  next if /^num contribs$/;
  next if /^contribs$/;
  next if /^platform$/;
  next if /^extensions$/;
  next if /^url$/;
  next if /^people$/;
  next if /^email$/;
  next if /^institutions$/;

  next if /^num users active$/;
  next if /^num users new$/;
  next if /^num pages active$/;
  next if /^num pages new$/;
  next if /^num edits$/;
  
  # missed
  warn "How did we miss : '$_' ?\n"
}



# Step 2) create the new page text

my $new_page_text = "
$pre_text
{{BioWiki
 |date created = ". ($fields{'date created'} || ''). "
 |logo file    = ". ($fields{'logo file'}    || ''). "
 |num pages    = ". ($fields{'num pages'}    || ''). "
 |num users    = ". ($fields{'num users'}    || ''). "
 |num contribs = ". ($fields{'num contribs'} || ''). "
 |contribs     = ". ($fields{'contribs'}     || ''). "
 |platform     = ". ($fields{'platform'}     || ''). "
 |extensions   = ". ($fields{'extensions'}   || ''). "
 |url          = ". ($fields{'url'}          || ''). "
 |people       = ". ($fields{'people'}       || ''). "
 |email        = ". ($fields{'email'}        || ''). "
 |institutions = ". ($fields{'institutions'} || ''). "

 |num users active = ". (scalar keys %users). "
 |num users new    = $number_of_new_users
 |num pages active = ". (scalar keys %pages). "
 |num pages new    = $number_of_new_pages
 |num edits        = $total_edits
}}
$post_text
";

#print $new_page_text, "\n";



# Step 3) upload the new page

warn "writing\n";

## In this simple case we don't need a new MW::API object for upload,
## however, we need to login now to write.

$mw->
  login({ lgname => 'Dan Bolser Bot',
          lgpassword => '000006',
        });

## To avoid edit conflicts
my $timestamp = $page_ref->{timestamp};

$mw->
  edit({ action => 'edit',
	 title => $page_title,
	 ## To avoid edit conflicts
	 basetimestamp => $timestamp,
	 text => $new_page_text,
         summary => "uploading statistics for $page_title",
         ## Mark the edit as a bot edit.
         bot => '',
         ## Guard against encoding corruption (I hope!)
	 md5 => md5_hex($new_page_text),
       });

warn "OK\n";
