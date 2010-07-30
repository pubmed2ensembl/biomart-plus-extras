# $Id: DatasetI.pm,v 1.30 2008-04-09 12:52:33 syed Exp $

# BioMart module for BioMart::DatasetI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::DatasetI

=head1 SYNOPSIS

BioMart::DatasetI objects provide a flexible framework to
allow almost any data source to be made into a BioMart dataset.
This is done by mapping the various attributes and filters into
a ConfigurationTree object, and creating any exportables and
importables that Link a given dataset to other datasets.

=head1 DESCRIPTION

The BioMart::DatasetI interface allows any data source
with attributes and filters to be made into a BioMart
dataset, regardless of its underlying access mode (RDBMS,
file system, etc).  Each implementation must provide access
to a BioMart::Configuration::ConfigurationTree object
describing its attributes and filters (see perlpod of
BioMart::Configuration::ConfigurationTree object for more
details).

Implementations can also export attributes to other datasets
to be used as filters in those systems, using the Links API.
This provides a way of functionally linking two datasets
together using a common name.  Exporting datasets should link
this name to a BioMart::Configuration::AttributeList object
containing one or more BioMart::Configuration::Attribute objects
representing the 'Exportable' for this dataset.

The AttributeList is added to the query targeted for the
exporting subsysytem by the QueryRunner to satisfy the Link
requirements.  Importing datasets should link this name to
a BioMart::Configuration::FilterList object representing the
'Importable' for the importing dataset.

The QueryRunner will set the FilterList Table to the
ResultTable from the exporting dataset, and add it to the
query targeted to the importing dataset.  This allows two
datasets to implicitly define ways to chain queries between
them.

=head1 AUTHOR - Arek Kasprzyk, Syed Haider, Richard Holland, Darin London, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::DatasetI;
use strict;
use warnings;
use Digest::MD5;
use Data::Dumper;
use XML::Simple qw(:strict);
use Storable qw(store retrieve freeze nfreeze thaw);
local $Storable::Deparse = 1;
$Storable::forgive_me = 1;
use Cwd;

use DBI;

use Log::Log4perl;      
my $logger=Log::Log4perl->get_logger(__PACKAGE__);
     
use base qw(BioMart::Root);
use BioMart::ResultTable;

use constant NAME                   => "name";
use constant DISPLAYNAME            => "display_name";
use constant CONFIGURATOR           => "configurator";
use constant INIT_BATCHSIZE         => "initial_batchsize";
use constant MAX_BATCHSIZE          => "max_batchsize";
use constant VISIBLE                => "visible";
use constant VERSION                => "version";
use constant LOCATIONDISPLAY        => "locationDisplayName";
use constant LOCATIONNAME           => "locationName";
use constant VIRTSCHEMA             => "virtualSchema";
use constant SERVERTYPE             => "serverType";
use constant INTERFACES             => "interfaces";
use constant MODIFIED               => "modified";

use constant TITLES => [
               NAME,
               DISPLAYNAME,
               CONFIGURATOR,
               INIT_BATCHSIZE,
               MAX_BATCHSIZE,
               VISIBLE,
	       VERSION,
               LOCATIONDISPLAY,
               LOCATIONNAME,
               VIRTSCHEMA,
	       INTERFACES,
	       MODIFIED,		
			 ];

=head2 _new

  Usage      : my $dataset =
                   BioMart::Dataset::ImpName->new(
                        'name'                 => $name,
                        'display_name'         => $display_name,
                        'configurator'         => $configurator,
                        'initial_batchsize'    => 100,
                        'max_batchsize'        => 100000,
                        'visible'              => $visible_boolean,
                        'version'              => $version,
                        'database'             => $instanceName,
                        'schema'               => $schema,
                        'virtualSchema'        => $virtualSchema,
                        'serverType'           => $serverType,
                        'interfaces'           => $interfaces,
                        'modified'             => $modified
                   );

  Description: Creates a new instance of a BioMart::Dataset
               implementation object named by ImpName.  Requires
               a name used as the key to this dataset in
               the BioMart::Registry, and a diplay_name used
               in any User Interfaces.  Also requires a
               reference to a BioMart::Configurator object.
               Initial_batchsize must be set to determine the
               number of rows to return in all initial batches
               unless explicitly overridden with a batch_size
               on getResultTable.  Max_batchsize must
               be set to limit the number of rows returned in any
               batch of a batched query.  This should be large
               enough so that the system can initiate a query
               with a small batch_size, allowing quick response,
               while ResultTable steps its subsequent request
               batch_size up after each call to get a batch.
               The visible flag instructs Graphical Interfaces
               to present (or not) the dataset as a choice to
               users.  Non visible datasets are loaded in the
               background, transparent to the user.  The version
               is used to present visible datasets to the
               user (not required for non-visible datasets).
               Dataset creation and management is done by the
               BioMart::Configurator object.  Users should not
               need to create DatasetI implementing objects
               manually.

  Returntype : new BioMart::Dataset implementing object.

  Exceptions : Missing or invalid Required Parameters.
               Implementation specific Exceptions.

  Caller     : BioMart::Configurator

=cut

sub _new {
  my ($self, @param) = @_;
  $self->SUPER::_new(@param);
  $self->addParams(TITLES, @param);

  $self->checkRequiredParams(TITLES);

  $self->_checkValidParams;

	
  $self->attr('supportedSchemas', undef); 

  $self->attr('exportables', {}); #hash of linkName -> attributeList objects
  $self->attr('importables', {}); #hash of linkName -> filterList objects
  $self->attr('configurationTrees', {});
  $self->attr('exhausted', undef); # Dataset determines when it is exhausted
  # explicit_batching set to true if first call to getResultTable 
  # includes a batch_size
  $self->attr('explicit_batching', undef); 
  $self->attr('links', []);
  $self->attr('cluster', undef);
  $self->attr('pathHash', {});
  $self->attr('schema',undef);
  $self->attr('serverType', undef);
  $self->attr('attributeHash', {});
  $self->attr('forceHash', undef);

  $self->attr('mode', 'MEMORY'); ## defaults to MEMORY, other option is LAZYLOAD, set by Registry::setMode
  $self->attr('dirPath', undef); ## absolute path to registry file directory, set by Registry::setDirPath
  $self->attr('LastDS', undef); ## set in QueryRunner when last DS is despatched for results
  							## used to track for last GS object to apply strtucture att merging on only last GS

  $self->attr('GenomicMAlignHack', undef); ## just for Compara Mart, follows the old hashing/merging

}

sub _checkValidParams {
  my $self = shift;

  my $conf = $self->getParam(CONFIGURATOR);
  unless ($conf->isa("BioMart::Configurator")) {
    BioMart::Exception::Configuration->throw("Dataset objects require a BioMart::Configurator object parameter\nReceived object ".$conf."\n");
  }
}

