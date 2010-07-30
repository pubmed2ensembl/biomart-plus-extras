=head1 NAME

BioMart::Web - Class for handling incoming BioMart web-requests


=head1 SYNOPSIS

    use BioMart::Web;
    my $webquery = BioMart::Web->new({conf => $path_to_registryfile});
    my $q = CGI->new();
    $webquery->handle_request($q);


=head1 DESCRIPTION

This class handles processing of CGI-requests to build BioMart queries, execute
them and show the results to the user. Only initialization, query-building and
other such logic is done here: all user-interface presentation related things
are handled by Template Toolkit templates. 
  
=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Richard Holland, Damian Smedley, Gudmundur Arni Thorisson

=head1 CONTACT

This module is part of the BioMart project
http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 SUBROUTINES/METHODS 

=cut

package BioMart::Web;

use strict;
use warnings;
use English;

use Readonly;
use Log::Log4perl;
use Mail::Mailer;
use Data::Dumper;
use File::Path;
use CGI::Session;
use CGI::Session::Driver::db_file; # required by CGI::Session
use XML::Simple qw(:strict);
use DBI;
use File::Basename qw(dirname basename);
use List::MoreUtils qw/apply uniq/;
use Number::Format qw(:subs);
use POSIX qw(strftime);
use Template;
use Time::HiRes qw/time/;
use Template::Constants qw( :debug ); 
use Storable qw(store retrieve freeze nfreeze thaw);
local $Storable::Deparse = 1;
$Storable::forgive_me = 1;


use BioMart::Initializer;
use BioMart::QueryRunner;
use BioMart::Query;
use BioMart::Exception;
# Need these for serialize/deserialize step
use BioMart::Registry;
use BioMart::Dataset::TableSet;
use BioMart::Dataset::GenomicSequence;
use BioMart::Dataset::GenomicAlign;
use BioMart::Web::SiteDefs;
use BioMart::Web::PageStub; ## Quick hack...!
use BioMart::Web::Zlib;
use base qw(BioMart::Root);

our $VERSION = '0.4.9.0';


	my $logger;						 # master logger
    	my $tt_processor;                # template processor
    	my $config;                      # configuration object
    	my $conf_dir;                    # configuration directory

sub get_mart_registry()
{
	my ($self) = @_;
	return $self->get('mart_registry');
}
sub get_conf_Dir()
{
	my ($self) = @_;
	return $self->get('confDir');		
}
sub get_config_dir
{
	my ($self) = @_;
	return $self->get('configDir');		
}
sub get_session_dir
{
	my ($self) = @_;
	return $self->get('sessionDir');
}
sub get_default_tt_dir
{
	my ($self) = @_;
	return $self->get('defaultDir');	
}
sub get_custom_tt_dir
{
	my ($self) = @_;
	return $self->get('customDir');	
}
sub get_cached_tt_dir
{
	my ($self) = @_;
	return $self->get('cachedDir');	
}
sub get_errstr
{
	my ($self) = @_;
	return $self->get('errmsg');	
}
sub getSettings
{
	my ($self, $attribute) = @_;
	my $mart_registry = $self->get_mart_registry();
     my $hash = $mart_registry->settingsParams();
     foreach(keys %$hash) {     	
	     if($_ eq $attribute) {
	     	return %{$hash->{$_}};
     	}
     }
}

=head2 new

  Usage      : my $webquery = BioMart::Web->new({conf     => $path_to_registryfile,
						 registry => $registry});
  Purpose    : Construct a new instance of this class
  Returns    : BioMart::Web instance
  Arguments  : path to Mart registry XML-configfile
               reference to BioMart::Registry object (optional)
  Throws     : BioMart::Exception::Configuration on registry initialization errors           
  Status     : Public
  Comments   : If registry object is provided in constructor, it will be used instead of
               initialization a new registry from scratch. The path to the registry
               XML-file is still needed, however.
  See Also   :

=cut


    # Constructor, sort of: Class::Std will call this method when it's constructing the object.
sub _new 
{
	my ($self, @params) = @_;

	$self->SUPER::_new(@params);
	my (%args_ref) = @params;
	#my $args_ref = %args_ref1;
	$self->attr('errmsg', undef);
	#print "\nWEB CONSTRUCTOR";
	
	exists $args_ref{conf} && -f $args_ref{conf} 
	       || BioMart::Exception::Configuration->throw("Must provide path to config file as 'conf' argument ($args_ref{conf} is not a file)");
	my $conf_dir = dirname($args_ref{conf});
	#$config_dir_of{ $ident } = $conf_dir;
	$self->attr('configDir', $conf_dir);		
		
     # Get reference to logger
    $logger = Log::Log4perl->get_logger(__PACKAGE__);

	my $mart_registry;
	if(defined($args_ref{registry})) {
		$logger->debug("Using existing registry passed to BioMart::Web constructor");
	    	$mart_registry = $args_ref{registry};
		#print STDERR "\nWEB.pm :: RECEIVED REGISTRY as registry OBJECT !! \n";
	}
	else {
	    # Otherwise deserialize registry from file if possible, or initialize from scratch
		my $cachefile = $args_ref{conf}.".cached"; 
		if(my $size = -s $cachefile) 
		{
			#print STDERR "\nWEB.PM :: RECEIVED REGISTRY . DESERIALISING....!!\n"; 
			# thats the one used, if file already exists, both for run apache and new TemplateBuilder
			$logger->debug("Deserializing registry from ".format_bytes($size)." of data in $cachefile");
			eval{ $mart_registry = retrieve($cachefile) };

			# Throw exception if deserialization failed
			if($@ || !defined($mart_registry)) {
		    		BioMart::Exception::Configuration->throw("Failed deserialization of registry from $cachefile. ".$@||q{} );
			}
		}    
	}
	
	#$self->set_mart_registry($mart_registry);
	$self->attr('mart_registry', $mart_registry);
	$self->attr('confDir',$conf_dir); # added to get path for settings.conf to make it available for Mr. Apache
	
	# Set up directory for sessions
	#$session_dir_of{ $ident } = $args_ref{session_dir} || $conf_dir.'/sessions';
	$self->attr('sessionDir', $args_ref{session_dir} || $conf_dir.'/sessions');
	# Set up template include-dirs and initialize template processor
	my $tt_dir =  $args_ref{tt_dir} || $conf_dir.'/templates';
	
     #$default_tt_dir_of{ $ident } = $args_ref{default_tt_dir} || $tt_dir.'/default';
     #$custom_tt_dir_of{  $ident } = $args_ref{custom_tt_dir}  || $tt_dir.'/custom';
     #$cached_tt_dir_of{  $ident } = $args_ref{cached_tt_dir}  || $tt_dir.'/cached';
     $self->attr('defaultDir',$args_ref{default_tt_dir} || $tt_dir.'/default');
     $self->attr('customDir',$args_ref{custom_tt_dir}  || $tt_dir.'/custom');
     $self->attr('cachedDir',$args_ref{cached_tt_dir}  || $tt_dir.'/cached');
     
	# NOTE TO SELF: check if dirs exist & can be used

	$tt_processor = Template->new({ INCLUDE_PATH => [		$self->get_cached_tt_dir,
                                                         	$self->get_custom_tt_dir,
                                                         	$self->get_default_tt_dir ],
                                        DEFAULT      => 'notfound.tt',
                                        RELATIVE     => 1,
                                        ABSOLUTE     => 1,
                                        INTERPOLATE  => 1,
                                        EVAL_PERL    => 1,
                                        POST_CHOMP   => 1,
                                        PRE_CHOMP    => 1,
					COMPILE_EXT  => 'c',
					COMPILE_DIR  => '/',
					CACHE_SIZE => 5
                                        # NOTE TO SELF: add constants here, for performance boost?
                                        # DEBUG => DEBUG_ALL,
                                        # CONSTANTS    => {},
                                        # ERROR        => 
                                   })
            || BioMart::Exception::Template->throw("Error when initalizing TT processor: ".$Template::ERROR);
	
        # Initalize a single BioMart query runner (for reuse, don't need to always make new one)
        #$query_runner_of{ $ident } = BioMart::QueryRunner->new();
        #$self->attr('QR', BioMart::QueryRunner->new());
        
}

=head2 process_template

  Usage      : $webquery->process_template($template,\%vars, $output);
  Purpose    : Process the specified template with Template Toolkit
  Returns    : Nothing if optional output argument is provided. If no output arg
               is provided, then returns processed text output to caller.
  Arguments  : Filename of template
               Optional argument hashref
               Optional output filehandle-like object (e.g. IO::File, \*STDOUT)
  Throws     : BioMart::Exception::Template on processing errors
  Status     : Public
  Comments   :
  See Also   :

=cut

    sub process_template {
        my ($self, $template, $vars, $output) = @_;
        $logger->debug("Processing template $template");
        $vars->{webquery} = $self;
	my $new_start_time = time();

        $logger->info("START PROCESSING TEMPLATE $template");
	
	$output ||= q{};
	$tt_processor->process($template,$vars,ref($output) ? $output : \$output)
            || BioMart::Exception::Template->throw("Error in processing template $template: ".$tt_processor->error());
        my $time_elapsed = round(time() - $new_start_time);
 	#ref($output);  || warn "length(\$output)=".format_number(length($output));
	$logger->info("!!!! $time_elapsed to get process template $template and print to ".(ref($output) || 'string'));
	ref($output) || return $output; # return string if this wasn't a filehandle-thingie that was passed in
	return;
    }
=head2 perlhash2js

  Usage      : my $js_hash = $self->perlhash2js(\%hash)
  Purpose    : Convert a Perl hash into the Javascript equivalent  (via Data::Dumper).
  Returns    : Javascript code representing the hash structure.
  Arguments  : Reference to the hash to be converted.
  Throws     : none
  Status     : Public
  Comments   :
  See Also   :

=cut

    sub perlhash2js {
        my ($self, $hashref) = @_;
		### for usage, e.g see filterpanel.tt
	local $Data::Dumper::Pair = ':';
	local $Data::Dumper::Indent = 0;
	local $Data::Dumper::Terse = 1;
	return Dumper($hashref);	
    }

=head2 set_errstr

  Usage      : $self->set_errstr('my error message');
  Purpose    : Set the error message
  Returns    : Nothing
  Arguments  : String to set the error message to.
  Throws     : Exception if use attempted by a non-BioMart::* class.
  Status     : Private to class hierarchy.
  Comments   :
  See Also   :

=cut

    sub set_errstr
    {
	my ($self, $errmsg) = @_;
	#$errstr_of{ ident($self) } = $errmsg;
	$self->set('errmsg',$errmsg);
    }

=head2 restore_session

  Usage      : my $session = $webquery->restore_session($CGI)
  Purpose    : Retrieve stored user session or creates new one
  Returns    : session object, either new or restored.
  Arguments  : CGI request to get session ID parameter from
  Throws     : BioMart::Exception::Session on session errors.
  Status     : Public
  Comments   :
  See Also   : save_session()

=cut

    sub restore_session {
        my ($self,$cgi) = @_;

	# Get session ID from URL-string if available. Note that this is not really required
	# since CGI::Session can take our CGI object  (or create its own on the fly) and 
	# grab the session ID parameter. We like however to have the ID in the URL.
	my $self_url     = $cgi->self_url();
	
	# see if the call is sent by JS, remove the trailing identity of this call
	$self_url =~ s/(__countByAjax|__resultsByAjax)//;
	
	my $full_url     = $cgi->url(-full => 1);
	my ($session_id) = $self_url =~ m{$full_url/([^/\?]+)}xms;
	
	$session_id    ||= "foobar"; # needed to force new-session in constructor below
	
	# Delete old sessions.	
	CGI::Session->find( sub {} );
	my $session;
    	my %sessions = $self->getSettings('sessions');

	# Retrieve existing session if possible. CGI::Session will create new session for us if necessary
	if($sessions{'driver'} eq 'files') # flat files
	{
		$session = CGI::Session->new('driver:file', $session_id,
			{ Directory=>$self->get_session_dir() })
             || BioMart::Exception::Session->throw(CGI::Session->errstr);
	}
	elsif ($sessions{'driver'} eq 'mysql')
	{
		my $dsn = $sessions{'dsn'};
		my $user = $sessions{'user'};
		my $pass = $sessions{'pass'};
		my $dbh = DBI->connect($dsn, $user, $pass, {'RaiseError' => 1});
		$session = CGI::Session->new("driver:MySQL", $session_id, {Handle=>$dbh})
			|| BioMart::Exception::Session->throw(CGI::Session->errstr);
		#$dbh->disconnect();		
	}
	elsif ($sessions{'driver'} eq 'oracle')
	{
		my $dsn = $sessions{'dsn'};
		my $user = $sessions{'user'};
		my $pass = $sessions{'pass'};
		# here LongReadLen determine the max size of a session that goes into a single row.
		# right now setting this to 1 MB for a session. can go up to 4GB as per Oracle specifications
		my $dbh = DBI->connect($dsn, $user, $pass, {'RaiseError' => 1, 'LongReadLen' => 1000000 });		
		$session = CGI::Session->new("driver:Oracle", $session_id, {Handle=>$dbh})
			|| BioMart::Exception::Session->throw(CGI::Session->errstr);
		#$dbh->disconnect();	
	}
	elsif ($sessions{'driver'} eq 'postgres')
	{
		print "POSTGRES DRIVER Not implemented yet";
	}
	else # default to BerkeleyDB
	{
		$session = CGI::Session->new('driver:db_file', $session_id,
		{ FileName=>$self->get_session_dir()."/cgisessions.db" })
			|| BioMart::Exception::Session->throw(CGI::Session->errstr);	
	}
	
	
	if($session->is_new()) {
		#### If the URL string does not contain a session ID or an inexistent session ID then a
		#### new session gets created and stored and script returns with out doing anything. 
		#### Then comes back again and tries to restore this session ID,
		#### and this time around, finds it and restores it. weirdoooo
		# Galaxy.
	   if ($cgi->param("GALAXY_URL") and !$session->param("GALAXY_URL")) {
			$session->param("GALAXY_URL",$cgi->param("GALAXY_URL")); 
		 	$session->param('export_saveto','text');
		 	$session->param('preView_outputformat','tsv');
	   }    	
	   # URL request e.g ensembl URL request for contigView
    	if ($cgi->param('VIRTUALSCHEMANAME') || $cgi->param('ATTRIBUTES') )
		{		
			$session->param("url_VIRTUALSCHEMANAME",$cgi->param('VIRTUALSCHEMANAME'));
			$session->param("url_ATTRIBUTES", $cgi->param('ATTRIBUTES'));
			if ($cgi->param('FILTERS')) {	$session->param('url_FILTERS', $cgi->param('FILTERS')); }
			else {	$session->clear("url_FILTERS"); }
			if ($cgi->param('VISIBLEPANEL')) {	$session->param('url_VISIBLEPANEL', $cgi->param('VISIBLEPANEL')); }
			else {	$session->clear("url_VISIBLEPANEL"); }			
		}
		# ?XML=... request to martview
		# ?query=... request to martview
		if ($cgi->param('XML') || $cgi->param('xml') || $cgi->param('QUERY') || $cgi->param('query')) {
			if ($cgi->param('XML')) {
				$session->param('url_XML', $cgi->param('XML'));				
			}
			elsif ($cgi->param('xml')) {
				$session->param('url_XML', $cgi->param('xml'));
			}
                        elsif ($cgi->param('QUERY')) {
                                $session->param('url_XML', $cgi->param('QUERY'));
                        }
                        elsif ($cgi->param('query')) {
                                $session->param('url_XML', $cgi->param('query'));
                        }
			else { $session->clear("url_XML"); }
		}
		
    	# Expiry.
    	$session->expire($sessions{'expire'});
    	# Aliases.
    	my %aliases = $self->getSettings('aliases');
    	$session->param("__dataset",$aliases{'dataset'});
    	$session->param("__Dataset",$aliases{'Dataset'});
    	$session->param("__database",$aliases{'database'});
    	$session->param("__Database",$aliases{'Database'});
    	$session->param("__schema",$aliases{'schema'});
    	$session->param("__Schema",$aliases{'Schema'});
	    # Rewrite URL if required, so session ID is part of URL string from now on (see note above). 
	    $logger->info("Creating new session and rewriting URL to ".$full_url.'/'.$session->id().", then redirecting");
	    print $cgi->redirect(-uri=>$full_url.'/'.$session->id(),
	    		 -status=>"301 Moved Permanently");
	    
	    return;
	}
	else {
	    $logger->info("Restoring existing session ", $session->id());
	}
	
        # NOTE TO SELF: How to handle permanent vs temporary users? Tmp-users only for now, but make 
	# sure we can expand into perm-users later on (db-storage of user-info). Look into CGI::Session
	# ID generators
	return $session;
    }

