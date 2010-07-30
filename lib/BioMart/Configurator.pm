# $Id: Configurator.pm,v 1.17.2.1 2008-07-04 16:12:59 syed Exp $
#
# BioMart module for BioMart::Configurator
#
# You may distribute this module under the same terms as perl
# itself.

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configurator

=head1 SYNOPSIS

TODO: Synopsis here.

=head1 DESCRIPTION

Each dataset is associated with a BioMart::Configurator
object.  This object is shared among all BioMart::Dataset
objects.  It holds information about database connectivity
(getConnectionAttribute()) and knows how to parse the
configuration file for a dataset (getConfigurationTree()).

=head1 AUTHOR - Arek Kasprzyk, Syed Haider, Richard Holland, Darin London, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project
http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut

#------------------------------------------------------------------------

package BioMart::Configurator;

use strict;
use warnings;

use XML::Simple qw(:strict);
use Compress::Zlib;
use Data::Dumper;
use Storable qw(store retrieve freeze nfreeze thaw);
local $Storable::Deparse = 1;
$Storable::forgive_me = 1;
use Cwd;
use BioMart::Web::CGIXSLT;

use DBI;
use Socket;

use BioMart::Configuration::ConfigurationTree;
use BioMart::Configuration::AttributeTree;
use BioMart::Configuration::FilterTree;
use BioMart::Configuration::AttributeGroup;
use BioMart::Configuration::FilterGroup;
use BioMart::Configuration::AttributeCollection;
use BioMart::Configuration::FilterCollection;
use BioMart::Configuration::Attribute;
use BioMart::Configuration::Option;
use BioMart::Configuration::PushAction;
use BioMart::Configuration::BooleanFilter;
use BioMart::Configuration::ValueFilter;
use BioMart::Configuration::AttributeList;
use BioMart::Configuration::FilterList;
use BioMart::Configuration::FilterList_List;


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

  Usage      :  my $configurator =
                    BioMart::Configurator->new(
                        $registry, $connectionAttributes);

  Description:  Creates a BioMart::Configurator object.

                The $registry argument should be a
                BioMart::Registry object, and $location a
                BioMart::Configuration::Location object
                    }

  Return type:  A BioMart::Configurator object.
  Exceptions :
  Caller     :  BioMart::Initializer::getRegistry()

=cut

sub _new {
    my ($self, $registry, $location, @params) = @_;

    $self->SUPER::_new(@params);

    $self->attr('registry', $registry);
    $self->attr('location', $location);
}


#------------------------------------------------------------------------

=head2 getConfigurationTree

  Usage      :  my $configurationTree =
                    $configurator->getConfigurationTree($virtualSchema, 
							$dataSetName);

  Description:  Builds the configuration tree for the named dataset in the 
                given virtualSchema using the XML pulled out of the database
                specified in the connection parameters for $dataSetName, if it does
                not already exists on disk

  Return type:  BioMart::Configuration::ConfigurationTree
  Exceptions :
  Caller     :

=cut