sub getConfigurator {
    my $self = shift;

    return $self->getParam(CONFIGURATOR);
}

sub _getDBH {
  my $self = shift;

  my $location=$self->getParam('configurator')->get('location');
  $location->openConnection();
  return $location->dbh() 
      || BioMart::Exception::Database->throw("no dbh database handle available from mart location $location");
}

sub _setExhausted {
  my ($self, $exhausted) = @_;

  $self->set('exhausted', $exhausted);
}

=head2 _processNewQuery


  Description  :  Private interface method to reset any inter-batch state 
                  variables to their initial settings.  Also sets the 
                  exhausted flag to false. Called at the beginning of every 
                  new Query recieved (eg, when no BioMart::ResultTable object 
                  has been passed into the call to_getResultTable).  This 
                  method is only required for those DatasetI implementations 
                  which maintain state over the extent of a batched query.  
                  Implementations needing to reset their state should 
                  implement a '__processNewQuery()' method.  If it is not 
                  implemeted, it does not throw an unimplemented method 
                  exception.

=cut

sub _processNewQuery {
  my ($self, $query) = @_;

  $self->set('exhausted', undef);
  $self->set('explicit_batching', undef);
  if ($self->can('__processNewQuery')) {
     $self->__processNewQuery($query);
  }
}

=head2 serverType
 
   Usage      : set the serverType:
                $ds->serverType($name);
 
                get the serverType:
                $ds->serverType;
   Description: sets or gets the serverType of the given dataset.
   Returntype : scalar $server_type
   Exceptions : none
   Caller     : caller
 
=cut
 
 sub serverType {
   my ($self, $newname) = @_;
 
   if ($newname) {
     $self->set(SERVERTYPE, $newname);
   }
   return $self->get(SERVERTYPE);
 }

=head2 interfaces
 
   Usage      : set the interfaces:
                $ds->interfaces($name);
 
                get the interfaces:
                $ds->interfaces;
   Description: sets or gets the interfaces of the given dataset.
   Returntype : scalar $interfaces
   Exceptions : none
   Caller     : caller
 
=cut
 
sub interfaces {
   my ($self, $interfaces) = @_;
 
   if ($interfaces) {
     $self->set(INTERFACES, $interfaces);
   }
   return $self->getParam(INTERFACES);
}

=head2 schema
 
   Usage      : set the database schema of a Dataset:
                $ds->schema($name);
 
                get the database schema of a Dataset:
                $ds->schema();
   Description: sets or gets the database schema of the given dataset.
   Returntype : scalar $schema
   Exceptions : none
   Caller     : caller
 
=cut
 
sub schema {
  my ($self, $schema) = @_;

  if ($schema) {
    $self->set('schema', $schema);
  }
  return $self->get('schema');
}

=head2 forceHash
 
   Usage      : set the forceHash setting:
                $ds->forceHash($name);
 
                get the forceHash setting:
                $ds->forceHash;
   Description: sets or gets the forceHash of the given dataset. This is used
                when linking placeholder attributes from a first visible
                dataset into a second visible dataset. As a natural link
                does not exist the hashing and merging of attributes has 
                to be forced
   Returntype : scalar $forceHash
   Exceptions : none
   Caller     : caller
 
=cut
 

sub forceHash {
  my ($self, $forceHash) = @_;

  if ($forceHash) {
    $self->set('forceHash', $forceHash);
  }
  return $self->get('forceHash');
}

=head2 name

  Usage      : set the name:
               $subsys->name($name);

               get the name:
               $subsys->name;
  Description: sets or gets the name of the given dataset.
  Returntype : scalar $name
  Exceptions : none
  Caller     : caller

=cut

sub name {
  my ($self, $newname) = @_;

  if ($newname) {
    $self->setParam(NAME, $newname);
  }
  return $self->getParam(NAME);
}

=head2 modified

  Usage      : set the modified:
               $ds->modified($name);

               get the modified:
               $ds->modified;
  Description: sets or gets the modified date time of the given dataset.
  Returntype : scalar $modified TIME DATE STAMP
  Exceptions : none
  Caller     : caller

=cut

sub modified {
  my ($self, $modified) = @_;


  if ($modified) {
    $self->setParam(MODIFIED, $modified);
  }
  return $self->getParam(MODIFIED);

}

=head2 displayName

  Usage      : set the displayName:
               $ds->displayName($name);

               get the displayName:
               $ds->displayName;
  Description: sets or gets the displayName of the given dataset.
  Returntype : scalar $dispname
  Exceptions : none
  Caller     : caller

=cut

sub displayName {
  my ($self, $newname) = @_;

  if ($newname) {
    $self->setParam(DISPLAYNAME, $newname);
  }
  return $self->getParam(DISPLAYNAME);
}


=head2 virtualSchema

  Usage      : set the virtualSchema:
               $ds->virtualSchema($name);

               get the virtualSchema:
               $ds->virtualSchema;
  Description: sets or gets the virtualSchema of the given dataset.
  Returntype : scalar $virtualSchema or undef
  Exceptions : none
  Caller     : caller

=cut

sub virtualSchema {
  my ($self, $newname) = @_;

  if ($newname) {
     $self->setParam(VIRTSCHEMA, $newname);
   }
   return $self->getParam(VIRTSCHEMA);
}


=head2 visible

  Usage        :  if ($dset->visible) { .. }
  Description  :  Sets/gets visible for a dataset
                  
  Returntype   :  boolean, true if visible, false otherwise
  Exceptions   :  na
  Caller       :  BioMart::QueryRunner

=cut

sub visible {
  my ($self, $visible) = @_;

  if ($visible) {
    $self->setParam(VISIBLE, $visible);
  }
  return $self->getParam(VISIBLE);
}

=head2 version

  Usage        :  if ($dset->version) { .. }
  Description  :  Sets/gets version for a dataset
                  
  Returntype   :  version
  Exceptions   :  na
  Caller       :  BioMart::QueryRunner

=cut

sub version {
  my ($self, $version) = @_;

  if ($version) {
    $self->setParam(VERSION, $version);
  }
  return $self->getParam(VERSION);
}


=head2 initialBatchSize

  Usage        :  my $init_batchsize = $dset->initialBatchSize
  Description  :  Sets/gets the initialBatchSize on the Dataset
  Returntype   :  initialBatchSize or null
  Exceptions   :  na
  Caller       :  BioMart::QueryRunner

=cut

sub initialBatchSize {
  my ($self, $initialBatchSize) = @_;
  if ($initialBatchSize) {
    $self->setParam(INIT_BATCHSIZE, $initialBatchSize);
  }
  return $self->getParam(INIT_BATCHSIZE);
}