=head2 save_session

  Usage      : $webquery->save_session($session, $CGI);
  Purpose    : Save CGI parameters to session, overwriting existing values.
  Returns    : Nothing
  Arguments  : Session object to save to, CGI-object which holds info from current request
  Throws     : None
  Status     : Public
  Comments   : This effectively 'piles up' request parameters into the user session, since
               saved parameter values are combined with values from other parameters from
               previous sessions.
  See Also   : restore_session()

=cut


    sub save_session {
        my ($self, $session, $cgi) = @_;

        # First need to handle upload-file parameters, as session can't store filehandles. We
        # basically want to replace the upload-file info with the actual ID-list from that file,
        # then the session-storage mechanism can easily handle the arrayref.
        # NOTE TO SELF: only do upload-thing IF we haven't already done it for the same file
        #               check for error after processing uploaded file?
        FILE:
        foreach my $file_param($cgi->param('upload_file_params')) {
	    my $fh = $cgi->param($file_param);
	    next FILE unless ($fh && (ref($fh) eq 'Fh'));
            local $INPUT_RECORD_SEPARATOR = undef;
            my $file_contents = <$fh>; 
            $logger->debug("Read content from upload-file $fh (param $file_param):\n$file_contents");
            $file_param =~ m/(.*)__file/;
            $cgi->param($1, $file_contents);
            $cgi->delete($file_param);
        }

		# Save all request parameters in the simplest CGI::Session manner. The darn module works
		# beautifully, I gotta say!
        $logger->debug("Saving parameters to session.\n");

	# added this as now turned off checkboxes have no CGI param rather
	# than value = "off" to save on the huge CGI object having to be sent
	# across from client browser for every attribute and filter

	my %session_hashref = %{$session->param_hashref()};
	foreach my $param_name (keys %session_hashref){
	    if (($session->param($param_name) and $session->param($param_name) eq 'on') &&
		!($cgi->param($param_name))){
		$session->param($param_name,'off');
	    }
	}

        $session->save_param($cgi);

	#$logger->is_debug()
	#    and $logger->debug("Combined session params after save:\n", Dumper($session->dataref()));
        return;
    }


