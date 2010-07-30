# $Id: Registry.pm,v 1.10.2.1 2008-07-30 15:35:59 syed Exp $
#
# BioMart module for BioMart::Registry
#
# You may distribute this module under the same terms as perl
# itself.

# POD documentation - main docs before the code.

=head1 NAME

BioMart::Registry

=head1 SYNOPSIS

TODO: Synopsis here.

=head1 DESCRIPTION

The registry is created by the initializer
(BioMart::Initializer::getRegistry()) and it acts as a
repository of datasets and links between datasets for
the entire BioMart system, and all client code.  The registry 
is also responsible for setting up all possible links between 
datasets once these are populated with filters and attributes.

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Andreas Kahari, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project
http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut

#------------------------------------------------------------------------

package BioMart::Registry;

use strict;
use warnings;
use BioMart::Links;
use Data::Dumper;
use Storable qw(store retrieve freeze nfreeze thaw);
local $Storable::Deparse = 1;
$Storable::forgive_me = 1;
use Cwd;
use BioMart::Dataset::TableSet;
use BioMart::Dataset::GenomicSequence;
use BioMart::Dataset::GenomicMAlign;
use constant INF => 10_000;     # Used in __Dijkstra(), must be
                                 # larger than the total number
                                 # of datasets.

# Extends BioMart::Root
use base qw(BioMart::Root);
BEGIN{
  # We want to use XML::Parser if installed, as it's faster than XML::SAX
  no strict 'refs';
  my $fail;
  unless( 'XML::'->{'Parser::'} ){ # Check if already used
    eval "require XML::Parser";
    if( $@ ){ $fail ++ }
    else{ XML::Parser->import() }
  }
  unless( $fail ){ $XML::Simple::PREFERRED_PARSER = 'XML::Parser' }
}
#------------------------------------------------------------------------

=head2 new

  Usage      :  my $registry = BioMart::Registry->new();
  Description:  Creates a new BioMart::Registry object.
  Return type:  A BioMart::Registry object.
  Exceptions :
  Caller     :

=cut

sub _new
{
    my ($self, @params) = shift;

    $self->SUPER::_new(@params);

    $self->attr('defaultDatasetName', undef);
    $self->attr('virtualSchemas',[]);
    $self->attr('mode','MEMORY'); ## default to MEMORY other option is LAZYLOAD
    $self->attr('dirPath',undef);
    $self->attr('settingsConfParams', undef);
}

#------------------------------------------------------------------------
=head2 getMode

  Usage      :  $registry->getMode()
                $registry->setMode('LAZYLOAD'); To set

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

  Usage      :  $registry->getMode()
                $registry->setMode('LAZYLOAD'); To set

  Description:  get the mode, default to MEMORY, Also sets the same mode for DATASETI objects
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
     
     foreach my $virtualSchema (@{$self->getAllVirtualSchemas}){
	    foreach my $location (@{$virtualSchema->getAllLocations}){
		    foreach my $dataset (@{$location->getAllDatasets}){
	             $dataset->setMode($val);
	         }
	    }
    }   


}
#------------------------------------------------------------------------
=head2 getDirPath

  Usage      :  $registry->getDirPath()
                $registry->setDirPath('/abc/def/'); To set

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

  Usage      :  $registry->getDirPath()
                $registry->setDirPath('/abc/def/'); To set

  Description:  get the path to the folder taht contains registry file, where confTrees, _portables, XML directories live, 
                also set the same path for DATASETI objects
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
     
     foreach my $virtualSchema (@{$self->getAllVirtualSchemas}){
	    foreach my $location (@{$virtualSchema->getAllLocations}){
		    foreach my $dataset (@{$location->getAllDatasets}){
	             $dataset->setDirPath($val);
	         }
	    }
    }   


}
#------------------------------------------------------------------------
=head2 cleanXMLs

  Usage      :  $registry->cleanXMLs()                

  Description:  deletes all existing XML files from disk, for action => clean, during Initializer->new 

  Return type:  none
  Exceptions :  none
  Caller     :  caller

=cut
sub cleanXMLs
{
     my ($self) = @_;     
     my $cleanFile = $self->getDirPath();
				
	my $v_schemas = $self->getAllVirtualSchemas();
	foreach my $schema (@$v_schemas)
	{
		my $databases = $self->getAllDatabaseNames($schema->name()); ## databases are locations as per old API calls
		foreach my $database_name (@$databases)
		{
			my $datasets = $self->getAllDataSetsByDatabaseName($schema->name(), $database_name);
			foreach my $dataset_name(@$datasets)
			{
				my $dataset = $self->getDatasetByName($schema->name(), $dataset_name); 				
				my $interfacesList = $dataset->interfaces(); # should return a comma separated list of interfaces
				my @interfacesArray = split /,/,$interfacesList; 
				foreach my $interface(@interfacesArray)
				{
					my $temp;
					$temp = $cleanFile;
                         $temp .= $schema->name()."/XML/".$dataset->locationName().".".$dataset->name().".".$interface;
                         #$temp .= $schema->name()."/XML/".$dataset->getParam('configurator')->get('location')->database().".".$dataset->name().".".$interface;
					if (-e $temp) { unlink $temp; }
				}
			}
		}
	}
}

#------------------------------------------------------------------------

=head2 getAllVirtualSchemaNames

  Usage      :  foreach my $vSchemas (
                    @{ $registry->getAllVirtualSchemas} ) {...}
  Description:  get an arrayref of all virtualSchemas within the registry
                This will always return at least 'defaultSchema'.
  Return type:  An arrayref of strings
  Exceptions :  none
  Caller     :  caller

=cut

sub getAllVirtualSchemaNames {
  my ($self,$visible_only) = @_;

  my @names;
  foreach my $virtualSchema (@{$self->getAllVirtualSchemas}){
      if ($visible_only){
	   push @names, $virtualSchema->name if ($virtualSchema->visible == 1);
      }
      else{
	  push @names, $virtualSchema->name;
      }
  }
  
  @names = sort(@names);
  return \@names;
}