=head2 maxBatchSize

  Usage        :  my $max_batchsize = $dset->maxBatchSize
  Description  :  Sets/gets the maxBatchSize on the Dataset
  Returntype   :  maxBatchSize or null
  Exceptions   :  na
  Caller       :  BioMart::QueryRunner

=cut

sub maxBatchSize {
  my ($self, $maxBatchSize) = @_;
  if ($maxBatchSize) {
    $self->setParam(MAX_BATCHSIZE, $maxBatchSize);
  }
  return $self->getParam(MAX_BATCHSIZE);
}

=head2 locationDisplayName

  Usage        :  if ($dset->locationDisplayName) { .. }
  Description  :  Sets/gets BioMart::Location's display name for a dataset
                  
  Returntype   :  scalar $locationDisplayName
  Exceptions   :  na
  Caller       :  BioMart::QueryRunner

=cut

sub locationDisplayName {
  my ($self, $database) = @_;

  if ($database) {
    $self->setParam(LOCATIONDISPLAY, $database);
  }
  return $self->getParam(LOCATIONDISPLAY);
}

=head2 locationName

  Usage        :  if ($dset->locationName) { .. }
  Description  :  Sets/gets BioMart::Location's name for a dataset
                  
  Returntype   :  scalar $locationName
  Exceptions   :  na
  Caller       :  BioMart::QueryRunner

=cut

sub locationName {
  my ($self, $schema) = @_;

  if ($schema) {
    $self->setParam(LOCATIONNAME, $schema);
  }
  return $self->getParam(LOCATIONNAME);
}

#------------------------------------------------------------------------
=head2 getMode

  Usage      :  $DS->getMode()
                $DS->setMode('LAZYLOAD'); To set

  Description:  get the mode, default to MEMORY
  Return type:  A string
  Exceptions :  none
  Caller     :  caller

=cut

sub getMode
{
     my ($self) = @_;
	    	return $self->get('mode');
}

#------------------------------------------------------------------------
=head2 setMode

  Usage      :  $DS->getMode()
                $DS->setMode('LAZYLOAD'); To set

  Description:  get the mode, default to MEMORY
  Return type:  none
  Exceptions :  none
  Caller     :  caller

=cut

sub setMode
{
    my ($self, $val) = @_; 
    if ($val)
    {
          $self->set('mode', $val);
    }    
}
#------------------------------------------------------------------------
=head2 getDirPath

  Usage      :  $self->getDirPath()
                $self->setDirPath('/abc/def/'); To set

  Description:  get the path to the folder taht contains registry file, where confTrees, _portables, XML directories live
  Return type:  A string
  Exceptions :  none
  Caller     :  caller

=cut

sub getDirPath
{
     my ($self) = @_;     
     return $self->get('dirPath');
}


#-------------------------------------------------------------------------
=head2 setDirPath

  Usage      :  $self->getDirPath()
                $self->setDirPath('/abc/def/'); To set

  Description:  get the path to the folder taht contains registry file, where confTrees, _portables, XML directories live
             
  Return type:  none
  Exceptions :  none
  Caller     :  caller

=cut

sub setDirPath
{
    my ($self, $val) = @_; 
    if ($val)
    {
          $self->set('dirPath', $val);
    }
}
#------------------------------------------------------------------------
=head2 getConfigurationTree

  Usage      : $confTree = $subsys->getConfigurationTree($interface,
							 $dsCounter);

  Description: Returns a
               BioMart::Configuration::ConfigurationTree
               object with all attributes and filters that are
               supported by the given dataset for the given interface type.

  Returntype : BioMart::Configuration::ConfigurationTree
  Exceptions : none
  Caller     : caller

=cut
sub getConfigurationTree {
	my ($self,$interface,$dsCounter)=@_;
    
	my %configurationTrees = %{$self->get('configurationTrees')};
	
	my $cacheFile = $self->getDirPath();
	$cacheFile .= $self->virtualSchema()."/";
	$cacheFile .= "confTrees/";
	my $createLinks = undef;
	if(($dsCounter) && ($dsCounter eq 'CREATE_ALL_LINKS'))
	{
		$dsCounter = undef; # so its not misused by _getConfiguration Tree		
		$createLinks = 1;
	}

	if ($configurationTrees{$interface})
	{
		if ($configurationTrees{$interface} eq 'LAZYLOAD') # means exists but on the disk
		{	
			$cacheFile .= $self->locationName().".".$self->name().".".$interface; 			
			#$cacheFile .= $self->getParam('configurator')->get('location')->database().".".$self->name().".".$interface; 			
	
			if(-e $cacheFile) # if file exists
			{
				my $configurationTreeFromFile;
				eval{$configurationTreeFromFile = retrieve($cacheFile)};
				
				if ($createLinks) # means the call is from Registry::createAllLinks, so need to keep tree in memory.
				{
					$configurationTrees{$interface} = $configurationTreeFromFile;			
					$self->set('configurationTrees', \%configurationTrees);
				}
				
				return $configurationTreeFromFile;
			}
		}
		return $configurationTrees{$interface};
	}

	if ($self->can('_getConfigurationTree')) 
	{
		my $configurationTree = $self->_getConfigurationTree($interface, $dsCounter);
		
		$configurationTrees{$interface} = $configurationTree;
		
		$self->set('configurationTrees', \%configurationTrees);
		
		## Store the configurationTree to DISK if LAZYLOAD is set
		if($self->getMode() eq 'LAZYLOAD')
		{
			$self->setConfigurationTree($interface, 'LAZYLOAD');
		}
		return $configurationTree;
	}	
	$self->unimplemented_method();
}


#------------------------------------------------------------------------
=head2 getAllConfigurationTrees

  Usage      : $confTree = $subsys->getAllConfigurationTrees($interface OPTIONAL)

  Description: Returns a
               BioMart::Configuration::ConfigurationTree
               object with all attributes and filters that are
               supported by the given dataset for the given interface type.

  Returntype : BioMart::Configuration::ConfigurationTree
  Exceptions : none
  Caller     : caller

=cut
sub getAllConfigurationTrees {
	my ($self, @params) = @_;

	my $allConfigTrees;
	my (%params) = @params;
	
	my $martUser = $params{'martUser'} || 'default'; 
	my $required_interface = $params{'interface'} || 'default'; 
	
	my $interfacesList = $self->interfaces(); # should return a comma separated list of interfaces
	my @interfacesArray = split /,/,$interfacesList; 
	foreach my $interface(@interfacesArray)
	{
		if ($required_interface eq $interface) ## interfaces checking done
		{
			my $confTree = $self->getConfigurationTree($interface);
			my $martUsersList = $confTree->mart_Users();
			my @allusers = split /,/,$martUsersList; 
			foreach my $user (@allusers)
			{
				if ($user eq $martUser)
				{
					push @{$allConfigTrees}, $confTree;
				}
			}
		}	
	}
	return $allConfigTrees;		
}

