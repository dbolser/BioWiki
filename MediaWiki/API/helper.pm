package MediaWiki::API::helper;

use MediaWiki::API;

use Moose;
use Moose::Util::TypeConstraints;

use Data::Validate::URI qw(is_web_uri);

subtype 'URL'
  => as 'Str'
  => where { is_web_uri $_ }
  => message { "The given URL '$_' does not seem to be valid!" };

has 'api_url' => (
    is  => 'rw',
    isa => 'URL',
    required => 1,
);

has 'api_obj' => (
    is  => 'ro',
    isa => 'MediaWiki::API',
    builder => '_connect',
    required => 1,
);

use DateTime;
has 'rcstart' => (
    is  => 'rw',
    isa => 'DateTime',
    lazy => 1,
    default => sub { DateTime->now },
);

has 'verbose' => ( is  => 'rw', isa => 'Int', default => 0 );
has 'debug'   => ( is  => 'rw', isa => 'Int', default => 0 );



## CONNECT TO A MediaWiki API
sub _connect {
  my $self = shift;
  warn "connecting\n";
  
  ## Get MediaWiki::API object for the given api_url
  return
    MediaWiki::API->
	new({ api_url => $self->api_url, retries => 5,
	      on_error => sub{ _on_error( $self ) }
	    });
}

## The error function
sub _on_error {
  my $self = shift;
  
  warn "API ERROR!\n";
  warn "\tError code: ", $self->api_obj->{error}->{code}, "\n";
  warn "\tDETAILS:\n",   $self->api_obj->{error}->{details}, "\n";
  
  ## Stack trace is often overkill
  warn $self->api_obj->{error}->{stacktrace}, "\n"
    if $self->verbose > 0;
  
  ## Debugging
  exit 1
    if $self->debug > 0;
}



sub test{
  my $self = shift;
  
  ## See: http://www.mediawiki.org/wiki/API:Meta#siteinfo_.2F_si
  my $ref =
    $self->api_obj->api({ action => 'query', meta => 'siteinfo' });
  
  warn "Connected to : '",
    $ref->{query}->{general}->{sitename}  || '', "' (",
    $ref->{query}->{general}->{generator} || '', ")\n";
  
  ## fail! rcunknown_rcprop: Unrecognised value for parameter 'rcprop'
  ## MediaWiki 1.12.0
  
  return $self->_ok;
}



sub _ok {
  my $self = shift;
  
  if($self->api_obj->{error}->{code}){
    ## We need to manually reset the error code, which sucks
    ## https://rt.cpan.org/Public/Bug/Display.html?id=66388
    $self->api_obj->{error}->{code} = 0;
    return 0;
  }
  return 1;
}

sub mw_login {
  my $self = shift;
  my $credentials = shift;
  
  warn "logging in\n";
  $self->api_obj->
    login({ lgname => $credentials->[0],
	    lgpassword => $credentials->[1],
	  });
  
  return $self->_ok;
}





## Compile edit statistics

## Here we collect five counts:

## Number of active users (number of new users)
## Number of pages edited (number of new pages)
## Number of edits

sub get_rc_stats{
  my $self = shift;
  my $rcstart_off = shift || { hours => 1 };
  
  my $rclist = $self->get_rclist( $rcstart_off );
  
  my (%users, $number_of_new_users,
      %pages, $number_of_new_pages,
      $total_edits,
     );
  
  foreach my $rc (@$rclist){
    
    if($rc->{type} eq 'log'){
      ## Seems image uploads don't set a log type
      unless(defined($rc->{logtype})){
	## Debugging
	#warn "unknown logtype!\n";
	#warn Dumper $rc;
	next;
      }
      if($rc->{logtype} eq 'newusers'){
	## Sanity check
	die Dumper $rc
	  unless
	    $rc->{logaction} eq 'create' ||
	    $rc->{logaction} eq 'create2'; # EcoliWiki
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
      die Dumper $rc
	unless defined($rc->{new});
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
  
  ## Return five numbers
  return [ scalar keys %users || 0, $number_of_new_users || 0,
	   scalar keys %pages || 0, $number_of_new_pages || 0,
	   $total_edits || 0,
	 ];
}



## Grab the recent changes list (object) from the MediaWiki API

sub get_rclist {
  my $self = shift;
  my $rcstart_off = shift || { hours => 1 };
  
  ## We use 'epoch' time format here, simply becase it's easy to pass
  ## to MediaWiki https://rt.cpan.org/Public/Bug/Display.html?id=66611
  my $rcstart =
    $self->rcstart->subtract( $rcstart_off )->epoch;
  
  my $rc_list = $self->api_obj->
    list ({
	   action  => 'query',
	   list    => 'recentchanges',
	   
	   ## Get changes since:
	   rcdir   => 'newer',
	   rcstart => $rcstart,
	   
	   ## Number of revisions to collect in each batch of results
	   ## returned by the API
	   rclimit => '500',
	   
	   ## Filters:
	   rcshow => '!minor|!bot',
	   
	   #For reference
	   #rctype => 'edit|new|log',
	   
	   #rcexcludeuser => '',
	   
	   ## Properties to return. See:
	   ## http://www.mediawiki.org/wiki/API:Recentchanges
	   rcprop =>
	   'user|timestamp|title|flags|loginfo'
	   
	  },
	  {
	   ## MW::API Config
	   
	   ## Max number of batches to collect (for debugging)
	   #max => 1
	   
	  }
	 );
  
  if($self->_ok){
    warn "Got ", scalar @$rc_list, " RCs to process\n";
    return $rc_list;
  }
  
  ## Return an empty list reference;
  return [];
}










1;
