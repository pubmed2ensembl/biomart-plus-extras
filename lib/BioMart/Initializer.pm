#Id: Initializer.pm,v 1.71 2006/01/25 16:47:24 ds5 Exp $
#
# BioMart module for BioMart::Initializer
#
# You may distribute this module under the same terms as perl
# itself.

# POD documentation - main docs before the code.

=head1 NAME

BioMart::Initializer

=head1 SYNOPSIS

TODO: Synopsis here.

=head1 DESCRIPTION

The BioMart::Initializer module reads the MartRegistry.xml 
configuration file containing the information about the 
databases and datasets that are to be used.  This is done 
by the constructor.  MartRegistry.xml files can contain
MartDBLocation/MartURLLocation pointing to a Mart Database 
or web server respectively containing
DatasetConfig.xml and the tables to be queried,
or RegistryDBLocation/RegistryURLLocation elements pointing to a 
Database/Web server containing other MartRegistry.xml files.
See the file "config/defaultMartRegistry.xml" 
for an example of the format of this file.
The Initializer is only used once, at the 
beginning of a BioMart session, to get the
BioMart::Registry object.

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Andreas Kahari, Darin London, Damian Smedley, Gudmundur Arni Thorisson

=head1 CONTACT

This module is part of the BioMart project
http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut

#------------------------------------------------------------------------

package BioMart::Initializer;

use strict;
use warnings;

use IO::File;
use BioMart::Configurator;
use BioMart::Registry;
use Data::Dumper;

use BioMart::Configuration::VirtualSchema;

use BioMart::Configuration::RegistryDBPointer;
use BioMart::Configuration::RegistryURLPointer;
use BioMart::Configuration::MartDBLocation;
use BioMart::Configuration::MartURLLocation;

use BioMart::Web::SiteDefs;

use XML::Simple qw(:strict);
use XML::DOM;
use Cwd;
use File::Path;
use Storable qw(store retrieve freeze nfreeze thaw);
local $Storable::Deparse = 1;
$Storable::forgive_me = 1;


# Extends BioMart::Root
use base qw(BioMart::Root);
use vars qw($REGISTRY);

use constant DEFAULTSCHEMANAME => 'default';
use constant INITBATCHSIZE =>200;
use constant MAXBATCHSIZE => 50000;
use constant VERSION => '0.5';

#------------------------------------------------------------------------

=head2 new

  Usage      :  my $initializer = BioMart::Initializer->new('registryFile'
							    =>$confFile)
  Description:  Builds BioMart configuration from a registry file. 
  Return type:  BioMart::Initializer
  Exceptions :
  Caller     :

=cut

sub _new {
     my ($self, @params) = @_;

     $self->SUPER::_new(@params);
    
     my(%params) = @params;
     my $registryFile=$params{'registryFile'};
     if (!defined ($registryFile)){
               BioMart::Exception::Configuration->throw ("Initializer needs a registry file");
     }
          
     $registryFile =~ m/(.*\/)([^\/]*)/;
     $self->attr('confDir', $1);
     $self->attr('cachedRegistries', $1.'cachedRegistries/');
     $self->attr('regFileName', $2);
     my $cahcedDirectory = $1.'cachedRegistries';
     if(!-e $cahcedDirectory) { system("mkdir $cahcedDirectory"); }    
          
     #print "\n",$registryFile, "\n",$self->get('cachedRegistries'), "\n", $self->get('regFileName') ;
     #print "\n\n\n", $self->get('registryFileDOM');
     #exit;
     
     $self->attr('dirPath', $1."Cached/"); ## absolute path to registry file directory
     ### this dollar one capturing in regex is path to registry folder and is used below at many places
     my $copyRegistryFile = $1.'registry_DOM_XML';
     $self->attr('registryFileDOM', $copyRegistryFile);     
     system("cp $registryFile $copyRegistryFile");
     $self->attr('orderedLocations', undef);          

     my $mart_registry;
     $self->attr('registry',undef);
     $self->attr('configurationUpdate','true');  ## onlt used by martview, to guess if there was anything updated

     $registryFile = $self->get('cachedRegistries') . $self->get('regFileName'); # changing it only for backup rules below
     
     

     if ($params{'registryFile'} && ( defined($params{'action'}) && ($params{'action'} eq 'clean')))          
     {
          if (-e "$registryFile.cached") { system("cp $registryFile.cached $registryFile.cached_backup"); }
          if (-e "$registryFile.min_cached_mem") { system("cp $registryFile.min_cached_mem $registryFile.min_cached_mem_backup"); }
          if (-e "$registryFile.min_cached_disk") { system("cp $registryFile.min_cached_disk $registryFile.min_cached_disk_backup"); }
          if (-e "$1Cached") { system("cp -r $1Cached $1Cached_backup"); }   
          $mart_registry = $self->init_clean(@params);     
     }
     elsif ($params{'registryFile'} && ( defined($params{'action'}) && ($params{'action'} eq 'update')))          
     {
          if (-e "$registryFile.cached") { system("cp $registryFile.cached $registryFile.cached_backup"); }
          if (-e "$registryFile.min_cached_mem") { system("cp $registryFile.min_cached_mem $registryFile.min_cached_mem_backup"); }
          if (-e "$registryFile.min_cached_disk") { system("cp $registryFile.min_cached_disk $registryFile.min_cached_disk_backup"); }
          if (-e "$1Cached") { system("cp -r $1Cached $1Cached_backup"); }   
          $self->_init(@params);          
          $mart_registry = $self->init_update(@params);               
     }
     elsif ($params{'registryFile'} && ( defined($params{'action'}) && ($params{'action'} eq 'backup'))) ## just as default            
     {
          if (-e "$registryFile.cached_backup") { system("mv $registryFile.cached_backup $registryFile.cached"); }
          if (-e "$registryFile.min_cached_mem_backup") { system("mv $registryFile.min_cached_mem_backup $registryFile.min_cached_mem"); }
          if (-e "$registryFile.min_cached_disk_backup") { system("mv $registryFile.min_cached_disk_backup $registryFile.min_cached_disk"); }

          if (-e "$1Cached_backup") { 
               system("rm -r $1Cached"); 
               system("mv $1Cached_backup $1Cached"); }             
          $mart_registry = $self->init_cached(@params);               
     }
     else ### defaults now to cached options           if ($params{'registryFile'} && ($params{'action'} eq 'cached' ))
     {
          $mart_registry = $self->init_cached(@params);               
     }          

     $self->set('registry',$mart_registry);
     if (-e $self->get('registryFileDOM')) { unlink $self->get('registryFileDOM');}
     
}