#------------------------------------------------------------------------
=head2 setConfigurationTree

  Usage      : $confTree = $subsys->setConfigurationTree($interface,
							 $dsCounter);

  Description: Stores to Disk
               BioMart::Configuration::ConfigurationTree
               object with all attributes and filters that are
               supported by the given dataset for the given interface type.

  Returntype : none
  Exceptions : none
  Caller     : caller

=cut

sub setConfigurationTree
{
	my ($self, $interface, $flag) = @_;
	my %configurationTrees = %{$self->get('configurationTrees')};
	
	my $cacheFile = $self->getDirPath();
	$cacheFile .= $self->virtualSchema()."/";
	$cacheFile .= "confTrees/";
	$cacheFile .= $self->locationName().".".$self->name().".".$interface; 			
	#$cacheFile .= $self->getParam('configurator')->get('location')->database().".".$self->name().".".$interface; 			
	
	if(-e $cacheFile) # if file exists
	{
		unlink $cacheFile;		
	}
	
	store($configurationTrees{$interface},$cacheFile);

	if ($flag eq 'LAZYLOAD')
	{
		$configurationTrees{$interface} = 'LAZYLOAD';
		$self->set('configurationTrees', \%configurationTrees);			
	}
	
}

=head2 setExportables

  Usage      : $DS->setExportables($interface, 'LAZYLOAD')

  Description: Stores the exportables associated with datasets
			to disk, and sets its value to LAZYLOAD

  Returntype : none
  Exceptions : none
  Caller     : caller

=cut

sub setExportables {
	my ($self, $interface ,$val) = @_;

	my $cacheFile = $self->getDirPath();
	$cacheFile .= $self->virtualSchema()."/";
	$cacheFile .= "_portables/";
	$cacheFile .= $self->locationName().".".$self->name().".".$interface.".exportables"; 			
	#$cacheFile .= $self->getParam('configurator')->get('location')->database().".".$self->name().".".$interface.".exportables"; 			

	if(-e $cacheFile) # if file exists
	{
		unlink $cacheFile;		
	}
	
	store($self->get('exportables'),$cacheFile);
	$self->set('exportables', $val); ### $val is 'LAZYLOAD'
	
}

=head2 setExportables

  Usage      : $DS->setImportables($interface, 'LAZYLOAD')

  Description: Stores the importables associated with datasets
			to disk, and sets its value to LAZYLOAD

  Returntype : none
  Exceptions : none
  Caller     : caller

=cut

sub setImportables {
	my ($self, $interface, $val) = @_;
	
	my $cacheFile = $self->getDirPath();
	$cacheFile .= $self->virtualSchema()."/";	
	$cacheFile .= "_portables/";
	$cacheFile .= $self->locationName().".".$self->name().".".$interface.".importables";
	#$cacheFile .= $self->getParam('configurator')->get('location')->database().".".$self->name().".".$interface.".importables";

	if(-e $cacheFile) # if file exists
	{
		unlink $cacheFile;		
	}
	
	store($self->get('importables'),$cacheFile);

	$self->set('importables', $val); ### $val is 'LAZYLOAD'
}

=head2 getExportables

  Usage      : my $exportables = $subsys->getExportables;
               my $exportables = $subsys->getExportables($linkName);

  Description: Returns an array_ref of BioMart::Configuration::AttributeList 
               objects representing the exportables for the given
               dataset, either across all Links, or for a given $LinkName.

  Returntype : array_ref of BioMart::Configuration::AttributeList
  Exceptions : none
  Caller     : caller

=cut

sub getExportables {
    my ($self, $linkName, $interface) = @_;

    my $exportables = $self->get('exportables');

	# ---------
	if ($exportables eq 'LAZYLOAD')
	{
		$interface ||='default';

		my $cacheFile = $self->getDirPath();
		$cacheFile .= $self->virtualSchema()."/";
		$cacheFile .= "_portables/";
		$cacheFile .= $self->locationName().".".$self->name().".".$interface.".exportables"; 				
		#$cacheFile .= $self->getParam('configurator')->get('location')->database().".".$self->name().".".$interface.".exportables"; 				
		$exportables =  retrieve($cacheFile);
	}	
	# ---------


    if ($linkName && $interface) {# just used in QueryRunner
	return $exportables->{$linkName}->{$interface};
    }

    my $ref = [];

    # need loop as now 2 levels deep
    foreach (values %{$exportables}){
	push @{$ref}, values %{$_};
    }

    return $ref;
}


=head2 getImportables

  Usage      : my $importables = $subsys->getImportables;
               my $importables = $subsys->getImportables($linkName);

  Description: Returns an array_ref of BioMart::Configuration::FilterList 
               objects representing the importables of the given
               dataset, either across all Links, or for a given $linkName.

  Returntype : array_ref of BioMart::Configuration::FilterList objects
  Exceptions : none
  Caller     : caller

=cut

sub getImportables {
  my ($self, $linkName, $interface) = @_;

  my $importables = $self->get('importables');

	# ---------
	if ($importables eq 'LAZYLOAD')
	{
		$interface ||='default';

		my $cacheFile = $self->getDirPath();
		$cacheFile .= $self->virtualSchema()."/";
		$cacheFile .= "_portables/";
		$cacheFile .= $self->locationName().".".$self->name().".".$interface.".importables";
		#$cacheFile .= $self->getParam('configurator')->get('location')->database().".".$self->name().".".$interface.".importables"; 			 			
		$importables =  retrieve($cacheFile);
	}	
	# ---------


  if ($linkName && $interface) {# just used in QueryRunner
    return $importables->{$linkName}->{$interface};
  }

  my $ref = [];

  foreach (values %{$importables}){
      push @{$ref}, values %{$_};
  }
  return $ref;
}
=head2 importableTo

  Usage        :  if ($dset->importableTo) { ... }
  Description  :  Determine if this Dataset can import from other Datasets
  Returntype   :  boolean
  Exception    :  na
  Caller       :  BioMart::QueryRunner

=cut

sub importableTo {
  my $self = shift;

  my  $importableTo = ( @{$self->getImportables} > 0 );
  return $importableTo;
}

=head2 exportableFrom

  Usage        :  if ($dset->exportableFrom) { ... }
  Description  :  Determine if this Dataset can export to other Datasets
  Returntype   :  boolean
  Exception    :  na
  Caller       :  BioMart::QueryRunner

=cut

sub exportableFrom {
  my $self = shift;

  my  $exportableFrom = ( @{$self->getExportables} > 0 );
  return $exportableFrom;
}