sub getConfigurationTree {
	my ($self, $virtualSchema, $dataSetName, $interfaceType,$dsCounter) = @_;
	my $registry = $self->get('registry');
	my $dataSet = $registry->getDatasetByName($virtualSchema, $dataSetName);
	
    #-------------------------------------- 
	my $xml;
	my $xmlFile = $registry->getDirPath();
	$xmlFile .= $virtualSchema."/XML/";     
	$xmlFile .= $self->get('location')->name().".".$dataSetName.".".$interfaceType;
	#$xmlFile .= $self->get('location')->database().".".$dataSetName.".".$interfaceType;
   
	if(-e $xmlFile) # if xml file exists on disk
	{
		$xml = ${retrieve($xmlFile)};
		print STDERR $self->get('location')->name(), "...", $dataSetName, "...", $interfaceType, "...", "Retrieving xml from DISK: ";
		#print STDERR $self->get('location')->database(), "...", $dataSetName, "...", $interfaceType, "...", "Retrieving xml from DISK: ";
	}
	else # Get XML from the appropriate server
	{
		$xml = $self->get('location')->getDatasetConfigXML($virtualSchema,
							  $dataSetName,
							  $interfaceType,
							  $dsCounter);

		# same funny character ü comes, and XML Parser moans. for pancreasExpression DB, 
		# we request ensembl datasets from webservice and on our side, parser crashes
		# $xml =~ s/Müller/Muller/mg;
		$xml =~ s/M[^a-zA-Z]{1}ller/Muller/mg;
		#print STDERR "\n\n", $xml;
		
		my $tempXMLHash = XMLin($xml, forcearray => [qw(AttributePage AttributeGroup 
		 	AttributeCollection AttributeDescription FilterPage FilterGroup 
			FilterCollection FilterDescription Importable Exportable Key 
			MainTable BatchSize SeqModule Option PushAction)], keyattr => []);

		my $softwareVersion = $tempXMLHash->{'softwareVersion'};
		# Transformation from 0.4 to 0.5 & 0.6
		if (!$softwareVersion || ($softwareVersion eq '0.4')) 
		{  
			# 0.4 TO 0.5
			print STDERR "->  upgrading to 0.5 ... ";
			my $params=BioMart::Web::CGIXSLT::read_https();
			open(STDOUTTEMP, ">temp.xml");
			print STDOUTTEMP $xml;
			close(STDOUTTEMP);
			$params->{'source'} = 'temp.xml';      
			$params->{'style'} = $registry->getDirPath().'../mart_0_4_0_5.xsl';
			my $new_xml;
			eval{$new_xml=BioMart::Web::CGIXSLT::transform();};
			if($@){BioMart::Web::CGIXSLT::print_error("Exception: Configurator Cannot parse xml as per xsl. $@\n"); exit;};
			#Now, we are printing and saving what we get
			$xml = BioMart::Web::CGIXSLT::print_output($new_xml);
			if (-e 'temp.xml') {
				unlink 'temp.xml';
			}
			
			# 0.5 TO 0.6
			print STDERR "->  upgrading to 0.6/0.7 ... ";
			$params=();
			$params=BioMart::Web::CGIXSLT::read_https();
			# ENSEMBL 37 & 38 crashes during this transformation for dataset  evoc_cell_type by XML:Parser 
			# used by CGIXSLT. The funny character ü comes and is lost after first transformation
			# $xml =~ s/\<Option displayName=\"M.*ller cell\" internalName=\"m.*ller_cell\" isSelectable=\"true\" value=\"M.*ller cell\" displayType=\"text\" multipleValues=\"1\" graph=\"\" style=\"\" autoCompletion=\"\"\/\>/\<Option displayName=\"Müller cell\" internalName=\"müller_cell\" isSelectable=\"true\" value=\"Müller cell\" displayType=\"text\" multipleValues=\"1\" graph=\"\" style=\"\" autoCompletion=\"\"\/\>/mg;

			open(STDOUTTEMP, ">temp.xml");
			print STDOUTTEMP $xml;
			close(STDOUTTEMP);
			$params->{'source'} = 'temp.xml';      
			$params->{'style'} = $registry->getDirPath().'../mart_0_5_0_6.xsl';
			eval{$new_xml=BioMart::Web::CGIXSLT::transform();};
			if($@){BioMart::Web::CGIXSLT::print_error("Exception: Configurator Cannot parse xml as per xsl. $@\n"); exit;};
			#Now, we are printing and saving what we get
			$xml = BioMart::Web::CGIXSLT::print_output($new_xml);
			if (-e 'temp.xml') {
				unlink 'temp.xml';
			}						
		}
		# Transform from 0.5 to 0.6
		if ($softwareVersion && $softwareVersion eq '0.5')
		{
			# 0.5 TO 0.6
			print STDERR "->  upgrading to 0.6/0.7 ... ";
			my $params=BioMart::Web::CGIXSLT::read_https();
			open(STDOUTTEMP, ">temp.xml");
			print STDOUTTEMP $xml;
			close(STDOUTTEMP);
			$params->{'source'} = 'temp.xml';      
			$params->{'style'} = $registry->getDirPath().'../mart_0_5_0_6.xsl';
			my $new_xml;
			eval{$new_xml=BioMart::Web::CGIXSLT::transform();};
			if($@){BioMart::Web::CGIXSLT::print_error("Exception: Configurator Cannot parse xml as per xsl. $@\n"); exit;};
			#Now, we are printing and saving what we get
			$xml = BioMart::Web::CGIXSLT::print_output($new_xml);
			if (-e 'temp.xml') {
				unlink 'temp.xml';
			}			
		}		
		store(\$xml, $xmlFile);
	}
	#--------------------------------------

    unless ($xml) {
	BioMart::Exception::Configuration->throw("Could not get xml for $dataSetName, interface $interfaceType\n");
    }

    # if want contents to be forced to be arrays even when there is a single
    #  entry should set in the forcearray options
    my $xmlHash = XMLin($xml, forcearray => [qw(AttributePage AttributeGroup 
	  AttributeCollection AttributeDescription AttributeList FilterPage FilterGroup 
	  FilterCollection FilterDescription Importable Exportable Key 
          MainTable BatchSize SeqModule Option PushAction)], keyattr => []);

    my $configurationTree = BioMart::Configuration::ConfigurationTree->new(
	     'dataSetName'  => $dataSetName,
    );
	# HERE XML version is 0.5 for our local marts and NONE for dicty and wormbase
	#open(STDVER,">>/homes/syed/Desktop/temp2/biomart-web/lib/BioMart/Configuration/version");
	#my $softwareVersion = $xmlHash->{'softwareVersion'};
	#print STDVER "!!!! DATASET $dataSetName Version: $softwareVersion ";
	#print STDVER "\n";
	#close(STDVER);
	#    #TODO: deal with softwareVersion test
	#    my $softwareVersion = $xmlHash->{'softwareVersion'};
	#    if (!$softwareVersion) {       
	#	warn("!!!! DATASET $dataSetName Version does NOT exist ") ;
	#    }
	#    elsif ( $softwareVersion ne '0.5') {       
	#	warn("!!!! DATASET $dataSetName Version: $softwareVersion ") ; 
	#    }
	#    #TODO: implement noCount functionality for datasets with it set
	#    my $noCount = $xmlHash->{'noCount'};
	#    warn("!!!! DATASET $dataSetName HAS NO COUNT SET ") if ($noCount && $noCount == 1);

    #resticted primary key access
    my $restricted_pk = $xmlHash->{'primaryKeyRestriction'};
    if ($restricted_pk) {
	$configurationTree->primaryKeyRestriction($restricted_pk);
    }

    #entry label
    my $entry_label = $xmlHash->{'entryLabel'};
    if ($entry_label) {
	$configurationTree->entryLabel($entry_label);
    }

    #optional parameters
    my $opt_params = $xmlHash->{'optional_parameters'};
    if ($opt_params) {
	$configurationTree->optionalParameters($opt_params);
    }

    #default dataset
    if ($xmlHash->{'defaultDataset'} 
	&& $xmlHash->{'defaultDataset'} eq 'true') {
	$configurationTree->defaultDataset('true');
    }
   
    #visible on filter page
    if ($xmlHash->{'visibleFilterPage'} 
	&& $xmlHash->{'visibleFilterPage'} == 1) {
	$configurationTree->visibleFilterPage('true');
    }
    
    #martUsers
    my $mart_users = $xmlHash->{'martUsers'};
    $configurationTree->mart_Users($mart_users);
    
    #xml version, would help in deciding what should be the version of xml query
    my $softwareVersion = $xmlHash->{'softwareVersion'};
    if (!$softwareVersion) 
    {       
	    $configurationTree->software_version('0.4');# special case for dicty
    }
    else
    {
	    $configurationTree->software_version($softwareVersion);
    }    

    # ATTRIBUTES
    foreach my $xmlAttributeTree (@{ $xmlHash->{'AttributePage'} }) {
	next if ($xmlAttributeTree->{'hidden'}
		 && $xmlAttributeTree->{'hidden'} eq 'true');
	my $outFormats = $xmlAttributeTree->{'outFormats'};
	$outFormats =~ s/,,/,/g if ($outFormats);
        my $attributeTree = BioMart::Configuration::AttributeTree->new(
		'name'        => $xmlAttributeTree->{'internalName'},
		'displayName' => $xmlAttributeTree->{'displayName'},
		'description' => $xmlAttributeTree->{'description'},
		'hideDisplay' => $xmlAttributeTree->{'hideDisplay'},
		'outFormats'  => $outFormats,
		'maxSelect'  => $xmlAttributeTree->{'maxSelect'},    
								       );
        foreach my $xmlAttributeGroup
            (@{ $xmlAttributeTree->{'AttributeGroup'} }) {
	    next if ($xmlAttributeGroup->{'hidden'} 
		     && $xmlAttributeGroup->{'hidden'} eq 'true');
            my $attributeGroup = BioMart::Configuration::AttributeGroup->new(
                    'name'        => $xmlAttributeGroup->{'internalName'},
                    'displayName' => $xmlAttributeGroup->{'displayName'},
		'description' => $xmlAttributeGroup->{'description'},
                    'maxSelect'   => $xmlAttributeGroup->{'maxSelect'},
									     );

            foreach my $xmlAttributeCollection
                (@{ $xmlAttributeGroup->{'AttributeCollection'} }) {
                next if ($xmlAttributeCollection->{'hidden'} 
			 && $xmlAttributeCollection->{'hidden'}eq 'true');
                my $attributeCollection =
                  BioMart::Configuration::AttributeCollection->new(
                     'name' => lc($xmlAttributeCollection->{'internalName'}),
		     'displayName' => $xmlAttributeCollection->{'displayName'},
		'description' => $xmlAttributeCollection->{'description'},
		     'maxSelect'  => $xmlAttributeCollection->{'maxSelect'},
  		     'selectAll'  => $xmlAttributeCollection->{'enableSelectAll'} || 'false',
								   );
                foreach my $xmlAttribute
                    (@{ $xmlAttributeCollection->{'AttributeDescription'} }) {
		    next if ($xmlAttribute->{'hidden'} 
			     && $xmlAttribute->{'hidden'} eq 'true');
                    my $attribute;
		    if ($xmlAttribute->{'pointerDataset'} 
			&& $xmlAttribute->{'pointerInterface'} 
			&& ($xmlAttribute->{'pointerAttribute'} 
			    || $xmlAttribute->{'pointerFilter'})){
			next;#add placeholders after createAllLinks
		    }
		    else{
			$attribute =
			   BioMart::Configuration::Attribute->new(
                            'name' => lc($xmlAttribute->{'internalName'}),
                            'displayName' => $xmlAttribute->{'displayName'},
                            'description' => $xmlAttribute->{'description'},
                            'imageURL' => $xmlAttribute->{'imageURL'},
                            'table' => $xmlAttribute->{'tableConstraint'},
                            'relational_attribute' => $xmlAttribute->{'field'},
                            'key' => lc($xmlAttribute->{'key'}),# lc to keep oracle happy
			    'width' => $xmlAttribute->{'maxLength'},
			    'link'  => $xmlAttribute->{'linkoutURL'},
			    'datasetLink' => $xmlAttribute->{'datasetLink'},
			    'default' => $xmlAttribute->{'default'},      
			    'dependsOnType' => $xmlAttribute->{'dependsOnType'},      
			    'dependsOn' => $xmlAttribute->{'dependsOn'},   
                            'dataSetName' => $dataSetName,
                            'interface' => $interfaceType,
                        );
                    $attributeCollection->addAttribute($attribute);
		    }
                }
                
                foreach my $xmlAttribute
                    (@{ $xmlAttributeCollection->{'AttributeList'} }) {
                    my $attribute;
			$attribute =
			   BioMart::Configuration::AttributeList->new(
                            'name' => lc($xmlAttribute->{'internalName'}),
                            'displayName' => $xmlAttribute->{'displayName'},
                            'description' => $xmlAttribute->{'description'},
                            'imageURL' => $xmlAttribute->{'imageURL'},
                            'table' => $xmlAttribute->{'tableConstraint'},
                            'relational_attribute' => $xmlAttribute->{'field'},
                            'key' => lc($xmlAttribute->{'key'}),# lc to keep oracle happy
			    'width' => $xmlAttribute->{'maxLength'},
			    'link'  => $xmlAttribute->{'linkoutURL'},
			    'datasetLink' => $xmlAttribute->{'datasetLink'},
			    'default' => $xmlAttribute->{'default'},      
			    'dependsOnType' => $xmlAttribute->{'dependsOnType'},      
			    'dependsOn' => $xmlAttribute->{'dependsOn'},     
			    'attribute_string' => $xmlAttribute->{'attributes'},        
                            'dataSetName' => $dataSetName,
                            'interface' => $interfaceType,
                        );
                    $attributeCollection->addAttribute($attribute);

                }
                
                $attributeGroup->addCollection($attributeCollection);
            }
            $attributeTree->addAttributeGroup($attributeGroup);
        }
    
        $configurationTree->addAttributeTree($attributeTree);
    }	
    
    # FILTERS
    
    foreach my $xmlFilterTree (@{ $xmlHash->{'FilterPage'} }) {
        next if ($xmlFilterTree->{'hidden'} 
		 && $xmlFilterTree->{'hidden'} eq 'true');
        my $filterTree = BioMart::Configuration::FilterTree->new(
                'name'  => $xmlFilterTree->{'internalName'},
                'displayName' => $xmlFilterTree->{'displayName'},
		'hideDisplay' => $xmlFilterTree->{'hideDisplay'}
								 );
        foreach my $xmlFilterGroup (@{ $xmlFilterTree->{'FilterGroup'} }) {
            next if ($xmlFilterGroup->{'hidden'} 
			     && $xmlFilterGroup->{'hidden'} eq 'true');
   	         my $filterGroup = BioMart::Configuration::FilterGroup->new(
                    'name'  => $xmlFilterGroup->{'internalName'},
                    'displayName' => $xmlFilterGroup->{'displayName'},
                    'description' => $xmlFilterGroup->{'description'},
								       );
            foreach my $xmlFilterCollection 
					(@{ $xmlFilterGroup->{'FilterCollection'} }) {
                next if ($xmlFilterCollection->{'hidden'} 
					 && $xmlFilterCollection->{'hidden'} eq 'true');
                my $filterCollection =
                    BioMart::Configuration::FilterCollection->new(
                        'name'  => lc($xmlFilterCollection->{'internalName'}),
                        'displayName' => $xmlFilterCollection->{'displayName'},
   	                 'description' => $xmlFilterCollection->{'description'},
								  );
                foreach my $xmlFilter
                    (@{ $xmlFilterCollection->{'FilterDescription'} }) {
                   	 	next if ($xmlFilter->{'hidden'} 
						     	&& $xmlFilter->{'hidden'} eq 'true');
						    	my $attribute;
						   	$attribute = $configurationTree->
								getAttributeByName($xmlFilter->{'internalName'});
					 	if (!$attribute){

							$attribute = BioMart::Configuration::Attribute->new(
			    				'name' => lc($xmlFilter->{'internalName'}),
                            'imageURL' => $xmlFilter->{'imageURL'},
                            'displayName' => $xmlFilter->{'displayName'},
                  	  	'description' => $xmlFilter->{'description'},
                            'table' => $xmlFilter->{'tableConstraint'},
                            'relational_attribute' => $xmlFilter->{'field'},
                            'key' => lc($xmlFilter->{'key'}),
			    				'dependsOnType' => $xmlFilter->{'dependsOnType'},      
			    					'dependsOn' => $xmlFilter->{'dependsOn'},   
                            'dataSetName' => $dataSetName,
                            'interface' => $interfaceType,
                        );
		    			}
		    
		    			my $filter;
		    		if ($xmlFilter->{'pointerDataset'} 
						&& $xmlFilter->{'pointerInterface'} && 
						$xmlFilter->{'pointerFilter'}){
						next;
		    		}
					# FILTER_LIST_HACK-part 1
		    		elsif ($xmlFilter->{'filterList'}) {
		    			#print STDERR "\nprocessing FILTER LIST: ", $xmlFilter->{'filterList'}, "\n";
		    			$filter = BioMart::Configuration::FilterList_List->new(
                    	'name'           => $xmlFilter->{'internalName'},
                    	'displayName'    => $xmlFilter->{'displayName'},
			       	  	'description' => $xmlFilter->{'description'},
		    				'filter_string'    => $xmlFilter->{'filterList'},
                    	'orderby_string' => $xmlFilter->{'orderby_string'},
                    	'dataSetName'    => $dataSetName,
                    	'interface' => $interfaceType,
                    	'type'				=> $xmlFilter->{'type'},
                    	'displayType'				=> $xmlFilter->{'displayType'},
                    	'hideDisplay'		=>	$xmlFilter->{'hideDisplay'},
                    	'legalQualifiers'		=>	$xmlFilter->{'legal_qualifiers'},
						 );
							# this is done once the configuration tree is populated, so we can find the filter Objects
							# and associate them with this filterList. see code before importables
							#foreach my $filterName (split (/,/, $xmlFilter->{'filterList'})) {
							#  my $filterListItem = $configurationTree->getFilterByName($filterName);
         				#	print Dumper($filter);
         				# 	$filter->addFilter($filterListItem);
							#}
		    		}
		    	elsif ($xmlFilter->{'type'}  
			   	&& $xmlFilter->{'type'} eq 'boolean'){
					$filter = BioMart::Configuration::BooleanFilter->new(
		               'name'          => $xmlFilter->{'internalName'},
                            'imageURL' => $xmlFilter->{'imageURL'},
			       'displayName' => $xmlFilter->{'displayName'},
			       'description' => $xmlFilter->{'description'},
			       'dataSetName' => $dataSetName,
                               'interface' => $interfaceType,
		               'buttonURL'   => $xmlFilter->{'buttonURL'},
                               'setAttributePage' => 
				       $xmlFilter->{'setAttributePage'},
                               'type'        => $xmlFilter->{'type'},
			    'dependsOnType' => $xmlFilter->{'dependsOnType'},      
			    'dependsOn' => $xmlFilter->{'dependsOn'},  
            	'hideDisplay'		=>	$xmlFilter->{'hideDisplay'},  
                    	'legalQualifiers'		=>	$xmlFilter->{'legal_qualifiers'},
									     );
			$filter->attribute($attribute);
                        $filter->defaultOn($xmlFilter->{'defaultOn'});
                        $filter->setAttribute($xmlFilter->{'setAttribute'});
		    }
		    elsif ($xmlFilter->{'type'} 
			   && $xmlFilter->{'type'} eq 'boolean_num'){
			# hack for 1,0,null snp filters
			$filter =
			    BioMart::Configuration::BooleanFilter->new(
			      'name'          => $xmlFilter->{'internalName'},
                            'imageURL' => $xmlFilter->{'imageURL'},
                              'displayName' => $xmlFilter->{'displayName'},
			       'description' => $xmlFilter->{'description'},
			      'dataSetName' => $dataSetName,
                              'interface' => $interfaceType,
			      'buttonURL'   => $xmlFilter->{'buttonURL'},
                              'setAttributePage' => 
				   $xmlFilter->{'setAttributePage'},
                              'type'        => $xmlFilter->{'type'},
			    'dependsOnType' => $xmlFilter->{'dependsOnType'},      
			    'dependsOn' => $xmlFilter->{'dependsOn'}, 
            	'hideDisplay'		=>	$xmlFilter->{'hideDisplay'},  
                    	'legalQualifiers'		=>	$xmlFilter->{'legal_qualifiers'},
								       );
			$filter->setNumberFlag();
			$filter->attribute($attribute);
                        $filter->defaultOn($xmlFilter->{'defaultOn'});
                        $filter->setAttribute($xmlFilter->{'setAttribute'});
		    }
		    else
		    {  
			    $filter =
			      BioMart::Configuration::ValueFilter->new(
				'name'        => $xmlFilter->{'internalName'},
                            'imageURL' => $xmlFilter->{'imageURL'},
                                'displayName' => $xmlFilter->{'displayName'},
			       'description' => $xmlFilter->{'description'},
                                'dataSetName' => $dataSetName,
                                'interface' => $interfaceType,
				'buttonURL'   => $xmlFilter->{'buttonURL'},
                                'setAttributePage' => 
				     $xmlFilter->{'setAttributePage'},
                                'type'        => $xmlFilter->{'type'},
			    'dependsOnType' => $xmlFilter->{'dependsOnType'},      
			    'dependsOn' => $xmlFilter->{'dependsOn'},
             	'hideDisplay'		=>	$xmlFilter->{'hideDisplay'},  
                    	'legalQualifiers'		=>	$xmlFilter->{'legal_qualifiers'},
								       );
			    $filter->attribute($attribute);
			    $filter->operation($xmlFilter->{'qualifier'});
			    $filter->otherFilters(
				 $xmlFilter->{'otherFilters'});
			    $filter->regexp($xmlFilter->{'regexp'});
			    $filter->defaultValue(
				 $xmlFilter->{'defaultValue'});
				 
			    $filter->defaultOn($xmlFilter->{'defaultOn'});
	    
			    $filter->setAttribute(
				 $xmlFilter->{'setAttribute'});			
		    }
		    # cycle through Options - needs to use a recursive method 
		    # as Options can contain further Options
		    foreach my $xmlOption (@{ $xmlFilter->{'Option'} }) {
			next if ($xmlOption->{'hidden'} 
				 && $xmlOption->{'hidden'} eq 'true');
			$filter = _addOption($filter,$xmlOption,
					     $dataSetName,$interfaceType,
					     $configurationTree);
		    }
			if (@{ $xmlFilter->{'Option'} } > 200){
			# safety guard for web performance
			# later on set autoCompletion for these type filters
			#$filter->displayType('text');
				print STDERR ("\nWarning: Too many Options for filter [ ", $xmlFilter->{'internalName'}, " ] possible rendering problems for  Martview    ");
			}
		    #else{
			$filter->displayType($xmlFilter->{'displayType'});			
		    #}
		    
			$filter->multipleValues($xmlFilter->{'multipleValues'});
			   
	 		# hack to test CONTAINER type multiSelect with bool radio buttons
			#if($xmlFilter->{'type'} eq 'boolean_list')
			#{
			#	$filter->multipleValues('1');
			#}
		    $filter->style($xmlFilter->{'style'});
		    $filter->graph($xmlFilter->{'graph'});
		    $filter->autoCompletion($xmlFilter->{'autoCompletion'});
                    
                    $filterCollection->addFilter($filter);
                    
       
                }
                $filterGroup->addCollection($filterCollection);
            }
            $filterTree->addFilterGroup($filterGroup);
        }
       	
        	$configurationTree->addFilterTree($filterTree);
    }
    
    # FILTER_LIST_HACK-part 2
	foreach my $filterTree (@{$configurationTree->getAllFilterTrees()}){
		foreach my $group(@{$filterTree->getAllFilterGroups()}){
			foreach my $collection (@{$group->getAllCollections()}){
				foreach my $filter (@{$collection->getAllFilters()}){
					if ($filter->isa("BioMart::Configuration::FilterList_List")) {
						#print STDERR "\nassociating FilterList filters to its objects";
						foreach my $filterName (split (/,/, $filter->filterString)) {
						  my $filterListItem = $configurationTree->getFilterByName($filterName);
         				#print STDERR "\n\tfound Filter: ", $filterListItem->name();
         				$filter->addFilter($filterListItem);
						}
					}
				}
			}
		}
	}
    
    
    
    # Importables
    my $extraAttTree = BioMart::Configuration::AttributeTree->new(
	  'name'  => 'extra_importable_atts',
	  'displayName' => '',
	  'hideDisplay' => 'true'
								  );
    my $extraAttGroup =	BioMart::Configuration::AttributeGroup->new(
	  'name'  => 'extra_importable_atts',
	  'displayName' => ''
								    );
    my $extraAttCollection = BioMart::Configuration::AttributeCollection->new(
	  'name'  => 'extra_importable_atts',
	  'displayName' => ''
									     );
    IMP: foreach my $importable (@{ $xmlHash->{'Importable'} }) {

	my $filterList = BioMart::Configuration::FilterList->new(
                    'name'           => $importable->{'name'},
                    'displayName'    => $importable->{'displayName'},
			       'description' => $importable->{'description'},
                    'linkName'       => $importable->{'linkName'},
		    		'linkVersion'    => $importable->{'linkVersion'},
		    'filter_string'    => $importable->{'filters'},
                    'orderby_string' => $importable->{'orderBy'},
                    'dataSetName'    => $dataSetName,
                    'interface'      => $interfaceType,
                    'type'				=> $importable->{'type'} || 'link'
								 );

	foreach my $filterName (split (/,/, $importable->{'filters'})) {
                my $filter =
                    $configurationTree->getFilterByName($filterName);

                #could be an option type filter
                unless ($filter) {
		    my $op = $configurationTree->getOptionByName($filterName);
		    #skip this importable if its filters are not available
		    next IMP unless ($op);
		    $filter = $op->filter;
	        }

                # for attribute joing between datasets the attribute equivalent
		# to the filter needs to be available in the configTree with
		# the same internalName

		if ($filter){
		    my $attribute = $filter->attribute;
		    if (!$configurationTree->getAttributeByName(
			     $attribute->name)){
			$extraAttCollection->addAttribute($attribute);
		    }
		    $filterList->addFilter($filter);
	        }
            }
            my $importables = $dataSet->get('importables');
            $importables->{$filterList->linkName}->{$interfaceType} = 
		$filterList;
            $dataSet->set('importables', $importables);
    }
 
    $extraAttGroup->addCollection($extraAttCollection);
    $extraAttTree->addAttributeGroup($extraAttGroup);
    $configurationTree->addAttributeTree($extraAttTree);

    # Exportables
    EXP:foreach my $exportable (@{ $xmlHash->{'Exportable'} }) {
	    my $attributeList = BioMart::Configuration::AttributeList->new(
                    'name'                => $exportable->{'name'},
                    'displayName'         => $exportable->{'displayName'},
                    'description'         => $exportable->{'description'},
                    'linkName'            => $exportable->{'linkName'},
                    'linkVersion'         => $exportable->{'linkVersion'},
		    'attribute_string'    => $exportable->{'attributes'},
                    'orderby_string'      => $exportable->{'orderBy'},
                    'dataSetName'         => $dataSetName,
                    'interface'           => $interfaceType,
							'type'				=> $exportable->{'type'} || 'link'
                );
            if ($exportable->{'default'}) { $attributeList->setDefault()}

               next EXP if($exportable->{'pointer'} && $exportable->{'pointer'} eq 'true'); # exportable is a placeholder - gtf
               
               foreach my $attributeName (split (/,/, $exportable->{'attributes'})) {
                    #placeholder attribute exportable gtf in xmls upto 41, as there we dont have pointer='true'     
		          next EXP if ($attributeName =~ /__/);
                    my $attribute = $configurationTree->getAttributeByName($attributeName);
                    $attributeList->addAttribute($attribute);
            }

            if ($exportable->{'orderBy'}) {
		     foreach my $attributeName (split (/,/, $exportable->{'orderBy'})) {
		     my $attribute =
			$configurationTree->getAttributeByName($attributeName);
		     $attributeList->addOrderByAttribute($attribute);
		     }
		  }

            my $exportables = $dataSet->get('exportables');
            $exportables->{$attributeList->linkName()}->{$interfaceType} = $attributeList;
            $dataSet->set('exportables', $exportables);
    }
     
    # MainTables
    foreach my $main (@{ $xmlHash->{'MainTable'} }) {
	next if ($xmlHash->{'type'} ne "TableSet");
	my $mains = $dataSet->get('mains');
	push @{ $mains }, $main;
	$dataSet->set('mains', $mains);
    }
    # Keys
    foreach my $key (@{ $xmlHash->{'Key'} }) {
	next if ($xmlHash->{'type'} ne "TableSet");
	my $keys = $dataSet->get('keys');
	push @{ $keys }, lc($key);#to avoid oracle complications
	$dataSet->set('keys', $keys);
    }
    # BatchSizes
    foreach my $batchSize (@{ $xmlHash->{'BatchSize'} }) {
	$dataSet->set('batch_size', $batchSize);
    }
    #SeqModules
    foreach my $seqModule (@{ $xmlHash->{'SeqModule'} }) {
	my $seqModules = $dataSet->get('seqModules');
	$seqModules->{$seqModule->{'linkName'}}{'moduleName'} = 
	    $seqModule->{'moduleName'};
	$dataSet->set('seqModules', $seqModules);
    }
    
    print STDERR " OK\n";
    $configurationTree->toXML($xml);
    return $configurationTree;
}