#------------------------------------------------------------------------

=head2 _init

  Usage      :  self->_init(@params) where @params as received by _new
							    
  Description:  gets the contents of meta_conf table, and populates initializer object
  Return type:  none
  Exceptions :
  Caller     :  $self

=cut

sub _init
{
     my ($self, @params) = @_;
  
     my(%params) = @params;

     $self->attr('path','/biomart/martservice');

     if( defined $REGISTRY ){ 
          $self->attr('registry', $REGISTRY);
          return $self;
     }

     $REGISTRY = undef;
     my $initbs = INITBATCHSIZE;
     $initbs = $params{'init_batchsize'} if ($params{'init_batchsize'});
     my $maxbs = MAXBATCHSIZE;
     $maxbs = $params{'max_batchsize'} if ($params{'max_batchsize'});
     $self->attr('init_batchsize',$initbs);
     $self->attr('max_batchsize',$maxbs);

     my $registryFile=$params{'registryFile'};
		# set the registryXML with the initial XML 
		my $fh = IO::File->new($registryFile, "<") or
		BioMart::Exception::Configuration->throw ("Unable to open configuration file '$registryFile', check file existence and permissions");
		my $newxml;
		while (<$fh>){
			$newxml .= $_;
		}     
		# close the network connection
		close($fh);
		#$self->_registryXML($newxml);
		$self->_registryXML('','');
		
		$self->set('registry',undef);
		$fh = IO::File->new($registryFile, "<");
		$self->_loadConfigFrom($fh);
		$fh->close();

     $REGISTRY = $self->_populateRegistry;

     #---- setting DirPaths for registry and datasetI via Registry.pm, 
     #---- and making driectory structure based on available VS    
     $REGISTRY->setDirPath($self->get('dirPath'));
     my $v_schemas = $REGISTRY->getAllVirtualSchemas();
	foreach my $schema (@$v_schemas)
	{  
                
          my $confDir = $self->get('dirPath').$schema->name()."/confTrees";
          my $ex_im_portablesDir = $self->get('dirPath').$schema->name()."/_portables";
          my $XMLDir = $self->get('dirPath').$schema->name()."/XML";
          unless(-d $confDir)
          {    
               mkpath($confDir, 1, 0711);
          }
          unless(-d $ex_im_portablesDir)
          {
               mkpath($ex_im_portablesDir, 1, 0711);
          }
          unless(-d $XMLDir)
          {
               mkpath($XMLDir, 1, 0711);
          }
     }
     #----         
     unless (@{$REGISTRY->getAllVirtualSchemas} > 0) 
          {
	         BioMart::Exception::Configuration->throw(" Problems with the retrieval of dataset configuration 
               Please check: 
               that your mart Registry files contains correct connection params, 
               that you are using the correct version on XML::Simple, 
               that BioMart  databases contain a populated meta_conf tables and
               that you have set martUser correctly if you are running in restricted data 
               access mode (populated meta_conf__user__dm)\n\n");
          }     
     $self->set('registry',$REGISTRY);     
}

#------------------------------------------------------------------------

=head2 init_cached

  Usage      :  $mart_registry = self->init_cached(@params) where @params as received by _new
							    
  Description:  gets the mart_registry object, if possible from disk
                otherwise reconfigure it from scratch 
  Return type:  $mart_registry object
  Exceptions :
  Caller     :  $self

=cut

sub init_cached
{
     my ($self, @params) = @_;
   
     my(%params) = @params;

     my $mart_registry;

     my $registryFile = $self->get('cachedRegistries') . $self->get('regFileName');# pointing to cachedRegistries directory

     #my $cachefile = $params{'registryFile'}.".cached";
     my $cachefile = $registryFile.".cached";
     
     if (-e $cachefile ) 
     {      
          print  STDERR "\nProcessing Cached Registry: $cachefile\n\n";                    
          eval{ $mart_registry = retrieve($cachefile); };
          $self->set('registry', $mart_registry);
          $self->set('configurationUpdate','false');
     }
     else
     {
          print  "\nCached Registry Unavailable...\n";          
          my $cachefile_min = undef;
          #my $cachefile_min_disk = $params{'registryFile'}.".min_cached_disk";          
          my $cachefile_min_disk = $registryFile.".min_cached_disk";
          
          #my $cachefile_min_mem = $params{'registryFile'}.".min_cached_mem";
          my $cachefile_min_mem = $registryFile.".min_cached_mem";
          
          my $previous_mode = undef;
          if (-e $cachefile_min_disk)
     	{    
         	     $previous_mode = 'LAZYLOAD';
               eval{ $mart_registry = retrieve($cachefile_min_disk); };                    
               unlink $cachefile_min_disk;
     	}
         	if (-e $cachefile_min_mem)
	     {    
               $previous_mode = 'MEMORY';
               eval{ $mart_registry = retrieve($cachefile_min_mem); };  
               unlink $cachefile_min_mem;                  
          }

          if(!$previous_mode)
          {
               print  "\nRunning Complete Clean...\n";               
               $mart_registry = $self->init_clean(@params);                  
          }
          else
          {         
               print  "\n[RUNNING UPDATE]";
               $self->_init(@params);
               $mart_registry = $self->get('registry');                              
               if (defined($params{'mode'}) && ($params{'mode'} eq 'lazyload'))
               {
                    print  ".... WITH LAZYLOADING\n";
                    $mart_registry->setMode('LAZYLOAD');  ### ========== should come here now, rather registry.
                    store($mart_registry, $cachefile_min_disk);
               }
			
		     else ### default to --memory option
		     {
                    print  " .... WITH MEMORY [default]\n";		
                    store($mart_registry, $cachefile_min_mem);
                    
		     }
               $mart_registry->configure; # need to do this to load all dset links

               store($mart_registry, $cachefile);    		          

          }            
     }     
     
     return $mart_registry;
}

#------------------------------------------------------------------------

=head2 init_clean

  Usage      :  $mart_registry = self->init_clean(@params) where @params as received by _new
							    
  Description:  reconfigure a new mart_regitry object,
                requesting new XMLs from RDBMS
  Return type:  $mart_registry object
  Exceptions :
  Caller     :  $self

=cut

sub init_clean
{
     my ($self, @params) = @_;
     my(%params) = @params;

     $self->_init(@params);     
     my $mart_registry = $self->get('registry');
    
     my $registryFile = $self->get('cachedRegistries') . $self->get('regFileName');# pointing to cachedRegistries directory    
    
     #my $cachefile = $params{'registryFile'}.".cached";
     my $cachefile = $registryFile.".cached";

     #my $cachefile_min_disk = $params{'registryFile'}.".min_cached_disk";
     my $cachefile_min_disk = $registryFile.".min_cached_disk";
     
     #my $cachefile_min_mem = $params{'registryFile'}.".min_cached_mem";
     my $cachefile_min_mem = $registryFile.".min_cached_mem";                                                         
                    
     if (-e $cachefile) { unlink $cachefile; }               
     if (-e $cachefile_min_disk)
     {	unlink $cachefile_min_disk;	}
     if (-e $cachefile_min_mem)
     {	unlink $cachefile_min_mem;	}

     $mart_registry->cleanXMLs(); ### clean all XMLs, should be implemented here, rather registry

     if (defined($params{'mode'}) && ($params{'mode'} eq 'lazyload'))
     {
          print  "\n[NEW CONFIGURATION] .... WITH LAZYLOADING\n";
          $mart_registry->setMode('LAZYLOAD');  ### should be implemented here, rather registry
          store($mart_registry, $cachefile_min_disk);
     }
     else ### default to --memory option
     {
          print  "\n[NEW CONFIGURATION] .... WITH MEMORY [default]\n";		
          store($mart_registry, $cachefile_min_mem);
     }
		
     $mart_registry->configure; # need to do this to load all dset links

     store($mart_registry, $cachefile);    		          

     return $mart_registry;          
}

#------------------------------------------------------------------------

=head2 init_update

  Usage      :  $mart_registry = self->init_update(@params) where @params as received by _new
							    
  Description:  runs an update on existing XMLs based on their
                modified DATE/TIME STAMP, and updates any XML
                if needed, followed by reconfiguring registry object
  Return type:  $mart_registry object
  Exceptions :
  Caller     :  $self

=cut

sub init_update
{
     my ($self, @params) = @_;
   
     my(%params) = @params;
     my $mart_registry = $self->get('registry');        
     
     my $registryFile = $self->get('cachedRegistries') . $self->get('regFileName');# pointing to cachedRegistries directory     
     
     my $reConfigure = 'false';
     my $previous_mode = undef ; # 'MEMORY', or 'LAZYLOAD'
     my $cachefile_min;
     #my $cachefile = $params{'registryFile'}.".cached"; 
     #my $cachefile_min_disk  = $params{'registryFile'}.".min_cached_disk";
     #my $cachefile_min_mem  = $params{'registryFile'}.".min_cached_mem"; 
     my $cachefile = $registryFile.".cached"; 
     my $cachefile_min_disk  = $registryFile.".min_cached_disk";
     my $cachefile_min_mem  = $registryFile.".min_cached_mem"; 
     
     if (-e $cachefile_min_disk)
     {    
          $cachefile_min = $cachefile_min_disk;	
          $previous_mode = 'LAZYLOAD';
     }
     if (-e $cachefile_min_mem)
	{    
          $cachefile_min = $cachefile_min_mem;
          $previous_mode = 'MEMORY';
     }
     if (! -e $cachefile || !$previous_mode)
     {
          print  "\n[REGISTRY OBJECT DOESNT EXIST] Reconfiguring using possible cached information !!!\t";
          $reConfigure = 'true';													 
     }
     else
     {
          my $mart_registry_min; 
    	     eval{ $mart_registry_min = retrieve($cachefile_min); };			# old mart registry from disk
          my $v_schemasA = $mart_registry->getAllVirtualSchemas();
          foreach my $schemaA (@$v_schemasA)
          {
               my $schemaB = $mart_registry_min->getVirtualSchemaByName($schemaA->name());
               if( ($schemaB) && ($schemaA->name() eq $schemaB->name()) )	
               {
                    my $allLocationsA = $schemaA->getAllLocations();       
                    my $allLocationsB = $schemaB->getAllLocations(); 
                    #print  scalar @$allLocationsA, "  :::  ", scalar @$allLocationsB, "\n";   
                    if(scalar @$allLocationsA == scalar @$allLocationsB)       ## check number of locations
                    {
                         for (my $i=0; $i < scalar @$allLocationsA; $i++)
                         {
                              #print  $schemaA->name(), " :::: ", $$allLocationsB[$i]->name(), " : ", $$allLocationsB[$i]->host(), " : " ,$$allLocationsB[$i]->host() ;
                              if ( ( (defined($$allLocationsA[$i]->name()) || defined($$allLocationsB[$i]->name())) &&  ($$allLocationsA[$i]->name() ne $$allLocationsB[$i]->name()) )
                              ||   ( (defined($$allLocationsA[$i]->displayName()) || defined($$allLocationsB[$i]->displayName())) &&  ($$allLocationsA[$i]->displayName() ne $$allLocationsB[$i]->displayName()) ) 
                              ||   ( (defined($$allLocationsA[$i]->host()) || defined($$allLocationsB[$i]->host())) &&  ($$allLocationsA[$i]->host() ne $$allLocationsB[$i]->host()) )
                              ||   ( (defined($$allLocationsA[$i]->port()) || defined($$allLocationsB[$i]->port())) &&  ($$allLocationsA[$i]->port() ne $$allLocationsB[$i]->port()) ) 
                              ||   ( (defined($$allLocationsA[$i]->default()) || defined($$allLocationsB[$i]->default())) &&  ($$allLocationsA[$i]->default() ne $$allLocationsB[$i]->default()) )
                              ||   ( (defined($$allLocationsA[$i]->visible()) || defined($$allLocationsB[$i]->visible())) &&  ($$allLocationsA[$i]->visible() ne $$allLocationsB[$i]->visible()) )
                              ||   ( (defined($$allLocationsA[$i]->includeDatasets()) || defined($$allLocationsB[$i]->includeDatasets())) &&  ($$allLocationsA[$i]->includeDatasets() ne $$allLocationsB[$i]->includeDatasets()) )
                              ||   ( (defined($$allLocationsA[$i]->martUser()) || defined($$allLocationsB[$i]->martUser())) &&  ($$allLocationsA[$i]->martUser() ne $$allLocationsB[$i]->martUser()) )
                              ||   ( (defined($$allLocationsA[$i]->schema()) || defined($$allLocationsB[$i]->schema())) &&  ($$allLocationsA[$i]->schema() ne $$allLocationsB[$i]->schema()) )
                              ||   ( (defined($$allLocationsA[$i]->databaseType()) || defined($$allLocationsB[$i]->databaseType())) &&  ($$allLocationsA[$i]->databaseType() ne $$allLocationsB[$i]->databaseType()) )
                              ||   ( (defined($$allLocationsA[$i]->database()) || defined($$allLocationsB[$i]->database())) &&  ($$allLocationsA[$i]->database() ne $$allLocationsB[$i]->database()) )
                              ||   ( (defined($$allLocationsA[$i]->user()) || defined($$allLocationsB[$i]->user())) &&  ($$allLocationsA[$i]->user() ne $$allLocationsB[$i]->user()) )
                              ||   ( (defined($$allLocationsA[$i]->password()) || defined($$allLocationsB[$i]->password())) &&  ($$allLocationsA[$i]->password() ne $$allLocationsB[$i]->password()) )
                              ||   ( (defined($$allLocationsA[$i]->proxy()) || defined($$allLocationsB[$i]->proxy())) &&  ($$allLocationsA[$i]->proxy() ne $$allLocationsB[$i]->proxy()) )
                              ||   ( (defined($$allLocationsA[$i]->path()) || defined($$allLocationsB[$i]->path())) &&  ($$allLocationsA[$i]->path() ne $$allLocationsB[$i]->path()) ) 
                              ||   ( (defined($$allLocationsA[$i]->serverVirtualSchema()) || defined($$allLocationsB[$i]->serverVirtualSchema())) &&  ($$allLocationsA[$i]->serverVirtualSchema() ne $$allLocationsB[$i]->serverVirtualSchema()) ) )
                              {
                                   $reConfigure = 'true'; #### Location Parameters are different
                                   #print  "IAM HERE, as PARAMETERS DIFFER\n";
                              }

                         }                                                  
                         if ($reConfigure ne 'true') 
                         {    my $databasesA = $mart_registry->getAllDatabaseNames($schemaA->name()); ## databases are locations as per old API calls
                              foreach my $database_nameA (@$databasesA)
                              {	                                   
                                   my $datasetsA = $mart_registry->getAllDataSetsByDatabaseName($schemaA->name(), $database_nameA);
                                   foreach my $dataset_nameA(@$datasetsA)
                                   {
                                        ## dataset is of type TABLESET/GS so you can call methods of DATASETI on it.
                                        my $datasetA = $mart_registry->getDatasetByName($schemaA->name(), $dataset_nameA); 
                                        my $datasetB = $mart_registry_min->getDatasetByName($schemaA->name(), $dataset_nameA); 
                                        if ($datasetA->modified() ne $datasetB->modified())
                                        {
                                             # unlink the xml file, if it exists
                                             #print "\n I'm NOT HAPPY with modified DATE : TIME, b'coz have to out extra effort now...";
                                             my $cleanFile .= $self->get('dirPath').$schemaA->name()."/XML/";
                                   		$cleanFile .= $datasetB->locationName().".".$datasetB->name();
                                             #$cleanFile .= $datasetB->getParam('configurator')->get('location')->database().".".$datasetB->name();
                         				my $interfacesList = $datasetB->interfaces(); # should return a comma separated list of interfaces
                                             my @interfacesArray = split /,/,$interfacesList; 
                              			foreach my $interface(@interfacesArray)
                                             {
                                            		my $temp = $cleanFile;
                                           		$temp .= ".".$interface;
                        	                    	if(-e $temp) { unlink $temp; } #### may be its a new dataset
                                             }
                                       		$reConfigure = 'true';													
                             	          }
                                   }
                              }
                         }	
                    }
                    else  ### reconfigure because number of locations under the same virtual schema differ
                    {
                         $reConfigure = 'true';                         
                    }	
               }
               else ## reconfigure because, virtualschemas name is different
               {
                    $reConfigure = 'true';
               }
          } 
    }

     ### Reconfigure Registry object again
   	if ($reConfigure eq 'true' || ($previous_mode eq 'MEMORY' && $params{'mode'} eq 'lazyload') || ($previous_mode eq 'LAZYLOAD' 
                                     && $params{'mode'} ne 'lazyload'))
   	{                  
          if ($reConfigure eq 'false')  {$self->set('configurationUpdate','false'); }
          if (-e $cachefile) { unlink $cachefile; }
          if (-e $cachefile_min_disk) {	unlink $cachefile_min_disk;	}
          if (-e $cachefile_min_mem)  {	unlink $cachefile_min_mem;	}
	    
          if ((defined($params{'mode'}) && ($params{'mode'} eq 'lazyload')))
          {
    			print  "\n[UPDATING] .... WITH LAZYLOADING\n";
    			$mart_registry->setMode('LAZYLOAD');           ### needs to be shifted here, I guess rather in registry
  			store($mart_registry, $cachefile_min_disk);
          }
			
          else ### default to --memory option
          {
               print  "\n[UPDATING] .... WITH MEMORY [default]\n";		
               store($mart_registry, $cachefile_min_mem);
          }
          $mart_registry->configure; # need to do this to load all dset links
          store($mart_registry, $cachefile);	
   	}   
     else ### retrieve the old mart registry and set it to current object;
     {
          #my $existingRegistry = $params{'registryFile'}.".cached";
          my $existingRegistry = $registryFile.".cached";
          eval{ $mart_registry = retrieve($existingRegistry); };
          $self->set('configurationUpdate','false');          
     }
     return $mart_registry;	
}



=head2 configurationUpdated

  Usage      :  $init->configurationUpdated()

  Description:  Returns true or false to check if there was anything updated, ONLY for martview
  Return type:  true/false
  Exceptions :
  Caller     :  configure.pl

=cut

sub configurationUpdated
{
     my ($self) = @_;
     return $self->get('configurationUpdate');
}

=head2 getRegistry

  Usage      :  my $registry = $initializer->getRegistry();

  Description:  Returns the BioMart::Registry object
                containing information for all loaded
                BioMart::Dataset objects.
  Return type:  BioMart::Registry
  Exceptions :
  Caller     :

=cut

sub getRegistry {
     my $self = shift;

     # temper registry object to embed settings.conf parameters.
     my $registryObj = $self->get('registry');
     my $settingsHash = BioMart::Web::SiteDefs->getSettings($self->get('confDir'));
    
     $registryObj->settingsParams($settingsHash);
     return $registryObj;
}


=head2 reloadRegistry

  Usage      :  $initializer->reloadRegistry();

  Description:  adds an already created registry object
  Return type:  
  Exceptions :
  Caller     :

=cut

sub reloadRegistry
{
    my $self = shift;
    $REGISTRY  = $self->get('registry');
}

#--------------------------------------------------------------

# $source can be an IO::Handle object, or a 
# string of xml text.  See the documentation
# for XML::Simple::XMLin for details. If $source
# is null, returns undef

sub _loadConfigFrom {

	my ($self, $source, $vSchemaName, $vSchemaDisplayName, $includeMarts,$proxy) = @_;

	return undef unless($source);
	#-------------------
	my $hashLocations;
	my $configurePass = 0;
	my $parserDOM = XML::DOM::Parser->new();
	my $doc = $parserDOM->parsefile($self->get('registryFileDOM'));
	my $vSchemaNodes = $doc->getElementsByTagName('virtualSchema');
	if($vSchemaNodes->getLength() > 0) {
		if($vSchemaNodes->getLength() == 1 && !$vSchemaNodes->[0]->getAttribute('default')) {
  			$configurePass = 1;			
		}		
		foreach my $vSchemaNode(@$vSchemaNodes) { ## check if there exists a VS with a default=1 otherwise no need to configure
     		if ($vSchemaNode->getAttribute('default')) {
     			$configurePass = 1;
     		}     		
     	}
		if (!$configurePass) {
			BioMart::Exception::Configuration->throw("\n\t\tInitializer.pm: Set at least one virtaulSchema attribute default=\"1\" ");
			exit;
		}
		foreach my $vSchemaNode(@$vSchemaNodes) {
			my $children = $vSchemaNode->getChildNodes;
			if($children) {
				foreach my $childNode (@$children) {
					if($childNode->isa('XML::DOM::Element')) {
						push @{$hashLocations->{$vSchemaNode->getAttribute('name')}}, $childNode->getAttribute('name');
					}
				}
			}          
		}
	}
     else ## assume its a 'default' VS
     {
          my $martRegistryNode = $doc->getElementsByTagName('MartRegistry');
          foreach my $allNodes (@$martRegistryNode) {          
               my $node = $allNodes->[0]; 
               foreach my $location (@$node) {
                    if($location->isa('XML::DOM::Element')) {
                         push @{$hashLocations->{'default'}}, $location->getAttribute('name');
                    }                   
               }
          }         
     }     
     $self->set('orderedLocations',$hashLocations);
   
     $doc->dispose();

     my $config = XMLin($source, forcearray=> [qw(virtualSchema 
       RegistryDBPointer RegistryURLPointer MartDBLocation MartURLLocation)], 
       keyattr => []);

    #the first time this method is called, $vSchemaName will be null,
    #which signals it to load locations without a virtualSchema into
    #defaultSchema. Subsequent recursive calls will have $vSchemaName
    #defined, which will signal it to load locations without a
    #virtualSchema into the given $vSchemaName (which could actually
    #still be the defaultSchema from the original call).
    #Thus, locations without a virtualSchema can be explicitly
    #defined into a virtualSchema at the Registry level, by
    #placing a virtualSchema wrapper around the RegistryDBLocation, but
    #any location within a virtualSchema wrapper in the registry pointed
    #to down the chain will override this virtualSchema
    

    my $registry = $self->get('registry');

    if (!defined $registry) {
	$registry = BioMart::Registry->new();
	$self->set('registry', $registry);     
    }
    
    my $dSchema = (defined($vSchemaName)) ? $vSchemaName : DEFAULTSCHEMANAME;
    my $schemaDisplayName = (defined($vSchemaDisplayName)) ? 
	$vSchemaDisplayName : DEFAULTSCHEMANAME;

	my $virtualSchema = $registry->getVirtualSchemaByName(DEFAULTSCHEMANAME);
	if (!defined $virtualSchema) {
		$virtualSchema = BioMart::Configuration::VirtualSchema->new(
			name => $dSchema,
			displayName => $schemaDisplayName
    	);
$virtualSchema->visible(0);
    }

    $virtualSchema = $self->_loadLocationsFrom($virtualSchema, $config, 
    		$includeMarts,$proxy);
    		
    if (!defined $registry->getVirtualSchemaByName(DEFAULTSCHEMANAME)) {
    	$registry->addVirtualSchema($virtualSchema)
			if ($virtualSchema && (@{$virtualSchema->getAllLocations} > 0));
    }
    
    foreach my $vSchemaNode (@{$config->{'virtualSchema'}}) {
		$virtualSchema = $registry->getVirtualSchemaByName($vSchemaNode->{'name'});
		if (!defined $virtualSchema){
  	    	$virtualSchema = BioMart::Configuration::VirtualSchema->new(
	      		name => $vSchemaNode->{'name'},
	       		displayName => $vSchemaNode->{'displayName'} || ''
	  		);
	  		$virtualSchema->visible(0) if (!$vSchemaNode->{'visible'});
			$registry->addVirtualSchema($virtualSchema);
        }
		$virtualSchema = $self->_loadLocationsFrom($virtualSchema, 
						   $vSchemaNode, $includeMarts,$proxy);
    }   

	
	$self->set('registry', $registry);
    $registry->toXML($self->_registryXML);
 }


sub _loadLocationsFrom {
	my ($self, $virtualSchema, $node, $includeMarts,$proxy) = @_;
	my $vSchemaName = $virtualSchema->name;
	my $vSchemaDisplayName = $virtualSchema->displayName;

	if ($node->{'default'}){
		$virtualSchema->default(1);
	}    
	#-------------------------------------------------------
	my $orderedLocations = $self->get('orderedLocations');
	#  print "\n  ============ ", $vSchemaName;
	if($self->get('orderedLocations')->{$vSchemaName})
	{
		foreach my $locationName(@{$self->get('orderedLocations')->{$vSchemaName}})
		{
			#print "\nDOM LOCATION    ====  ",$locationName, "\n";
			my @rtypes=('RegistryDBPointer','RegistryURLPointer');
			foreach my $rtype (@rtypes){
				foreach my $regdbloc (@{$node->{$rtype}}) {
					#print "\nREG LOCATION    ====  ",$regdbloc->{'name'}, "\n";
					if ($regdbloc->{'name'} eq $locationName)
					{    
						$self->_setRegistryPointer($rtype,$vSchemaName, $vSchemaDisplayName,$regdbloc); 
					}
				}
			}
			my @mtypes=('MartDBLocation','MartURLLocation');
			foreach my $mtype (@mtypes){
				foreach my $dbloc (@{ $node->{$mtype} }) {
					if ($dbloc->{'name'} eq $locationName)	{
						# if includeMarts set then check if on list - if not next
						if ($includeMarts){
							my $seen;
							foreach my $martName(split(/,/,$includeMarts)) {
          		               	if ($martName !~ /\./){
           			               $martName = 'default.'.$martName;
								}
								if ($vSchemaName.'.'.$dbloc->{'name'} eq $martName) {
									$seen++;
									last;
								}
							}
							next if (!$seen);
						}
						
						my $martLocation =   $self->_setMartLocation($mtype,$virtualSchema,$dbloc,$proxy);
						next if (!$martLocation);
						# serverVirtualSchema for martservice,
						if (!$dbloc->{'serverVirtualSchema'}) {
							$dbloc->{'serverVirtualSchema'} = $virtualSchema->name();
						}
						$self->_registryXML($mtype, $dbloc);
						$virtualSchema->addLocation($martLocation);   		
					}
				}
			}
		}
	}
	#-------------------------------------------------------
	warn("\n");
	# validation of Registry file
	my @knownTypes=('virtualSchema', 'RegistryDBPointer','RegistryURLPointer',
		'MartDBLocation','MartURLLocation','DatabaseLocation','RegistryDBLocation');
	foreach my $locType (keys %$node){
	# skip empty keys
		next if (!ref $node->{$locType} || !@{$node->{$locType}});
		if (! grep $locType eq $_, @knownTypes){
			warn("... Unknown location type:$locType\n");
			next;
		}
		foreach my $loc (@{$node->{$locType}}){
			# replace warns with die before 0_4 release
			warn("Warning: DatabaseLocation is replaced with MartDBLocation in 0_4. Fix your registry for ".$loc->{'name'}."\n") 
				if ($locType eq 'DatabaseLocation');
			warn("Warning: RegistryDBLocation is replaced with RegistryDBPointer in 0_4. Fix your registry for ".$loc->{'name'}."\n") 
				if ($locType eq 'RegistryDBLocation');
		}
	}
	warn("\n");
	return $virtualSchema;
}


sub _setRegistryPointer {
    my ($self,$type,$vSchemaName,$vSchemaDisplayName,$regdbloc)=@_;
    
    my $pointer = $self->_setLocation($type,$regdbloc);
    my $regXML = $pointer->getRegistryXML();
    my $regDOMFILE = $self->get('registryFileDOM');
    open (STDXML, ">$regDOMFILE");
    print STDXML $regXML;
    close(STDXML);
    $self->_loadConfigFrom($regXML, $vSchemaName,$vSchemaDisplayName,$regdbloc->{'includeMarts'},$regdbloc->{'proxy'});
}


sub _setMartLocation {
    my ($self,$type,$virtualSchema,$dbloc,$proxy)=@_;

    my $martLocation=$self->_setLocation($type,$dbloc,$proxy);
    return $martLocation;  
}




sub _setLocation {   
    my ($self,$type,$dbloc,$proxy)=@_;
    
    my $module = sprintf("BioMart::Configuration::%s", $type);
    $self->loadModule($module);

    # validate parameters
    my (@required,@optional,$name);
    if ($type eq 'RegistryURLPointer'){
	@required = qw(host port);
	@optional = qw(includeMarts path);
    }
    elsif ($type eq 'RegistryDBPointer'){
	@required = qw(host port database schema databaseType user password);
	@optional = qw(includeMarts);
    }
    elsif ($type eq 'MartURLLocation'){
	@required = qw(name displayName host port);
	@optional = qw(serverVirtualSchema visible default martUser 
		       includeDatasets path);
    }
    elsif ($type eq 'MartDBLocation'){
	@required = qw(name displayName host port schema databaseType database 
		       user password);
	@optional = qw(visible default martUser includeDatasets );
    }

    foreach (@required){
	$name = defined $dbloc->{'name'} ? $dbloc->{'name'} : '';
	# replace warn with die for 0_4 release
          if (!defined($dbloc->{$_}))	
          {               
               BioMart::Exception::Configuration->throw("Initializer.pm: No setting for required parameter $_ in $type location:$name, Please check your registry file for parameter '$_' ");
          }
    }
    foreach (@optional){
	$name = defined $dbloc->{'name'} ? $dbloc->{'name'} : '';
	# replace warn with die for 0_4 release
	warn("Optional setting for $_ in $type location:$name not defined - setting to default values \n") if (!defined($dbloc->{$_}));
    }
    my $location;
      eval {
	  $location = $module->new(
	name => $dbloc->{'name'},
	displayName  => $dbloc->{'displayName'},
	host         => $dbloc->{'host'},
	port         => $dbloc->{'port'},
	default      => $dbloc->{'default'} || '',
	visible      => $dbloc->{'visible'} || 0,
	includeDatasets => $dbloc->{'includeDatasets'} || '',
	martUser      => $dbloc->{'martUser'} || '',
        schema        => $dbloc->{'schema'},
	databaseType => $dbloc->{'databaseType'},
	database => $dbloc->{'database'},
	user  => $dbloc->{'user'},
	password =>$dbloc->{'password'},
        proxy  => $dbloc->{'proxy'} || $proxy,
        path  => $dbloc->{'path'} || $self->get('path'),
				   serverVirtualSchema  => $dbloc->{'serverVirtualSchema'} || 'default',);
  };
  if($@ || !$location) {
      warn("\n\n\n !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                \n COULD NOT CONNECT TO DATABASE ".$dbloc->{'database'}.".CHECK YOUR SETTINGS\n 
 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! \n\n\n");
      
  }
  else {
        if($dbloc->{'displayName'}){
             print STDERR "\nConnection parameters of [".$dbloc->{'displayName'}."]\t[ OK ]";
        }
  }   
  return $location;
}

sub _populateRegistry {
    my $self = shift;

    my $registry = $self->get('registry');
    my %configurators;
    # below stops ref problems if virtualSchemas get removed during loop
    my $virtualSchemas = [ @{$registry->getAllVirtualSchemas} ];
    foreach my $virtualSchema (@{$virtualSchemas}){
	# below stops ref problems if locations get removed during loop
	my $locations = [ @{$virtualSchema->getAllLocations} ];
	foreach my $location (@{$locations}){


############################################### hack to change include datasets list to include invisible ones too
############################################### For 0.6, simply shift delete this code in # OR the following if block
		if($location->includeDatasets())
		{
			my %configurators_1;
			my @dataSets = $location->retrieveDatasetInfo($virtualSchema->name, $virtualSchema->default);
			my %pointerDS;
		    
    	   	
     	if(!scalar (@dataSets))
         {    my $name=$location->name;
               #BioMart::Exception::Configuration->throw("\n
               #No datasets available with given parameters for Location: $name\n");
               warn("\n
               No datasets available with given parameters for Location: $name\n");
          }
	 foreach my $datasetData (@dataSets){
		my $dataSetName = lc($datasetData->{'dataset'});
		if ($virtualSchema->getDatasetByName($dataSetName)){
		    BioMart::Exception::Configuration->throw("
               Dataset '${dataSetName}' is duplicated in virtualSchema '$virtualSchema->name'
               Please rename datasets in meta_conf tables or separate conflicting datasets 
               into different virtual schemas in defaultMartRegistry.xml\n\n");
		}

		my $configuratorKey_1;
		if($location->database)
		{
		     $configuratorKey_1 = $location->database.'_'.$location->host.'_'.$location->port;
		}
		else ## dicty case
		{
		     $configuratorKey_1 = $location->name.'_'.$location->host.'_'.$location->port;
		}
		
		my $configurator_1 = $configurators_1{$configuratorKey_1};
		if (!defined $configurator_1) {
		    $configurator_1 = BioMart::Configurator->new($registry,
							       $location);
		    $configurators_1{$configuratorKey_1} = $configurator_1;
		}
		my $datasetModule =
		    sprintf("BioMart::Dataset::%s", $datasetData->{'type'});

		$self->loadModule($datasetModule);
		my $dataset = $datasetModule->new(
		  'name'              => $datasetData->{'dataset'},
                  'display_name'      => $datasetData->{'displayName'} || '',
                  'configurator'      => $configurator_1,
                  'initial_batchsize' => $datasetData->{'initialBatchSize'} || 
					 $self->get('init_batchsize'),
                  'max_batchsize'     => $datasetData->{'maxBatchSize'} || 
					 $self->get('max_batchsize'),
                  'visible'           => $datasetData->{'visible'} || 0,
	 	  'version'           => $datasetData->{'version'} || '',
		  'interfaces'        => $datasetData->{'interfaces'} || 
					 'default',
                  'modified'          => $datasetData->{'modified'} || 
					 'MODIFIED_UNAVAILABLE',
		  'locationDisplayName' => $location->displayName,
		  'locationName'            => $location->name,
                  'virtualSchema'     => $virtualSchema->name);

	
	
	
			my $configTree;
			my $xml;
			my @interfaces = split(/\,/,$dataset->interfaces);
			foreach my $interface(@interfaces){
				#$configTree = $dataset->getConfigurationTree($interface,'CREATE_ALL_LINKS');
				$xml = $dataset->getConfigurator->get('location')->getDatasetConfigXML($virtualSchema->name,
							  $dataset->name,
							  $interface,
							  0,1);	#last one is for not printing configure message
         		}
         		
			my $tempXMLHash = XMLin($xml, forcearray => [qw(AttributePage AttributeGroup 
                  AttributeCollection AttributeDescription FilterPage FilterGroup 
                  FilterCollection FilterDescription Importable Exportable Key 
                MainTable BatchSize SeqModule Option PushAction)], keyattr => []);

          	my $softwareVersion = $tempXMLHash->{'softwareVersion'};
               if (!$softwareVersion || ($softwareVersion eq '0.4')) 
                {       
                    #print STDERR "->  upgrading to 0.5 ... ";
     	          my $params=BioMart::Web::CGIXSLT::read_https();
	               open(STDOUTTEMP, ">temp.xml");
               	print STDOUTTEMP $xml;
          	     close(STDOUTTEMP);               
     	          $params->{'source'} = 'temp.xml';              
	               $params->{'style'} = $self->get('confDir').'/mart_0_4_0_5.xsl';
               	my $new_xml;
          	     eval{$new_xml=BioMart::Web::CGIXSLT::transform();};
     	          if($@){BioMart::Web::CGIXSLT::print_error("Exception: Configurator Cannot parse xml as per xsl. $@\n"); exit;};
	               #Now, we are printing and saving what we get
          	     $xml = BioMart::Web::CGIXSLT::print_output($new_xml);
               	if (-e 'temp.xml')
     	          {
	                    unlink 'temp.xml';           
               	}                          
                           
          	}

	my $xmlHash = XMLin($xml, forcearray => [qw(AttributePage AttributeGroup 
		AttributeCollection AttributeDescription AttributeList FilterPage FilterGroup 
		FilterCollection FilterDescription Importable Exportable Key 
        	MainTable BatchSize SeqModule Option PushAction)], keyattr => []);              
     

	foreach my $xmlAttributeTree (@{ $xmlHash->{'AttributePage'} }) {
		next if ($xmlAttributeTree->{'hidden'} && $xmlAttributeTree->{'hidden'} eq 'true');
     	foreach my $xmlAttributeGroup (@{ $xmlAttributeTree->{'AttributeGroup'} }) {
		next if ($xmlAttributeGroup->{'hidden'} && $xmlAttributeGroup->{'hidden'} eq 'true');
          	foreach my $xmlAttributeCollection(@{ $xmlAttributeGroup->{'AttributeCollection'} }) {
               	next if ($xmlAttributeCollection->{'hidden'} && $xmlAttributeCollection->{'hidden'}eq 'true');
				foreach my $xmlAttribute (@{ $xmlAttributeCollection->{'AttributeDescription'} }) {
					next if ($xmlAttribute->{'hidden'} && $xmlAttribute->{'hidden'} eq 'true');                    	
		    			if ($xmlAttribute->{'pointerDataset'})  ## ACTION TIME
		    			{ 
						$pointerDS{$xmlAttribute->{'pointerDataset'}}++;	# increamenting for debugggni purpose only
		    			}
		    		}
		    	}
		}
	}

    	foreach my $xmlFilterTree (@{ $xmlHash->{'FilterPage'} }) {
        	next if ($xmlFilterTree->{'hidden'}  && $xmlFilterTree->{'hidden'} eq 'true');
		foreach my $xmlFilterGroup (@{ $xmlFilterTree->{'FilterGroup'} }) {
          	next if ($xmlFilterGroup->{'hidden'} && $xmlFilterGroup->{'hidden'} eq 'true');
	          foreach my $xmlFilterCollection (@{ $xmlFilterGroup->{'FilterCollection'} }) {
	          	next if ($xmlFilterCollection->{'hidden'}  && $xmlFilterCollection->{'hidden'} eq 'true');
	               foreach my $xmlFilter (@{ $xmlFilterCollection->{'FilterDescription'} }) {
	               	next if ($xmlFilter->{'hidden'}     && $xmlFilter->{'hidden'} eq 'true');
	    			 	if ($xmlFilter->{'pointerDataset'}) ## ACTION TIME
				    	{
						$pointerDS{$xmlFilter->{'pointerDataset'}}++;# increamenting for debugggni purpose only
				    	}	
				}
			}
		}
	}

	} ## end of for loop each dataset



			if (%pointerDS) {
				## first add the ones which already exists
				my @oldList = split (/\,/,$location->includeDatasets());
				foreach (@oldList){
					$pointerDS{$_}++; # increamenting for debugggni purpose only
				}				
				my $includeList;
				foreach (keys %pointerDS) {
					if($includeList){ $includeList .= ','.$_ ;	}
					else {$includeList .= $_ ;}
				}
				
				$location->includeDatasets($includeList);				
			}
			
		}	## end of if block - hack for tempering includeDataset list
##################################################################################
	    my @datasets = $location->retrieveDatasetInfo($virtualSchema->name, $virtualSchema->default);
          if(!@datasets)
          {    my $name=$location->name;
               #BioMart::Exception::Configuration->throw("\n
               #No datasets available with given parameters for Location: $name\n");
               warn("\n
               No datasets available with given parameters for Location: $name\n");
          }
	    foreach my $datasetData (@datasets){
		my $dataSetName = lc($datasetData->{'dataset'});
		if ($virtualSchema->getDatasetByName($dataSetName)){
		    BioMart::Exception::Configuration->throw("
               Dataset '${dataSetName}' is duplicated in virtualSchema '$virtualSchema->name'
               Please rename datasets in meta_conf tables or separate conflicting datasets 
               into different virtual schemas in defaultMartRegistry.xml\n\n");
		}

		my $configuratorKey;
		if($location->database)
		{
		     $configuratorKey = $location->database.'_'.$location->host.'_'.$location->port;
		}
		else ## dicty case
		{
		     $configuratorKey = $location->name.'_'.$location->host.'_'.$location->port;
		}
		
		my $configurator = $configurators{$configuratorKey};
		if (!defined $configurator) {
		    $configurator = BioMart::Configurator->new($registry,
							       $location);
		    $configurators{$configuratorKey} = $configurator;
		}
		my $datasetModule =
		    sprintf("BioMart::Dataset::%s", $datasetData->{'type'});

		$self->loadModule($datasetModule);
		my $dataset = $datasetModule->new(
		  'name'              => $datasetData->{'dataset'},
                  'display_name'      => $datasetData->{'displayName'} || '',
                  'configurator'      => $configurator,
                  'initial_batchsize' => $datasetData->{'initialBatchSize'} || 
					 $self->get('init_batchsize'),
                  'max_batchsize'     => $datasetData->{'maxBatchSize'} || 
					 $self->get('max_batchsize'),
                  'visible'           => $datasetData->{'visible'} || 0,
	 	  'version'           => $datasetData->{'version'} || '',
		  'interfaces'        => $datasetData->{'interfaces'} || 
					 'default',
                  'modified'          => $datasetData->{'modified'} || 
					 'MODIFIED_UNAVAILABLE',
		  'locationDisplayName' => $location->displayName,
		  'locationName'            => $location->name,
                  'virtualSchema'     => $virtualSchema->name);

		if ($location->isa("BioMart::Configuration::MartURLLocation")){
		    $dataset->serverType("web");		    
		}
		else{
		    $dataset->serverType("rdbms");
		    $dataset->schema($location->schema);
		}
		
		
		
		$location->addDataset($dataset);
	    }
	    if (@{$location->getAllDatasets} == 0){
		$virtualSchema->removeLocation($location);
	    }
	}
	if (@{$virtualSchema->getAllLocations} == 0){
	    $registry->removeVirtualSchema($virtualSchema);
	}
    }
    return $registry;
}

sub _registryXML {
	my ($self, $type, $contentsHash) = @_;
	if ($type && $contentsHash) {
		my @attributes = qw(name displayName host port schema serverVirtualSchema databaseType database user password visible default martUser includeDatasets path redirect proxy );
		my $reg_xml = $self->{'registryXML'};
		my $node = '';
		# first time here, add XML DOC, and MartRegistry Tags
		if (!$reg_xml)
		{
			$reg_xml .= "<?xml version=\"1.0\" encoding=\"UTF-8\"?><\!DOCTYPE MartRegistry><MartRegistry><\/MartRegistry>";
		}
		$node .= "<$type ";
		foreach my $key(@attributes)
		{	
			no warnings 'uninitialized';
			if(exists $contentsHash->{$key})
			{	
#				print "\n LINE   ", $key . ' = ' . '"' . $contentsHash->{$key}. '"';
				$node .= $key . ' = ' . '"' . $contentsHash->{$key}. '" ';
			}
		}
		$node .= " \/>";
		$node .= "<\/MartRegistry>";
		
		$reg_xml =~ s/<\/MartRegistry>/$node/;		
		$self->{'registryXML'} = $reg_xml;
	}
	return $self->{'registryXML'};
}

1;

# vim: et