=head2 getResultTable

  Usage      : fully specified for retrieving a batch of 1000
               records, starting with record 100 (eg. 100 - 999)
               into an existing ResultTable:

               my $rTable = $subsys->getResultTable(
                    'query'         => $query,
                    'batch_start'   => 100,
                    'batch_size'    => 1000,
                    'table' => $rtable
               );

               minimal, returns all results for a given query as
               a BioMart::ResultTable object:

               my $rTable = $subsys->getResultTable(
                    'query'         => $query
               );

               get all rows, starting from record 150
               as a BioMart::ResultTable:

               my $rTable = $subsys->getResultTable(
                    'query'         => $query,
                    'batch_start'   => 150
               );

               get only the first 1000 rows (same as
               batch_start = 0, batch_size = 1000)
               into an existing BioMart::AttributeTable:

               my $rTable = $subsys->getResultTable(
                    'query'         => $query,
                    'batch_size'    => 1000,
                    'table' => $atable
               );


  Description: Executes a BioMart::Query and returns
               a BioMart::ResultTable object.
               If a reference to an existing
               BioMart::ResultTable (or BioMart::AttributeTable)
               is passed in the 'table' parameter,
               it is modified and returned, otherwise
               a new BioMart::ResultTable object is
               created and returned.

               Each Implementation must implement a
               _getResultTable method. It must take
               the same parameters as DatasetI->getResultTable
               itself, although it will always recieve a 'table'
               parameter, so it will never need to create a new
               ResultTable object.

  Returntype : BioMart::ResultTable, or undef if Dataset is exhausted for a 
               batched query

  Exceptions : Missing or invalid Query object.  Unsupported
               Attribute/Filter request, invalid Link requests,
               Implementation specific Exceptions.

  Caller     : caller

=cut

sub getResultTable {
	my ($self, @param) = @_;

	local($^W) = 0;  # prevent "odd number of elements" warning with -w.
	my(%param) = @param;

	my $query = $param{'query'};
  
	unless ($query->isa("BioMart::Query")) {
    		BioMart::Exception::Query->throw("getResultTable requires a valid BioMart::Query object\nRecieved object ".$query."\n");
	}

	my $table = $param{'table'};
	
#	print  "<BR>_getResultTable ", $self->name();	
    
	my $firstbatch;
	unless ($table) {
		$firstbatch = 1;
		$self->_processNewQuery($query); # resets for all new queries
 		if ($param{'batch_size'}) {
	 	     $self->set('explicit_batching',1);
		}
		else {
			#set the batch_size to the initial_batchsize. Some queries not involving
			#importables, or not explicitly batched, will ignore this setting.
			$param{'batch_size'} = $self->getParam(INIT_BATCHSIZE);
		}

		$table = BioMart::ResultTable->new('query' => $query, 
                            'target_dataset' => $self,
                            'max_batchsize' => $self->getParam(MAX_BATCHSIZE),
                            'initial_batchsize' => $param{'batch_size'});

		if ($param{'web_origin'} && $param{'web_origin'} == 1){
			$table->webOrigin(1);
		}
		$param{'table'} = $table;
	}

	return undef if ($self->get('exhausted'));
	
	# Call the DatasetI implementing object's getResultTable method
  	if ($self->can('_getResultTable')) 
  	{
		my ($importable_size,$exportable_size,$linkName,$to_hash,$importable);

    	  # IDENTIFY IF HAVE AN IMPORTABLE FILTERLIST AND RECOVER PREVIOUS
    	  # DATASET'S HASHED RESULTS AND ADD EXTRA ATTS FOR MERGING IF REQUIRED
    	  my $filters = $query->getAllFilters;
    	  foreach my $filter (@$filters)
    	  {
			  if ($filter->isa("BioMart::Configuration::FilterList") 
		      && $filter->batching) 
		     {
		      $importable = $filter;

		      $importable_size = @{$importable->getAllFilters};
		      $linkName = $importable->linkName;
		      # set initial hash so below extra att handling happens even 
		      # before 1st batch
		      my $attribute_table = $importable->getTable;
		      my $attributeHash = $self->get('attributeHash');
		      $attributeHash->{$linkName} = $attribute_table->hashedResults;
		      $self->set('attributeHash',$attributeHash);

		      if ($self->get('attributeHash')->{$linkName} && 
			  !$query->getAttributeListByName($linkName))
			  {
				  # add an attribute at the beginning of the result table for 
				  # each filter in the importable for attribute merging
				  my $alist = BioMart::Configuration::AttributeList->new(
				   'name' => $linkName,
				   'dataSetName' => $self->name ,
				   'interface' => $query->getInterfaceForDataset($self->name));
				  my $attribute_string = '';
				  my $comma = '';
				  my $list_filters = $importable->getAllFilters;
				  foreach (@$list_filters){
				      $attribute_string = $attribute_string.$comma.
					  $_->attribute->name;
				      $comma = ',';
					      $alist->addAttribute($_->attribute);
				  }
			  # add as an AttributeList so gets to start of SQL select
			  $alist->attributeString($attribute_string);
			  $query->addAttributeListFirst($alist);
		      }
	      
		      last;
		  }
      }

      	# GET RESULTTABLE FROM DATASETI IMPLEMENTING OBJECT      
		my $has_data = $self->_getResultTable(%param);
		
		#print ":  YES DATA " if $has_data;

		$logger->debug("Got results") if $has_data;
		$logger->debug("Got no results") unless $has_data;

#		if ($self->isa("BioMart::Dataset::GenomicSequence"))
#		{
#			print "<BR>RS RETURNS: <BR>", Dumper($has_data->getRows) if ($has_data);
#		}

 	    # DO MERGING OF ATTRIBUTES IF REQUIRED 
   	   	if ($importable){
   	   	# these lines are necessary to repopulate attributeHash as the 
		# getResultTable call may have resulted in a new batch of the
	 	# previous dataset and hence new hashed results to be merged

	 	  my $attribute_table = $importable->getTable;
	 	  
 		  my $attributeHash = $self->get('attributeHash');
 		  $attributeHash->{$linkName} = $attribute_table->hashedResults;
 		  
 		  $self->set('attributeHash',$attributeHash);
 	     } 
 	     
#	    print "\n<BR>++++++++++ GOT RESULTS (Before Merging) +++++++++++++++ <BR>";
#		if($table && $self->isa("BioMart::Dataset::GenomicSequence") ) {
#			print Dumper($table->getRows), if ($table->getRows);
#		}
 	     
		if ($has_data && $has_data > 0 && $linkName && 
			$self->get('attributeHash')->{$linkName}){
			$logger->debug("Attribute merge using linkName: $linkName");
			$logger->debug("Before merge: ".scalar(@{$has_data->get('columns')}));
					
			$table = $self->_attributeMerge($table,$importable_size,$linkName, $query);
			
#			print "\n<BR>++++++++++ AFTER MERGING TABLE +++++++++++++++ <BR>", Dumper($table->getRows);
		
			$logger->debug("After merge: ".scalar(@{$has_data->get('columns')}));
		}

	      # DO HASHING OF ATTRIBUTES IF REQUIRED 
	      if ($self->forceHash){
			  # Dataset is being used for placeholder attributes on the first 
			  # visible dataset of a two visible dataset query. Need to force
			  # attribute hashing and merging
			  $to_hash = 1;
			  $exportable_size = $self->forceHash;
	      }     
	      elsif ($query->getAllAttributeLists && $query->getAllAttributes){
	          # have user chosen atts and an exportable - going to want to do
			  # attribute hashing and merging to perform a join
			   foreach my $exportable(@{$query->getAllAttributeLists}){
			      if ($exportable->linkName){
			         $to_hash = 1;
					 $exportable_size =  @{$exportable->getAllAttributes};
					 last;
			     }
			  }
	      }
	      else {
			  # if table is bigger than exportable_size after merging then should 
			  # be hashed - fixes problem of getting no seq, gene dataset merging 
			  # if no structure atts chosen for example	  

			foreach my $exportable(@{$query->getAllAttributeLists}){
			     if ($exportable->linkName){
					$exportable_size =  @{$exportable->getAllAttributes};
					last;
				}
			}
			my $first_row = ${$table->getRows()}[0];
	          my $col_number = @{$first_row} if ($first_row);   
	          if ($col_number && $exportable_size && 
				$col_number > $exportable_size){
				$to_hash = 1;
			}
			# another special case, say Human (seq)/msd, and u donot choose human main table att(deselect: biotype)
			# and this will stop the hashing call, even for empty DS, which will break the intermediate logic
			# of prKeys being passed over from one DS to another one. causing complete chaos.
			# try removing this IF and request Sequence for gene: ENSG00000188170 with MSD as second DS.
			if (!$col_number && $exportable_size)
			{
				$to_hash = 1;
			}
			
		}

	     if ($to_hash){
			$logger->debug("Attribute hash");						
			$logger->debug("Before hash: ".scalar(@{$table->get('columns')}));
#			print  "\n<BR>++++++++++ BEFORE HASHING +++++++++++++++ <BR>",Dumper($table->getRows());
			$table = $self->_hashAttributes($table,$exportable_size);
			  
#			print  "\n<BR>++++++++++ AFTER HASHING TABLE - ROWS +++++++++++++++ <BR>",Dumper($table->getRows());
#			print  "\n<BR>++++++++++ AFTER HASHING TABLE - HASHEDRESULTS +++++++++++++++ <BR>",Dumper($table->hashedResults);
		
	      $logger->debug("After hash: ".scalar(@{$table->get('columns')}));
	
		}



	      # RETURN FULL TABLE, EMPTY TABLE (1st batch), UNDEF (last batch)
	      $logger->debug("Returning defined has_data") if $has_data;

	      return $has_data if ($has_data); #always return defined result
	      $logger->debug("Returning table") if $firstbatch;
	      return $table if ($firstbatch); #returns empty table for first call. 
                                      #Next call will be exhausted
	      $logger->debug("Returning undefined has_data") if $has_data;
	      return $has_data; #subsequent batches must return undef
	}
  	$self->unimplemented_method();
  	
  	
}