sub _addOption {
    my ($parentObject,$xmlOption,$dataSetName,$interfaceType,
	$configurationTree) = @_;

    my $option = BioMart::Configuration::Option->new(
	'name'        => $xmlOption->{'internalName'},
        'displayName' => $xmlOption->{'displayName'},
	      'description'          => $xmlOption->{'description'},
        'dataSetName' => $dataSetName,
	'value'       => $xmlOption->{'value'}
						     );

    $option->operation($xmlOption->{'qualifier'});

    if ($xmlOption->{'tableConstraint'} && $xmlOption->{'field'}){#filterOption
       my $attribute;
       $attribute = $configurationTree->
	   getAttributeByName($xmlOption->{'internalName'});
       if (!$attribute){
	   $attribute = BioMart::Configuration::Attribute->new(
	      'name'                 => $xmlOption->{'internalName'},
                            'imageURL' => $xmlOption->{'imageURL'},
	      'displayName'          => $xmlOption->{'displayName'},
	      'description'          => $xmlOption->{'description'},
              'table'                => $xmlOption->{'tableConstraint'},
              'relational_attribute' => $xmlOption->{'field'},
              'key'                  => lc($xmlOption->{'key'}),
              'dataSetName'          => $dataSetName,
              'interface'            => $interfaceType,  
			    'dependsOnType' => $xmlOption->{'dependsOnType'},      
			    'dependsOn' => $xmlOption->{'dependsOn'},  
							       );
       }
       
       my $filter;
       if ($xmlOption->{'type'} && $xmlOption->{'type'} eq 'boolean'){
	   $filter = BioMart::Configuration::BooleanFilter->new(
		  'name'          => $xmlOption->{'internalName'},
                            'imageURL' => $xmlOption->{'imageURL'},
		  'displayName'   => $xmlOption->{'displayName'},
	      'description'          => $xmlOption->{'description'},
		  'dataSetName'   => $dataSetName,
                  'interface'     => $interfaceType,
                  'type'          => $xmlOption->{'type'},
			    'dependsOnType' => $xmlOption->{'dependsOnType'},      
			    'dependsOn' => $xmlOption->{'dependsOn'},  
                    	'legalQualifiers'		=>	$xmlOption->{'legal_qualifiers'},
								);
	   $filter->attribute($attribute);
	   $filter->setAttribute($xmlOption->{'setAttribute'});
       }
       elsif ($xmlOption->{'type'}  && $xmlOption->{'type'} eq 'boolean_num'){
	   # hack for 1,0,null snp filters
	   $filter = BioMart::Configuration::BooleanFilter->new(
		   'name'        => $xmlOption->{'internalName'},
                            'imageURL' => $xmlOption->{'imageURL'},
		   'displayName' => $xmlOption->{'displayName'},
	      'description'          => $xmlOption->{'description'},
		   'dataSetName' => $dataSetName,
                   'interface'   => $interfaceType,
                   'type'        => $xmlOption->{'type'},
			    'dependsOnType' => $xmlOption->{'dependsOnType'},      
			    'dependsOn' => $xmlOption->{'dependsOn'},  
				'legalQualifiers'		=>	$xmlOption->{'legal_qualifiers'},
								);
	   $filter->setNumberFlag();
	   $filter->attribute($attribute);
           $filter->setAttribute($xmlOption->{'setAttribute'});
       }
       else{
	   $filter = BioMart::Configuration::ValueFilter->new(
		   'name'          => $xmlOption->{'internalName'},
	      'description'          => $xmlOption->{'description'},
		   'displayName' => $xmlOption->{'displayName'},
                            'imageURL' => $xmlOption->{'imageURL'},
                   'dataSetName' => $dataSetName,
                   'interface' => $interfaceType,
				'buttonURL'   => $xmlOption->{'buttonURL'},
                   'type'        => $xmlOption->{'type'},
			    'dependsOnType' => $xmlOption->{'dependsOnType'},      
			    'dependsOn' => $xmlOption->{'dependsOn'},  
				'legalQualifiers'		=>	$xmlOption->{'legal_qualifiers'},
							      );
	   $filter->attribute($attribute);
	   $filter->operation($xmlOption->{'qualifier'});
           $filter->setAttribute($xmlOption->{'setAttribute'});

       }
       $filter->displayType($xmlOption->{'displayType'});
       $filter->multipleValues($xmlOption->{'multipleValues'});
       $filter->style($xmlOption->{'style'});
       $filter->graph($xmlOption->{'graph'});
       $filter->autoCompletion($xmlOption->{'autoCompletion'});
       $option->filter($filter);
   }
   # recursive call as Options can contain Options
   foreach my $xmlSubOption(@{ $xmlOption->{'Option'} }) {
       next if ($xmlSubOption->{'hidden'} && 
		$xmlSubOption->{'hidden'} eq 'true');
       $option = _addOption($option,$xmlSubOption,$dataSetName,
			    $interfaceType,$configurationTree);
   }
   # recursive call as Options can contain PushActions
   foreach my $xmlPushAction(@{ $xmlOption->{'PushAction'} }) {
       next if ($xmlPushAction->{'hidden'} && 
		$xmlPushAction->{'hidden'} eq 'true');
       $option = _addPushAction($option,$xmlPushAction,$dataSetName,
				$interfaceType,$configurationTree);
   }
   $parentObject->addOption($option);
   return $parentObject;
}