#------------------------------------------------------------------------

=head2 getDefaultVirtualSchema

  Usage      :  my $default = $registry->getDefaultVirtualSchema;
  Description:  gets the default virtualSchema if any as defined in the 
                registry XML
  Return type:  String
  Exceptions :  none
  Caller     :  caller

=cut

sub getDefaultVirtualSchema {
    my $self = shift;

    foreach my $virtualSchema (@{$self->getAllVirtualSchemas}){
	return $virtualSchema->name if ($virtualSchema->default == 1);
    }
}


=head2 getAllDatasetNames

  Usage      :  my @dataSetNames =
                    $registry->getAllDatasetsNames($virtualSchema);

                my @visibleDatasetNames =
                    $registry->getAllDatasetsNames($virtualSchema, 
						   $visible_only);

  Description:  Gets all names of all datasets within a virtualSchema, or 
                all visible datasets within a virtualSchema.
                If $visible_only is defined, only visible datasets are
                returned.

  Return type:  An array of strings in list context, or a
                reference to such an array in scalar context.

  Exceptions :  none
  Caller     :  caller

=cut

sub getAllDatasetNames {
	my ($self, $virtualSchemaName, $visible_only) = @_;
	# sort all the dataset Names per Mart based on their displayNames if visible_only = 1
	my @dataSetNames;
	my %sortedNames;
	foreach my $virtualSchema (@{$self->getAllVirtualSchemas}){
		next unless ($virtualSchema->name eq $virtualSchemaName);
		foreach my $location (@{$virtualSchema->getAllLocations}){
			%sortedNames=();
			foreach my $dataset (@{$location->getAllDatasets}){
				if ($visible_only){
					$sortedNames{$dataset->displayName} = $dataset->name if ($dataset->visible == 1);
				}
				else{
					# directly pushing as invisible datasets often has no display Name
					push @dataSetNames,$dataset->name;
				}
			}
			if ($visible_only){
				foreach my $displayName ( sort keys %sortedNames ) {
					push @dataSetNames, $sortedNames{$displayName};
				}
			}
		}
	}
	return (wantarray() ? @dataSetNames : \@dataSetNames);
}


#------------------------------------------------------------------------

=head2 getAllDisplayNames

  Usage      :  my @dataSetNames =
                    $registry->getAllDisplayNames($virtualSchema);
                my @dataSetNames =
                    $registry->getAllDisplayNames($virtualSchema,
						  $visible_only);


  Description:  Gets all display names of all datasets within
                a virtualSchema. If
                $visible_only is defined, displayNames are
                returned only for visible datasets.

  Return type:  An array of strings in list context, or a
                reference to such an array in scalar context.

  Exceptions :  none
  Caller     :  caller

=cut

sub getAllDisplayNames {
    my ($self, $virtualSchemaName, $visible_only) = @_;
    my @dataSetNames;
    foreach my $virtualSchema (@{$self->getAllVirtualSchemas}){
	next unless ($virtualSchema->name eq $virtualSchemaName);
	foreach my $location (@{$virtualSchema->getAllLocations}){
	    if ($visible_only){
		push @dataSetNames, @{$location->getAllVisibleDatasetDisplayNames};
	    }
	    else {
		foreach my $dataset (@{$location->getAllDatasets}){
		    push @dataSetNames,$dataset->displayName;
		}
	    }
	}
    }
    return (wantarray() ? @dataSetNames : \@dataSetNames);
}

#------------------------------------------------------------------------


=head2 getLinksBetween

  Usage      :  my @link = $registry->getLinkBetween($virtualSchema,
						     $exportingDatasetName,
						     $importingDatasetName);

  Description:  Returns the BioMart::Links object that links
                the given exportingDataset to the given
                importingDataset within the given virtualSchema, if one exists.

  Return type:  BioMart::Dataset::Links object, or undef it no link exists
                between the two datasets within the given virtualSchema.

  Exceptions :  exporting or importing DatasetName are not known in the 
                configuration
  Caller     :

=cut

sub getLinkBetween {
  my ($self,$virtualSchema,$exportingDatasetName,$importingDatasetName) = @_;

  my $link;

  my $exportingDatasetEntry = $self->__fetchDatasetEntry($virtualSchema, 
							$exportingDatasetName);
  my $importingDatasetEntry = $self->__fetchDatasetEntry($virtualSchema,
							$importingDatasetName);

  LINK: foreach my $li (@{ $exportingDatasetEntry->{'links'} }) {
    my $targetDatasetName = $li->targetDataset();
    if ($importingDatasetName && $importingDatasetName eq $targetDatasetName) {
      $link = $li;
      last LINK;
    }
  }

  return $link;
}

#------------------------------------------------------------------------

=head2 getDatasetByName

  Usage      :  my $dataSet =
                    $registry->getDatasetByName($virtualSchema, $DatasetName);
  Description:  Gets a named dataset from the registry within the given
                virtualSchema.
  Return type:  A BioMart::DatasetI object, or undef
  Exceptions :  none
  Caller     :  caller

=cut

sub getDatasetByName {
     my ($self, $virtualSchema, $dataSetName ,$martUser) = @_;

     my $dataSetEntry = $self->__fetchDatasetEntry($virtualSchema, $dataSetName,
						  $martUser);
    
     return $dataSetEntry;     
}

#------------------------------------------------------------------------

=head2 getAttribute

  Usage      :  my $att = $registry->getAttribute($dataset, $attribute, 
						  $schema, $interface);

  Description:  Retrieve attribute object given its internal name and dataset
  Return type:  A BioMart::Configuration::Attribute object, or undef
  Exceptions :  none
  Caller     :  caller

=cut