sub _attributeMerge {
  	my ($self,$rtable,$importable_size,$linkName, $query) = @_;
	$logger->debug("Importable size: $importable_size");
	$logger->debug("Link name: $linkName");

	my $sequenceType = 'none';
	
	my %prev_dset_hash = %{$self->get('attributeHash')->{$linkName}};
	
	my %this_dset_hash;
	my $rows = $rtable->getRows();
	
	HASHROW:foreach my $row(@{$rows}){
		my $key_string = '';
		my $pKey = '';
		for (my $i = 0; $i < $importable_size; $i++)
		{
		    next if (!$$row[$i]);
		    $logger->debug("Appending ".$$row[$i]);
		    $key_string .= $$row[$i];
		    $pKey = $$row[$i] if (!$pKey);
		}
		$logger->debug("Final key string is: ".$key_string);
		next if ($key_string eq "" );
	
		# store hash element;
		my $hashed_rows;
		$hashed_rows = $this_dset_hash{$pKey}{$key_string} if (!$self->GenomicMAlignHack());
		$hashed_rows = $this_dset_hash{$key_string}{$key_string} if ($self->GenomicMAlignHack());

		my $row_to_add = [@{$row}[$importable_size..@{$row}-1]];

		push @$hashed_rows, $row_to_add;
		
		$this_dset_hash{$pKey}{$key_string} = $hashed_rows if (!$self->GenomicMAlignHack());
		$this_dset_hash{$key_string}{$key_string} = $hashed_rows if ($self->GenomicMAlignHack());		
	}
	    
	if ($self->isa("BioMart::Dataset::GenomicSequence")
		&& ($self->lastDS() == 1 || $self->lastDS() == 2)
		&& ($query->getAllAttributes($self->name)->[0]->name()) )
	{
		$sequenceType = $query->getAllAttributes($self->name)->[0]->name();
		$sequenceType = 'ok';
			

			#if ($this_dset_hash{'52041'})
			#{
			#	print "<BR>=================== PREV DS  ================== <BR>", Dumper (\%prev_dset_hash);
			#}			
			# The last set of rows, against a pkey in GS is ignored due to batching as 
			# the remaining rows could possibly come in next batch.
			# so for merging them back again to corresponding structure Atts, we store 
			# structure atts in GS and add them to the new %prev_dset_hash, so when the 
			# sequences is returned in next batch, it available for merging.
			
			
		if ($self->get('rowsFromLastBatch'))
		{
			my $lastBatchRows = $self->get('rowsFromLastBatch');
			my $doWriteBack =0;
			foreach my $firstkey( keys %$lastBatchRows) {
				if (exists $this_dset_hash{$firstkey}) ####### only bring into prev_hash if required and delete immediately
				{	
					foreach my $secondkey (keys %{$lastBatchRows->{$firstkey}}) {
						#$prev_dset_hash{$firstkey}{$secondkey} = $lastBatchRows->{$firstkey}{$secondkey};
						foreach my $rows (@{$lastBatchRows->{$firstkey}{$secondkey}})
						{
							push @{$prev_dset_hash{$firstkey}{$secondkey}}, $rows;
						}
					}
					delete $lastBatchRows->{$firstkey};
					$doWriteBack = 1;
				}
			}
			$self->set('rowsFromLastBatch', $lastBatchRows) if ($doWriteBack);
#			print "<BR>=================== THIS_DATASET ================ <BR>", Dumper(\%this_dset_hash);
#			print "<BR>=================== RECOVERED  ================== <BR>", Dumper (\%prev_dset_hash);
		}

		my $saveForNextBatch = undef;
		foreach my $firstkey (keys %prev_dset_hash) {
			if (!exists $this_dset_hash{$firstkey}) {
				$saveForNextBatch ||= $self->get('rowsFromLastBatch');
				foreach my $secondkey (keys %{$prev_dset_hash{$firstkey}}) {
#					print "<BR>$firstkey : $secondkey";
#					print "<BR>Already EXISTS :", Dumper($saveForNextBatch) if(exists $saveForNextBatch->{$firstkey}{$secondkey});
					#$saveForNextBatch->{$firstkey}{$secondkey} = $prev_dset_hash{$firstkey}{$secondkey};
					foreach my $rows (@{$prev_dset_hash{$firstkey}{$secondkey}})
					{
						push @{$saveForNextBatch->{$firstkey}{$secondkey}}, $rows;
					}
				}					
			}
		}
		$self->set('rowsFromLastBatch', $saveForNextBatch);
	}	
		
	my @new_rows;
  	# loop over both hashes and produce new table

	
    	
#	print "<BR>=================== PREV_DATASET ================ <BR>", Dumper(\%prev_dset_hash);
#	print "<BR>=================== THIS_DATASET ================ <BR>", Dumper(\%this_dset_hash);

	foreach my $prkey(keys %this_dset_hash)
	{
		
		foreach my $key(keys %{$this_dset_hash{$prkey}})
		{
			my $this_dset_rows = $this_dset_hash{$prkey}{$key};
			
			my $pKey = $prkey;
			$logger->warn("Processing key: ".$key);
    		$logger->warn("This previous rows: ".scalar(@$this_dset_rows));
			foreach my $this_dset_row(@$this_dset_rows)
			{
				#print "<BR>  ++ THIS DS: [ $pKey ] <BR>", Dumper($this_dset_row) ;

		    	my $prev_dset_rows = $prev_dset_hash{$prkey};	#{$key};		## this matching of both lower and upper case of keys
				if(!$prev_dset_rows)								## is introduced ever since ensembl 41 has made the 
				{													## pdb for e.g in UPPER case and in MSD its in LOWER case	
					$prev_dset_rows = $prev_dset_hash{lc($prkey)}; #{lc($key)};	## so its safe to test both the scenarios
				}		
				if(!$prev_dset_rows)								## is introduced ever since ensembl 41 has made the 
				{												## pdb for e.g in UPPER case and in MSD its in UPPER case	
					$prev_dset_rows = $prev_dset_hash{uc($prkey)}; #{uc($key)};	## so its safe to test both the scenarios
				}			
			 	if ($prev_dset_rows)
				{
					#if ($sequenceType eq 'ok') 
	    			#{						
#						print "<BR>  ++ THIS DS: [ $pKey ] <BR>", Dumper($this_dset_row) ;
#						print "<BR>=================== GS: PREV_ROWS ================ <BR>", Dumper(\%prev_dset_hash);
					#}

    				my @allRows;
		    		if (defined $prev_dset_hash{$pKey})
					{
						foreach my $key_string (keys %{$prev_dset_hash{$pKey}}) {
	    					push @allRows, $prev_dset_hash{$pKey}{$key_string} ;
		    			}
		    		}
		    		if (!@allRows && exists $prev_dset_hash{lc($pKey)})
		    		{
		    			foreach my $key_string (keys %{$prev_dset_hash{lc($pKey)}}) {
	    					push @allRows, $prev_dset_hash{lc($pKey)}{$key_string} ;
		    			}
		    		}
		    		if (!@allRows && exists $prev_dset_hash{uc($pKey)})
		    		{
		    			foreach my $key_string (keys %{$prev_dset_hash{uc($pKey)}}) {
	    					push @allRows, $prev_dset_hash{uc($pKey)}{$key_string} ;
		    			}
		    		}
#			 		print "<BR> READY FOR MERGING -1";
#	    			$logger->debug("There were previous rows: ".scalar(@$prev_dset_rows));
					## GS semi colon separated list for structure attributes
	    			if ($sequenceType eq 'ok') 
	    			{						
#						print "<BR>, Merging Here";
						#e.g pKey=267929 AND key=26792911522636522755-15 
	    											
			    		my ($finalRow, $avoidRepeats) = ();
#						print "<BR>=================== ALL_ROWS ================ <BR>", Dumper(\@allRows);
						foreach my $subrow (@allRows) {						    	
			   				if($subrow) {
								foreach my $row (@$subrow) {
									for (my $i = 0; $i < scalar(@{$row}); $i++)	{
										if ( $row->[$i] ) {
											if (!$finalRow->[$i]) {
												$finalRow->[$i] = $row->[$i];
											}
											else {
												$finalRow->[$i] .= ';'.$row->[$i] if (!$avoidRepeats->{$i}->{$row->[$i]});
											}
											$avoidRepeats->{$i}->{$row->[$i]} = 1;
										}
									}	
								}		
							}
						}
						push @new_rows, [@$this_dset_row,@$finalRow] if ($finalRow);
						push @new_rows, [@$this_dset_row,""] if (!$finalRow);
   					}
					else 
					{
						my %avoidDuplication = ();

#						print "<BR>  ++ ALL ROWS: [ $pKey ] ", Dumper(\@allRows) ;
#						print "<BR>  ++ THIS DS: [ $pKey ] ", Dumper($this_dset_row) ;

						foreach my $subrow (@allRows) {
		   					if($subrow) {
			   					NEXTROW: foreach my $row (@$subrow) {
		   							#print "<BR>HERE: SUB_ROW: ", Dumper($row);
			   						# avoid using "@A" eq "@B" type comparison, it floods error log
									my $rowAsString = $self->toString($row);
									next NEXTROW if (!$rowAsString || exists $avoidDuplication{$rowAsString} ) ;
									$avoidDuplication{$rowAsString} = '';
#									print "<BR>going be merged with seq: ",Dumper($row);
									push @new_rows, [@$this_dset_row,@$row];
								}
		   					}
		   				}
			    	}
		    	}
	    		else 
	    		{
	    	  		$logger->debug("There were NO previous rows");
			    }
			}
		}
	}
	$logger->debug("Finished with rows: ".scalar(@new_rows));
	
   	$rtable->setRows(\@new_rows);
    	
   	return $rtable;

}