=head2 extract_queryparams

  Usage      : my ($filtervalue_hash, $attribute_arrayref) 
                   = $self->extract_queryparams($CGI->Vars(), \@filterlist, \@attributelist);
  Purpose    : Extracts information on filter/value pairs and attribute on/off status from
               a larger collection of parameter/value pairs from a CGI-request.
  Returns    : Reference to hash of filter values keyed to the filternames and an arrayref
               with list of attribute names.
  Arguments  : Reference to hash of parameter/value data (typically $CGI->Vars() from a CGI
               object or $session->dataref() from a CGI::Session object.
               Arrayref of filternames to extract values for (i.e. keys in hashref above).
               Arrayref of attributenames to extract on/off status for.
  Throws     : none
  Status     : Public
  Comments   :
  See Also   :

=cut

    sub extract_queryparams {
        my ($self,$value_of_param, $filterlist, $attributelist) = @_;
	
	# Default to empty lists of filters or attributes if not provided as args
	$filterlist    ||= [];
	$attributelist ||= [];

        # These are to be returned to the caller at the end
	
        $logger->debug("#### STARTING extract_queryparams ####");

        # Not much to do for the attribute list: just strip away the prefix and exclude
        # non-enabled (value 'off') checkboxes, checkbox proxy-parameters etc.
        my %values_of_attributefilter;  # which values are assigned to each attributefilter
        my @attribute_params_final;
        ATTRIBUTE:
        foreach my $attributename(@$attributelist) {
            next ATTRIBUTE if $attributename =~ /__checkbox\Z/xms;
            # This line unneccessary - if it's in the list, we want it!
            #next ATTRIBUTE if $value_of_param->{ $attributename } eq 'off';
                                
        	# Parse out attribute filter.  
	    	my ($filtername_prefix) = $attributename =~ /\A(\w+__attribute)\./xms;
	    	$filtername_prefix .= "filter."; 
	    	my ($datasetname) = $attributename =~ /\A(\w+?)__/xms;   

			# Remember attribute itself.            
            $attributename =~ s/\A\w+__attribute\.//xms;
	    	my $filtername = $filtername_prefix.$attributename;

			# Work out filter stuff.
            my $filtervalue = $value_of_param->{ $filtername };
            $logger->debug("Testing if attribute $attributename is an attributefilter");
            
            if ((not defined($filtervalue)) || $filtervalue eq q{}) {
            # if not found, try __list, __text, __text__file (and redirect file),
            # then update value accordingly.
            # it's especially tricky to grab some of the list-type filters, where the filtervalue
            # we have by now isn't the actual filter per se, but rather provides the name of the actual filter. The value
            # stored in another parameter (according to certain naming convention), so need to check if that
	    	# secondary param is present in the parameter-collection.
            my $real_value;
	    
            if($real_value = $value_of_param->{ $filtername.'__list' }) {
               # First case: boolean-list type, where the filter indicates which db-table column has the boolean flag
               $logger->debug("Modifying bool-list filter name/value pair $filtername=>$filtervalue to $filtervalue=>$real_value");
              # $filtername  = $filtervalue;# name of the actual filter (bool-list thing)
               $filtervalue = $real_value; # and the real value, stored in the secondary parameter
            }
            elsif($real_value = $value_of_param->{ $filtername.'__text__file' }) {
               # Second case: ID-list upload filter type, where the filter indicates against which db-table column
               # The list of uploaded identifiers should be matched. IDs can come from either textarea or uploaded file
                 if (ref($real_value) eq 'ARRAY') { $real_value = @$real_value[0]; }
			   $real_value =~ m/(.*)__file/;
               $real_value = $value_of_param->{$1}; # redirected value.               
               $logger->debug("Modifying ID-list filter name/value pair $filtername to $real_value (list from uploaded file)");
              # $filtername = $filtervalue;
               my @values = split(/[\n+\s+\,]+/, $real_value); # split paste-in text into a list of identifiers
               map { s/\A\s+//xms; s/\s+\z//xms; } @values;        # clean out leading & trailing spaces
               $filtervalue = \@values;
             }
            elsif($real_value = $value_of_param->{ $filtername.'__text' }) {
               # Second case: ID-list upload filter type, where the filter indicates against which db-table column
               # The list of uploaded identifiers should be matched. IDs can come from either textarea or uploaded file
               if (ref($real_value) eq 'ARRAY') { $real_value = @$real_value[0]; }
               $logger->debug("Modifying ID-list filter name/value pair $filtername to $real_value (list from textarea)");
              # $filtername = $filtervalue;
               my @values = split(/[\n+\s+\,]+/, $real_value); # split paste-in text into a list of identifiers
               map { s/\A\s+//xms; s/\s+\z//xms; } @values;        # clean out leading & trailing spaces
               $filtervalue = \@values;
             }
           }

            # We might have an empty list of values, so skip filter entirely if this is the  case
            #if($filtervalue eq q{}) {
            if ((not defined($filtervalue)) || $filtervalue eq q{}) {
                $logger->debug("Empty list of values for attributefilter '$filtername', so is not an attributefilter");

            	$logger->debug("Enabling attribute $attributename instead");
            	push @attribute_params_final, $attributename;
            
                next ATTRIBUTE;
            }
	    $logger->debug("#### $filtername HAS VALUE $filtervalue####");
	    
	    # clean out potential leading & trailing spaces and empty lines and whatnot
	    $filtervalue =~  s/\A[\s\n\r,]+//xms; 
	    $filtervalue =~  s/[\s\n\r,]\z//xms;
	    
            # Now that we know that this filter is enabled and has a valid value, figure out whether it's a single
            # value or list of values encoded in the cgi-lib format (\0 seperator), or simply an arrayref
            my @filtervalues = ref($filtervalue) eq 'ARRAY' ? @$filtervalue             # actual arrayref passed
                             : $filtervalue =~ /\0/         ? split("\0", $filtervalue) # CGI-style multi-value list-string
			     : $filtervalue =~ /[\n\r,]/    ? split(/[\n\r\s\,]+/, $filtervalue)
                             :                              ( $filtervalue )            # plain single value
			     ;
	    # Well, it still might be an empty upload-list or whatever, so let's check for that just in case
            if(@filtervalues == 0) {
                $logger->debug("Finished with an empty list of values for attributefilter '$filtername', so is not an attributefilter");

            	$logger->debug("Enabling attribute $attributename instead");
            	push @attribute_params_final, $attributename;
            
                next ATTRIBUTE;
            }         

            $logger->debug("Enabling attributefilter $attributename with values: '@filtervalues'");
            $values_of_attributefilter{ $datasetname }{ $attributename } = \@filtervalues;
        }
        
        # Process list of regular filters and their values
        my %values_of_filter;  # which values are assigned to each filter
        FILTER:
        foreach my $filtername (@$filterlist) {
	    $logger->debug("#### DEALING WITH $filtername ####");
            my $filtervalue = $value_of_param->{ $filtername };
            
            if ((not defined($filtervalue)) || $filtervalue eq q{}) {
            # if not found, try __list, __text, __text__file (and redirect file),
            # then update value accordingly.
            # it's especially tricky to grab some of the list-type filters, where the filtervalue
            # we have by now isn't the actual filter per se, but rather provides the name of the actual filter. The value
            # stored in another parameter (according to certain naming convention), so need to check if that
	    	# secondary param is present in the parameter-collection.
            my $real_value;
	    
            if($real_value = $value_of_param->{ $filtername.'__list' }) {
               # First case: boolean-list type, where the filter indicates which db-table column has the boolean flag
				if (ref($real_value) eq 'ARRAY') { 
	               # radio boolean makes an array of only/excluded in safari
                   $real_value = pop(@$real_value);
				}
				$filtervalue = $real_value; # and the real value, stored in the secondary parameter
				$logger->debug("Modifying bool-list filter name/value pair $filtername=>$filtervalue to $filtervalue=>$real_value");
              	# $filtername  = $filtervalue;# name of the actual filter (bool-list thing)
            }
            elsif($real_value = $value_of_param->{ $filtername.'__text__file' }) {
               # Second case: ID-list upload filter type, where the filter indicates against which db-table column
               # The list of uploaded identifiers should be matched. IDs can come from either textarea or uploaded file
               if (ref($real_value) eq 'ARRAY') { $real_value = @$real_value[0]; }
			   $real_value =~ m/(.*)__file/;
               $real_value = $value_of_param->{$1}; # redirected value.    
               $logger->debug("Modifying ID-list filter name/value pair $filtername to $real_value (list from uploaded file)");
              # $filtername = $filtervalue;
               my @values = split(/[\n+\s+\,]+/, $real_value); # split paste-in text into a list of identifiers
               map { s/\A\s+//xms; s/\s+\z//xms; } @values;        # clean out leading & trailing spaces
               $filtervalue = \@values;
             }
            elsif($real_value = $value_of_param->{ $filtername.'__text' }) {
               # Second case: ID-list upload filter type, where the filter indicates against which db-table column
               # The list of uploaded identifiers should be matched. IDs can come from either textarea or uploaded file
               if (ref($real_value) eq 'ARRAY') { 
               	#$real_value = @$real_value[0];
               	$real_value = "@{$real_value}"; 
               }
               $logger->debug("Modifying ID-list filter name/value pair $filtername to $real_value (list from textarea)");
              # $filtername = $filtervalue;
               my @values = split(/[\n+\s+\,]+/, $real_value); # split paste-in text into a list of identifiers
               map { s/\A\s+//xms; s/\s+\z//xms; } @values;        # clean out leading & trailing spaces
               $filtervalue = \@values;
             }
           }

           # preprocess filter name to get prefix.
	    my ($filtername_prefix) = $filtername =~ /\A(\w+__filter\.)/xms; # for later stripping
	    my ($datasetname) = $filtername =~ /\A(\w+?)__/xms; # for later stripping

            # We might have an empty list of values, so skip filter entirely if this is the  case
            #if($filtervalue eq q{}) {
            if ((not defined($filtervalue)) || $filtervalue eq q{}) {
                $logger->debug("Empty list of values ('') for filter '$filtername', skipping this filter");
                next FILTER;
            }
	    $logger->debug("#### $filtername HAS VALUE $filtervalue####");
	    
	    # clean out potential leading & trailing spaces and empty lines and whatnot
	    $filtervalue =~  s/\A[\s\n\r,]+//xms; 
	    $filtervalue =~  s/[\s\n\r,]\z//xms;
	    
            # Now that we know that this filter is enabled and has a valid value, figure out whether it's a single
            # value or list of values encoded in the cgi-lib format (\0 seperator), or simply an arrayref
            my @filtervalues = ref($filtervalue) eq 'ARRAY' ? @$filtervalue             # actual arrayref passed
                             : $filtervalue =~ /\0/         ? split("\0", $filtervalue) # CGI-style multi-value list-string
			     : $filtervalue =~ /[\n\r,]/    ? split(/[\n\r\s\,]+/, $filtervalue)
                             :                              ( $filtervalue )            # plain single value
			     ;
	    # Well, it still might be an empty upload-list or whatever, so let's check for that just in case
            if(@filtervalues == 0) {
                $logger->debug("Empty list of values for filter $filtername, skipping this filter");
                next FILTER;
            }

	    $filtername =~ s/$filtername_prefix//xms; # strip off prefix, if required
            $logger->debug("Adding values to filter $filtername: '@filtervalues'");
            $values_of_filter{ $datasetname }{ $filtername } = \@filtervalues;
        }
        
        return (\%values_of_filter, \@attribute_params_final, \%values_of_attributefilter);
    }

=head2 prepare_martquery
    
  Usage	     : my $query = $self->prepare_martquery({
                                         schema     => $schema_name,
					 filters    => {'hsapiens_gene_ensembl' => \%values_of_filter},
					 attributes => {'hsapiens_gene_ensembl' => \@attributes}
				     });

  Purpose    : Construct BioMart query with provided filters & attributes.
  Returns    : Reference to a BioMart::Query object
  Arguments  : Anonymous hash with the following arguments:
                schema     Name of virtual schema (defaults to 'default' schema).
                filters    Hashref where the keys are the names of datasets and 
                           the values are hashrefs of filter/value pairs (prepared
                           by extract_queryparams()).
                attributes Hashref where the keys are the names of datasets and 
                           the values are arrayrefs with attribute names (prepared
                           by extract_queryparams()).
                dataset    Name of dataset (only required if no filters or attributes
                           are being passed, typically to get total entrycount for dset).
  Throws     : BioMart::Exception::Configuration on errors from building the query
  Status     : Public
  Comments   :
  See Also   : extract_queryparams()

=cut

    sub prepare_martquery {
        my ($self, $args) = @_;
        $args->{schema} ||= 'default';
       
        # Get some necessary BioMart thingies set up. Note that an existing query can be passed as
	# an argument and modified with additional filters & attributes.
        $logger->debug("Getting dataset $args->{dataset} in schema $args->{schema} from registry");
        my $mart_registry = $self->get_mart_registry();
        my $query;
	if( defined($args->{query}) ) {
	    $logger->debug("Using provided query object");
	    $query = $args->{query};
	}
	else {
	    $logger->debug("Creating new query from scratch");
	    $query =  BioMart::Query->new(registry          => $mart_registry,
					  virtualSchemaName => $args->{ 'schema' });
	}
	
	my @datasets_in_query = @{ $query->getDatasetNames };
	foreach my $dataset_name (keys %{ $args->{ 'attributes' } }) {
	    my $dataset   = $mart_registry->getDatasetByName($args->{ 'schema' }, $dataset_name);
	    my $dataset_conf  = $dataset->getConfigurationTree('default');

	    # Process any attributes present
	    $logger->debug("Processing attributes from dataset $args->{schema}\.$dataset_name");	    
	    ATTRIBUTE:
	    $query->setDataset($dataset_name);
	    foreach my $attributename(@{ $args->{ 'attributes' }->{ $dataset_name } }) {
		$logger->debug("Enabling attribute $attributename");
			if(defined $attributename)
			{	$query->addAttribute($attributename, 'default');
			}
	    }
	}
	    
	foreach my $dataset_name (keys %{ $args->{ 'attributefilters' } }) {
	    my $dataset   = $mart_registry->getDatasetByName($args->{ 'schema' }, $dataset_name);
	    my $dataset_conf  = $dataset->getConfigurationTree('default');

	    # Process any attribute filters present
	    $logger->debug("Processing attributefilters from dataset $args->{schema}\.$dataset_name");	    
	    ATTRIBUTEFILTER:
	    $query->setDataset($dataset_name);
	    while(my ($attributename,$filtervalues) = each(%{ $args->{ 'attributefilters' }->{ $dataset_name } })) {
		$logger->debug("Enabling attributefilter $attributename to query, setting values to ".join('|',@$filtervalues) );
		$query->addAttributeFilter($attributename, $filtervalues, 'default');
	    }
	}
	
	foreach my $dataset_name (keys %{ $args->{ 'filters' } }) {
	    my $dataset   = $mart_registry->getDatasetByName($args->{ 'schema' }, $dataset_name);
	    my $dataset_conf  = $dataset->getConfigurationTree('default');

	    # Process any filters we may have 
	    $logger->debug("Processing filters from dataset $args->{schema}\.$dataset_name");	    
	    FILTER:
	    $query->setDataset($dataset_name);
	    while(my ($filtername,$filtervalues) = each(%{ $args->{ 'filters' }->{ $dataset_name } })) {
		$logger->debug("Enabling filter $filtername to query, setting values to ".join('|',@$filtervalues) );
		$query->addFilter($filtername, $filtervalues, 'default'); # NOTE TO SELF: add interface-param here		
	    }
	}

        # In case no datasets are set, need to explicitly set schema + dataset properties for query
        if( @{ $query->getDatasetNames() } == 0 ) {
	    exists($args->{dataset}) 
		|| BioMart::Exception::Query->throw("Can't build query with no filters or attributes unless explicitly receiving the 'dataset' argument explicitly");
            $logger->debug("No dataset name for query, explicitly setting to $args->{dataset}");
            $query->addDatasetName($args->{dataset},'default');
        }
	return $query;	
    }
    
=head2 handleURLRequest

  Usage      : 
  Purpose    : handles URL requests and populates the session object accordingly
  Returns    : Nothing
  Arguments  : URL params
  Throws     : BioMart::Exception::* exceptions not caught somewhere deeper.
  Status     : Public
  Comments   : This method is called by handle_request.
  See Also   :

=cut

sub handleURLRequest
{
	my ($self, $session) = @_;
	my $registry = $self->get_mart_registry();
	
	eval {

		BioMart::Exception::Usage->throw("please specify both VIRTUALSCHEMANAME and ATTRIBUTES in URL in correct format")
		if (!$session->param("url_VIRTUALSCHEMANAME") || !$session->param("url_ATTRIBUTES"));

	my $schema = $session->param("url_VIRTUALSCHEMANAME");
	my @DS;
	my $datasets;
	my @attributes;
	my @attributeList = split (/\|/, $session->param("url_ATTRIBUTES") );


	foreach(@attributeList)
	{
		my @temp_portions = split (/\./, $_);
		# <DatasetName>.<Interface>.<AttributePage>.<AttributeInternalName>."<Optional: attributevalue incase its an AttributeFilter>"
		if ($temp_portions[4]) {
			$temp_portions[4] =~ s/\"//g; # remove double quotes
			$datasets->{$temp_portions[0]}->{$temp_portions[1]}->{'ATTRIBUTES'}->{$temp_portions[2].'.'.$temp_portions[3]}  = $temp_portions[4];
		}
		else{
			$datasets->{$temp_portions[0]}->{$temp_portions[1]}->{'ATTRIBUTES'}->{$temp_portions[2].'.'.$temp_portions[3]}  = "NULL";
		}			
		
		# adding dataset names in array to maintain the order of datasets for query execution
		my $dsFlag = 0;
		foreach my $dsExists (@DS){
			$dsFlag = 1 if($dsExists eq $temp_portions[0])
		}
		push @DS, $temp_portions[0] if (!$dsFlag);
	}
	
	my @filterList = split (/\|/, $session->param("url_FILTERS") ) if $session->param("url_FILTERS");
	foreach(@filterList)
	{
		my @temp_portions = split (/\./, $_,5); # strictly splitting into five as the values in ""quotes might have dots e.g human band p36.33
		# <DatasetName>.<Interface>.<FilterPAGE>.<FilterInternalName>."<commaSeperatedValues>"
		$temp_portions[4] =~ s/\"//g; # remove double quotes
		$datasets->{$temp_portions[0]}->{$temp_portions[1]}->{'FILTERS'}->{$temp_portions[2].'.'.$temp_portions[3]} = $temp_portions[4];
	}		
	

	BioMart::Exception::Usage->throw("You cannot have zero OR more than 2 datasets")
		if (scalar (@DS) == 0 || scalar (@DS) > 2);

	
	##### START SETTNG THE SESSSION manually before the handle requests starts it business
	#----------------------------------- SCHEMA, DB, DS
	$session->param('schema', $schema);
	$session->param('dataset', \@DS );
	foreach my $vSchema (@{$registry->getAllVirtualSchemas()}) {
		if ($vSchema->name eq $schema){
			foreach my $mart (@{$vSchema->getAllMarts()}) {					
				foreach my $dataset (@{$mart->getAllDatasets()}) {
					if ($dataset->name eq $DS[0]) {	#use first DS name for DSPanel to set
						$session->param('dataBase', $mart->displayName); ## should always come here to set session DB naem
					}
				}
			}
		}
	}

	#print "**SCHEMA: ", $session->param('schema');
	#print "**DB: ", $session->param('dataBase');
	#print "**DS: ", $session->param('dataset');
	#--------------------------------------------------
	#----------------------------------- query Params
	# ATTRIBUTES
	my $atts;
	foreach my $dsName(keys %$datasets) {
		foreach my $interface(keys %{$datasets->{$dsName}}) {
			foreach my $ATTRIBUTES (keys %{$datasets->{$dsName}->{$interface}}) {
				if ($ATTRIBUTES eq 'ATTRIBUTES') {
					foreach my $attTreeAttribute (keys %{$datasets->{$dsName}->{$interface}->{'ATTRIBUTES'}}) {
						# set AttTree
						my @portions = split(/\./,$attTreeAttribute);
						$session->param($dsName.'__attributepage', $portions[0]) if (!$session->param($dsName.'__attributepage'));
						
						# make a AttName ds__AttTree__attribute.internalName   FOR __attributelist
						my $attributeString = $dsName.'__'.$portions[0].'__attribute'.'.'.$portions[1];
						push @{$atts->{$dsName}}, $attributeString;
						
						# it has a value- assuming its attributeFilter, then add DS_attPage_attributefilter.internalName = 'value'
						my $val = $datasets->{$dsName}->{$interface}->{'ATTRIBUTES'}->{$attTreeAttribute};
						if ($val ne "NULL")	{
							$attributeString =~ s/attribute\./attributefilter\./;
							$session->param($attributeString, $val);								
						}
					}
				}
			}			
		}
		# adding _attributelist foreach dataset
		my $currentPage = $session->param($dsName.'__attributepage');
		$session->param($session->param('schema').'____'.$dsName.'__'.$currentPage.'__attributelist', \@{$atts->{$dsName}} );
	}
	
	# FILTERS
	my $filts;
	my $filterCollections;
	foreach my $dsName(keys %$datasets) {
		foreach my $interface(keys %{$datasets->{$dsName}}) {
			foreach my $FILTERS (keys %{$datasets->{$dsName}->{$interface}}) {
				if ($FILTERS eq 'FILTERS') {
					foreach my $filtTreeFilter (keys %{$datasets->{$dsName}->{$interface}->{'FILTERS'}}) {

						my @portions = split(/\./,$filtTreeFilter);
						# make a FiltName ds__filter.internalName FOR __filterlist
						my $filterString = $dsName.'__filter'.'.'.$portions[1];
						push @{$filts->{$dsName}}, $filterString;
						
						# finding out filter's value/values
						my $val = $datasets->{$dsName}->{$interface}->{'FILTERS'}->{$filtTreeFilter};
						my @temp_values;
						foreach my $val1 (split (/\,/, $val) ) {
							push @temp_values, $val1;
						}
						
						if ($self->filterDisplayType($dsName, $interface, $portions[1], $session) =~ m/(.*?)\.?container__LIST/ ) {
							# original filterName as the one received is just options Name
							# add filter with value  <ds>__filter.<filterInternalName>__list = array of values
							my $realFilterName = $1;
							$session->param($dsName.'__filter.'.$1.'__list', $val) if ($1); # for display of radio buttons
							if ($1 && !$session->param($dsName.'__filter.'.$1))
							{
								$session->param($dsName.'__filter.'.$1, $portions[1]);
							}
							# to handle MultiSelect followed by radio buttons
							elsif ($1 && $session->param($dsName.'__filter.'.$1))
							{
								my @temp_arr;
								push @temp_arr, $session->param($dsName.'__filter.'.$1);
								push @temp_arr, $portions[1] ;
								$session->clear($dsName.'__filter.'.$1);
								$session->param($dsName.'__filter.'.$1, \@temp_arr);
								#print Dumper($session->param($dsName.'__filter.'.$1)), " GO AWAY ";
							}
							
							# add OptionName (thats the one which comes in URL) with value just as in XML query  
							# <ds>__filter.<OptionInternalName>__list = array of values
							$filterString .= '__list';
						}
						elsif ($self->filterDisplayType($dsName, $interface, $portions[1], $session) =~ m/(.*?)\.?container__TEXT/ ) {

							# original filterName as the one received is just options Name
							# add filter with value  <ds>__filter.<filterInternalName>__text = array of values
							my $realFilterName = $1;
							$session->param($dsName.'__filter.'.$1.'__text', $val) if ($1); # for display of textBox
							$session->param($dsName.'__filter.'.$1, $portions[1]) if ($1); # for display of select Menu

							# add OptionName (thats the one which comes in URL) with value just as in XML query  
							# <ds>__filter.<OptionInternalName>__list = array of values
							$filterString .= '__text';
						}
						else {
							# add filter with value  <ds>__filter.<filterInternalName> = array of values
						}
						
						if (scalar (@temp_values) > 1) { $session->param($filterString, \@temp_values); }
						else { $session->param($filterString, $temp_values[0]);	}
						
						# find filterCollectionName for ds__filtercollections
						my $collectionName = $self->getFilterCollectionName($dsName, $interface, $portions[1], $session);
						my $filtCollectionString = $dsName.'__filtercollection.'.$collectionName;
						$filterCollections->{$dsName}->{$filtCollectionString}++; # counting for debugging only
					}
				}
			}			
		}
		# adding __filterlist foreach dataset
		$session->param($session->param('schema').'____'.$dsName.'__filterlist', \@{$filts->{$dsName}} );
		
		# adding __filtercollections
		my @collectionsArray;
		foreach (keys %{$filterCollections->{$dsName}}) {
			push @collectionsArray, $_;
		}
		$session->param($dsName.'__filtercollections', \@collectionsArray);
	}
	#--------------------------------- Setting visible sections of attribute pages radio buttons
	#--------------------------------- and results pages nad etc etc
	foreach my $dsName(keys %$datasets) {
		foreach my $interface(keys %{$datasets->{$dsName}}) {
			foreach my $ATTRIBUTES (keys %{$datasets->{$dsName}->{$interface}}) {
				if ($ATTRIBUTES eq 'ATTRIBUTES') {
					foreach my $attTreeAttribute (keys %{$datasets->{$dsName}->{$interface}->{'ATTRIBUTES'}}) {
						my @portions = split(/\./,$attTreeAttribute);
						$session->param($dsName.'__attributepages__current_visible_section', $dsName.'__attributepanel__'.$portions[0])
							if (!$session->param($dsName.'__attributepages__current_visible_section'));
					}
				}
			}
		}
	}

	# URL_REQUEST is in addition to resultsButton, so at the end of this file
	# when we process main.tt, we donot consider this request as AJAX request
	# and print the whole page instead of returning results only
	$session->param('URL_REQUEST', '1');
	$session->param('exportView_outputformat', 'tsv');
	$session->param('preView_outputformat', 'html');
	$session->param('datasetmenu_3', $DS[0]);
	# setting the visible main panel and summary panel branch, defaults to resutls panel as in 0.6
	if ($session->param('url_VISIBLEPANEL') && $session->param('url_VISIBLEPANEL') eq 'mainpanel' ) {
		$session->param("mart_mainpanel__current_visible_section", $DS[0].'__infopanel');
		$session->param("summarypanel__current_highlighted_branch", $DS[0].'__summarypanel_datasetbranch');
	}
	elsif ($session->param('url_VISIBLEPANEL') && $session->param('url_VISIBLEPANEL') eq 'attributepanel' ) {
		$session->param("mart_mainpanel__current_visible_section", $DS[0].'__attributepanel');
		$session->param("summarypanel__current_highlighted_branch", $DS[0].'__summarypanel_attributebranch');
	}
	elsif ($session->param('url_VISIBLEPANEL') && $session->param('url_VISIBLEPANEL') eq 'filterpanel' ) {
		$session->param("mart_mainpanel__current_visible_section", $DS[0].'__filterpanel');
		$session->param("summarypanel__current_highlighted_branch", $DS[0].'__summarypanel_filterbranch');
	}
	elsif ($session->param('url_VISIBLEPANEL') && $session->param('url_VISIBLEPANEL') eq 'linkpanel' ) {
		if ($DS[1]) {
			$session->param("mart_mainpanel__current_visible_section", $DS[1].'__infopanel');
			$session->param("summarypanel__current_highlighted_branch", $DS[1].'__summarypanel_datasetbranch');
		}
		else { # if no 2nd DS, then jump to link panel
			$session->param("mart_mainpanel__current_visible_section", 'add_linked_datasetpanel');
			$session->param("summarypanel__current_highlighted_branch", 'show_linked_datasetpanel');
		}
	}
	elsif ($session->param('url_VISIBLEPANEL') && $session->param('url_VISIBLEPANEL') eq 'linkattributepanel' ) {
		if ($DS[1]) {
			$session->param("mart_mainpanel__current_visible_section", $DS[1].'__attributepanel');
			$session->param("summarypanel__current_highlighted_branch", $DS[1].'__summarypanel_attributebranch');
		}
		else { # if no 2nd DS, then jump to link panel
			$session->param("mart_mainpanel__current_visible_section", 'add_linked_datasetpanel');
			$session->param("summarypanel__current_highlighted_branch", 'show_linked_datasetpanel');
		}
	}
	elsif ($session->param('url_VISIBLEPANEL') && $session->param('url_VISIBLEPANEL') eq 'linkfilterpanel' ) {
		if ($DS[1]) {
			$session->param("mart_mainpanel__current_visible_section", $DS[1].'__filterpanel');
			$session->param("summarypanel__current_highlighted_branch", $DS[1].'__summarypanel_filterbranch');
		}
		else { # if no 2nd DS, then jump to link panel
			$session->param("mart_mainpanel__current_visible_section", 'add_linked_datasetpanel');
			$session->param("summarypanel__current_highlighted_branch", 'show_linked_datasetpanel');
		}
	}
	else { # default case, jump to results panel
		$session->param('resultsButton', '1');
		$session->param("mart_mainpanel__current_visible_section", "resultspanel");		
	}
	
	#--------------------------------------------------
	
	$session->clear("url_VIRTUALSCHEMANAME");
	$session->clear("url_ATTRIBUTES");
	$session->clear("url_FILTERS");
	$session->clear("url_VISIBLEPANEL");
	}; #end of eval block
	
	my $ex;
 	if ( $ex = Exception::Class->caught() )
	{
    		my $errmsg = $ex->error();
		$logger->debug("URL Access error: ".$errmsg);
			UNIVERSAL::can($ex, 'rethrow') ? $ex->rethrow : die $ex;
		return 'exit'; 
	}	
}
=head2 getFilterCollectionName
  Usage      : 
  Purpose    : helper method to handleURLRequest
  Returns    : 
  Arguments  : 
  Throws     : 
  Status     : 
  Comments   : 
  See Also   :

=cut

sub getFilterCollectionName
{
	my ($self, $dsName, $interface, $filterName, $session) = @_;
	
	my $registry = $self->get_mart_registry();
	foreach my $vSchema (@{$registry->getAllVirtualSchemas()}) {
		if ($vSchema->name eq $session->param('schema')){
			foreach my $mart (@{$vSchema->getAllMarts()}) {
				foreach my $dataset (@{$mart->getAllDatasets()}) {
					if ($dataset->name eq $dsName) {	#use first DS name for DSPanel to set
						## find the fileterCollectionName now
						foreach my $configurationTree (@{$dataset->getAllConfigurationTrees()}) {
						    	foreach my $filterTree (@{$configurationTree->getAllFilterTrees()}) {
								foreach my $group(@{$filterTree->getAllFilterGroups()}) {
									foreach my $collection (@{$group->getAllCollections()}) {
										foreach my $filter (@{$collection->getAllFilters()}) {
											if ($filter->name eq $filterName)
											{
												#print "Collection FOUND through Filters : ", $collection->name;
												return $collection->name;
											}
										}
										# now look into options of filters - case: 'container' type fitler 
										foreach my $filter (@{$collection->getAllFilters()}) {
											if ($filter->getAllOptions()) {
												foreach ( @{$filter->getAllOptions()} ) {	
													if ($_->name eq $filterName)
													{
														#print "Collection FOUND through Options : ", $collection->name;
														return $collection->name;
													}
												}
											}
										}										
									}
								}
							}
						}			
					}
				}
			}
		}
	}
}
=head2 filterDisplayType
  Usage      : 
  Purpose    : helper method to handleURLRequest
  Returns    : 
  Arguments  : 
  Throws     : 
  Status     : 
  Comments   : 
  See Also   :

=cut

sub filterDisplayType
{
	my ($self, $dsName, $interface, $filterName, $session) = @_;
	my $registry = $self->get_mart_registry();
	foreach my $vSchema (@{$registry->getAllVirtualSchemas()}) {
		if ($vSchema->name eq $session->param('schema')){
			foreach my $mart (@{$vSchema->getAllMarts()}) {
				foreach my $dataset (@{$mart->getAllDatasets()}) {
					if ($dataset->name eq $dsName) {	#use first DS name for DSPanel to set
						foreach my $configurationTree (@{$dataset->getAllConfigurationTrees()}) {
						    	foreach my $filterTree (@{$configurationTree->getAllFilterTrees()}) {
								foreach my $group(@{$filterTree->getAllFilterGroups()}) {
									foreach my $collection (@{$group->getAllCollections()}) {
										foreach my $filter (@{$collection->getAllFilters()}) {
											if ($filter->name eq $filterName)	{
												if($filter->displayType  eq 'container')	{
													foreach ( @{$filter->getAllOptions()} ) {
														#print "FOUND in Filters : ", $filter->name;
														return "container__LIST" if ($_->filter()->displayType() eq 'list');
														return "container__TEXT" if ($_->filter()->displayType() eq 'text');																}													
												}												
											}
										}
										# find in the options
										foreach my $filter (@{$collection->getAllFilters()}) {
											if ($filter->getAllOptions()) {
												foreach ( @{$filter->getAllOptions()} ) {	
													if ($_->name eq $filterName && $filter->displayType  eq 'container')	{
														#print "FOUND in options : ", $_->name;	
														return $filter->name.".container__LIST" 
															if ($_->filter()->displayType() eq 'list');
														return $filter->name.".container__TEXT" 
															if ($_->filter()->displayType() eq 'text');				
													}
												}
											}
										}										
									}
								}
							}
						}			
					}
				}
			}
		}
	}
}

=head2 getURLBookmark

  Usage      : $self->getURLBookmark($registry, $xml, $session);
  Purpose    : handles xml equivalent of the query
  Returns    : url_string
  Arguments  : registryObject, QueryObject, session
  Throws     : BioMart::Exception::* exceptions not caught somewhere deeper.
  Status     : Public
  Comments   : This method is called by SELF.
  See Also   :

=cut

sub getURLBookmark
{

	my ($self, $registry, $xml, $session) = @_;
	
	my ($url_string, $url_vs, $url_datasetName, $url_interface, $url_attPage, $url_atts, $url_filtPage, $url_filts, $url_visiblePanel);
	my @DS;
	my @attributes;
	my $i=0;
	my $config = XMLin($xml, forcearray=> [qw(Query Dataset Attribute 
		      ValueFilter BooleanFilter 
		      Filter Links)], keyattr => []);
       
	$url_vs =  $config->{'virtualSchemaName'} || 'default';

	$url_string = "?VIRTUALSCHEMANAME=".$url_vs;
	$url_atts = "&ATTRIBUTES=";
	$url_filts = "&FILTERS=";
	$url_visiblePanel = "&VISIBLEPANEL=";
	$url_attPage = "_ATT_PAGE_";
	$url_filtPage = "_FILT_PAGE_";
	
	# lets work out atts and filters
	foreach my $url_dataset (@{$config->{'Dataset'}}) {
		$url_interface = $url_dataset->{'interface'} || 'default';
		$url_datasetName = $url_dataset->{'name'};
		$DS[$i++] = $url_datasetName;
		
		my $datasetObj = $registry->getDatasetByName($url_vs, $url_dataset->{'name'});
		if (!$datasetObj){
			BioMart::Exception::Usage->throw ("WITHIN Virtual Schema : $url_vs, Dataset ".$url_dataset->{'name'}." NOT FOUND");
		}
		my $confTree = $registry->getDatasetByName($url_vs, $url_dataset->{'name'})->getConfigurationTree($url_interface);
		if (!$confTree){
			BioMart::Exception::Usage->throw ("Cannot find Configuration Tree for $url_vs.".$url_dataset->{'name'});
		}

	
		# work out atts
		foreach my $attributeNode (@{$url_dataset->{'Attribute'}}) {
			$url_atts = $url_atts.$url_datasetName.'.'.$url_interface.'.'.$url_attPage.'.'.$attributeNode->{'name'}.'|';
			push @attributes, $attributeNode->{'name'};
		}

		# work out filts
		foreach my $filterNode (@{$url_dataset->{'Filter'}}) {
			# test if its an attributeFilter
			my $attFilt;
			foreach my $attPage (@{$confTree->getAllAttributeTrees()}) {
				$attFilt = $attPage->getFilterByName($filterNode->{'name'});
				if ($attFilt && $attFilt->isa("BioMart::Configuration::ValueFilter")){
					$url_atts = $url_atts.$url_datasetName.'.'.$url_interface.'.'.$url_attPage.'.'.$filterNode->{'name'}.'."'.$filterNode->{'value'}.'"|';
					push @attributes, $filterNode->{'name'};
					last;
				}
			}
			if(!$attFilt){ # not an attributeFilter - simple Filter
				if (defined $filterNode->{'excluded'}){
					$url_filts = $url_filts.$url_datasetName.'.'.$url_interface.'.'.$url_filtPage.'.'.$filterNode->{'name'}.'.'."excluded".'|' 
						if ($filterNode->{'excluded'} eq '1');
					$url_filts = $url_filts.$url_datasetName.'.'.$url_interface.'.'.$url_filtPage.'.'.$filterNode->{'name'}.'.'."only".'|' 
						if ($filterNode->{'excluded'} eq '0');
				}
				elsif  (defined $filterNode->{'value'}){
				$url_filts = $url_filts.$url_datasetName.'.'.$url_interface.'.'.$url_filtPage.'.'.$filterNode->{'name'}.'."'.$filterNode->{'value'}.'"|';
				}
				else {
					BioMart::Exception::Usage->throw ("Filter ".$filterNode->{'name'}." INVALID, FILTER NEEDS 'excluded' or 'value' attribute");
				}
			}
		}
		
		# work out attributePage
		# not finding out from session as this function is also called from handleXMLRequest, so need
		# to find out attPage from library
		# (NO) my @attPageUnits = split (/__/, $session->param($url_datasetName.'__attributepages__current_visible_section'));
		# (NO) $url_attPage = $attPageUnits[2];
		foreach my $attPage (@{$confTree->getAllAttributeTrees()}) {
			my $dirtyFlag = 1;
			foreach my $attName (@attributes) {
				my $attObj = $attPage->getAttributeByName($attName);
				if (!$attObj) {
					$attObj = $attPage->getFilterByName($attName);
				}
				$dirtyFlag = 0 if (!$attObj); # this cant be the desired attPage
			}
			if ($dirtyFlag == 1) { # means all atts were found on this attPage - good
				$url_attPage = $attPage->name();
				last;
			}
		}

		# work out filterPage
		# unfortunately, there are no signs of filterPageName in session/HTML,
		# need to find out from library with an assumption that there is ONLY ONE filterPage set with hideDisplay=false/""
		foreach my $filterPage (@{$confTree->getAllFilterTrees()}){
			$url_filtPage = $filterPage->name() if ($filterPage->hideDisplay ne 'true');
		}
		
		# substitute the attPage and filtPage Tags
		$url_atts =~ s/_ATT_PAGE_/$url_attPage/g;
		$url_filts =~ s/_FILT_PAGE_/$url_filtPage/g;				
	}
	# lets work out visible panel
	if ($session->param("mart_mainpanel__current_visible_section") eq $DS[0].'__infopanel') {
		$url_visiblePanel .= 'mainpanel';
	}
	elsif ($session->param("mart_mainpanel__current_visible_section") eq $DS[0].'__attributepanel') {
		$url_visiblePanel .= 'attributepanel';
	}
	elsif ($session->param("mart_mainpanel__current_visible_section") eq $DS[0].'__filterpanel') {
		$url_visiblePanel .= 'filterpanel'
	}
	elsif ($DS[1] && $session->param("mart_mainpanel__current_visible_section") eq $DS[1].'__infopanel') {
		$url_visiblePanel .= 'linkpanel';
	}
	elsif ($DS[1] && $session->param("mart_mainpanel__current_visible_section") eq $DS[1].'__attributepanel') {
		$url_visiblePanel .= 'linkattributepanel';
	}
	elsif ($DS[1] && $session->param("mart_mainpanel__current_visible_section") eq $DS[1].'__filterpanel') {
		$url_visiblePanel .= 'linkfilterpanel';
	}

	elsif ($session->param("mart_mainpanel__current_visible_section") eq 'add_linked_datasetpanel') {
		$url_visiblePanel .= 'linkpanel';
	}
	else { # default case, jump to results panel
		$url_visiblePanel .= "resultspanel";
	}

	# chop only if there is any att/filt, otherwise no point chopping off =
	chop($url_atts) if ($url_atts ne "&ATTRIBUTES=");
	chop($url_filts) if ($url_filts ne "&FILTERS=");
		
	$url_string .= $url_atts;
	$url_string .= $url_filts;
	$url_string .= $url_visiblePanel;
	return $url_string;

}

=head2 handleXMLRequest

  Usage      : $self->handleXMLRequest($session, $url_string);
  Purpose    : handles xml equivalent of the query
  Returns    : none
  Arguments  : session, url_string 
  Throws     : BioMart::Exception::* exceptions not caught somewhere deeper.
  Status     : Public
  Comments   : This method is called by SELF.
  See Also   :

=cut

sub handleXMLRequest
{
	my ($self, $session, $url_string) = @_;
	$url_string =~ m/.*?VIRTUALSCHEMANAME=(.*?)\&ATTRIBUTES=(.*?)\&FILTERS=(.*?)\&VISIBLEPANEL=(.*)/;
	$session->param("url_VIRTUALSCHEMANAME", $1);
	$session->param("url_ATTRIBUTES", $2);
	if ($3) {	$session->param('url_FILTERS', $3); }
	else {	$session->clear("url_FILTERS"); }
	if ($4) {	$session->param('url_VISIBLEPANEL', $4); }
	else {	$session->clear("url_VISIBLEPANEL"); }
	
	$session->clear("url_XML");

}

=head2 handle_request

  Usage      : $bmweb->handle_request(CGI->new());
  Purpose    : Main method of class, handles incoming CGI-requests 
  Returns    : Nothing
  Arguments  : CGI object representing the request.
  Throws     : BioMart::Exception::* exceptions not caught somewhere deeper.
  Status     : Public
  Comments   : This method is called by the skeleton martview script.
  See Also   :

=cut

sub handle_request {
	my ($self, $CGI) = @_;
	
	my $qtime = time();
	my $registry = $self->get_mart_registry();
	my $confPATH = $self->get_conf_Dir();
	$self->set_errstr(''); # Reset errstring, might be some leftover from previous request.	

	# Retrieve session information
	my $session = $self->restore_session($CGI) || return;	    
    
	# Unset any validation errors.
	$session->clear("__validationError");

	my $form_action = $CGI->url(-absolute => 1) . '/' . $session->id();
	$logger->is_debug() 
	    and $logger->info("Incoming CGI-params:\n",Dumper(\%{$CGI->Vars()}));
		
	#------------------------------------------------------------------------
	# TO HANDLE URL REQUEST with XML Query, it populates the minimal session,
	# to invoke URL API's 'IF' statement right after
	#------------------------------------------------------------------------
	if($session->param("url_XML"))
	{	$self->handleXMLRequest($session,
				$self->getURLBookmark($registry, $session->param("url_XML"), $session));		
	}
	#------------------------------------------------------------------------
	# TO HANDLE URL REQUEST specially for ensembl ContigView etc etc
	# testing if its  a URL request, then need to temper the session object 
	# to make it look alike of URL request		
	#------------------------------------------------------------------------
	if($session->param("url_VIRTUALSCHEMANAME") ||  $session->param("url_ATTRIBUTES"))
	{	my $returnVal = $self->handleURLRequest($session);
		return if ($returnVal eq 'exit'); ## exception thrown	
	}
	
	#------------------------------------------------------------------------
	# if its a count/Results request, only save the session, and go back sending
	# nothing back to the target = 'hiddenIFrame'
	# for javascript to access the updated session, the form needs to be submitted
	# and the target should be some sort of dummyTarget so the actual window stays
	# as it was with out getting updated
	#------------------------------------------------------------------------
	my $returnaAfterSave = 0;
	if (($CGI->Vars()->{'countButton'}) && $CGI->Vars()->{'countButton'} eq '5')
	{	
		$CGI->Vars()->{'countButton'} = '0';
		$returnaAfterSave = 1;
		## sending the results back in HTML formatting with html, body div tags is important
		## otherwise Safari doesnt call onload() of hiddenIFrame
		print $CGI->header();
		print "<html><body><div id =\"countDivIFrameId\" style=\"display:none;\">ToCountHiddenIFrame</div></body></html>";
	}
	
	if (($CGI->Vars()->{'resultsButton'}) && $CGI->Vars()->{'resultsButton'} eq '5')
	{	
		$CGI->Vars()->{'resultsButton'} = '0';
		$returnaAfterSave = 1;
		## sending the results back in HTML formatting with html, body div tags is important
		## otherwise Safari doesnt call onload() of hiddenIFrame
		print $CGI->header();
		print "<html><body><div id =\"resultsDivIFrameId\" style=\"display:none;\">ToResultsHiddenIFrame</div></body></html>";
	}
	
	# Save parameters in this request to session, where they are combined with other
	# parameters from (potential) previous requests. Combined parameters are required
	# from here on, to build the full Mart query and more.
	$self->save_session($session, $CGI);
	return if ($returnaAfterSave);
	
	# determine if its a count request by JS	
	$session->param('countButton', '1')  if ($CGI->self_url() =~ m/__countByAjax\z/) ;
	$session->param('resultsButton', '1')  if ($CGI->self_url() =~ m/__resultsByAjax\z/) ;
	
	# Galaxy, we set do_export to 1 and galaxy sets the following 2, but
	# when we set resultsButton=1, galaxy doesnt forward this to us. so
	# lets do the following
	# e.g Galaxy sends us: OUR_URL/sessionIDdo_export=1&_export=1&GALAXY_URL=0
	if (!$session->param('GALAXY_URL') && ($session->param('_export') && $session->param('_export') eq '1') ) {
		$session->param('resultsButton', '1');
	}
	
	my( $def_schema, $def_db, $def_ds, $def_ds_OBJ);
	my $reverseName = 0;# Incase of Compara Menus, determines whether its a dataset as in DB or its a dataste with reverse naming convention	
	#======================================
	#print $session->param("summarypanel__current_highlighted_branch");
	#print " == ", $session->param("mart_mainpanel__current_visible_section");
	##-------- NOTE - 1A	
	##-------- this is the case when schema/DB menus are triggered. dsname is removed from session and we receive the
	##-------- following values for focus panels. better remove them so as to make this work like very first run.
	##-------- in case dataset menu (single name DS's menu not Compara) are triggered, they remove and add the dsname from
	##-------- script, so that doesnt cause any trouble. Some more complexity is 'else' below when we have compara
	##-------- splitted name multi menus. in that case we donot remove datasetName though its not of any use, but keep it 
	##-------- to direct it to correct else, where clear focus sections params from sessions and add the ones with
	##-------- correct and updated dsname
	##-------- hint: where ever we have [%session->param(somehting)%], this gets replaced not just on first parse
	##-------- but the moment session's value of param changes, this changes magically. 
	if (($session->param("mart_mainpanel__current_visible_section") && 
			$session->param("mart_mainpanel__current_visible_section") eq "__infopanel")
			|| ($session->param("summarypanel__current_highlighted_branch") && 
				$session->param("summarypanel__current_highlighted_branch") eq "__summarypanel_datasetbranch"))
	{
		$session->clear("mart_mainpanel__current_visible_section");
		$session->clear("summarypanel__current_highlighted_branch");
	}
	
#----------------------------------------------------------------------------
#----------------------------------------------------------------------------
	#print "SCHEMA: ", $session->param('schema'), "<br/>DB: ", $session->param('dataBase'), "<br/>DATASET: ", $session->param('dataset');
	$session->clear('newQuery');
	my %js_datasetpanel_sessions_values = ();
	my @schemas;
	my @database_names;
	my @datasets;
	my %build_errors;
	my %js_pushactions_of_datasetmenu = ();
	my $default_dataset;
	my @datasetUnits;
	my $unitsHash = ();
	my $multiMenuDS = 0;
	my $TAG_path;
	my	$dbName;
	my $result_string;
	my @dataset_names_in_query = ();
	my %entrycount_of_dataset;
	my %filtercount_of_dataset;
	my $preView_formatter_name;
	my $exportView_formatter_name;
	my $noFilter = "";
	my $countStringForJS="";
	my $all_formatters="";
	my $exceptionFlag=0;
	my %location_path = $self->getSettings('httpdSettings');
	$TAG_path = $location_path{'location'};

	my $schemas = $registry->getAllVirtualSchemas();
	SCHEMA:
	foreach my $schema(@$schemas) {
		push(@schemas, $schema);
		my $schema_name = $schema->name();
	  	my $databases = $registry->getAllDatabaseNames($schema_name, 1);
     	DATABASE:
	  	foreach my $database_name(@$databases) {
	    	$multiMenuDS = 0;
	    	$unitsHash = ();
			my %defDSHash = ();	    	
			push @database_names, $database_name;
			my $schema__dbName = $schema_name.'____'.$database_name;
			# Add this database to pushaction-hash
			push(@{ $js_pushactions_of_datasetmenu{ 'schema' }->{ $schema_name }->{ 'databasemenu' } }, [$schema__dbName, $database_name] );
			my $datasets = $registry->getAllDataSetsByDatabaseName($schema_name, $database_name, 1);
			my $last_dataset;
	     	DATASET:	     	
			#foreach my $dataset_name(sort @$datasets) {
			foreach my $dataset_name(@$datasets) {
				my $dataset = $registry->getDatasetByName($schema_name, $dataset_name)
				|| BioMart::Exception::Configuration->throw("Couldn't get dataset $schema_name->$database_name->$dataset_name from registry");
	    		push @datasets, $dataset;
	    		my $conf_tree = $dataset->getConfigurationTree('default');
	    		#######------------ SINGLE MENU FOR DS datastructure
	    		# Add this dataset to pushaction-hash
	    		if ($dataset->displayName !~ m/\|/)
	    		{
					# setting the default dataset to appear as first option in the menu
					if ($conf_tree->defaultDataset()){
						# unshift(@{ $js_pushactions_of_datasetmenu{ 'databasemenu' }->{ $schema__dbName }->{ 'datasetmenu_3' } }, 
						#								[$dataset->name, $dataset->displayName()]);
						# just in case there are more than one defaults DSs in a MART, they shouls also be ordered
						# alphabetically tore them in a separate hash, and towards the end of this Mart
						# add them to the top in alphabetical order
						$defDSHash{$dataset->displayName()} = $dataset->name();						
	    			}
	    			else{
						push(@{ $js_pushactions_of_datasetmenu{ 'databasemenu' }->{ $schema__dbName }->{ 'datasetmenu_3' } }, 
													[$dataset->name, $dataset->displayName()]);
	    			}
	    			$default_dataset ||= $dataset; 
	    		}		    		
				#-------------------------------------------
				#######------------ MULTI MENU FOR DS datastructure	
	    		else
	    		{
					$multiMenuDS = 1;
					my $dsName = $dataset->displayName;
	    			my @dsPortions = split(/\|/,$dsName);
	    			my $menuCount = 1;
	    			$unitsHash->{$dsPortions[0]}->{$dsPortions[1]}->{$dsPortions[2]} = [$dataset->name, $dataset->displayName()];
					$unitsHash->{$dsPortions[1]}->{$dsPortions[0]}->{$dsPortions[2]} = [$dataset->name, $dataset->displayName()];	    			
					$default_dataset ||= $dataset;
					$dsName = $default_dataset->displayName;
					@datasetUnits = split(/\|/,$dsName);					
	    		}
				#-------------------------------------------		    		
			} # foreach datasets closes
			if($multiMenuDS == 1)
			{
				foreach my $one(sort keys %$unitsHash) {
					#	print STDME "\n$one"; 
					my $temp_one = $schema__dbName.'____'.$one;
					push(@{ $js_pushactions_of_datasetmenu{ 'databasemenu' }->{ $schema__dbName }->{ 'datasetmenu_1' } },	[$temp_one,$one]);
					foreach my $two (sort keys %{$unitsHash->{$one}}) {
						#		print STDME "\n\t$two"; 
						my $temp_two = $temp_one.'____'.$two;
						push(@{ $js_pushactions_of_datasetmenu{ 'datasetmenu_1' }->{ $temp_one }->{ 'datasetmenu_2' } },	[$temp_two, $two]);
						foreach my $three (sort keys %{$unitsHash->{$one}->{$two}}) {
							#			print STDME "\n\t\tKEY: $three \t VALUE: "; 
							my @dsName = ();
							my $index = 0;
							foreach (@{$unitsHash->{$one}->{$two}->{$three}}) {
								$dsName[$index++] = $_;
							}	
							my $temp_three = $temp_two.'____'.$three;
							push(@{ $js_pushactions_of_datasetmenu{ 'datasetmenu_2' }->{ $temp_two }->{ 'datasetmenu_3' } }, [$three, $three]);
						}
					}	
				}
			}
			# find out longest dataset displayName in order to draw separator line b/w default DS and the rest
	     	my $separator_length = 5; # default
	     	foreach my $dataset_name(@$datasets) {
				my $dataset = $registry->getDatasetByName($schema_name, $dataset_name);
				if (length($dataset->displayName()) > $separator_length) {
					$separator_length = length($dataset->displayName());
				}
			}
			my $separator_added = 0;
			my $separator = '-'x$separator_length;
			foreach my $dispName(reverse sort keys %defDSHash) {
				if (!$separator_added) {
					unshift(@{ $js_pushactions_of_datasetmenu{ 'databasemenu' }->{ $schema__dbName }->{ 'datasetmenu_3' } }, 
						['', $separator]); # behave just like -choose dataset-, so set no value
					$separator_added = 1;
				}
				unshift(@{ $js_pushactions_of_datasetmenu{ 'databasemenu' }->{ $schema__dbName }->{ 'datasetmenu_3' } }, 
						[$defDSHash{$dispName}, $dispName]);				
			}
		} # foreach database closes
	} # foreach schema closes
	$default_dataset ||= $datasets[0];
	# build schema+dataset select-menus from the info collected above
	if(keys(%{ $js_pushactions_of_datasetmenu{ 'databasemenu' } }) == 0) {
		$logger->info("No datasets found in registry, so no templates were built. Returning 0");
		return 0;
	}	

	# finding if two virtualSchemas (1 visible and other invisible) set mergeVs to 1 
	my $schemaCount = $registry->getAllVirtualSchemas();
	if (scalar (@{$schemaCount}) == 2) {
		my ($visibleVS, $invisibleVS) = 0 ;
		foreach my $schema(@$schemaCount) {
			$visibleVS++ if($schema->visible());
			$invisibleVS++ if(!$schema->visible());
		}
		$session->clear('mergeVS');
		if ($visibleVS == 1 && $invisibleVS == 1) {	$session->param('mergeVS', '1');	}
		else {	$session->param('mergeVS', '0');	}		
	}
	else {	$session->param('mergeVS', '0');	}
		
	if($session->param('menuNumber') && $session->param('menuNumber') eq '3')
	{
		# this form is returned by datasetpanel.tt so set the schema, DB and DS session params
		
		my @schemaDB_units = split (/____/,$session->param('databasemenu'));
		$session->param('schema', $schemaDB_units[0]);
		$session->param('dataBase', $schemaDB_units[1]);
	}	
	
	if (!$session->param('schema') && !$session->param('dataBase') && !$session->param('dataset'))
	{		
		# NEW QUERY, set NO DEFAULTS
		# print "***** 1";
		print $CGI->header(-charset=>'utf-8');
		$session->param('newQuery', '1');
		$js_datasetpanel_sessions_values{'schema'} = '';
		$js_datasetpanel_sessions_values{'databasmenu'} = '';
		$js_datasetpanel_sessions_values{'datasetmenu_1'} = '';
		$js_datasetpanel_sessions_values{'datasetmenu_2'} = '';
		$js_datasetpanel_sessions_values{'datasetmenu_3'} = '';
		
	}
	else ### we have all three items at run time, SUBMITTED BY THE USER
	{
		# print "***** 4";
		# this deals when session url string is being saved/bookmarked, say from one window to another
		if (!$session->param('dataBase') && $session->param('dataset') && $session->param('schema')){
			my @schemaDB_units = split (/____/,$session->param('databasemenu'));	
			$session->param('dataBase', $schemaDB_units[1]);			
		}
		
		# print "<br/>SCHEMA: ", $session->param('schema');
		# print "<br/>DBMENU: ", $session->param('databasemenu');
		
		$js_datasetpanel_sessions_values{'schema'} = $session->param('schema');
		$js_datasetpanel_sessions_values{'databasemenu'} = $session->param('dataBase');
		my $dsName = $session->param('datasetmenu_3');
		# compara menu triple menus values to be set by ONLOAD. SET when third menu invoked or by linked dataset menu INVOKED
		if($session->param('menuNumber') && ($session->param('menuNumber') eq '3' || $session->param('menuNumber') eq '5' ))
		{
			#print "<br/>****TRIPLE MENUS<BR/>";
			my $dsHint1 = $session->param('datasetmenu_1');
			my $dsHint2 = $session->param('datasetmenu_2');
			my $dsHint3 = $session->param('datasetmenu_3');

			## find out whihc number is triggered
			my $dsDisplayName;
			# remove schema____dbName____ prefix
			$dsHint2 =~ m/.*?____.*?____(.*)/;
			$dsHint2 = $1;
			$dsDisplayName = $dsHint2;
			$dsDisplayName =~ s/____/\|/;
			$dsDisplayName .= '|'.$dsHint3;			

			my @dsUnits = split (/\|/, $dsDisplayName);
			$js_datasetpanel_sessions_values{'datasetmenu_1'} = $dsUnits[0];
			$js_datasetpanel_sessions_values{'datasetmenu_2'} = $dsUnits[1];
			$js_datasetpanel_sessions_values{'datasetmenu_3'} = $dsUnits[2];
		}
		else # simlpe menu
		{
			#print "<br/>****SINGLE MENU<BR/>";
			my $dsDisplayName;
			foreach my $schema (@{$registry->getAllVirtualSchemas()}) {
				if($schema->name eq $session->param('schema')) {				
					foreach my $mart (@{$schema->getAllMarts(1)}) {
						if($mart->displayName eq $session->param('dataBase')) {
					   	foreach my $dataset (@{$mart->getAllDatasets(1)}) {
					    		if($dsName eq $dataset->name)	{			    					
			    					$dsDisplayName = $dataset->displayName;
			    					#$def_ds_OBJ = $dataset;
			    					### only for compara to maintain the reverse naming logic when dataset panel is redrawn
			    					### when count, results or linked dataset menu is invoked
			    					#if ($session->param ("reverseName") && $session->param ("reverseName") eq '1')
			    					#{	$reverseName = 1;	} # keep  the reverse logic alive
			    				}
					    	}
						}
					}
				}
			}
			$js_datasetpanel_sessions_values{'datasetmenu_3'} = $dsDisplayName;
			$js_datasetpanel_sessions_values{'datasetmenu_1'} = '';
			$js_datasetpanel_sessions_values{'datasetmenu_2'} = '';
			$session->clear('datasetmenu_1');
			$session->clear('datasetmenu_2');		
		}
		$session->clear('ds_1_count');
		$session->clear('ds_2_count');
#	print "<BR/>SCHEMA: ", $session->param('schema');
#	print "<BR/>DATABASE: ", $session->param('dataBase');
#	print "<BR/>DATASETs: ", $session->param('dataset');		
#	print "<BR/>MENU 1: ", $session->param('datasetmenu_1');
#	print "<BR/>MENU 2: ", $session->param('datasetmenu_2');
#	print "<BR/>MENU 3: ", $session->param('datasetmenu_3');
#	print "<BR/>DUMPER :   ", Dumper(\%js_datasetpanel_sessions_values);

		## find out if its a call from multi menus, so need to find out the dataset by urself and nemu number 0 means for count and results button
		$def_schema = $session->param('schema');
		$def_db = $session->param('dataBase');
		$def_ds = $session->param('dataset');
		
		if($session->param('menuNumber') && $session->param('menuNumber') eq '3') 
		{
			#print "*** COMPARA LOGIC";
			$def_ds = undef; # as WE need to guess this as per changes in sub menus
			$session->clear('dataset'); # v imp for compara stuff, when a menu is triggerred, dataset val changes
			my $dsHint1 = $session->param('datasetmenu_1');
			my $dsHint2 = $session->param('datasetmenu_2');
			my $dsHint3 = $session->param('datasetmenu_3');

			my $dsDisplayName;
			# remove schema____dbName____ prefix
			$dsHint2 =~ m/.*?____.*?____(.*)/;
			$dsHint2 = $1;
			$dsDisplayName = $dsHint2;
			$dsDisplayName =~ s/____/\|/;
			$dsDisplayName .= '|'.$dsHint3;			

			my ($tempRemoveSpaces, $tempdsDisplayName);
			foreach my $schema (@{$registry->getAllVirtualSchemas()}) {
				if($schema->name eq $def_schema) {
					foreach my $mart (@{$schema->getAllMarts()}) {
						if($mart->displayName eq $def_db) {
					    		foreach my $dataset (@{$mart->getAllDatasets(1)}) {
					    			# ----- Effort 1 - to see if we can find out the ds_internalName from displayName
					    			# ----- with menu1.menu2.menu3
					    			$tempRemoveSpaces = $dataset->displayName;
					    			$tempdsDisplayName = $dsDisplayName;
					    			$tempRemoveSpaces =~ s/\s//mg; # space cause trouble in matching regex
					    			$tempdsDisplayName =~ s/\s//mg;
					    			$tempRemoveSpaces =~ s/\|//mg; # pipe pretends to be OR cause trouble in matching regex
					    			$tempdsDisplayName =~ s/\|//mg;
					    			$tempRemoveSpaces =~ s/\(//mg; # ( pretends to be OR cause trouble in matching regex
					    			$tempdsDisplayName =~ s/\(//mg;
					    			$tempRemoveSpaces =~ s/\)//mg; # ) pretends to be OR cause trouble in matching regex
					    			$tempdsDisplayName =~ s/\)//mg;

					    			if($tempRemoveSpaces =~ m/^$tempdsDisplayName/) {
			    						foreach my $configurationTree (@{$dataset->getAllConfigurationTrees()}){
			    							if($configurationTree->defaultDataset())
			    							{
						    					$def_ds = $dataset->name();
						    					$def_ds_OBJ = $dataset;
						    				}
						    			}
						    			$def_ds ||= $dataset->name();
						    			$def_ds_OBJ ||= $dataset;
						    			$reverseName = 2;
			    					}
			    				}
				    			if(!$reverseName) {
						    		foreach my $dataset (@{$mart->getAllDatasets(1)}) {     		
					    				# ----- Effort 2 - to see if we can find out the ds_internalName from displayName
					    				# ----- with menu2.menu1.menu3
									my @unitsArray = split('\|', $dsDisplayName);
									$tempdsDisplayName = $unitsArray[1].'|'.$unitsArray[0].'|'.$unitsArray[2];
									$tempdsDisplayName =~ s/\s//mg;						    			
						    			$tempdsDisplayName =~ s/\|//mg;						    			
						    			$tempdsDisplayName =~ s/\(//mg;						    			
						    			$tempdsDisplayName =~ s/\)//mg;
						    			$tempRemoveSpaces = $dataset->displayName;
						    			$tempRemoveSpaces =~ s/\s//mg; # space cause trouble in matching regex
						    			$tempRemoveSpaces =~ s/\|//mg; # pipe pretends to be OR cause trouble in matching regex	
						    			$tempRemoveSpaces =~ s/\(//mg; # ( pretends to be OR cause trouble in matching regex	
						    			$tempRemoveSpaces =~ s/\)//mg; # ) pretends to be OR cause trouble in matching regex
	

						    			if($tempRemoveSpaces =~ m/^$tempdsDisplayName/) {
				    						foreach my $configurationTree (@{$dataset->getAllConfigurationTrees()}){
				    							if($configurationTree->defaultDataset())
				    							{
							    					$def_ds = $dataset->name();
							    					$def_ds_OBJ = $dataset;
							    				}
							    			}
							    			$def_ds ||= $dataset->name();
							    			$def_ds_OBJ ||= $dataset;
					    					$reverseName = 1;
				    					}
				    				}
				    			}
					    		if(!$reverseName) {
						    		foreach my $dataset (@{$mart->getAllDatasets(1)}) {     		
		    							#### last case, even when reverse doesnt work, that means
				    					#### this value in menu one itself has no corresponding dataset 
				    					#### where name begins with it, so it a second portion of some other
				    					#### dataset/datasets only
						    			$tempRemoveSpaces = $dataset->displayName;
						    			$tempdsDisplayName = $dsDisplayName;
						    			$tempRemoveSpaces =~ s/\s//mg; # space cause trouble in matching regex
						    			$tempdsDisplayName =~ s/\s//mg;
						    			$tempRemoveSpaces =~ s/\|//mg; # pipe pretends to be OR cause trouble in matching regex
						    			$tempdsDisplayName =~ s/\|//mg;
						    			$tempRemoveSpaces =~ s/\(//mg; # ( pretends to be OR cause trouble in matching regex
						    			$tempdsDisplayName =~ s/\(//mg;
						    			$tempRemoveSpaces =~ s/\)//mg; # ) pretends to be OR cause trouble in matching regex
						    			$tempdsDisplayName =~ s/\)//mg;

				    					if($tempRemoveSpaces =~ m/$tempdsDisplayName/) {
					    					foreach my $configurationTree (@{$dataset->getAllConfigurationTrees()}){
				    							if($configurationTree->defaultDataset())
				    							{
							    					$def_ds = $dataset->name();
							    					$def_ds_OBJ = $dataset;
							    				}
							    			}
								    		$def_ds ||= $dataset->name();
								    		$def_ds_OBJ ||= $dataset;
						    				$reverseName = 1;
					    				}
								}
					    		}
					    	}
					}
				}
			}
			##-------- cont. NOTE - 1A at the beginning of this subroutine	
			if ($session->param("mart_mainpanel__current_visible_section") =~ m/__infopanel$/
				|| $session->param("summarypanel__current_highlighted_branch") =~ m/__summarypanel_datasetbranch$/)
			{
				$session->clear("mart_mainpanel__current_visible_section");
				$session->clear("summarypanel__current_highlighted_branch");
				my $vSection = $def_ds.'__infopanel';
				my $summaryBranch = $def_ds.'__summarypanel_datasetbranch';
				$session->param("mart_mainpanel__current_visible_section", $vSection);
				$session->param("summarypanel__current_highlighted_branch", $summaryBranch);
			}

		}
		else
		{
			#print "*** SIMPLE LOGIC";
			## ==== first check if there are more than one datasets in query or not. change def_ds accordingly
			my $datasets_all = $session->param('dataset');
			my @dataset_names   = ref($datasets_all) ? @$datasets_all : ($datasets_all);
			$def_ds = $dataset_names[0]; # should be the first ds names as its the one which goes to datasetpanel.tt via def_ds_OBJ
			## ==== find out the dsObject to pass to datasetpanel.tt
			foreach my $schema (@{$registry->getAllVirtualSchemas()}) {
				if($schema->name eq $def_schema) {
					foreach my $mart (@{$schema->getAllMarts()}) {
						if($mart->displayName eq $def_db) {
					   	foreach my $dataset (@{$mart->getAllDatasets(1)}) {
					    		if($def_ds eq $dataset->name)
			    				{
			    					$def_ds_OBJ = $dataset;
			    					### only for compara to maintain the reverse naming logic when dataset panel is redrawn
			    					### when count, results or linked dataset menu is invoked
			    					if ($session->param ("reverseName") && $session->param ("reverseName") eq '1')
			    					{	$reverseName = 1;	} # keep  the reverse logic alive
			    				}
					    	}
					    }
					}
				}
			}			
		}
	

		#print " ", $session->param('schema');
		#print " ", $session->param('dataBase');
		#print " ", $session->param('dataset'), "==";

	
		$session->clear('schema');
		$session->clear('dataBase');
		$session->param('schema', $def_schema);
		$session->param('dataBase', $def_db);
		$session->param('dataset', $def_ds) if (!$session->param('dataset'));
	
	
		# If one or more datasets are selected by now, get initial counts and build query
		my $datasets_string = $session->param('dataset');
		my $schema_name     = $session->param('schema');

		my $query_main      =  BioMart::Query->new(registry	=> $registry,
														virtualSchemaName => $schema_name);
		my $qrunner = BioMart::QueryRunner->new();		
				
		my @dataset_names   = ref($datasets_string) ? @$datasets_string : ($datasets_string); 
		$logger->debug("Need to query datasets ".join(',',@dataset_names)." for total entry counts for each");
	
		# Turn on/off background jobs option in interface.
		my %backgroundSettings = $self->getSettings('background');
		$session->param('__enable_background', ($backgroundSettings{'enable'} eq 'yes') ? 1 : 0);
	
		foreach my $dataset_name(@dataset_names) {
		    
			# Pull out filter & attribute params for this dataset and prepare the query
			my $vs_dataset_name = $session->param('schema').'____'.$dataset_name;
			my $filterlist_string    = $session->param($vs_dataset_name.'__filterlist') if ($session->param($vs_dataset_name.'__filterlist'));
			
			my $attributepage        = $session->param($dataset_name.'__attributepage') if ($session->param($dataset_name.'__attributepage'));
			
			my $attributelist_string = $session->param($vs_dataset_name.'__'.($attributepage||'').'__attributelist');
	    	
	    	if ($filterlist_string){ $logger->debug("FILTERLIST_STRING IS $filterlist_string"); }
			else {$logger->debug("FILTERLIST_STRING IS *EMPTY*"); }
	    	
			my @filterlist = !defined($filterlist_string) ? ()
	                 		: ref($filterlist_string) ? @$filterlist_string 
								: ($filterlist_string); 
		
			my @attributelist = !defined($attributelist_string) ? ()
	                    	: ref($attributelist_string) ? @$attributelist_string 
		              		: ($attributelist_string); 
			$logger->debug("Enabled filters for dset $dataset_name: ".join('|',@filterlist));
	    	$logger->debug("Enabled attributes for dset $dataset_name: ".join('|',@attributelist));
	    
			foreach (@attributelist)
			{
				if($_ eq 'dummy')
				{
					undef $_;
					##$session->clear($dataset_name.'__'.'feature_page'.'__attributelist');
				}
			}
			foreach (@filterlist)
			{
				if($_ eq 'dummy') ### refers to Mummi' addition of dummy filter in removeFromSummaryPanelList of java script
				{	
					## storing it to retrieve back once query param extraction is done
					$noFilter = 1;				
					## its a filter with out value and then handled by extract_queryparams. gets ignored as it has no value
					$session->clear($dataset_name.'__filtercollections'); 	## these are hidden form parameters so they dont appear in HTML source
																## making life more difficult to trace them.				
				}
			}
			
			# Extract filtervalues & attributelist from the full set of request-parameters
	    	my ($values_of_filter, $attributes, $values_of_attributefilter)
				= $self->extract_queryparams($session->dataref(), \@filterlist, \@attributelist);
	    

	    	# Add filters(if any) to single-dset query to get counts
			push(@dataset_names_in_query, $dataset_name);
		   		
			# only do for the first top dataset
			if (@dataset_names_in_query == 1)
			{
				my $atttree = $registry->getConfigTreeForDataset($dataset_name, $schema_name, 'default')->getAttributeTreeByName($attributepage);
				# || BioMart::Exception::Configuration->throw("Can't find attpage $attributepage for $schema_name\.$dataset_name");			
				if (defined($atttree))
				{ 
					$logger->debug("Got outputformats ".$atttree->outFormats()." for attpage $attributepage, in dataset $dataset_name");
					my @outputformats = split(',', $atttree->outFormats());
					$all_formatters = $atttree->outFormats();
					$session->param("export_outputformats", \@outputformats);		    	
					my $preView_session_outformat = $session->param('preView_outputformat');
					my $exportView_session_outformat = $session->param('exportView_outputformat');
				 	foreach (@outputformats)
			    	{
						if (defined($preView_session_outformat) && $preView_session_outformat eq $_)
						{
			    			$preView_formatter_name = uc($preView_session_outformat);
						}
						if (defined($exportView_session_outformat) && $exportView_session_outformat eq $_)
						{
			    			$exportView_formatter_name = uc($exportView_session_outformat);
						}
		    		}
					$preView_formatter_name = uc($outputformats[0]) if (!$preView_formatter_name);
		    		$exportView_formatter_name = uc($outputformats[0]) if (!$exportView_formatter_name);
		    	}
				else
				{
			    	# this is just for setting the export_outputformats session param for the first time since
					# we have AJAX working now, so this param should be set right from the beginning so the
					# results panel menus would turn up populated right from the beginning.
					my $allAttributeTrees = $registry->getConfigTreeForDataset($dataset_name, $schema_name, 'default')->getAllAttributeTrees();
					my $atttree = $allAttributeTrees->[0]; # first one is supposed to be the default one
					$logger->debug("Got outputformats ".$atttree." for attpage $attributepage, in dataset $dataset_name");
					my @outputformats = split(',', $atttree->outFormats());
					$all_formatters = $atttree->outFormats();
					$session->param("export_outputformats", \@outputformats);
				}
			}
		
			# need to calculate count here as adding attributes to query from GS would crash the counting
			# so better do counting with out any attributes and this involves less processing by QRunner
			if ($session->param('countButton') && $session->param('countButton') eq '1' ) 
			{
				#$session->clear('get_count_button'); # don't get stuck here
				# Get counts if possible, i.e. if it's only a single dataset query
				#print "INSIDE COUNT";
				$logger->debug("Sending query for execution to get counts only");
				# process TOTAL count using the above retrived attribute
				my ($entry_count, $total_count) = 'N/A';
				my $qrunner_count = BioMart::QueryRunner->new();
				my $query_count = $self->prepare_martquery({	schema     => $schema_name,
							   						dataset    => $dataset_name	});
				$query_count->count(1);
				$qrunner_count->execute($query_count);
				$total_count = $qrunner_count->getCount();	    		
				$entrycount_of_dataset{$dataset_name} = $total_count || 0;
				$session->param('entrycount_of_dataset',  \%entrycount_of_dataset);

				# process FILTER SPECIFIC count now
				$query_count = $self->prepare_martquery({	schema     => $schema_name,
						   						dataset    => $dataset_name,
						   						filters    => $values_of_filter});
				$query_count->count(1);
				$qrunner_count->execute($query_count);	    		
				$entry_count = $qrunner_count->getCount();		
				$filtercount_of_dataset{$dataset_name} = $entry_count || 0;
				$session->param('filtercount_of_dataset', \%filtercount_of_dataset);	
		    	$logger->debug("COUNT: $entry_count out of TOTAL: $total_count");

				$countStringForJS .= '____' if ($countStringForJS); # used as separator for TWO DS counts 
				$countStringForJS .= $entry_count || 0;
				$countStringForJS .= ' / ';
				$countStringForJS .= $total_count || 0;
				$countStringForJS .= ' ';
				$countStringForJS .= $registry->getConfigTreeForDataset($dataset_name, $schema_name, 'default')->entryLabel || 'Entries';
				$countStringForJS = "Count unavailable" if ($registry->getConfigTreeForDataset($dataset_name, $schema_name, 'default')->entryLabel eq "Count unavailable");
			}

		    # Add filters & atts to main query as well, if any		
			$query_main = $self->prepare_martquery({query      => $query_main,
									schema     => $schema_name,
									dataset    => $dataset_name,
									filters    => $values_of_filter,
									attributes => {$dataset_name => $attributes},
									attributefilters => $values_of_attributefilter});
			if($noFilter)
			{
				## adding back blank/dummy, so defaults are ignored as user explicitly removes all filters
				## but this time, not to filterList, its for filtercollections. see filterpanel.tt javascript as well
				$noFilter = $dataset_name.'__filtercollections';
				$session->param($noFilter, 'dummy');
				undef $noFilter; 															
			}
		}

		########### copying it to another session variable as the  original once gets reset in main.tt back again
		$session->param('ds_1_count', $session->param('summarypanel_filter_count_1_hidden'));
		$session->param('ds_2_count', $session->param('summarypanel_filter_count_2_hidden'));
	
		$session->clear('get_count_button'); # don't get stuck here
		#$session->clear('countButton'); # don't get stuck here
		###########	
	
		# Check if there are any datasets on our list which did not make it into the query, and
		# if so then undef the main query to avoid inconsistencies in the user interface
		$logger->debug("Datasetcount added to query:   ".scalar(@dataset_names_in_query));
		$logger->debug("Datasetcount in session:       ".scalar(@dataset_names));
		
		# Save the main query in session, for later use, if there's anything in query by now
		if(defined($query_main)) {
			# Then save info to session
		    my %lastquery_info;
		    $lastquery_info{xml} = $query_main->toXML(1,1,1,1);
		    $lastquery_info{timestamp} = strftime "%Y-%m-%d %H:%M:%S", localtime;
		    $session->param('lastquery_info', \%lastquery_info);
		}
	
		# Display the xml query or PERL API equivalent in separate browser window
		my $showQuery = $session->param('showquery');

		if(defined ($showQuery) && defined($query_main) && $showQuery ne '0')
		{
			# XML Query
			if ($showQuery eq '1') {
				# do not want to show internals of BioMart ;-) 
				my $tempered_xml = $query_main->toXML(1,1,1,1);
				$tempered_xml =~s/limitStart.*?limitSize\s*=\s*\"\d*\"/formatter = \"$exportView_formatter_name\" header = \"0\" uniqueRows = \"0\"/g;
				$tempered_xml =~s/requestId\s*=\s*\".*\"//g;
				$tempered_xml =~s/softwareVersion/datasetConfigVersion/g;
				$tempered_xml =~s/</&lt;/g;
				$tempered_xml =~s/>/&gt;/g;
				print $CGI->header(-charset=>'utf-8');
				print "<html><body><pre>$tempered_xml</pre></body></html>";
			}
			# PERL API equivalent of the query
			if ($showQuery eq '2') {
				my $tempered_perlScript = $query_main->toPerl();
				$tempered_perlScript =~ s/my \$query_runner = BioMart::QueryRunner->new\(\)\;/\$query->formatter\(\"$exportView_formatter_name\"\)\;\n\nmy \$query_runner = BioMart::QueryRunner->new\(\)\;/;
				print $CGI->header(-charset=>'utf-8');
				print "<html><body><pre>$tempered_perlScript</pre></body></html>";
			}
			# URL access equivalent of the query
			if ($showQuery eq '3') {
				my $xml = $query_main->toXML(1,1,1,1);
				my $url_string = $CGI->url(-full => 1) . $self->getURLBookmark($registry, $xml, $session);
				print $CGI->header(-charset=>'utf-8');
				print "<html><body><pre>$url_string</pre></body></html>";
			}
			$session->clear('showquery'); # so we don't get stuck a this stage
			$session->flush();
			return;
		}
	
		# If there's enough information at hand now, set up formatter for query & get subset of results
		RUN_QUERY:
		if(defined($query_main)) 
		{
			$logger->debug("Query has both filters and attributes by now, let's go get some results!");
			# Figure out how many entries to print
			my $export_subset = $session->param('export_subset') || '10';
	    	undef $export_subset if defined($export_subset) && $export_subset eq q{};
			undef $export_subset if ($session->param("do_export"));

			# Eval next line and check to see if any exception thrown. If so,
			# return nicely with exception in session parameter.
			my $return_after_eval = 0;
			eval {
				if ( $session->param('resultsButton') && $session->param('resultsButton') eq '1' )
				{
					$session->clear('get_results_button'); # don't get stuck here
					my $selectedFormatterMenu;
					if($session->param('formatterMenu') && $session->param('formatterMenu') eq 'exportView')
					{ $selectedFormatterMenu = $exportView_formatter_name; }
					else
					{ $selectedFormatterMenu = $preView_formatter_name; }

					my $formatterName = $selectedFormatterMenu || 'TSV';
					my $formatter_class = 'BioMart::Formatter::'.$formatterName;
					eval "require $formatter_class" or BioMart::Exception->throw("could not load module $formatter_class: $@");
					my $formatter = $formatter_class->new();
					$logger->debug("Formatting data as $formatterName");
	
			    	# START NEW CODE
			    	# Run in background?
					my $export_saveto = $session->param('export_saveto');
					# if its ALL option, to be redirected to Browser with preView formatter
					if ($session->param('export_subset') eq 'All' 
							&& $session->param('showAll') &&  $session->param('showAll') eq '1')
					{
						$export_saveto = 'text';
						$exportView_formatter_name = $preView_formatter_name;						
					}
					# change the option Menu value to 10 if it was All and then user comes back to 
					# Atts/Filts/Ds panels and hit results again or hits the count button
					if ($session->param('export_subset') eq 'All' && !$session->param("do_export"))
					{	
						$session->param('export_subset', '10');
					}
					
					if ($session->param('do_export') and ($export_saveto eq 'file_bg' or $export_saveto eq 'gz_bg')) 
			    	{
						$logger->debug("Running in background.");
						$session->clear('do_export'); # so it only happens once
						
						# Work out filename.    
						my $background_file = strftime("martquery_%m%d%H%M%S", localtime).'_'.int(rand(1000));
	    				# Append extensions to the filename.
						$background_file .= '.'.$formatter->getFileType(); 
						if ($export_saveto eq 'gz_bg') {
							$background_file .= '.gz';
						}
						# Hash the filename.
						my %backgroundSettings = $self->getSettings('background');
	    				my $background_file_dirCount = $backgroundSettings{'resultsDirCount'};
	    				my $background_file_hash = int(rand($background_file_dirCount)) + 1;
	    				# Work out where the file is going to.
	    				my $background_file_dir = $backgroundSettings{'resultsDir'.$background_file_hash}.'/';				
						
						# Work out metadata for file.
						open (MIME, '>'.$background_file_dir.$background_file.'.mime');
						open (BINMODE, '>'.$background_file_dir.$background_file.'.binmode');
						if ($export_saveto eq 'gz_bg') {
							print MIME 'application/octet-stream';
							print BINMODE '1';
						} 
						else {
							print MIME $formatter->getMimeType();
							print BINMODE $formatter->isBinary();
						}
						close (MIME);
						close (BINMODE);
						
						# Work out URL for file.				
						my $server_url = $CGI->url();
						$server_url =~ m{(.*/)martview.*};
						$server_url = $1;
						my $background_file_url = $server_url.'martresults?file='.$background_file; 
						
						# Tell user where file will be.
						$session->param("mart_mainpanel__current_visible_section","resultspanel");
						$session->param("summarypanel__current_highlighted_branch","show_results");
						$result_string = 
						"<br/>Your results are being compiled in the background.".
						"<br/>Your reference is $background_file.".
						"<br/><br/>An email will be sent to you when they are ready.";
												
						# Fork and run in background.
	    				$SIG{CHLD} = 'IGNORE';
   					defined (my $pid = fork) or die "Cannot fork: $!\n";
				   	unless ($pid) {    	
				   	# Ready for mail.
						my %mailSettings = $self->getSettings('mailSettings');
						my $mailer = new Mail::Mailer $mailSettings{'mailerType'};  
						my %mail_headers = ();
						# apply Ensembl Security patch for email address
						my $TO = $session->param("background_email");
						$TO =~ s/[\r\n].*$//sm;						
  						$mail_headers {From} = $mailSettings{'from'}; 
						$mail_headers {To}  = $TO; 
						$mail_headers {Subject}  = $mailSettings{'subject'}; 
						eval {
				   		# Run query.			    
				   		$logger->debug("Sending query for execution to get full resultset");
	    					$query_main->formatter($exportView_formatter_name);
	    					$query_main->count(0);# don't get count below
	    					$qrunner->uniqueRowsOnly(1) if ($session->param('uniqueRowsExportView') && $session->param('uniqueRowsExportView') eq '1');
							$qrunner->execute($query_main);						
							# Create results.
							if ($export_saveto eq 'gz_bg') {
								$logger->debug("Writing results to ".$background_file_dir.$background_file);
								open(FH,">".$background_file_dir.$background_file);
								my $fh = BioMart::Web::Zlib->new(\*FH);
								$qrunner->printHeader($fh);
								$qrunner->printResults($fh, $export_subset);
								$qrunner->printFooter($fh);
								$fh->close();
								close(FH);
				  			} 
				  			else 	{
								$logger->debug("Writing results to ".$background_file_dir.$background_file);
								open(FH,'>'.$background_file_dir.$background_file);	
								if ($formatter->isBinary()) {	
									binmode FH;						
								}	
								$qrunner->printHeader(\*FH);
								$qrunner->printResults(\*FH, $export_subset);
								$qrunner->printFooter(\*FH);
								close(FH);
				  			}	
						};
						if ($@) {
							# Send failure email.
							my $ex = Exception::Class->caught();
				   		$logger->debug("Serious error: ".$ex);
							$mailer->open(\%mail_headers); 
							print $mailer "Your results file FAILED.\n\n".
							"Here is the reason why:\n\n$ex\n\n".
							"Please try your request again, or alternatively contact your service provider\nincluding a copy of this email and quoting this reference: $background_file.";
	  						$mailer->close;
						}
						else {	
							# Send email with link to file.
							$mailer->open(\%mail_headers); 
							print $mailer "Your results are ready and can be downloaded by following this link:\n\n$background_file_url";
	  						$mailer->close; 
						}
   					# Child is done so should stop here.		 			
	   				CORE::exit(0);
	   				} # end background process
			    	} 
			    	# Not in background, then is export or show-in-browser.
			    	else {
			    		# Export?
			    		if ($session->param("do_export")) {
			    			# Exit after eval block.
							$return_after_eval = 1;		
							$session->clear('do_export'); # so it only happens once
											    						   			
				    		# Run query.			    
					  		$logger->debug("Sending query for execution to get full resultset");
	    					$query_main->formatter($exportView_formatter_name);
	    					$query_main->count(0);# don't get count below
	    					if ( ($session->param('uniqueRowsExportView') && $session->param('uniqueRowsExportView') eq '1' )
	    						||($session->param('uniqueRowsPreView') && $session->param('uniqueRowsPreView') eq '1' 
	    							&& $session->param('showAll') &&  $session->param('showAll') eq '1' ) )
	    					{
		    					$qrunner->uniqueRowsOnly(1);		    					
	    					}
	    					$qrunner->execute($query_main);
						
							# Work out filename.    
							my $file = 'mart_export';
							$file .= '.'.$formatter->getFileType(); 
							if ($export_saveto eq 'gz') {
								$file .= '.gz';
							}

							$logger->debug("Exporting file.");
							
							# Work out CGI headers
							if ($export_saveto eq 'text') {
								print $CGI->header(-type=>$formatter->getMimeType(),
											-charset=>'utf-8');
							}
							elsif ($export_saveto eq 'gz') {
								print $CGI->header(-type=>'application/octet-stream',
										-attachment=>$file,
										-charset=>'utf-8');
							}
							else {
								print $CGI->header(-type=>$formatter->getMimeType(),
										-attachment=>$file,
										-charset=>'utf-8');
							}
							
				   		# Create results.
				   		if ($export_saveto eq 'gz') {
				   			my $fh = BioMart::Web::Zlib->new(\*STDOUT);
								$qrunner->printHeader($fh);
								$qrunner->printResults($fh, $export_subset);
								$qrunner->printFooter($fh);
								$fh->close();
				   		}
				   		else {				   									
								if ($formatter->isBinary()) {	
									binmode STDOUT;						
								}
								$qrunner->printHeader(\*STDOUT);
								$qrunner->printResults(\*STDOUT, $export_subset);
								$qrunner->printFooter(\*STDOUT);
				   		}
				   		# Finish up.
							undef $/;
			    		}
			    		# No export, so show in browser.
			    		else {
			    			# Set up browser to show stuff.			    								
		    				$session->param("mart_mainpanel__current_visible_section","resultspanel");
							$session->param("summarypanel__current_highlighted_branch","show_results"); 

							$logger->debug("Showing in browser.");
			    		
			    			# Can't show binary formats.	
			    			if($formatter->isBinary()) {		
								$result_string = "<br/>Cannot display binary output in this panel.<br/>Choose the target from the menu above & press Go.";
			    			} 

			    			# Can't show HUGE MAF output for PECAN 7 & 9 species
			    			elsif(($query_main->formatter($preView_formatter_name)) eq 'MAF_NOPREVIEW') {		
								$result_string = "<br/>Cannot preview multiple genomic alignments due to the huge amount of data.<br/>Choose the target from the menu above & press Go.<br/>The size of the output expected will be between tens of Mb to a few Gb depending on your filtering";
			    			} 

			    			# But can show everything else.
			    			else {	    				
								$logger->debug("Showing ".($export_subset||'all')." entries in main panel");
		    				   			
				    			# Run query.			    
					  			$logger->debug("Sending query for execution to get full resultset");
	    						$query_main->formatter($preView_formatter_name);
		    					$query_main->count(0);# don't get count below
		    					$qrunner->uniqueRowsOnly(1) if ($session->param('uniqueRowsPreView') && $session->param('uniqueRowsPreView') eq '1');
								$qrunner->execute($query_main);
								
								undef $export_subset if ($export_subset eq 'All');
								# Get results
								open(my $result_buffer, '>', \$result_string);
								$qrunner->printHeader($result_buffer);
								$qrunner->printResults($result_buffer, $export_subset);
								$qrunner->printFooter($result_buffer);
								close($result_buffer);
								
								if($preView_formatter_name =~ '^HTML$|^HTML_36$|^GOENRICH$|^FAMILYENRICH$|^EXPRESSIONENRICH$|^SAME$|^DIFF$|^ALL$') {
								    # strip out HTML stuff in case this is HTML-format
								    $result_string =~ s/\A\<\?xml.+\<table/\<table/xms; 
								    $result_string =~ s/\<\/body.+\Z//xms;
								    # apply different css styles here, the classes now removed from
								    # HTML formatter as for EXPORT options, no point having those
								    # class tags in there
								    $result_string =~ s/\<table\>/\<table\ class=\"mart_table\">/gxms;
								    $result_string =~ s/\<th\>/\<th\ class=\"mart_th\">/gxms;						    		
								    $result_string =~ s/\<tr\>/\<tr\ class=\"mart_tr1\">/gxms;
								    $result_string =~ s/\<td/\<td\ class=\"mart_td\"/gxms;
								}
								else {
								    # wrap in <pre/> to make it look pretty.
								    $result_string = "<pre class=\"mart_results\">$result_string</pre>";
								}
			    			}
			    												    			
			    			# Turn on/off background jobs option in interface.
							#my %backgroundSettings = $self->getSettings('background');
							#$session->param('__enable_background', ($backgroundSettings{'enable'} eq 'yes') ? 1 : 0);
			    		}
			    	}
			    	# END NEW CODE		    	
				} # end of if session->param count defined
  			}; # end eval, trouble maker
  			
  			# catch
		  	my $ex;
		  	$exceptionFlag=0;
		  	if ( $ex = Exception::Class->caught('BioMart::Exception::Usage') )
  			{
  				$exceptionFlag = 1;
  				my $errmsg = $ex->error();
				# for new AJAX issues, the validation error goes into results panel
				print "Validation Error: ", $errmsg;
 				
    			$logger->debug("Validation error: ".$errmsg);
				$session->param("__validationError",$errmsg);
				## display setting back to where it was
				$session->param('mart_mainpanel__current_visible_section', $session->param('track_visible_section')); 
		  	}
			elsif ($ex = Exception::Class->caught()) 
			{
  				$exceptionFlag = 1;			
				my $errmsg = $ex->error();
				# for new AJAX issues, the validation error goes into results panel				
				print "Serious Error: ", $errmsg;
				
   			$logger->debug("Serious error: ".$ex);
     			UNIVERSAL::can($ex, 'rethrow') ? $ex->rethrow : die $ex;
 			}
		  	else 
		  	{
    			$logger->debug("Everything's fine");
			}
			if ($return_after_eval == 1) 
			{			 
				return; 
			}  	
	 
		} # end of if (defined $query_main... (RUN_QUERY)
	 
		# Clear count request.
		$session->clear('get_count_button'); # so we don't get stuck at this stage
		$qtime = round(time - $qtime, 4);
		$logger->info("All Mart counts and main Mart-query executed in ".$qtime);						  
		# Render main query-building interface page
		print $session->header(); # adds the required session-ID cookie to the header
		$logger->debug("Incoming SESSION-params:\n",Dumper($session));
	
		#------------------------------------------------------------ Populate the DS panel		
		
		$dbName = $session->param('dataBase');
		$session->clear('dataBase');
	
	}	##### end of IF/ELSE (****4) statement for governing if its a submit from user and not the first parse
	
	my $dsOLD = $self->get_conf_Dir()."/templates/default/datasetpanel.ttc";
	if (-e $dsOLD) {unlink $dsOLD;}
	$dsOLD = $self->get_conf_Dir()."/templates/cached/datasetpanel.ttc";
	if (-e $dsOLD) {unlink $dsOLD;}
	$dsOLD = $self->get_conf_Dir()."/templates/cached/datasetpanel.tt";
	if (-e $dsOLD) {unlink $dsOLD;}
	
	## E! hack
	my $PS = new BioMart::Web::PageStub( $session );
	$PS->start();
	## End of hack

	if ( $session->param('countButton') && $session->param('countButton') eq '1')
	{
		$session->param('countButton', '0') ;
		# only countString
		print "$countStringForJS";			
	}
	elsif ($session->param('resultsButton') && $session->param('resultsButton') eq '1' && !$session->param('URL_REQUEST'))
	{
		$session->param('resultsButton', '0') ;
		if ($exceptionFlag != 1)
		{
			# should return 5 values
			$all_formatters = 'TSV' if ($session->param("GALAXY_URL"));
			my @outputformat_displays;
			foreach my $formatter(split(/\,/,$all_formatters)){
				my $formatter_mod = 'BioMart::Formatter::'.uc($formatter);
				if ($formatter_mod->getFormatterDisplayName()){      
					push @outputformat_displays, $formatter.';'.$formatter_mod->getFormatterDisplayName();
				}
				else{
					push @outputformat_displays, $formatter.';'.uc($formatter);
				}
			}
			
			my $display_string = join ",",@outputformat_displays;
			print $CGI->header(-charset=>'utf-8');			
			print lc($preView_formatter_name);
			print '____';
			print $display_string;
			print '____';
			print lc($exportView_formatter_name);
			print '____';
			print $display_string;
			print '____';
			print $result_string;
			# only resultsString
		}
	}
	else
	{
		$session->param('resultsButton', '0') if ($session->param('URL_REQUEST'));
		$session->clear('URL_REQUEST');
		
		my $completePage = "";
		$self->process_template( "main.tt", {
			tbuilder			=> $self,
			js_pushactions_of_datasetmenu => \%js_pushactions_of_datasetmenu,
			js_datasetpanel_sessions_values => \%js_datasetpanel_sessions_values,
			session       	=> $session,
			wq            	=> $self,
			form_action	=> $form_action,
			sessionDBNAME	=> $dbName,
			datasetOBJ	=> $def_ds_OBJ,
			reverseNAME	=> $reverseName,
			TAG_path		=> $TAG_path,			
			result_string 	=> $result_string
						#   	}, \*STDOUT );
   	}, \$completePage );

		# complete HTML page as in 0.5
		print $completePage;
	}
	## E! hack	
	$PS->end();
	## End of hack
}					  
1;