sub getAttribute {
    my ($self, $dataset_name, $attributename, $schema_name, $interface) = @_;
    
    $schema_name ||= 'default';
    $interface ||= 'default';
    # Retrieve config-info for this dataset, return undef if can't be found
    my $dataset_obj   = $self->getDatasetByName($schema_name,$dataset_name);
    if(!defined($dataset_obj)) {
	my $errmsg = 
	    "Dataset $schema_name\.$dataset_name not found in registry";
	BioMart::Exception::Configuration->throw($errmsg);
    }
    my $dataset_conf = $dataset_obj->getConfigurationTree($interface);
    BioMart::Exception::Configuration->throw("No config-tree found for dataset $schema_name\.
                  $dataset_name") if (!$dataset_conf);
    
    # Query config-tree for attribute, return undef if we can't find it
    my $attribute = $dataset_conf->getAttributeByName($attributename);
    if(!defined($attribute)) {
	my $errmsg = "Attribute '$attributename' not found in dataset $schema_name\.$dataset_name";
	BioMart::Exception::Configuration->throw($errmsg);
    }
    
    # returning softwareVersion each time as thats the only quiet method of doing so
    # no additional memory headache as conftree is already requested for a particular att/filter
    my $softwareVersion = $dataset_conf->software_version();
    if(wantarray())
    {
         return ($attribute, $softwareVersion);
    }
    else
    {
          return $attribute;
    }
    
    #return $attribute;
}

=head2 getFilter

  Usage      :  my $filter = $registry->getFilter($dataset, $filtname, 
						  $schema, $interface);

  Description:  Retrieve filter object given its internal name and dataset
  Return type:  A BioMart::Configuration::BaseFilter implementing object, 
                or undef
  Exceptions :  none
  Caller     :  caller

=cut

sub getFilter {
    my ($self, $dataset_name, $filtername, $schema_name, $interface) = @_;
    
    $schema_name ||= 'default';
    $interface ||= 'default';
    # Retrieve config-info for this dataset, return undef if can't be found
    my $dataset_obj   = $self->getDatasetByName($schema_name,$dataset_name);
    if(!defined($dataset_obj)) {
	my $errmsg = 
	    "Dataset $schema_name\.$dataset_name not found in registry";
	BioMart::Exception::Configuration->throw($errmsg);
    }
    my $dataset_conf = $dataset_obj->getConfigurationTree($interface);
    BioMart::Exception::Configuration->throw("No config-tree found for dataset $schema_name\.
                  $dataset_name") if (!$dataset_conf);
    
    # Query config-tree for attribute, return undef if we can't find it
    my $filter = $dataset_conf->getFilterByName($filtername);
    if(!defined($filter)) {
	my $errmsg = "Filter '$filtername' not found in dataset $schema_name\.$dataset_name";
	BioMart::Exception::Configuration->throw($errmsg);
    }
    
    # returning softwareVersion each time as thats the only quiet method of doing so
    # no additional memory headache as conftree is already requested for a particular att/filter
    my $softwareVersion = $dataset_conf->software_version();
    
    if(wantarray())
    {
          return ($filter, $softwareVersion);
    }
    else
    {
          return $filter;
    }
     #return $filter;
}

=head2 getConfigTreeForDataset

  Usage      :  my $confTree = $registry->getConfigTreeForDataset($dataset, 
								  $schema, 
								  $interface);

  Description:  Retrieve ConfigTree object given its dataset and interface
  Return type:  A BioMart::Configuration::ConfigurationTree object, or undef
  Exceptions :  none
  Caller     :  caller

=cut

sub getConfigTreeForDataset {
    my ($self, $dataset_name, $schema_name,$interface) = @_;
 
   $schema_name ||= 'default';
    $interface ||= 'default';

    my $dataset = $self->getDatasetByName($schema_name,$dataset_name);
    if(!defined($dataset)) {
	my $errmsg = "Can't find dataset $schema_name\.$dataset_name in registry";
	BioMart::Exception::Configuration->throw($errmsg);
    }
    return $dataset->getConfigurationTree($interface);
}

#------------------------------------------------------------------------
=head2 getDefaultDataset

  Usage      :  my $dataset = $registry->getDefaultDataset;

  Description:  Retrieve the default Schema's default Database' default Dataset
  Return type:  Dataset object
  Exceptions :  none
  Caller     :  caller

=cut

sub getDefaultDataset {
     my ($self) = @_;
 
     my $default_schema = $self->getDefaultVirtualSchema() || 'default';
	my $default_database = $self->getDefaultDatabase($default_schema);
	$default_database ||= $self->getAllDatabaseNames($default_schema, 1)->[0];
	my $dataset_names = $self->getAllDataSetsByDatabaseName($default_schema, $default_database, 1);
	foreach my $dataset_name(@$dataset_names) {
          my $dataset = $self->getDatasetByName($default_schema, $dataset_name);
          my $is_default = $dataset->getConfigurationTree('default')->defaultDataset();
          if($is_default && $is_default eq 'true') {
               return $dataset;
	     }
     }
	# Return first dset on list if no dsets are flagged as default
	return $self->getDatasetByName($default_schema, $dataset_names->[0]); 
}


#------------------------------------------------------------------------


=head2 getAllDatabaseNames

  Usage      :  my $databases =
                    $registry->getAllDatabaseNames($virtualSchema);
                my $visible_databases =
                    $registry->getAllDatabaseNames($virtualSchema, 
						   $visible_only);

  Description:  Gets a ref to an array of database names from a particular
                virtualSchema in the registry. ('defaultSchema' is the
                virtualSchema assigned to any database not explicitly
                assigned to a virtualSchema).
                If $visible_only is defined, returns names only for
                visible databases.
  Return type:  A ref to an array of Strings
  Exceptions :  none
  Caller     :  caller

=cut

sub getAllDatabaseNames {
    my ($self, $virtualSchemaName, $visible_only) = @_;

    my @dataBaseNames;
    foreach my $virtualSchema (@{$self->getAllVirtualSchemas}){
	next unless ($virtualSchema->name eq $virtualSchemaName);
	foreach my $location (@{$virtualSchema->getAllLocations}){
	    if ($visible_only){
		push @dataBaseNames,$location->displayName 
		    if ($location->visible == 1);
	    }
	    else{
		push @dataBaseNames,$location->displayName;
	    }
	}
    }
    return (wantarray() ? @dataBaseNames : \@dataBaseNames);
}

=head2 getDefaultDatabase

  Usage      :  my $databases =
                    $registry->getDefaultDatabase($virtualSchema);


  Description:  Gets the default database name for a particular
                virtualScema from the registry.
               
  Return type:  String
  Exceptions :  none
  Caller     :  caller

=cut

sub getDefaultDatabase {
     my $self = shift;
     my $virtualSchemaName = shift;

     foreach my $virtualSchema (@{$self->getAllVirtualSchemas}){
          next unless ($virtualSchema->name eq $virtualSchemaName);
     	foreach my $location (@{$virtualSchema->getAllLocations}){
               return $location->displayName if ($location->default && $location->default == 1);
          }
          # incase no default location, use the first one as default location
          foreach my $location (@{$virtualSchema->getAllLocations}) {
               return $location->displayName;
          }
          
     }

     
     
     return '';
}

#------------------------------------------------------------------------

=head2 getAllDataSetsByDatabaseName

  Usage      :  my $dataSets =
                    $registry->getAllDatasetsByDatabaseName($virtualSchema, 
							    $DatabaseName);
                my $visible_dataSets =
                    $registry->getAllDatasetsByDatabaseName($virtualSchema, 
							    $DatabaseName, 
							    $visible_only);

  Description:  Gets a ref to an array of dataset names from the registry
                for a particular database, in a particular virtualSchema.
                If $visible_only is defined returns names only for visible
                datasets.
  Return type:  A ref to an array of Strings.
  Exceptions :  none
  Caller     :  caller

=cut

sub getAllDataSetsByDatabaseName {
	my ($self, $virtualSchemaName, $databaseName, $visible_only) = @_;
	# sort all the dataset Names in a Mart based on their displayNames if visible_only is true 
	my @dataSetNames;
	my %sortedNames;
	foreach my $virtualSchema (@{$self->getAllVirtualSchemas}){
		next unless ($virtualSchema->name eq $virtualSchemaName);
		foreach my $location (@{$virtualSchema->getAllLocations}){
			next unless ($location->displayName eq $databaseName);
			%sortedNames=();
			foreach my $dataset (@{$location->getAllDatasets}){
				if ($visible_only){
					$sortedNames{$dataset->displayName} = $dataset->name if ($dataset->visible == 1);
				}
				else{
					# directly pushing as invisible datasets often has no display Name
					push @dataSetNames,$dataset->name;
				}
			}
			if ($visible_only){
				foreach my $displayName ( sort keys %sortedNames ) {
					push @dataSetNames, $sortedNames{$displayName};
				}
			}
		}
	}
	return (wantarray() ? @dataSetNames : \@dataSetNames);    
}


#------------------------------------------------------------------------


=head2 _createAllLinks

  Usage      :  $registry->_createAllLinks();

  Description:  Investigates all datasets in the registry and
                creates all possible links between them.  Any
                already existing link will be removed.

                Also precalculates dataset clusters and
                shortest paths between datasets.

  Return type:
  Exceptions :
  Caller     :

=cut

sub _createAllLinks {
    my ($self) = @_;
    
    warn("Setting possible links between datasets\n");
    
    # Count them
    my $totalDSCount = 0;
    my $currentDSCount = 0;
    foreach my $virtualSchema (@{$self->getAllVirtualSchemas}){
	foreach my $location (@{$virtualSchema->getAllLocations}){
	    $totalDSCount += scalar @{$location->getAllDatasets};
	}
    }
    
    foreach my $virtualSchema (@{$self->getAllVirtualSchemas}){
	foreach my $location (@{$virtualSchema->getAllLocations}){
	    foreach my $dataset (@{$location->getAllDatasets}){
		 delete $dataset->{'links'};
		 delete $dataset->{'cluster'};
		 delete $dataset->{'pathHash'}; 
		 $currentDSCount++;
		 
     	 printf STDERR "\r....(scanning) %d%%",(100*($currentDSCount/$totalDSCount));
		 
		 # add any missing placeholder datasets before create links
		 my $dataSetName = $dataset->name;
		 my @interfaces = split(/\,/,$dataset->interfaces);
		 foreach my $interface(@interfaces){
		     next if (!${$dataset->get('configurationTrees')}
		              {$interface});# only do for cached configTrees
		     my $configTree = 
		              #$dataset->getConfigurationTree($interface);
         		         $dataset->getConfigurationTree($interface,'CREATE_ALL_LINKS');
		     my $configurator = $dataset->getConfigurator();

		     # incase placeholder datasets not added yet
		     $configurator->
			 addPlaceHolderDatasets($configTree,
						$virtualSchema->name,
						);
	         }
	     }
          #---------------------reset the configurations trees to 'DISK'          
          if ($self->getMode() eq 'LAZYLOAD') ### this call is made by Web.pm, when disk flag is set          
          {
               foreach my $dataset (@{$location->getAllDatasets}) {
                  my $dataSetName = $dataset->name;
     		   my @interfaces = split(/\,/,$dataset->interfaces);		 
                  foreach my $interface(@interfaces){
                      $dataset->setConfigurationTree($interface, 'LAZYLOAD');		          
                    }
               }
          }
          #---------------------
	}
    }
    print STDERR "\n";

	$currentDSCount = 0;
   	my $squaredDSCount = $totalDSCount*$totalDSCount;
    foreach my $virtualSchema (@{$self->getAllVirtualSchemas}){
	foreach my $location (@{$virtualSchema->getAllLocations}){
	    foreach my $datasetA (@{$location->getAllDatasets}){
		foreach my $locationB (@{$virtualSchema->getAllLocations}){
		    foreach my $datasetB (@{$locationB->getAllDatasets}){
		    	$currentDSCount++;
	    	 printf STDERR "\r....(linking) %d%%",(100*($currentDSCount/$squaredDSCount));
			next if ($datasetA->name eq $datasetB->name);
			$self->__linkDatasets($virtualSchema->name, 
					      $datasetA->name, 
					      $datasetB->name);
		    }
		}
	    }
	}
    }

    print STDERR "\n";

	$currentDSCount = 0;
    foreach my $virtualSchema (@{$self->getAllVirtualSchemas}){
	foreach my $location (@{$virtualSchema->getAllLocations}){
	    foreach my $dataset (@{$location->getAllDatasets}){
	    	$currentDSCount++;	    
	    	 printf STDERR "\r....(sorting) %d%%",(100*($currentDSCount/$totalDSCount));
		  $dataset->{'pathHash'} = $self->__Dijkstra(
				$virtualSchema->name, $dataset->name);
	    }
	}
    }

    print STDERR "\n";

    $self->__cluster($totalDSCount);

    # add placeholder filts/atts now all datasets initialised as can 
    # then recover real filts/atts from cached configurationTrees and 
    # also check the linking is valid
	$currentDSCount = 0;
    foreach my $virtualSchema (@{$self->getAllVirtualSchemas}){
	my $virtualSchemaName = $virtualSchema->name;
	foreach my $location (@{$virtualSchema->getAllLocations}){
	    foreach my $dataset (@{$location->getAllDatasets}){
	    	$currentDSCount++;
	     printf STDERR "\r....(resolving) %d%%",(100*($currentDSCount/$totalDSCount));
		my $dataSetName = $dataset->name;
		my @interfaces = split(/\,/,$dataset->interfaces);
		foreach my $interface(@interfaces){
		    next if (!${$dataset->get('configurationTrees')}
		               {$interface});# only do for cached configTrees
		    my $configTree = 
		         #$dataset->getConfigurationTree($interface);
   		         $dataset->getConfigurationTree($interface,'CREATE_ALL_LINKS'); 
		    my $configurator = $dataset->getConfigurator();

			$configurator->addPlaceHolders($configTree,
						       $virtualSchemaName,
						       $dataSetName,
						       $interface);
	         
	         # cause dependsOn stuff to be distributed and populated
		     $configurator->resolveDependsOn($configTree,
						       $virtualSchemaName,
						       $dataSetName,
						       $interface);
		}
	    }
          #---------------------reset the configurations trees to 'DISK'          
          if ($self->getMode() eq 'LAZYLOAD') ### this call is made by Web.pm, when disk flag is set          
          {
               foreach my $dataset (@{$location->getAllDatasets}) {
                  my $dataSetName = $dataset->name;
     		   my @interfaces = split(/\,/,$dataset->interfaces);		 
                  foreach my $interface(@interfaces){
                      $dataset->setConfigurationTree($interface, 'LAZYLOAD');		          
                    }
               }
          }
          #---------------------
	}
    }   
    
    print STDERR "\n";
}


#------------------------------------------------------------------------

=head2 getPath

  Usage      :  my @dataSetNames = $registry->getPath($virtualSchema, 
                                                      $sourceDataset, 
                                                      $targetDataset);

  Description:  Returns the shortest path from $sourceDataset
                to $targetDataset withing the given virtualSchema.

  Return type:  Array of scalars (strings, dataset names), or
                undef if a path could not be found.

  Exceptions :
  Caller     :

=cut

sub getPath {
    my ($self, $virtualSchema, $sourceDataset, $targetDataset) = @_;

    my $sourceDatasetEntry = $self->__fetchDatasetEntry($virtualSchema, 
							$sourceDataset);
    my $targetDatasetEntry = $self->__fetchDatasetEntry($virtualSchema, 
							$targetDataset);

    my $pathHash = $sourceDatasetEntry->{'pathHash'};

    my @path;

    my $currentDataset = $targetDataset;

    while (defined $currentDataset) {
        unshift @path, $currentDataset;
        $currentDataset = $pathHash->{$currentDataset};
    }

    if (!$path[0] || ($path[0] ne $sourceDataset) ||
        !$path[-1] || ($path[-1] ne $targetDataset)) {
        return undef;
    }
    return (wantarray() ? @path : \@path);
}




#------------------------------------------------------------------------

=head2 configure

  Usage      :  $registry->configure();
                $registry->configure([['hsapiens_gene_ensembl'],
				      ['mmusculus_gene_ensembl']);
                $registry->configure([['hsapiens_gene_ensembl',
				       'default',
				       'default'],
				      ['mmusculus_gene_ensembl',
				       'default',
				       'default']]);

  Description:  The method caches configurationTrees in the Dataset
                objects for the specified datasets (or all if none are 
		specified) and builds all possible links between subsystem 
		by calling Registry::createAllLinks()

  Return type:  

  Exceptions :
  Caller     :

=cut

sub configure {
    my ($self,$datasets) = @_;
    
     if (!$datasets)
     {
	    $self->_getConfigurationTrees;
     }
     else
     {
     	foreach my $dataset(@{$datasets}){
	     $self->getConfigTreeForDataset(${$dataset}[0],
	                                   ${$dataset}[1] || 'default',
	                                   ${$dataset}[2] || 'default');
	    }
         $self->_createAllLinks();
     }

     #----------------------------------------------------------------
     if ($self->getMode() eq 'LAZYLOAD')
     {
          my $v_schemas = $self->getAllVirtualSchemas();
		foreach my $schema (@$v_schemas)
		{
		my $databases = $self->getAllDatabaseNames($schema->name()); ## databases are locations as per old API calls
			foreach my $database_name (@$databases)
			{
				my $datasets = $self->getAllDataSetsByDatabaseName($schema->name(), $database_name);
				foreach my $dataset_name(@$datasets)
				{
					my $dataset = $self->getDatasetByName($schema->name(), $dataset_name); 				
					my $interfacesList = $dataset->interfaces(); # should return a comma separated list of interfaces
					my @interfacesArray = split /,/,$interfacesList; 
					foreach my $interface(@interfacesArray)
					{
						$dataset->setExportables($interface, 'LAZYLOAD');
						$dataset->setImportables($interface, 'LAZYLOAD');
					}
				}
			}
		}     
     }
     #----------------------------------------------------------------
}





#------------------------------------------------------------------------

=head2 _getConfigurationTrees

  Usage      :  $registry->_getConfigurationTrees();

  Description:  The method caches all configurationTrees in the Dataset
                pbjects and builds all possible links between subsystem by 
                calling Registry::createAllLinks()

  Return type:  

  Exceptions :
  Caller     :

=cut

sub _getConfigurationTrees {
    my $self = shift;
    
    my $dsCounter;
    foreach my $virtualSchema (@{$self->getAllVirtualSchemas}){
	foreach my $location (@{$virtualSchema->getAllLocations}){
	    $dsCounter=0;
	    foreach my $dataset (@{$location->getAllDatasets}){
		my @interfaces = split(/\,/,$dataset->interfaces);
	        foreach my $interface(@interfaces){
		    $dsCounter++;
		    $dataset->getConfigurationTree($interface,$dsCounter);
              }
	    }
	}
    }   
    $self->_createAllLinks();
}


sub toXML {
  my ($self, $registryXML) = @_;

  if ($registryXML) {
     $self->{'registryXML'}=$registryXML;
  }
  return $self->{'registryXML'};
}



=head2 interface_type

  Usage      :  $registry->interface_type
  Description:  get/set the interface_type
  Returntype :  string interface_type
  Exceptions :  none
  Caller     :  caller

=cut


sub interface_type {

  my ($self, $value) = @_;

  if ($value) {
    $self->{'interface_type'}= $value;
  }
  return $self->{'interface_type'};

}


=head2 addVirtualSchema

  Usage      : usage
  Description: Description
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub addVirtualSchema {
  my ($self, $virtualSchema) = @_;

  my $virtualSchemas = $self->get('virtualSchemas');
  push @{$virtualSchemas}, $virtualSchema;
}


#------------------------------------------------------------------------

=head2 getVirtualSchemaByName

  Usage      :  
  Description:  Fetches a virtualSchema entry.  
  Caller     :  

=cut

sub getVirtualSchemaByName {
    my ($self, $virtualSchemaName) = @_;
    my $retSchema;
    foreach my $virtualSchema (@{$self->getAllVirtualSchemas}){
	return $virtualSchema if ($virtualSchema->name eq $virtualSchemaName);
	
    }
    return $retSchema;
}


=head2 getAllVirtualSchemas

  Usage      : usage
  Description: Description
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub getAllVirtualSchemas {
  my $self = shift;
  return $self->get('virtualSchemas');
}

=head2 removeVirtualSchema

  Usage      : usage
  Description: Description
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub removeVirtualSchema {
  my ($self,$virtualSchema) = @_;
  my $virtualSchemas = $self->getAllVirtualSchemas;
  my $i = 0;
  foreach my $vs (@$virtualSchemas){
      if ($vs->name eq $virtualSchema->name){
	  splice @$virtualSchemas,$i,1;
	  last;
      }
      $i++;
  }
}


sub getDatasetsExportingTo {
    my ($self,$virtualSchema,$to_dataset) = @_;

    my @exporting_datasets;
    my $dataset_names = $self->getAllDatasetNames($virtualSchema,1);
    foreach my $fr_dataset (@{$dataset_names}){
	next if ($fr_dataset eq $to_dataset);
	push @exporting_datasets, $fr_dataset if ($self->getLinkBetween(
		  $virtualSchema,$fr_dataset,$to_dataset));
    }
    return @exporting_datasets;
}

# only called by linked dataset panel to reverse the order of DBs in linking Menu
sub getDatasetsExportingTo_reverseDBs
{
	my ($self,$virtualSchema,$to_dataset) = @_;
	my @exporting_datasets;
	my $dataset_names = $self->getAllDatasetNames($virtualSchema,1);
	foreach my $fr_dataset (@{$dataset_names}) {
		next if ($fr_dataset eq $to_dataset);
		push @exporting_datasets, $fr_dataset if ($self->getLinkBetween(
		$virtualSchema,$fr_dataset,$to_dataset));
	}

	# get LocationName of this dataset
	my $to_datasetLocationName = $self->getDatasetByName($virtualSchema, $to_dataset)->locationDisplayName();

	# maintain the same order of datasets by rearrange them as
	# the mart of first DS selection should go at the bottom of second dataset list
	my @allMarts;
	my %martsHash;
	my %martsHashDefaultDS;
	my @revisedOrder;
	foreach my $virtualSchemaObj (@{$self->getAllVirtualSchemas}) {
		next unless ($virtualSchemaObj->name eq $virtualSchema);
		foreach my $location (@{$virtualSchemaObj->getAllLocations(1)}) {				
			next if ($location->displayName() eq $to_datasetLocationName);
			push @allMarts, $location->displayName();
		}
		push @allMarts, $to_datasetLocationName;
	}
	
	# assigning datasets to their marts, except default datasets, they need to be sorted
	foreach my $dsName (@exporting_datasets) {
		my $dsObj = $self->getDatasetByName($virtualSchema, $dsName);
		my $dbName = $dsObj->locationDisplayName();
		if ($dsObj->getConfigurationTree('default')->defaultDataset())	{
			#push @{$martsHashDefaultDS{$dbName}}, $dsName;
			push @{$martsHash{$dbName}}, $dsName;
		}
		else {		
			push @{$martsHash{$dbName}}, $dsName;
		}
	}
	
	# sorting default datasets and adding them to their respective mart keys
	foreach my $dbName (keys %martsHashDefaultDS)	{
		if ($martsHashDefaultDS{$dbName}) {
			foreach my $dsName (reverse sort(@{$martsHashDefaultDS{$dbName}})) {
				unshift @{$martsHash{$dbName}}, $dsName;
			}
		}
	}
	
	# determine if splitter-line is required or not. 
	# this is only required when linking within the mart and across
	# marts exists
	my $splitter_line = 0;
	$splitter_line = 1 if($martsHash{$to_datasetLocationName} && scalar keys %martsHash > 1);

	foreach my $martName (@allMarts) {
		push @revisedOrder, "splitter-line" if($splitter_line && $martName eq $to_datasetLocationName);
		foreach (@{$martsHash{$martName}}) {
			push @revisedOrder, $_;
		}
	}
	
	return @revisedOrder;
}

#------------------------------------------------------------------------
# internal

=head2 __linkDatasets (internal)

  Usage      :  $self->linkDatasets(
                    $virtualSchema,
                    $sourceDatasetName,
                    $targetDatasetName);

  Description:  Links two datasets in the same virtualSchema, if
                possible.

  Caller     :  BioMart::Registry

=cut

sub __linkDatasets {
    my ($self, $virtualSchema, $sourceDatasetName, $targetDatasetName) = @_;

    my $sourceDataset =
        $self->__fetchDatasetEntry($virtualSchema, $sourceDatasetName);

    return unless ($sourceDataset);

    my $targetDataset =
        $self->__fetchDatasetEntry($virtualSchema, $targetDatasetName);

    return unless ($targetDataset);

    my $link = BioMart::Links->new($self);
    $link->sourceDataset($sourceDatasetName);
    $link->targetDataset($targetDatasetName);

    my $haveLink = 0;

    my @sourceInterfaces = split(/\,/,$sourceDataset->interfaces);
    my @targetInterfaces = split(/\,/,$targetDataset->interfaces);

    foreach my $importable (@{ $targetDataset->getImportables() }) {
        foreach my $exportable (@{ $sourceDataset->getExportables() }) { 
            if ($importable->linkName eq $exportable->linkName) {
            # do not link on DAS or GFF type exp/imp pairs
				next if ($importable->type() ne 'link' || $exportable->type ne 'link');
				# versions must be compatible as well if exists for both
				next if (($importable->linkVersion && $exportable->linkVersion)
                    && ($importable->linkVersion ne $exportable->linkVersion));
                $link->addLink($virtualSchema, $importable->linkName);
                $haveLink = 1;
	    }
	}
    }

    if ($haveLink) {
        push @{ $sourceDataset->{'links'} }, $link;
        push @{ $targetDataset->{'links'} }, $link;
      }
}

#------------------------------------------------------------------------

=head2 __fetchDatasetEntry (internal)

  Usage      :  my $dataSetEntry =
                    $self->__fetchDatasetEntry($virtualSchema, $DatasetName);

  Description:  Fetches a dataset entry.  Throws an exception if the
                dataset does not exist.

  Caller     :  BioMart::Registry

=cut

sub __fetchDatasetEntry {
    my ($self, $virtualSchemaName, $dataSetName, $martUser) = @_;
    return unless ($virtualSchemaName && $dataSetName);
    my $retDataset;
    OUTER:foreach my $virtualSchema (@{$self->getAllVirtualSchemas}){
	next unless ($virtualSchema->name eq $virtualSchemaName);
	foreach my $location (@{$virtualSchema->getAllLocations}){
	    next if ($martUser && $location->martUser && $location->martUser 
		     ne $martUser);
	    my $dataSetEntry = $location->getDatasetByName($dataSetName);
	    if (defined $dataSetEntry) {
		return $dataSetEntry;
	    }	
	}
    }
    return $retDataset;
}

#------------------------------------------------------------------------

=head2 __Dijkstra (internal)

  Usage      :  my $pathHash = $registry->__Dijkstra($virtualSchema, 
						     $sourceDataset);

  Description:  Computes all shortest paths from $sourceDataset within
                a particular virtualSchema.
                See "http://en.wikipedia.org/wiki/Dijkstra's_algorithm"

  Caller     :  BioMart::Registry::createAllLinks()

=cut

sub __Dijkstra {
    my ($self, $virtualSchema, $dataSetName) = @_;

    my @vertices = $self->getAllDatasetNames($virtualSchema);

    my %dist;
    my %path;

    foreach my $vertex (@vertices) {
        $dist{$vertex} = INF;
    }

    $dist{$dataSetName} = 0;

    while (scalar @vertices > 0) {
        my $min_vert_idx = 0;
        my $min_vert = $vertices[$min_vert_idx];
        my $min_dist = $dist{$min_vert};

        for (my $vertex_idx = 1;
            $vertex_idx < scalar @vertices;
            ++$vertex_idx) {

            my $vertex = $vertices[$vertex_idx];
            if ($dist{$vertex} < $min_dist) {
                $min_vert_idx = $vertex_idx;
                $min_vert = $vertex;
                $min_dist = $dist{$vertex};
            }
        }

        if ($min_dist == INF) {
            # Exhausted a disjoint set of datasets.
            last;
        }

        splice @vertices, $min_vert_idx, 1;

        my @edges = $self->__getLinksFrom($virtualSchema, $min_vert);
        foreach my $edge (@edges) {
            my $vertex = $edge->targetDataset();

            if ($dist{$vertex} > $dist{$min_vert} + 1) {
                $dist{$vertex} = $dist{$min_vert} + 1;
                $path{$vertex} = $min_vert;
            }
	}
    }

    return \%path;
}

#------------------------------------------------------------------------

=head2 __cluster (internal)

  Usage      :  $registry->__cluster();

  Description:  Finds all of the connected sets of the
                datasets within each virtualSchema.  
                Assigns a cluster ID to the members
                of each set.

  Caller     :  BioMart::Registry::createAllLinks()

=cut

sub __cluster {
    my $self = shift;
    my $totalDSCount = shift;

    my $cluster = 0;
	my $currentDSCount = 0;

    foreach my $virtualSchema (@{$self->getAllVirtualSchemas}){
	my $vSchema = $virtualSchema->name;
	foreach my $location (@{$virtualSchema->getAllLocations}){
	    foreach my $seedDatasetEntry (@{$location->getAllDatasets}){
	    	$currentDSCount++;
		    print STDERR "\r....(clustering) ".$currentDSCount."/".$totalDSCount."                ";
	    	
		my $seedDataset = $seedDatasetEntry->name;	
		
		next if (defined $seedDatasetEntry->{'cluster'});

		my @vertices = ( $seedDataset );

		++$cluster;

		
		while (scalar @vertices > 0) {
		    my $dataSet = shift @vertices;

		    print STDERR "\r....(clustering) ".$currentDSCount."/".$totalDSCount." - ".(scalar @vertices)." remain    ";

		    foreach my $otherDataset (
			$self->__getDatasetsImportingFrom($vSchema, $dataSet),
			$self->__getDatasetsExportingTo($vSchema, $dataSet)) {

			my $otherDatasetEntry = $self->getDatasetByName
			    ($vSchema,$otherDataset);
			next if ($otherDatasetEntry->{'cluster'});
			push @vertices, $otherDataset;
		    }
		    
		    my $thisEntry = $self->getDatasetByName($vSchema,$dataSet);
		    $thisEntry->{'cluster'} = $cluster;
		}
	    }
	}
    }
    
    print STDERR "\n";
}




#--------------------------------------------------------------------

=head2 __getDatasetsImportingFrom (internal)

  Usage      :  my @dataSetNames =
                    $registry->__getDatasetsImportingFrom($virtualSchema, 
							$DatasetName);

  Description:  Returns the names of the datasets that import
                from the named dataset within the given virtualSchema.

  Return type:  An array of strings in list context, or a
                reference to such an array in scalar context.

  Exceptions :
  Caller     :

=cut

sub __getDatasetsImportingFrom {
    my ($self, $virtualSchema, $dataSetName) = @_;

    my $dataSetEntry = $self->__fetchDatasetEntry($virtualSchema, 
						  $dataSetName);

    my @dataSetNames;
    foreach my $link (@{ $dataSetEntry->{'links'} }) {
        my $targetDatasetName = $link->targetDataset();
        my $targetDatasetEntry =
            $self->__fetchDatasetEntry($virtualSchema, $targetDatasetName);

        my $sourceDatasetName = $link->sourceDataset();
        my $sourceDatasetEntry =
            $self->__fetchDatasetEntry($virtualSchema, $sourceDatasetName);

        if ($sourceDatasetName eq $dataSetName) {
            push @dataSetNames, $targetDatasetName;
        }
    }

    return (wantarray() ? @dataSetNames : \@dataSetNames);
}

#------------------------------------------------------------------------

=head2 __getDatasetsExportingTo (internal)

  Usage      :  my @dataSetNames =
                    $registry->__getDatasetsExportingTo($virtualSchema, 
						      $DatasetName);

  Description:  Returns the names of the datasets that export
                to the named dataset within the given virtualSchema.

  Return type:  An array of strings in list context, or a
                reference to such an array in scalar context.

  Exceptions :
  Caller     :

=cut

sub __getDatasetsExportingTo {
    my ($self, $virtualSchema, $dataSetName) = @_;

    my $dataSetEntry = $self->__fetchDatasetEntry($virtualSchema, 
						  $dataSetName);

    my @dataSetNames;
    foreach my $link (@{ $dataSetEntry->{'links'} }) {
        my $targetDatasetName = $link->targetDataset();
        my $targetDatasetEntry =
            $self->__fetchDatasetEntry($virtualSchema, $targetDatasetName);

        my $sourceDatasetName = $link->sourceDataset();
        my $sourceDatasetEntry =
            $self->__fetchDatasetEntry($virtualSchema, $sourceDatasetName);

        if ($targetDatasetName eq $dataSetName) {
            push @dataSetNames, $sourceDatasetName;
	  }
    }
    return (wantarray() ? @dataSetNames : \@dataSetNames);
}

#------------------------------------------------------------------------

=head2 __getLinksFrom (internal)

  Usage      :  my @links =
                    $registry->__getLinksFrom($virtualSchema, $DatasetName);

  Description:  Returns all BioMart::Links objects defining
                a directional link from the named Dataset to
                a Dataset able to import from the named Dataset
                within the given virtualSchema.
  Return type:  An array of BioMart::Links objects in list
                context, or a reference to such an array in
                scalar context.

  Exceptions :
  Caller     :

=cut



sub __getLinksFrom {
    my ($self, $virtualSchema, $dataSetName) = @_;

    my $dataSetEntry = $self->__fetchDatasetEntry($virtualSchema, 
						  $dataSetName);

    my @links;
    foreach my $link (@{ $dataSetEntry->{'links'} }) {
        my $targetDatasetName = $link->targetDataset();
        my $targetDatasetEntry =
            $self->__fetchDatasetEntry($virtualSchema, $targetDatasetName);

        my $sourceDatasetName = $link->sourceDataset();
        my $sourceDatasetEntry =
            $self->__fetchDatasetEntry($virtualSchema, $sourceDatasetName);

        if ($sourceDatasetName eq $dataSetName) {
            push @links, $link;
	}
    }

    return (wantarray() ? @links : \@links);
}

=head2  settingsParams

  Usage      :  $registry->settingsParams($settingsHash);

  Description:  adds all params in hash passed to registry
                These params come from settings.conf
                only used by Web.pm and martview
  
  Return type:  

  Exceptions :
  Caller     : Initializer's getRegistry()

=cut
sub settingsParams
{
     my ($self, $hash) = @_;
     if($hash)
     {
          $self->set('settingsConfParams', $hash);
     }
     return $self->get('settingsConfParams');
}

1;

# vim: et