sub _hashAttributes {
	my ($self,$tempTable,$exportable_size) = @_;
    my %datasetAttributeHash;

	my @new_rows;
	my @order_of_rows;
	my %groupSameKeyRows;
	   
	my $rows = $tempTable->getRows();
	
	if ($self->forceHash){# keys atts are at the end
        	  
		HASHROW1:foreach my $row(@{$rows}){
	  		
	  		my $new_row = [@{$row}[@{$row}-$exportable_size..@{$row}-1]];

	  	 	#push @new_rows, $new_row;# do first so even empty rows get added so 
		                           # batching behaviour not confused
			no warnings 'uninitialized';
			if (! exists $groupSameKeyRows{$new_row->[0]})
			{
				push @order_of_rows, $new_row->[0];
			}
			push @{$groupSameKeyRows{$new_row->[0]}}, $new_row;
			
		  	my $key_string = '';
		  	my $pKey = '';
		  	for (my $i = @{$row} - $exportable_size; $i < @{$row}; $i++){
		    	next if (!$$row[$i]);
		   		$key_string .= $$row[$i];
		      	$pKey = $$row[$i] if (!$pKey);
		  	}
		  	next if ($key_string eq "");
		  	# store hash element;
			my $hashed_rows;
		  	$hashed_rows = $datasetAttributeHash{$pKey}{$key_string} if (!$self->GenomicMAlignHack());
		  	$hashed_rows = $datasetAttributeHash{$key_string}{$key_string} if ($self->GenomicMAlignHack());
		  
		  	my $row_to_add = [@{$row}[0..@{$row}-1-$exportable_size]];
		  
		  	#next HASHROW1 if ($self->rowExists($row_to_add, $hashed_rows));
		 	if ($hashed_rows){
		    	foreach my $prev_row (@{$hashed_rows}){
			     	# avoid using "@A" eq "@B" type comparison, it floods error log
					next HASHROW1 if ( (($prev_row && $row_to_add) && ($self->toString($prev_row) eq $self->toString($row_to_add)))
							|| (!$prev_row && !$row_to_add) );
				}	     
		  	}	  	  
		  	push @$hashed_rows,$row_to_add;
		 	$datasetAttributeHash{$pKey}{$key_string} = $hashed_rows if (!$self->GenomicMAlignHack());
		 	$datasetAttributeHash{$key_string}{$key_string} = $hashed_rows if ($self->GenomicMAlignHack());		 	
	   	}
	}
    
    else{

		HASHROW:foreach my $row(@{$rows}){
	  		  		
		my $new_row = [@{$row}[0..$exportable_size-1]];

		#push @new_rows, $new_row;# do first so even empty rows get added so 
	                           # batching behaviour not confused
		
#		if($new_row->[0]) # just to avoid warnings
#		{
		no warnings 'uninitialized';
			if (! exists $groupSameKeyRows{$new_row->[0]})
			{
				push @order_of_rows, $new_row->[0];
			}
			push @{$groupSameKeyRows{$new_row->[0]}}, $new_row;
#		}
		

		my $key_string = '';
		my $pKey = '';
		for (my $i = 0; $i < $exportable_size; $i++){
			next if (!$$row[$i]);
			$key_string .= $$row[$i];
			$pKey = $$row[$i] if (!$pKey);	      
		}
		next if ($key_string eq "");

		# store hash element;
		my $hashed_rows;
	  	$hashed_rows = $datasetAttributeHash{$pKey}{$key_string} if (!$self->GenomicMAlignHack());
	  	$hashed_rows = $datasetAttributeHash{$key_string}{$key_string} if ($self->GenomicMAlignHack());
	  
		my $row_to_add = [@{$row}[$exportable_size..@{$row}-1]];
	  
		#next HASHROW if ($self->rowExists($row_to_add, $hashed_rows));
		if ($hashed_rows){# make sure unique before add, error_log flooding
	    	foreach my $prev_row (@{$hashed_rows}){
			# avoid using "@A" eq "@B" type comparison, it floods error log
			next HASHROW if ( (($prev_row && $row_to_add) && ($self->toString($prev_row) eq $self->toString($row_to_add)))
							|| (!$prev_row && !$row_to_add) );
			}
	  	}
	  
	  	#warn($key_string." => ".join ",",@$row_to_add);
	 	push @$hashed_rows,$row_to_add;

	 	$datasetAttributeHash{$pKey}{$key_string} = $hashed_rows if (!$self->GenomicMAlignHack());
	 	$datasetAttributeHash{$key_string}{$key_string} = $hashed_rows if ($self->GenomicMAlignHack());
	  
    	}
    }


	foreach my $rowKey (@order_of_rows)
	{
		foreach my $row (@{$groupSameKeyRows{$rowKey}})
		{
			push @new_rows, $row;
		}
	}
    
    $tempTable->setRows(\@new_rows);
    
    #if (!%datasetAttributeHash)
    #{
    #	print "<BR>BIG CLEVER FINDING :", Dumper(\%datasetAttributeHash), "<BR>and old ones" , Dumper($tempTable->hashedResults) ;
    #}
    
    $tempTable->hashedResults(\%datasetAttributeHash) if (%datasetAttributeHash);
	# this is a very clever line
	# if (!%datasetAttributeHash) = {}, while if there are previous results then they should be kept
	# however, if previous results are undef, then hashedResults should be assigne to {} instead of undef
	if (!%datasetAttributeHash && !$tempTable->hashedResults)
    {
    	$tempTable->hashedResults(\%datasetAttributeHash);
    }

    return $tempTable;
}


