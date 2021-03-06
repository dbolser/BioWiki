package BioWikiTools;

use LWP::Simple;

use vars qw(@ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA =
  qw(Exporter AutoLoader);

@EXPORT_OK =
  qw( get_biowiki_api_list_from_bifx
      parse_biowiki_page_text_and_create_new_text
   );



## Query API url list

sub get_biowiki_api_list_from_bifx {
  
  ## Getting csv feel wrong, but what can you do?
  my $url = "http://www.bioinformatics.org/wiki/Special:Ask";
  my $query =
    "{{#ask: [[Category:BioWiki]] [[MediaWiki API URL::+]] | ?MediaWiki API URL  | format=csv }}";
  
  ## URL encode
  #$query =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
  
  ## Cant seem to encode it right, here is the URL SMW gives for the
  ## above query
  my $bleah = "http://www.bioinformatics.org/wiki/Special:Ask/-5B-5BCategory:BioWiki-5D-5D-20-5B-5BMediaWiki-20API-20URL::%2B-5D-5D/-3FMediaWiki-20API-20URL/format%3Dcsv/sep%3D,/headers%3Dshow/limit%3D100";
  
  my $query_result = get( $bleah );
  
  die "Couldn't get query result!"
    unless defined $query_result;
  
  ## Debugging
  #die $query_result;
  
  my (%api_list, $got_header);
  
  for (split("\n", $query_result)){
    next unless $got_header++;
    
    my ($page_name, $api_url) = split(/,/, $_);
    
    ## Strip quotes, if necessary
    $page_name = $1 if $page_name =~ /^"(.*)"$/;
    
    $api_list{$page_name} = $api_url;
  }
  
  warn "Got ", scalar keys %api_list, " APIs to process\n";
  
  return %api_list;
}





sub parse_biowiki_page_text_and_create_new_text {
  my $page_text = shift;
  my ( $users, $number_of_new_users,
       $pages, $number_of_new_pages,
       $total_edits,
     ) = @{(shift)};
  
  ## Parse out the (first) 'BioWiki' template from the page text
  die "failed to parse page text\n"
    unless $page_text =~ /^(.*?){{(BioWiki)\s*\|(.*?)}}(.*)$/s;
  
  #print "'$1'\n";
  #print "'$2'\n";
  #print "'$3'\n";
  #print "'$4'\n";
  
  my $pre_text       = $1 || '';
  my $template_title = $2;       # BioWiki in this case
  my $template_body  = $3;
  my $post_text      = $4;
  
  ## Strip newlines from pre and post text (stop newline creep in
  ## sucessive updates)
  chomp($pre_text);
  chomp($post_text);

  ## Strip newlines from the template body?
  #$template_body =~ s/\n//g;
  
  ## Parse the template fields
  my @fields = split(/\||=/, $template_body);
  
  for (my $i=0; $i<@fields; $i++){
    $fields[$i] =~ s/^\s*|\s*$//g;
  }
  
  my %fields = @fields;
  
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
    next if /^api url$/;
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
  
  
  
  ## Create the new page text
  
  my $new_page_text = "$pre_text
{{BioWiki
|date created=". ($fields{'date created'} || ''). "
|num pages=".    ($fields{'num pages'}    || ''). "
|num users=".    ($fields{'num users'}    || ''). "
|num contribs=". ($fields{'num contribs'} || ''). "
|contribs=".     ($fields{'contribs'}     || ''). "
|logo file=".    ($fields{'logo file'}    || ''). "
|platform=".     ($fields{'platform'}     || ''). "
|api url=".      ($fields{'api url'}      || ''). "
|extensions=".   ($fields{'extensions'}   || ''). "
|num users active=". $users                     . "
|num users new=".    $number_of_new_users       . "
|num pages active=". $pages                     . "
|num pages new=".    $number_of_new_pages       . "
|num edits=".        $total_edits               . "
|url=".          ($fields{'url'}          || ''). "
|people=".       ($fields{'people'}       || ''). "
|email=".        ($fields{'email'}        || ''). "
|institutions=". ($fields{'institutions'} || ''). "
}}$post_text";
  
  return $new_page_text;
}

1;