sub _addPushAction {
    my ($parentObject,$xmlPushAction,$dataSetName,$interfaceType,
	$configurationTree) = @_;

    my $pushAction = BioMart::Configuration::PushAction->new(
        'name'        => $xmlPushAction->{'internalName'},
        'ref'         => $xmlPushAction->{'ref'},
        'dataSetName' => $dataSetName,
							     );    
   # recursive call as PushActions can contain Options
   foreach my $xmlSubOption(@{ $xmlPushAction->{'Option'} }) {
       next if ($xmlSubOption->{'hidden'} && 
		$xmlSubOption->{'hidden'} eq 'true');
       $pushAction = _addOption($pushAction,$xmlSubOption,$dataSetName,
				$interfaceType,$configurationTree);
   }
   $parentObject->addPushAction($pushAction);
   return $parentObject;
}

 
    
sub resolveDependsOn {
    	my ($self, $configTree, $virtualSchemaName, $dsName, $interfaceName) = @_;    
        
    	# Replace dependsOn attribute names with attribute objects.
	foreach my $aTree (@{$configTree->getAllAttributeTrees()}) {
    		foreach my $aGroup (@{$aTree->getAllAttributeGroups()}) {
			foreach my $aColl (@{$aGroup->getAllCollections()}) {
				foreach my $a (@{$aColl->getAllAttributes()}) {
					if ($a->dependsOn) {
						foreach my $dependsOn (split(/,/,$a->dependsOn)) {
							my $est = $a->name;
							my $dependent = $configTree->getAttributeByName($dependsOn);
							if (!$dependent) {
					 		#print "Problem with $virtualSchemaName.$dsName.$interfaceName:\n";
					   		#print "  DependsOn link between ".$a->name." and $dependsOn not possible.\n";
							} 
							else {
						   		$dependent->addDependency($a->name);
						    	}
    						}
					}
					if (UNIVERSAL::can($a,'attributeString')) {
			          	foreach my $attributeName (split (/,/, $a->attributeString)) {
							my $attribute = $configTree->getAttributeByName($attributeName);
							if ($attribute) {
								$a->addAttribute($attribute);
               				}
               				else {
		                		# Search all attributes looking for one with pointedFrom
								foreach my $aTree (@{$configTree->getAllAttributeTrees()}) {
									foreach my $aGroup (@{$aTree->getAllAttributeGroups()}) {
										foreach my $aColl (@{$aGroup->getAllCollections()}) {
						    		                foreach my $ra (@{$aColl->getAllAttributes()}) {
                         							if ($ra->pointedFromAttribute and $ra->pointedFromAttribute eq $attributeName) {
                              							$a->addAttribute($ra);
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
    
    
sub addPlaceHolderDatasets {
    my ($self, $configTree, $virtualSchemaName) = @_;
    # loop over all attributes and filters and convert as necessary
    my $xml = $configTree->toXML();#cached
    my $registry = $self->get('registry');
    
    my $xmlHash = XMLin($xml, forcearray => [qw(AttributePage AttributeGroup 
       AttributeCollection AttributeDescription FilterPage FilterGroup 
       FilterCollection FilterDescription Importable Exportable Key MainTable 
       BatchSize SeqModule Option PushAction)], keyattr => []);

    foreach my $xmlAttributeTree (@{ $xmlHash->{'AttributePage'} }) {
	my $attributePage = $configTree->
	    getAttributeTreeByName($xmlAttributeTree->{'internalName'});
	next if ($xmlAttributeTree->{'hidden'} && 
		 $xmlAttributeTree->{'hidden'} eq 'true');
	foreach my $xmlAttributeGroup 
	    (@{ $xmlAttributeTree->{'AttributeGroup'} }) {
	    my $attributeGroup = $attributePage->
		getAttributeGroupByName($xmlAttributeGroup->{'internalName'});
	    next if ($xmlAttributeGroup->{'hidden'} 
		     && $xmlAttributeGroup->{'hidden'} eq 'true');
	    foreach my $xmlAttributeCollection 
		(@{ $xmlAttributeGroup->{'AttributeCollection'} }) {
		my $attributeCollection = $attributeGroup->
		    getAttributeCollectionByName(
			$xmlAttributeCollection->{'internalName'});
		next if ($xmlAttributeCollection->{'hidden'} 
			 && $xmlAttributeCollection->{'hidden'}eq 'true');
		foreach my $xmlAttribute 
		    (@{ $xmlAttributeCollection->{'AttributeDescription'} }) {
		    next if ($xmlAttribute->{'hidden'} && 
			     $xmlAttribute->{'hidden'} eq 'true');
		    my $attribute;
		    # TODO:REMOVE FOR 0_5 - nb put in hack to convert 0_4 
		    # style placeholders for now until all XML gets updated
		    if ( #  $xmlAttribute->{'internalName'} =~ /\./ || 
			($xmlAttribute->{'pointerDataset'} && 
			 $xmlAttribute->{'pointerInterface'} && 
			 $xmlAttribute->{'pointerAttribute'} || $xmlAttribute->{'pointerFilter'} )){
			my ($pointerDatasetName, $pointerInterface);
			# get real attribute from pointer dataset
			if ($xmlAttribute->{'pointerDataset'}){
			    $pointerDatasetName = 
				$xmlAttribute->{'pointerDataset'};
			    $pointerInterface = 
				$xmlAttribute->{'pointerInterface'};
			}
			my $dataset = 
			    $registry->getDatasetByName($virtualSchemaName,
							$pointerDatasetName);
			if (!$dataset){
			    warn("      WARNING:  Pointer attributes from $pointerDatasetName will not be available as $pointerDatasetName not in registry\n");
			    next;
			}
			$dataset->getConfigurationTree($pointerInterface);
		    }
		}
	    }
	}
    }


    foreach my $xmlFilterTree (@{ $xmlHash->{'FilterPage'} }) {
	my $filterPage = $configTree->getFilterTreeByName(
			      $xmlFilterTree->{'internalName'});
	next if ($xmlFilterTree->{'hidden'} && 
		 $xmlFilterTree->{'hidden'} eq 'true');
	foreach my $xmlFilterGroup (@{ $xmlFilterTree->{'FilterGroup'} }) {
	    my $filterGroup = $filterPage->getFilterGroupByName(
				   $xmlFilterGroup->{'internalName'});
	    next if ($xmlFilterGroup->{'hidden'} && 
		     $xmlFilterGroup->{'hidden'} eq 'true');
	    foreach my $xmlFilterCollection 
		(@{ $xmlFilterGroup->{'FilterCollection'} }) {
		my $filterCollection = $filterGroup->getFilterCollectionByName
		    ($xmlFilterCollection->{'internalName'});
		next if ($xmlFilterCollection->{'hidden'} && 
			 $xmlFilterCollection->{'hidden'}eq 'true');
		foreach my $xmlFilter 
		    (@{ $xmlFilterCollection->{'FilterDescription'} }) {
		    next if ($xmlFilter->{'hidden'} && 
			     $xmlFilter->{'hidden'} eq 'true');
		    my $filter;

		    if ( ($xmlFilter->{'pointerDataset'} 
			 && $xmlFilter->{'pointerInterface'} 
			 && $xmlFilter->{'pointerFilter'})){
			# get real filter from pointer dataset
			my ($pointerDatasetName,$pointerInterface);
			if ($xmlFilter->{'pointerDataset'}){
			    $pointerDatasetName = 
				$xmlFilter->{'pointerDataset'};
			    $pointerInterface = 
				$xmlFilter->{'pointerInterface'};
			}
			my $dataset = 
			    $registry->getDatasetByName($virtualSchemaName,
							$pointerDatasetName);
			if (!$dataset){
			    warn("      WARNING: Pointer attributes from $pointerDatasetName will not be available as $pointerDatasetName not in registry\n");
			    next;
			}
			$dataset->getConfigurationTree($pointerInterface);
		    }
		}
	    }
	}
    }

}

sub addPlaceHolders {
    my ($self, $configTree, $virtualSchemaName, $dataSetName, $interface) = @_;
    
    # loop over all attributes and filters and convert as necessary
    my $xml = $configTree->toXML();#cached
    my $registry = $self->get('registry');
    my $dataSet = $registry->getDatasetByName($virtualSchemaName, 
					      $dataSetName);
    
    my $xmlHash = XMLin($xml, forcearray => [qw(AttributePage AttributeGroup 
       AttributeCollection AttributeDescription FilterPage FilterGroup 
       FilterCollection FilterDescription Importable Exportable Key MainTable 
       BatchSize SeqModule Option PushAction)], keyattr => []);

    foreach my $xmlAttributeTree (@{ $xmlHash->{'AttributePage'} }) {
	my $attributePage = $configTree->
	    getAttributeTreeByName($xmlAttributeTree->{'internalName'});
	    next unless $attributePage;
	#next if ($xmlAttributeTree->{'hidden'} && 
	#	 $xmlAttributeTree->{'hidden'} eq 'true');
	foreach my $xmlAttributeGroup 
	    (@{ $xmlAttributeTree->{'AttributeGroup'} }) {
	    my $attributeGroup = $attributePage->
		getAttributeGroupByName($xmlAttributeGroup->{'internalName'});
	    next unless $attributeGroup;
	    #next if ($xmlAttributeGroup->{'hidden'} 
		#     && $xmlAttributeGroup->{'hidden'} eq 'true');
	    foreach my $xmlAttributeCollection 
		(@{ $xmlAttributeGroup->{'AttributeCollection'} }) {
		my $attributeCollection = $attributeGroup->
		    getAttributeCollectionByName(
			$xmlAttributeCollection->{'internalName'});
	    next unless $attributeCollection;
		#next if ($xmlAttributeCollection->{'hidden'} 
		#	 && $xmlAttributeCollection->{'hidden'}eq 'true');
		foreach my $xmlAttribute 
		    (@{ $xmlAttributeCollection->{'AttributeDescription'} }) {
			#next if ($xmlAttribute->{'hidden'} 
			#	 && $xmlAttribute->{'hidden'}eq 'true');
		    my $attribute;
		    if ( ($xmlAttribute->{'pointerDataset'} && 
			 $xmlAttribute->{'pointerInterface'} && 
			 $xmlAttribute->{'pointerAttribute'} || $xmlAttribute->{'pointerFilter'} )){
			my ($pointerDatasetName, $pointerInterface, 
			    $pointerAttribute, $pointerFilter);
			# get real attribute from pointer dataset
			if ($xmlAttribute->{'pointerDataset'}){
			    $pointerDatasetName = 
				$xmlAttribute->{'pointerDataset'};
			    $pointerInterface = 
				$xmlAttribute->{'pointerInterface'};
			    $pointerAttribute = 
				$xmlAttribute->{'pointerAttribute'};
			    $pointerFilter = 
				$xmlAttribute->{'pointerFilter'};
			}
	
			my $pointerDataset = $registry->getDatasetByName(
			    $virtualSchemaName, $pointerDatasetName) || next;
			my $pointerConfigurationTree = $pointerDataset->
			    getConfigurationTree($pointerInterface) || next;
								
			if ($pointerFilter){
			    # have a placeholder filter within an attributePage
			    my $filter = $pointerConfigurationTree->
				getFilterByName($pointerFilter) || next;
			
			    my $newName = $pointerFilter;# needed to work with current GenomicSequence module
			    # need to make copies incase placeholder 
			    # shared by more than 1 dataset
			    my $new_filter;
			    if ($filter->isa
			       ("BioMart::Configuration::BooleanFilter")){
			       $new_filter = 
				  BioMart::Configuration::BooleanFilter->new(
				   'name'          => $newName,#$filter->name,
                            'imageURL' => $filter->imageURL,
                                   'displayName' => $filter->displayName,
				   'dataSetName' => $filter->dataSetName,
                                   'interface' => $filter->interface,
				   'buttonURL'   => $filter->buttonURL,
                                   'setAttributePage' => 
				       $filter->setAttributePage,
                                   'type'        => $filter->type,
                                   'dependsOn'        => $filter->dependsOn,
                                   'dependsOnType'        => $filter->dependsOnType,
                                   'hidden' => $xmlAttribute->{'hidden'},
                                   'legalQualifiers'		=>	$filter->legalQualifiers,
									     );
			       $new_filter->attribute($filter->attribute);
			       $new_filter->defaultOn($filter->defaultOn);
			       $new_filter->setAttribute($filter->setAttribute);
			       $new_filter->setNumberFlag($filter->getNumberFlag);
			    }
			    elsif ($filter->isa
				   ("BioMart::Configuration::ValueFilter")){
			      $new_filter = 
				    BioMart::Configuration::ValueFilter->new(
				   'name'          => $newName,
                            'imageURL' => $filter->imageURL,
				   'displayName' => $filter->displayName,
				   'dataSetName' => $filter->dataSetName,
                                   'interface' => $filter->interface,
				   'buttonURL'   => $filter->buttonURL,
                                   'setAttributePage' => 
				       $filter->setAttributePage,
                                   'type'        => $filter->type,
                                   'hidden' => $xmlAttribute->{'hidden'},
                                   'dependsOn'        => $filter->dependsOn,
                                   'dependsOnType'        => $filter->dependsOnType,
                                   'legalQualifiers'		=>	$filter->legalQualifiers,
                                   );
			      $new_filter->attribute($filter->attribute);
			      $new_filter->operation($filter->operation);
			      $new_filter->otherFilters($filter->otherFilters);
			      $new_filter->regexp($filter->regexp);
			      $new_filter->defaultValue($filter->defaultValue);
			      $new_filter->defaultOn($filter->defaultOn);
			      $new_filter->setAttribute($filter->setAttribute);
			      $new_filter->addOptions($filter->getAllOptions);
			    }
			    $new_filter->pointedFromDataset($dataSetName);
			    $new_filter->pointedFromInterface($interface);
			    
			    if ($registry->getPath($virtualSchemaName,
						   $dataSetName,
						   $pointerDatasetName)){
                               # only add if valid link exists
			    $new_filter->displayType($filter->displayType);
			    $new_filter->multipleValues(
						  $filter->multipleValues);
			    $new_filter->style($filter->style);
			    $new_filter->graph($filter->graph);
			    $new_filter->autoCompletion(
						  $filter->autoCompletion);

			       $attributeCollection->addAttribute($new_filter);
                               # allow filters in attribute list
			   }
			}
			else{# add normal attribute to attributeCollection
			    
			    my $newName = $pointerAttribute;

			    $attribute = $pointerConfigurationTree->
				getAttributeByName($pointerAttribute) || next;
			    # need to make a copy as several datasets can 
			    # share the same placeholder
			    my $new_attribute = 
				BioMart::Configuration::Attribute->new(
				   'name' => $newName,#$attribute->name,
                            'imageURL' => $attribute->imageURL,
			           'displayName' => $attribute->displayName,
                                   'table' => $attribute->table,
                                   'relational_attribute' => 
				       $attribute->relationalAttribute,
                                   'key' => $attribute->key,
			           'width' => $attribute->width,
			           'link'  => $attribute->link,
			           'datasetLink' => $attribute->datasetLink,
			           'default' => $attribute->default,      
					'hidden' => $xmlAttribute->{'hidden'},
						   'dataSetName' => $attribute->dataSetName, 
			    'attributes' => $attribute->attributes,  
                                   'interface' => $attribute->interface,
                                   'dependsOn'        => $attribute->dependsOn,
                                   'dependsOnType'        => $attribute->dependsOnType
								       );
			    $new_attribute->pointedFromDataset($dataSetName);
		 	    $new_attribute->pointedFromInterface($interface);
			    $new_attribute->pointedFromAttribute($xmlAttribute->{'internalName'});
			
			    if ($registry->getPath($virtualSchemaName,
						   $dataSetName,
						   $pointerDatasetName)){
                                # only add if valid link exists		
				$attributeCollection->
				    addAttribute($new_attribute);
			    }
		        }
		    }
		}
	    }
	}
    }

    # FILTERS
		    
    foreach my $xmlFilterTree (@{ $xmlHash->{'FilterPage'} }) {
	my $filterPage = $configTree->getFilterTreeByName(
			      $xmlFilterTree->{'internalName'});
			      next unless $filterPage;
	#next if ($xmlFilterTree->{'hidden'} && 
	#	 $xmlFilterTree->{'hidden'} eq 'true');
	foreach my $xmlFilterGroup (@{ $xmlFilterTree->{'FilterGroup'} }) {
	    my $filterGroup = $filterPage->getFilterGroupByName(
				   $xmlFilterGroup->{'internalName'});
				   next unless $filterGroup;
	    #next if ($xmlFilterGroup->{'hidden'} && 
		#     $xmlFilterGroup->{'hidden'} eq 'true');
	    foreach my $xmlFilterCollection 
		(@{ $xmlFilterGroup->{'FilterCollection'} }) {
		my $filterCollection = $filterGroup->getFilterCollectionByName
		    ($xmlFilterCollection->{'internalName'});
		    next unless $filterCollection;
		#next if ($xmlFilterCollection->{'hidden'} && 
		#	 $xmlFilterCollection->{'hidden'}eq 'true');
		foreach my $xmlFilter 
		    (@{ $xmlFilterCollection->{'FilterDescription'} }) {
		    #next if ($xmlFilter->{'hidden'} && 
			#     $xmlFilter->{'hidden'} eq 'true');
		    my $filter;

		    if ( ($xmlFilter->{'pointerDataset'} 
			 && $xmlFilter->{'pointerInterface'} 
			 && $xmlFilter->{'pointerFilter'})){
			# get real filter from pointer dataset
			my ($pointerDatasetName,$pointerInterface,
			    $pointerFilter);
			if ($xmlFilter->{'pointerDataset'}){
			    $pointerDatasetName = 
				$xmlFilter->{'pointerDataset'};
			    $pointerInterface = 
				$xmlFilter->{'pointerInterface'};
			    $pointerFilter = 
				$xmlFilter->{'pointerFilter'};
			}
			
			my $pointerDataset = $registry->getDatasetByName
			    ($virtualSchemaName, $pointerDatasetName) || next;
			my $pointerConfigurationTree = $pointerDataset->
			    getConfigurationTree($pointerInterface) || next;
			$filter = $pointerConfigurationTree->getFilterByName
			    ($pointerFilter) || next;
			my $newName = $pointerFilter;
			if ($configTree->getFilterByName($newName)){
			    warn("Placeholder Filter $newName from $pointerDatasetName has an internalName clash in dataset $dataSetName\n");
			    next;
			}

			# need to make copies incase placeholder shared by 
			# more than 1 dataset
			my $new_filter;

			if ($filter->isa
			    ("BioMart::Configuration::BooleanFilter")){
			    $new_filter = 
				BioMart::Configuration::BooleanFilter->new(
				   'name'          => $newName,
                            'imageURL' => $filter->imageURL,
                                   'displayName' => $filter->displayName,
				   'dataSetName' => $filter->dataSetName,
                                   'interface' => $filter->interface,
				   'buttonURL'   => $filter->buttonURL,
				   'hidden' => $xmlFilter->{'hidden'},
                                   'setAttributePage' => 
				       $filter->setAttributePage,
                                   'type'        => $filter->type,
                                   'dependsOn'        => $filter->dependsOn,
                                   'dependsOnType'        => $filter->dependsOnType,
                                   'legalQualifiers'		=>	$filter->legalQualifiers,
									   );
			    $new_filter->attribute($filter->attribute);
			    $new_filter->defaultOn($filter->defaultOn);
			    $new_filter->setAttribute($filter->setAttribute);
			    $new_filter->setNumberFlag($filter->getNumberFlag);
			    $new_filter->addOptions($filter->getAllOptions);
			}

			elsif ($filter->isa
			       ("BioMart::Configuration::ValueFilter")){
			    $new_filter = 
				BioMart::Configuration::ValueFilter->new(
				   'name'          => $newName,
                            'imageURL' => $filter->imageURL,
				   'displayName' => $filter->displayName,
			 	   'dataSetName' => $filter->dataSetName,
                                   'interface' => $filter->interface,
				   'buttonURL'   => $filter->buttonURL,
				   'hidden' => $xmlFilter->{'hidden'},
                                   'setAttributePage' => 
				       $filter->setAttributePage,
                                   'type'        => $filter->type,
                                   'dependsOn'        => $filter->dependsOn,
                                   'dependsOnType'        => $filter->dependsOnType,
                                   'legalQualifiers'		=>	$filter->legalQualifiers,
									 );
			    $new_filter->attribute($filter->attribute);
			    $new_filter->operation($filter->operation);
			    $new_filter->otherFilters($filter->otherFilters);
			    $new_filter->regexp($filter->regexp);
			    $new_filter->defaultValue($filter->defaultValue);
			    $new_filter->defaultOn($filter->defaultOn);
			    $new_filter->setAttribute($filter->setAttribute);
			    $new_filter->addOptions($filter->getAllOptions);
			}

		 
			$new_filter->pointedFromDataset($dataSetName);
			$new_filter->pointedFromInterface($interface);
			
			if ($registry->getPath($virtualSchemaName,
					       $pointerDatasetName,
					       $dataSetName)){
                            # only add if valid link exists
			    # add new types
			    $new_filter->displayType($filter->displayType);
			    $new_filter->multipleValues(
						  $filter->multipleValues);
			    $new_filter->style($filter->style);
			    $new_filter->graph($filter->graph);
			    $new_filter->autoCompletion(
						  $filter->autoCompletion);

			    $filterCollection->addFilter($new_filter);
			}
		    }
		}
	    }
	}
    }

    # Deal with exportables that contained placeholders
    EXP: foreach my $exportable (@{ $xmlHash->{'Exportable'} }) 
    {
          # exportable is a placeholder - gtf __ check should be useless from ensembl 42 but need to keep it here for backward compatibility
     	if (($exportable->{'attributes'} =~ /__/) || ($exportable->{'pointer'} && $exportable->{'pointer'} eq 'true'))
	     {
	          my $attributeList = BioMart::Configuration::AttributeList->new(
		    'name'                => $exportable->{'name'},
                    'displayName'         => $exportable->{'displayName'},
                    'linkName'            => $exportable->{'linkName'},
                    'linkVersion'         => $exportable->{'linkVersion'},
	     	    'attribute_string'    => $exportable->{'attributes'},
                    'orderby_string'      => $exportable->{'orderBy'},
                    'dataSetName'         => $dataSetName,
                    'interface'           => $interface,
						'type'				=> $exportable->{'type'} || 'link'
	     );
	          if ($exportable->{'default'}) { $attributeList->setDefault()}
     
	          foreach my $attributeName (split (/,/, $exportable->{'attributes'})) {

	            # with new placeholder change the dataset__ part is stripped
	            # from the attribute name but we need this part in the exportable
	            # to indicate should be done here rather than usual place for exp
	              my $attributeWithName = $attributeName;
	              if($attributeName =~ m/__/) # test for old style gtf exportable, ens 41 and before
	              {
	                    my @attributeName = split(/__/,$attributeName);
	                    $attributeWithName = $attributeName[1];
	              }
     
	               	               	               	                   	               
	               my $attribute = $configTree->getAttributeByName($attributeWithName);
	               $attributeList->addAttribute($attribute);
	          }
	
     	     if ($exportable->{'orderBy'}) {
     	         foreach my $attributeName (split (/,/, $exportable->{'orderBy'})) {
     	          my $attributeWithName = $attributeName;
	               if($attributeName =~ m/__/) # test for old style gtf exportable, ens 41 and before
	               {
	                    my @attributeName = split(/__/,$attributeName);
	                    $attributeWithName = $attributeName[1];
	               }
     	     	my $attribute = $configTree->getAttributeByName($attributeWithName);
     	     	$attributeList->addOrderByAttribute($attribute);
     	         }
     	     }
     	     my $exportables = $dataSet->get('exportables');
     	     $exportables->{$attributeList->linkName()}->{$interface} = $attributeList;
          	$dataSet->set('exportables', $exportables);
          }
          else
          {
               next EXP;
          }

     }

    # fix displayType etc for push action referenced filters - should be list
    
    foreach my $fpage (@{$configTree->getAllFilterTrees}){
	foreach my $fgroup (@{$fpage->getAllFilterGroups}){
	    foreach my $fcollection(@{$fgroup->getAllCollections}){
		foreach my $filter(@{$fcollection->getAllFilters}){
		    my $options = $filter->getAllOptions;
		    next if (!$$options[0]);
		    my $push_actions = $$options[0]->getAllPushActions;
		    next if (!$push_actions);
		    foreach my $push_action(@{$push_actions}){
			my $filter_to_fix = 
			    $configTree->getFilterByName($push_action->ref);
		    if ($filter_to_fix) {
				$filter_to_fix->displayType('list');
				$filter_to_fix->style('menu');
		    }
		    }
		}
	    }
	}
    }


    return $configTree;
}

1;

# vim: et