=head2 getCount

  Usage      : my $count = $subsys->getCount(
                    'query'         => $query,
               );

  Description: Executes a BioMart::Query and returns
               a count.
               Each Implementation must implement a
               _getCount method. It must take
               the same parameters as DatasetI->getCount
               itself.

               Currently, queries involving importables from
               other visible datasets which are batched are
               not countable.  These will return -1 as the count.

  Returntype : String $count

  Exceptions : Missing or invalid Query object.  Unsupported
               Attribute/Filter request, invalid Link requests,
               Implementation specific Exceptions.

  Caller     : caller

=cut

sub getCount{
  my ($self, @param) = @_;

  local($^W) = 0;  # prevent "odd number of elements" warning with -w.
  my(%param) = @param;

  my $query = $param{'query'};
  unless ($query->isa("BioMart::Query")) {
    BioMart::Exception::Query->throw("getResultTable requires a valid BioMart::Query object\nRecieved object ".$query."\n");
  }

  if ($self->can('_getCount')) {
    return $self->_getCount(%param);
  }
  $self->unimplemented_method();
}

=head2 toString
  Usage      : 

  Description: Helper rouinte for Array comparison by converting
  			it to string first. Comparing arrays as "@A" eq "@B"
  			brings flood of warning

  Returntype : String

  Exceptions : none

  Caller     : caller

=cut
sub toString
{
	my ($self, $curRow) = @_;
	my $string;
    	foreach (@{$curRow})
    	{
		$string .= $_ if ($_);
    	}
 	return $string;   	
}

sub lastDS {
  my ($self, $val) = @_;

  if ($val) {
    $self->set('LastDS', $val);
  }
  return $self->get('LastDS');
}

sub GenomicMAlignHack {
  my ($self, $val) = @_;

  if ($val) {
    $self->set('GenomicMAlignHack', $val);
  }
  return $self->get('GenomicMAlignHack');
}


1;
