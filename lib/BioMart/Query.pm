#
# BioMart module for BioMart::Query
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Query

=head1 SYNOPSIS

Object which encapsulates a Query against a BioMart Dataset.

=head1 DESCRIPTION

The BioMart::Query object encapsulates a query against a BioMart Dataset.
This may involve complex data merging between multiple Datasets and the
chosen Dataset, using the Links system.  Query objects hold lists of
BioMart::Configuration::Attribute objects, and lists of 
BioMart::Configuration::BaseFilter implementing objects.  They can also hold 
one or more BioMart::Configuration::AttributeList objects 
representing the Exportables from Datasets Exporting their ResultTable 
to some other Dataset via a Link. They can also hold one or more 
BioMart::Links objects describing requests to linking Multiple Datasets 
together using their Exportable - Importable relationship.

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Darin London, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Query;

use strict;
use warnings;
use Digest::MD5;
use XML::Simple qw(:strict);
use Data::Dumper;
use base qw(BioMart::Root);

=head2 _new

  Usage      : my $query = BioMart::Query->new;
  Description: creates an empty Query object.
  Returntype : BioMart::Query
  Exceptions : none
  Caller     : caller

=cut

sub _new {
  my ($self, @param) = @_;

  local($^W) = 0;  # prevent "odd number of elements" warning with -w.
  my(%param) = @param;

  my $registry = $param{'registry'};
  $self->attr('registry',$registry);

  # empty/default settings for all constructed Query objects
  $self->attr('dataset_names', {});
  $self->attr('ordered_dataset_names', []);
  $self->attr('attributes', []);
  $self->attr('filters', []);    
  $self->attr('limitStart',undef);
  $self->attr('limitSize',undef);
  $self->attr('count',undef);
  $self->attr('header',undef);
  $self->attr('completionStamp',undef);
  $self->attr('virtualSchema', undef);    
  $self->attr('attribute_lists', []);
  $self->attr('links', []);
  $self->attr('orderby',undef);
  $self->attr('oldFilterListValues',{});
  $self->attr('formatter', 'TSV');#default is tab sep output
  $self->attr('finalDatasetOrder', undef);
  $self->attr('softwareVersion', undef);
  $self->attr('currentDS', undef);
  $self->attr('attsAndAttListsForXMLDisplay', undef);

  my $virtualSchemaName =  $param{'virtualSchemaName'};  
  if (!defined $virtualSchemaName){
      BioMart::Exception::Query->throw ("You need to define virtual schema name in order to create a Query object");
  }

  $self->virtualSchema($virtualSchemaName);


  if ($param{'xml'}){
      # populate query object from XML string
      $self->_populateFromXML($param{'xml'});
  }
  elsif ($param{'mql'}){
      # TODO: populate query object from MQL string
  }
  elsif ($param{'cgi'}){
       # TODO: populate query object from CGI object
  }
  
 
}

=head2 toXML

  Usage      : my $query = BioMart::Query->newFromXML($xml);
  Description: creates a populated Query object.
  Returntype : BioMart::Query
  Exceptions : none
  Caller     : caller

=cut

sub toXML {
	my ($self,$limit_start,$limit_size,$count, $webClientTempering) = @_;

	my $registry = $self->getRegistry;
	### incase this query has been declared via QR, or its a martservice query where NO version
	### was specified and any other martservice query. martservice queries which needs to be directed to
	### another martservice,  eg dicty tends to lose software version because of XML to QUERY and back to XML
	### conversion
	if(!$self->get('softwareVersion') ) 
	{
		my $virtualSchema = $self->_getSchemaName($self->virtualSchema);		
		my $datasetNames = $self->getDatasetNames;
		foreach my $datasetName(@$datasetNames)
		{
     		my $queryAtts = $self->getAllAttributes($datasetName);

			my $dataset = $registry->getDatasetByName($virtualSchema, $datasetName);
			my $confTree = $dataset->getConfigurationTree($self->getInterfaceForDataset($datasetName));
			$self->set('softwareVersion', $confTree->software_version);
		}
	}   
	

	if($webClientTempering) # only for display purpose of Martview
	{
		undef $limit_start;
		undef $limit_size;
		undef $count;
		if($self->get('softwareVersion') eq '0.4') 
		{
			my $xml =  $self->_toXML_old($limit_start,$limit_size,$count); 		 
			return $xml;
		}
		else ## latest xml query
		{
			my $xml =  $self->_toXML_latest($limit_start,$limit_size,$count); 
			return $xml;
		}
	}
	else	### for rest of the API calls; Query, QueryRunner, Tableset and family
	{
		my $xml =  $self->_toXML_old($limit_start,$limit_size,$count); 		 
		return $xml;	
	}

}


=head2 _getSchemaName

  Usage      : internal function, called by toXML and _toXML_latest
  Description: to check if the given schema name is a URLpointer serverVirtualSchema or 
  			a VirtualSchema from local registry
  Returntype : schemaName
  Exceptions : none
  Caller     : caller

=cut

sub _getSchemaName
{
	my ($self,$trickyVSchema) = @_;
	my $registry = $self->getRegistry;
	my $datasetNames = $self->getDatasetNames;
	my $schemaExists = 0;
	foreach my $schema (@{$registry->getAllVirtualSchemas()})	
	{
		if ($schema->name eq $trickyVSchema)
		{	$schemaExists = 1;	}	## fine
	}
	if($schemaExists == 0) # may be dicty so look into location->servervirtualschema for match
	{
		my $realSchema = $trickyVSchema;
		foreach my $schema (@{$registry->getAllVirtualSchemas()})	
		{
			my $allMarts = $schema->getAllMarts();
			foreach my $mart (@$allMarts)
			{
				if($mart->serverVirtualSchema eq $trickyVSchema)
				{
					$realSchema = $schema->name();
				}
			}
		}
		$trickyVSchema = $realSchema;				
	}
	return $trickyVSchema;
}

=head2 _visibleDataset

  Usage      : internal function, called by _toXML_latest
  Description: to check if datasets is visible or not
  Returntype : true/false
  Exceptions : none
  Caller     : caller

=cut
sub _visibleDataset
{
	my ($self,$dataset) = @_;
	my $registry = $self->getRegistry;
	
	my $virtualSchema = $self->_getSchemaName($self->virtualSchema);		
	my $datasetNames = $self->getDatasetNames;
	foreach my $datasetName(@$datasetNames)
	{
		if($dataset eq $datasetName)
		{	
#			if($virtualSchema eq 'dictyMart')
#			{$virtualSchema = 'dicty';}
			my $datasetObj = $registry->getDatasetByName($virtualSchema, $datasetName);

			if ($datasetObj->visible)
			{	return 1;	}
			else
			{	return 0; }	
		}	
	}   
}

sub getActualDS
{
	my ($self, $dataset, $vDataset) = @_ ;
	my $actualDS;
	my $links;
     #$links = $registry->__Dijkstra($self->_getSchemaName($self->virtualSchema), $_);
     ## magic to find out e.g peptide or any genomic sequence attribute, which dataset it belongs to
     ## say if we have a query with hsapiens_gene_ensembl and hsapiens_gene_vega, and a peptide from
     ## hsapiens_genomic_sequence
     my $allLinks = $self->get('links');
     foreach my $link (@$allLinks)
     {
     	$links->{$link->targetDataset()} = $link->sourceDataset();
     }
     
	my $interface = $self->getInterfaceForDataset($dataset);
    	if($self->_visibleDataset($dataset)) #### its already a visible dataset, so just append to this
    	{
    		$actualDS = $dataset;     		     		
    	}
    	else    	## decide which visible dataset this att/filter should go to, need to use links
    	{
    		foreach(keys %$vDataset)
    		{    			
				if ($self->_getActualDS($links, $dataset, $_) == 1)
				{	
					$actualDS = $_;    
				}    				 				
    		}
    	}
     return $actualDS;
}


=head2 _getActualDS

  Usage      : internal function, called by getactualDS 
  Description: to find the actual visible DS to shown in XML
  Returntype : true/false
  Exceptions : none
  Caller     : caller

=cut
sub _getActualDS
{
	my ($self,$links, $dataset, $targetVisibleDS) = @_;
	
	if($links->{$dataset})	
	{
		if($links->{$dataset} eq $targetVisibleDS)
		{
			return 1;
		}
		else
		{
			if($self->_visibleDataset($links->{$dataset})) ## if we have reached another visible targetdataset.
			{
				return 0;
			}
			else
			{
				$self->_getActualDS($links, $links->{$dataset}, $targetVisibleDS);
			}
		}
	}
	else
	{
		return 0;
	}
}


sub getActualDS_reverseLinks
{
	my ($self, $dataset, $vDataset) = @_;
	my $temp = $self->get('links');
	my $links;
	my $allLinks = $self->get('links');
	foreach my $link (@$allLinks)
	{
		$links->{$link->sourceDataset()} = $link->targetDataset();
	}
	
	if(exists $links->{$dataset})
	{
		foreach my $dsName (keys %$vDataset)
		{
			if ($dsName eq $links->{$dataset})
			{
				return $dsName;
			}
		}
	}	
}



=head2 _toXML_latest

  Usage      : internal function, called by toXML
  Description: for new xml query
  Returntype : BioMart::Query
  Exceptions : none
  Caller     : caller

=cut
sub _toXML_latest
{
	my ($self,$limit_start,$limit_size,$count) = @_;
	# Dumps query object into an xml string 
	my $registry = $self->getRegistry;
	$limit_size  ||= q{};
	$limit_start ||= q{};
	$count      ||= q{};
	my $datasetBlock_open = 0;
	my $softwareVersion = $self->get('softwareVersion');
	my $xml = qq|<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Query>
<Query  virtualSchemaName = "|.$self->virtualSchema.qq|" limitStart = "|. $limit_start.qq|" limitSize = "|.
$limit_size.qq|" count = "|.$count.qq|" softwareVersion = "|.$softwareVersion.qq|" requestId= "biomart-client">|;

	my $datasets = $self->getDatasetNames;

	## open dataset tags for visible datasets only first and then 
	## append the filters and atts to the block they belong to.
	## the is done on the naming convention which biomart follows
	## datasetName_content_type
 	my $visibleDSCount=0;
	my $actualDS;
 	my %vDataset;
 	foreach my $dataset(@$datasets) 
	{
		my $interface = $self->getInterfaceForDataset($dataset);
     	if($self->_visibleDataset($dataset)) ## only for visible datasets,
     	{
			$vDataset{$dataset} = qq |
	<Dataset name = "|.$dataset.qq|" interface = "|.$interface.qq|" >|; 
			$visibleDSCount++;			
			
     	}    	
	}
	
	## Filters
	my $filts = $self->getAllFilters();
	foreach my $filter (@$filts)
	{
		$actualDS = $self->getActualDS($filter->dataSetName, \%vDataset);
		# e.g if filter is from gnf_xxx or evoc_xxx datasets which are generic for all but
		# used for human so far. the only way to assign such filters to the corresponding dataset
		# is to find an the representative visible dataset in reverse order in LINKS Target and source pairs
		if(!$actualDS)
		{
			$actualDS = $self->getActualDS_reverseLinks($filter->dataSetName, \%vDataset);
		}	

		if ($filter->isa("BioMart::Configuration::ValueFilter")
			|| $filter->isa("BioMart::Configuration::FilterList_List"))
		{
			my @values;
			my @rows;
			my $atable = $filter->getTable;
			while (my $row = $atable->nextRow)	{
				push @rows,$row;
				foreach my $col (@$row)	{
					push @values,$col;
		  		}
			}
			# need to regenerate AttributeTable cols for subsequent calls
			$atable->addRows(\@rows);
			my $value = join(',',@values);
	    	 
			$vDataset{$actualDS} .= qq |
		<Filter name = "|.$filter->name.qq|" value = "|.
	               $value.qq|"/>|;
		}
		elsif ($filter->isa("BioMart::Configuration::FilterList"))
		{
			my @values;
			my $filts = $filter->get('filters');
			my @filters = @$filts;
			my $attribute_table = $filter->get('attribute_table');
			my $rows_avail = $attribute_table->hasMoreRows();
			my $value;
		  	# deal with non-batching invisible datasets for webservice
		  	# need to keep reusing the same values for the filterlist
			if (!$rows_avail)
			{
				if (!$filter->batching || $filter->batching != 1)
				{
					my $oldFilterListValues = $self->get('oldFilterListValues');
					$value = $oldFilterListValues->{$filter->name};
				}
			}
			else
			{	
				while ($rows_avail && $filter->_inBatch($attribute_table)) {
					my $row = $attribute_table->nextRow();
					my $val = '';
					my $separator = '';
					foreach my $col (@$row)	{	
						$val = $val.$separator.$col;
						$separator = '|';
					}
					push @values,$val;
				}
				$value = join(',',@values);
			}
			# needed for correct batching behaviour
			$filter->set('exhausted', 1) unless ($rows_avail);
			
			my $oldFilterListValues = $self->get('oldFilterListValues');
			$oldFilterListValues->{$filter->name} = $value;
			$self->set('oldFilterListValues',$oldFilterListValues);

			unless( defined $value) {$value="";} 
			$vDataset{$actualDS} .= qq |
		<Filter name = "|.$filter->name.qq|" value = "|.
$value.qq|"/>|;
	
		}
		elsif ($filter->isa("BioMart::Configuration::BooleanFilter")) {
			$vDataset{$actualDS} .= qq |
		<Filter name = "|.$filter->name.qq|" excluded = "|.
$filter->getExcluded.qq|"/>|;
		}
	}
	
	## Attributes and AttributeLists
	my $attsAndAttLists = $self->get('attsAndAttListsForXMLDisplay'); ## this hash is populated in addAttribute() and _populateFromXML() only
	foreach my $attribute (@$attsAndAttLists)
	{
		foreach my $attName (keys %$attribute)	{
			$actualDS = $self->getActualDS($attribute->{$attName}, \%vDataset);
			$vDataset{$actualDS} .= qq |
		<Attribute name = "|.$attName.qq|" />|;
		}
	}
     
	my $ds;
  	foreach (keys %vDataset)
  	{
  	$vDataset{$_} .= qq |
	</Dataset>|;
		$ds=$vDataset{$_};		
	}

    # so it does not forget to stick dataset for counts
	if ($count eq '1') { $xml .= qq |$ds|}

	# ------ Determine correct order of datasets in the query without calling QueryRunner
	# ------ using getAllAttributes to find corresponding datasets and then ascertain
	# ------ which dataset comes first in XML representation
	my $allAtts = $self->getAllAttributes();
	foreach (@{$allAtts})
	{
		if ($vDataset{$_->dataSetName})
		{

			$xml .= qq |
			$vDataset{$_->dataSetName}|;
			delete $vDataset{$_->dataSetName}; # so this never added twice
		}
		# may be its a query with only structure or GS atts. forexample peptide, transcript_id query
		# you will only see invisible datasets
		if (!$vDataset{$_->dataSetName})
		{			
			my $temp_actualDS = $self->getActualDS($_->dataSetName,\%vDataset);
			if ($temp_actualDS && $vDataset{$temp_actualDS})
			{
				$xml .= qq |
				$vDataset{$temp_actualDS}|;
				delete $vDataset{$temp_actualDS}; # so this never added twice
			}
		}
	}
	# ----------------------------------------------------------------------------------
  		
	$xml .= qq|
</Query>|;

	return $xml;

}

=head2 _toXML_old

  Usage      : internal function, called by toXML
  Description: for old style xml query, still used by dicty and wormbase
  Returntype : BioMart::Query
  Exceptions : none
  Caller     : caller

=cut
sub _toXML_old
{
	my ($self,$limit_start,$limit_size,$count) = @_;
	# Dumps query object into an xml string 
	$limit_size  ||= q{};
	$limit_start ||= q{};
	$count      ||= q{};
	my $softwareVersion = $self->get('softwareVersion');
	my $xml = qq|<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Query>
<Query  virtualSchemaName = "|.$self->virtualSchema.qq|" limitStart = "|. $limit_start.qq|" limitSize = "|.
$limit_size.qq|" count = "|.$count.qq|" softwareVersion = "|.$softwareVersion.qq|" requestId= "biomart-client">|;

	my $datasets = $self->getDatasetNames;
	foreach my $dataset(@$datasets)
	{
		my $interface = $self->getInterfaceForDataset($dataset);
		$xml .= qq |
	<Dataset name = "|.$dataset.qq|" interface = "|.$interface.qq|" >|;

		my $atts = $self->getAllAttributeLists($dataset);
		foreach my $attribute_list (@$atts)
		{
			my $attributeString = $attribute_list->attributeString;
			my @attributeNames = split(/,/,$attributeString);
			foreach my $attributeName (@attributeNames){
				$xml .= qq |
			<Attribute name = "|.$attributeName.qq|" />|;
			}
		}

		$atts = $self->getAllAttributes($dataset);
     	foreach my $attribute (@$atts)
		{
			$xml .= qq |
				<Attribute name = "|.$attribute->name.qq|" />|;
		}

     	my $filts = $self->getAllFilters($dataset);
		foreach my $filter (@$filts)
     	{
			if ($filter->isa("BioMart::Configuration::ValueFilter") 
				|| $filter->isa("BioMart::Configuration::FilterList_List"))
			{
				my @values;
				my @rows;
				my $atable = $filter->getTable;
				while (my $row = $atable->nextRow)
				{
					push @rows,$row;
					foreach my $col (@$row)
					{
				     	push @values,$col;
			  		}
				}
				# need to regenerate AttributeTable cols for subsequent calls
			   $atable->addRows(\@rows);
				my $value = join(',',@values);
				
				$xml .= qq |
	     	<ValueFilter name = "|.$filter->name.qq|" value = "|.
                   $value.qq|"/>|;
			}
			elsif ($filter->isa("BioMart::Configuration::FilterList"))
			{
				my @values;
				my $filts = $filter->get('filters');
				my @filters = @$filts;
				my $attribute_table = $filter->get('attribute_table');
				my $rows_avail = $attribute_table->hasMoreRows();
				my $value;
	  		  	# deal with non-batching invisible datasets for webservice
	  		  	# need to keep reusing the same values for the filterlist
				if (!$rows_avail)
				{
					if (!$filter->batching || $filter->batching != 1)
					{
						my $oldFilterListValues = $self->get('oldFilterListValues');
						$value = $oldFilterListValues->{$filter->name};
					}
				}
				else
				{	
					while ($rows_avail && $filter->_inBatch($attribute_table))
					{
						my $row = $attribute_table->nextRow();
						my $val = '';
						my $separator = '';
						foreach my $col (@$row)
						{	
							$val = $val.$separator.$col;
							$separator = '|';
						}
						push @values,$val;
					}
					$value = join(',',@values);
				}
				# needed for correct batching behaviour
				$filter->set('exhausted', 1) unless ($rows_avail);
         		   
	 		   	my $oldFilterListValues = $self->get('oldFilterListValues');
	 		   	$oldFilterListValues->{$filter->name} = $value;
				$self->set('oldFilterListValues',$oldFilterListValues);

				# removing batching from second dataset onwards/invisible datasets 
				$xml =~ s/limitStart.*?limitSize\s*=\s*\"\d*\"//g;
    	 
				unless( defined $value) {$value="";} 
			     $xml .= qq |
			     <ValueFilter name = "|.$filter->name.qq|" value = "|.
$value.qq|"/>|;
	
			}
	
		     elsif ($filter->isa("BioMart::Configuration::BooleanFilter"))
    		 	{
				$xml .= qq |
	      <BooleanFilter name = "|.$filter->name.qq|" excluded = "|.
$filter->getExcluded.qq|"/>|;
			}
		}  
		$xml .= qq |
	  </Dataset>|;
	  
  	}
	my $links = $self->get('links');
	foreach my $link (@$links)
	{
	$xml .= qq |
	<Links source = "|.$link->sourceDataset.qq|" target = "|.
$link->targetDataset.qq|" defaultLink = "|.$link->defaultLink.qq|" />
	  |;
  	}
	$xml .= qq|
</Query>|;

	return $xml;
}

=head2 validate

  Usage      : $query->validate;
  Description: validates a populated Query object.
  Returntype : none
  Exceptions : BioMart::Exception::Query if any of validation steps fail
  Caller     : caller

=cut

sub validate {
  	my $self = shift;

  	my $registry = $self->getRegistry;
  
	my $visibleDataset = 0;
	my $datasetNames = $self->getDatasetNames;
	
	if(!$datasetNames)
	{
		BioMart::Exception::Usage->throw('Problem: No dataset names in the Query');
	}
    	  	
    	# validate if there are any attributes in query as yet, only fires exception if results are requested. Shouldnt moan if count is requested
    	my $queryAttsExist = 0;	
    	foreach my $datasetName(@$datasetNames){
       	my $atts = $self->getAllAttributes($datasetName);
       	if($atts) {$queryAttsExist = 1; last;}
    		}
	    if (!$queryAttsExist && $self->count()==0){
			BioMart::Exception::Usage->throw('No attributes selected, please select at least one');
    	}
  	
  	foreach my $datasetName(@$datasetNames){
      my $queryAtts = $self->getAllAttributes($datasetName);

      # validate the configuration trees
      my $maxGroupSelect;
      my $maxCollectionSelect;
      my $groupSelect;
      my $collectionSelect;
      my $prevCollection;
      my $apageSelected;
      my $dataset = $registry->getDatasetByName($self->virtualSchema,
						$datasetName);
      $visibleDataset++ if ($dataset->visible());
      BioMart::Exception::Usage->throw('Only two visible datasets allowed in query') if ($visibleDataset > 2);

      my $confTree = $dataset->getConfigurationTree(
		       $self->getInterfaceForDataset($datasetName));
      
      # do apage validation first - should be possible to get all query atts
      # from a single page
      my ($failed,$apage);
      PAGE:foreach my $currentPage (@{$confTree->getAllAttributeTrees}){
	  $failed = 0;
	  ATT:foreach my $attribute (@$queryAtts){
	      if (!$currentPage->getAttributeByName($attribute->name)){
		  # check the attribute is not present in a hideDispay page instead
		  foreach my $hiddenPage (@{$confTree->getAllAttributeTrees}){
		      next if ($hiddenPage->name eq $currentPage->name ||
			       !$hiddenPage->hideDisplay ||
			       $hiddenPage->hideDisplay ne 'true');
		      next ATT if ($hiddenPage->getAttributeByName(
						$attribute->name));
		  }
		  $failed = 1;
		  next PAGE;
	      }
	  }
	  $apage = $currentPage;
	  last;
      }
      
      BioMart::Exception::Usage->throw('Attributes from multiple attribute pages are not allowed') if ($failed);

	#------------- this section deals with max number of groups selected in a query. eg. ensembl - homologs tree
	if($apage->maxSelect())
	{		
		my $maxPageSelect = $apage->maxSelect();
		my $pageSelectCount = 0;
		my $groupFlag;
		foreach my $attgroup (@{$apage->getAllAttributeGroups}){
			$groupFlag = 0;
	     	foreach my $acollection(@{$attgroup->getAllCollections}){
				foreach my $att( @{$acollection->getAllAttributes} ){
		     		foreach my $attribute (@$queryAtts){
			  			if ($attribute->name eq $att->name){
							$groupFlag = 1; ## group marked for presence in query		
						}
					}
				}
			}
			if ($groupFlag == 1)
			{
				$pageSelectCount++;
			}
		
		}
		if($pageSelectCount > $maxPageSelect)
		{
			BioMart::Exception::Usage->throw('Too many groups select for '.$apage->name().' Max allowed : '.$maxPageSelect);
		}
	}
	#-----------------------------------------------------------		
		
	  foreach my $agroup (@{$apage->getAllAttributeGroups}){
		
	      $maxGroupSelect = $agroup->maxSelect || 0;
	      $groupSelect = 0;
	      foreach my $acollection(@{$agroup->getAllCollections}){
		  $maxCollectionSelect = $acollection->maxSelect || 0;
                  $collectionSelect = 0;
		  $prevCollection = 0;
		  foreach my $att( @{$acollection->getAllAttributes} ){
		      foreach my $attribute (@$queryAtts){
			  if ($attribute->name eq $att->name){

#			      if ($apageSelected && 
#				  $apageSelected ne $apage->name){
#				  # throw Exception unless internal 
#				  # placeholders are responsible
#				  
#				  BioMart::Exception::Usage->throw('Attributes from multiple attribute pages are not allowed - '.$att->name) 
#				      if !($confTree->
#					 getAttributeTreeByName($apageSelected)
#					 ->getAttributeByName($att->name));
#                                  next;
#			      }
#			      $apageSelected = $apage->name;

			      $groupSelect++ if (!$prevCollection);
			      $prevCollection++;
			      $collectionSelect++;
			      if ($maxGroupSelect && 
				  $groupSelect > $maxGroupSelect) {
				  BioMart::Exception::Usage->throw('Too many attributes selected for '.$agroup->displayName);
			      }
			      if ($maxCollectionSelect && 
				  $collectionSelect > $maxCollectionSelect) {
				  BioMart::Exception::Usage->throw('Too many attributes selected for '.$acollection->displayName);
				  }
			  }
		      }
		  }
	      }
	  }
#      }

      # validate the filters added to the query 
      my $filts = $self->getAllFilters($datasetName);
      foreach my $filter (@$filts){
	  if ($filter->isa("BioMart::Configuration::ValueFilter")){
	      # validate valueFilter
	      my $regexp = $filter->regexp();
	      if ($regexp){
		  my $attribute_table = $filter->getTable;
		  my $new_attribute_table = BioMart::AttributeTable->new();
		  while (my $row = $attribute_table->nextRow()){
		      $new_attribute_table->addRow($row);
		      if ($$row[0] !~ /$regexp/) {
			  BioMart::Exception::Usage->throw('Wrong format value for '.$filter->displayName);
		      }
		  }
		  $filter->setTable($new_attribute_table);
	      }
	  }
      }
   }
}

=head2 virtualSchema

  Usage      :  my $vSchema = $query->virtualSchema;
                $query->virtualSchema($newSchema);
  Description:  gets/sets the virtualSchema for the query.
                Defaults to 'defaultQuery'
  Returntype :  string virtualSchema
  Exceptions :  none
  Caller     :  caller

=cut

sub virtualSchema {
  my ($self, $vSchema) = @_;

  if ($vSchema) {
    $self->set('virtualSchema', $vSchema);
  }
  return $self->get('virtualSchema');
}


=head2 getRegistry
  
  Usage      :  my $registry = $query->getRegistry;
  Description:  Returns a Registry object.
  Returntype :  Registry object.
  Exceptions :  none
  Caller     :  caller

=cut


sub getRegistry {
  my $self = shift;

  return $self->get('registry');
}

=head2 getInterfaceForDataset
  
  Usage      :  my $interface = $query->getInterfaceForDataset($dataset);
  Description:  Returns the interface name used for the supplied dataset 
                in this query.
  Returntype :  string interface name.
  Exceptions :  none
  Caller     :  caller

=cut

sub getInterfaceForDataset {
  my ($self,$dataset) = @_;

  my $datasetHash =  $self->get('dataset_names');
  return $datasetHash->{$dataset};
}

=head2 getDatasetNames
  
  Usage      :  my $dataSets = $query->getDatasetNames; 
                foreach my $subName (@{$dataSets}) { ... }
  Description:  Returns a list_ref of names for all Datasets required to 
                resolve this Query.
  Returntype :  list_ref of scalar dataSet names.
  Exceptions :  none
  Caller     :  caller

=cut


sub getDatasetNames {
  my $self = shift;

  my @datasetNames = keys %{$self->get('dataset_names')};
  return \@datasetNames;
}

=head2 getOrderedDatasetNames
  
  Usage      :  my $dataSets = $query->getOrderedDatasetNames; 
                foreach my $subName (@{$dataSets}) { ... }
  Description:  Returns an ordered list_ref of names for all Datasets required to 
                resolve this Query.
  Returntype :  list_ref of scalar dataSet names.
  Exceptions :  none
  Caller     :  caller

=cut


sub getOrderedDatasetNames {
  my $self = shift;
  my $datasets = $self->get('ordered_dataset_names');
  return @$datasets ? $datasets:undef;
}

=head2 getAllAttributes

  Usage      :  get all attributes, involving all datasets:
                my $atts = $query->getAllAttributes;

                get only those attributes involving a specific dataset:
                my $atts = $query->getAllAttributes($subName);

  Description:  Returns all BioMart::Configuration::Attribute objects from a 
                Query, across all involved Datasets, or just for a particular 
                Dataset. BioMart::Configuration::Attribute objects contained 
                in any BioMart::Configuration::AttributeList objects added to 
                the Query will not be returned.  These should be retrieved 
                from the Query using its getAllAttributeLists method.

  Returntype :  list_ref of BioMart::Configuration::Attribute objects
  Exceptions :  none
  Caller     :  caller

=cut


sub getAllAttributes{
  my ($self,$dataset_name) = @_;

  my $attributes = $self->get('attributes');
  if (!$dataset_name){
      return @$attributes ? $attributes:undef;
  }
  my $specific_atts = [];
  foreach my $attribute (@$attributes){
    if ($attribute->dataSetName() eq $dataset_name){
      push @{$specific_atts}, $attribute;
    }
  }
  return @$specific_atts ? $specific_atts:undef;
  

}

sub removeAllAttributes{
  my $self = shift;
  $self->set('attributes',[]);
}

sub removeAllFilters{
    my $self = shift;
    $self->set('filters',[]);
}
 



=head2 getAllAttributeLists

  Usage      :  get all attributeLists, involving all datasets:
                my $attLists = $query->getAllAttributeLists;

                get only those attributeLists involving a specific dataset:
                my $attLists = $query->getAllAttributeLists($subName);

  Description:  Returns all BioMart::Configuration::AttributeList objects 
                from a Query, across all involved Datasets, or just for a 
                particular Dataset.
                
  Returntype :  list_ref of BioMart::Configuration::AttributeList objects
  Exceptions :  none
  Caller     :  caller

=cut


sub getAllAttributeLists{
  my ($self,$dataset_name) = @_;

  my $attributeLists = $self->get('attribute_lists');
  if (!$dataset_name){
      return $attributeLists;
  }
  my $specific_attLists = [];
  foreach my $attributeList (@$attributeLists){
    if ($attributeList->dataSetName() eq $dataset_name){
      push @{$specific_attLists}, $attributeList;
    }
  }
  return $specific_attLists;
}

=head2 getAttributeListByLinkName

Usage        :  my $exportable = $query->getAttributeListByLinkName;
Description  :  Get an Exportable AttributeList for a given LinkName.
                This can be used to get Fields from a ResultTable
                based on the name of the Attributes in the AttributeList,
                and their order.  Mainly for BioMart::DatasetI implementations
                needing to merge data from the exportable with its own data,
Returntype   :  BioMart::Configuration::AttributeList (may be undef)
Exceptions   :  none
Caller       :  BioMart::DatasetI.

=cut

sub getAttributeListByLinkName {
  my ($self, $linkName) = @_;

  my $ret;
  my $attributeLists = $self->get('attribute_lists');
  foreach my $attributeList (@{$attributeLists}){
    if ($attributeList->linkName() eq $linkName){
      $ret = $attributeList;
      last;
    }
  }

  return $ret;
}

=head2 getAttributeListByName

Usage        :  my $exportable = $query->getAttributeListByName;
Description  :  Get an Exportable AttributeList for a given Name.
Returntype   :  BioMart::Configuration::AttributeList (may be undef)
Exceptions   :  none
Caller       :  BioMart::DatasetI.

=cut

sub getAttributeListByName {
  my ($self, $name) = @_;

  my $ret;
  my $attributeLists = $self->get('attribute_lists');
  foreach my $attributeList (@{$attributeLists}){
    if ($attributeList->name() eq $name){
      $ret = $attributeList;
      last;
    }
  }

  return $ret;
}

=head2 getAllFilters

  Usage      : get all filters, involving all subsytems:
               my $filts = $query->getAllFilters;

               get only those filters involving a specific dataset:
               my $filts = $query->getAllFilters($subName);

  Description: Returns all BioMart::Configuration::BaseFilter implementing 
               objects from a Query, across all involved Datasets, or just 
               for a particular Dataset. This list will include any FilterList
               objects added to the Query as Importables.
  Returntype : list_ref of BioMart::Configuration::BaseFilter implementing 
               objects.
  Exceptions : none
  Caller     : caller

=cut


sub getAllFilters{
  my ($self,$dataset_name) = @_;

  my $filters = $self->get('filters');
  if (!$dataset_name){
      return @$filters ? $filters:undef;

 }
  my $specific_filts = [];
  foreach my $filter (@$filters){
    if ($filter->dataSetName() eq $dataset_name){ 
      push @{$specific_filts}, $filter;
    }
  }
  return @$specific_filts ? $specific_filts:undef;

}

=head2 getAllPlaceholderFilters

  Usage      : get only those placeholder filters involving a specific dataset:
               my $filts = $query->getAllPlaceholderFilters($subName);

  Description: Returns all BioMart::Configuration::BaseFilter implementing 
               objects from a Query, for a particular Dataset that were 
               implemented as placeholders.

  Returntype : list_ref of BioMart::Configuration::BaseFilter implementing 
               objects.
  Exceptions : none
  Caller     : caller

=cut


sub getAllPlaceholderFilters{
  my ($self,$dataset_name) = @_;

  my $filters = $self->get('filters');
  my $specific_filts = [];
  foreach my $filter (@$filters){
      if ($filter->pointedFromDataset() && $filter->pointedFromDataset 
	  eq $dataset_name){ 
	  push @{$specific_filts}, $filter;
      }
  }
  return $specific_filts;

}


=head2 getLinks

  Usage      : my $links = $query->getLinks($sourceDataset,$targetDataset)
  Description: Finds the link (if any) set on the Query object between the 
               source and target datasets and returns it
  Returntype : returntype
  Exceptions : none
  Caller     : caller

=cut

sub getLinks{
  my ($self,$sourceDataset,$targetDataset) = @_;# only use in 1 direction

  my $links = $self->get('links');
  foreach my $link (@$links){
      if (($link->sourceDataset() eq $sourceDataset
           && $link->targetDataset() eq $targetDataset)){
	  return $link;
      }
  }
}

=head2 setDataset
  
  Usage      :  $query->setDataset
  Description:  sets the dataset name for adding attributes and filters
  Returntype :  none
  Exceptions :  none
  Caller     :  query object itself

=cut

sub setDataset
{
	my ($self, $dataset) = @_;
	if ($dataset) {
	    	$self->set('currentDS', $dataset);
  	}
  	return $self->get('currentDS');
}

=head2 addLinks

  Usage      : $query->addLinks($link, $sourceInterface, $targetInterface);
  Description: Adds a BioMart::Links object to the query
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut


sub addLinks{

  # adds links object
  my ($self, $link, $sourceInterface, $targetInterface) = @_;
  my $links = $self->get('links');
  push @{$links}, $link;
  $self->set('links', $links);
  $self->addDatasetName($link->sourceDataset, $sourceInterface);
  $self->addDatasetName($link->targetDataset, $targetInterface);
}

=head2 addAttribute

  Usage      : $query->addAttribute($attribute_name,
				    $interface);
  Description: Adds a BioMart::Configuration::Attribute object to the Query,
               first recovering it from the registry by name
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut


sub addAttribute{
    my ($self, $attributename, $interface) = @_;

    my $schema_name = $self->virtualSchema() ||'default';
    my $dataset_name = $self->get('currentDS');
    $interface ||= 'default';
    my $registry = $self->get('registry');
    #my $attribute = $registry->getAttribute($dataset_name, $attributename, 
	#				    $schema_name, $interface);
	my ($attribute, $softwareVersion) = $registry->getAttribute($dataset_name, $attributename, 
					    $schema_name, $interface);
	$self->set('softwareVersion', $softwareVersion);
	
	## its an attribute list, so need to store some information about this attributeList 
	## which would help us recover the name of AttributeList in to_XML_latest as
	## we donot want to display the names of individual attributes there
	## The same logic goes into _populateFromXML
	my $tempArray = $self->get('attsAndAttListsForXMLDisplay');
	my $tempHash;
	$tempHash->{$attribute->name} = $attribute->dataSetName;
	push @{$tempArray}, $tempHash;
	$self->set('attsAndAttListsForXMLDisplay', $tempArray);
			
	if (UNIVERSAL::can($attribute,'getAllAttributes')) {
		my @attributes = @{$attribute->getAllAttributes};
		foreach my $attr (@attributes) {
			$self->_addAttribute($attr);
		}
	}
	else {
    		$self->_addAttribute($attribute);
	}
}

=head2 addAttributeFilter

  Usage      : $query->addAttributeFilter($attribute_name,
				    $values,
				    $interface);

  Description: Adds a BioMart::Configuration::Filter object to the Query,
               first recovering it from the Attribute registry by name
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut


sub addAttributeFilter{
    my ($self, $attributename, $values, $interface) = @_;

    my $schema_name = $self->virtualSchema() ||'default';
    my $dataset_name = $self->get('currentDS');
    $interface ||= 'default';
    my $registry = $self->get('registry');
    #my $attribute = $registry->getAttribute($dataset_name, $attributename, 
	#				    $schema_name, $interface);

    my ($attribute, $softwareVersion) = $registry->getAttribute($dataset_name, $attributename, 
					    $schema_name, $interface);
	$self->set('softwareVersion', $softwareVersion);

    if(!defined($values)) {
	BioMart::Exception::Query->throw("Value not defined for getSetFilter");
    }
    
    my $atbl = BioMart::AttributeTable->new();
    my $value_filter;
    foreach my $value(@{$values}){
	if ($value =~ /Only|Excluded/i){
	    if ($value =~ /Excluded/i)
		{
			$attribute->setExcluded(1);
		}
		if ($value =~ /Only/i)
		{
			$attribute->setExcluded(0);
		}		
	    last;
	}
	else{
	    $value_filter++;
	    $atbl->addRow([ $value ]);
	}
    }
    if ($value_filter){
	$attribute->setTable($atbl);
    }
    
    $self->_addFilter($attribute);
}

=head2 addFilter

  Usage      : $query->addFilter($filter_name,
				 $values,
				 $interface);

  Description: Adds a BioMart::Configuration::BaseFilter implementing object 
               to the Query,first recovering it from the registry by name and 
               adding the values in the $values arrayref
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut


sub addFilter{
    my ($self, $filtername, $values, $interface) = @_;
    
    my $schema_name = $self->virtualSchema() ||'default';
    my $dataset_name = $self->get('currentDS');    
    $interface ||= 'default';
    my $registry = $self->get('registry');
    #my $filter = $registry->getFilter($dataset_name, $filtername, 
	#			      $schema_name, $interface);

    my ($filter, $softwareVersion) = $registry->getFilter($dataset_name, $filtername, 
				      $schema_name, $interface);
	$self->set('softwareVersion', $softwareVersion);

    if(!defined($values)) {
	BioMart::Exception::Query->throw("Value not defined for getSetFilter");
    }
    
    my $atbl = BioMart::AttributeTable->new();
    my $value_filter;
    foreach my $value(@{$values}){
	if ($value =~ /Only|Excluded/i){
	    if ($value =~ /Excluded/i)
		{
			$filter->setExcluded(1);
		}
		if ($value =~ /Only/i)
		{
			$filter->setExcluded(0);
		}		
	    last;
	}
	else{
	    $value_filter++;
	    $atbl->addRow([ $value ]);
	}
    }
    if ($value_filter){
	$filter->setTable($atbl);
    }

    $self->_addFilter($filter);
}


=head2 addAttributeWithoutLinking

  Usage      : $query->addAttributeWithoutLinking($att);
  Description: Adds a BioMart::Configuration::Attribute object to the Query,
               maintaining the order of addition. Unlike the _addAttribute 
               method links for placeholder attributes are not automatically
               created. This is necessary for the single dataset subqueries
               created within QueryRunner
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut


sub addAttributeWithoutLinking{
  my ($self, $attribute) = @_;

  BioMart::Exception::Query->throw("Tried to add nonexistent attribute to query") if (!defined($attribute));

  my $atts = $self->get('attributes');
  push @{$atts}, $attribute;
  $self->set('attributes', $atts);

  $self->addDatasetName($attribute->dataSetName,$attribute->interface);
}


=head2 _addAttribute

  Usage      : $query->_addAttribute($att);
  Description: Adds a BioMart::Configuration::Attribute object to the Query,
               maintaining the order of addition.
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut


sub _addAttribute{
  my ($self, $attribute) = @_;

  # Check it really is an attribute, not a filter. If it is a filter, ignore it.
  if (UNIVERSAL::can($attribute,'displayType')) { return; }

  BioMart::Exception::Query->throw("Tried to add nonexistent attribute to query") if (!defined($attribute));

  my $atts = $self->get('attributes');
  push @{$atts}, $attribute;
  $self->set('attributes', $atts);

  $self->addDatasetName($attribute->dataSetName,$attribute->interface);
  # add the link if a placeholder attribute  
  if ($attribute->pointedFromDataset && $attribute->pointedFromInterface){
      my @path = $self->getRegistry()->getPath($self->virtualSchema,
					       $attribute->pointedFromDataset,
					       $attribute->dataSetName);
      foreach (my $j = 1; $j < @path; $j++){
	  my $link = $self->getRegistry()->getLinkBetween($self->virtualSchema,
							  $path[$j-1], 
							  $path[$j]);
	  my $attributeLink = $attribute->datasetLink;
	  if ($attributeLink && ($path[$j] eq $attribute->dataSetName)){
	      $link->defaultLink($attributeLink);
	  }
	  next if (!$link->validateLink($self->virtualSchema,
					$attribute->pointedFromInterface,
					$attribute->interface,
					$link->defaultLink));
	  $self->addLinks($link, $attribute->pointedFromInterface, 
			  $attribute->interface);
      }
  }

}

=head2 addAttributes

  Usage      : $query->addAttributes($atts);
  Description: Adds a listref of BioMart::Configuration::Attribute objects to 
               the Query
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut


sub addAttributes{
  my ($self, $attributes) = @_;
  
  foreach my $attribute (@$attributes){
      $self->_addAttribute($attribute);
  }
}

=head2 addAttributeListFirst

  Usage      : $query->addAttributeListFirst($attList);
  Description: Adds a BioMart::Configuration::AttributeList object to the 
               Query, as the first one - useful for maintaining correct order 
               in ResultTable.
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut

sub addAttributeListFirst{
  my ($self, $alist) = @_;
  my $aLists = $self->get('attribute_lists');
  unshift @{$aLists}, $alist;
  $self->set('attribute_lists', $aLists);
  $self->addDatasetName($alist->dataSetName,$alist->interface);
}

=head2 addAttributeList

  Usage      : $query->addAttributeList($attList);
  Description: Adds a BioMart::Configuration::AttributeList object to the 
               Query,
               maintaining the order of addition.
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut

sub addAttributeList{
  my ($self, $alist) = @_;
  my $aLists = $self->get('attribute_lists');
  push @{$aLists}, $alist;
  $self->set('attribute_lists', $aLists);
  $self->addDatasetName($alist->dataSetName,$alist->interface);
}



=head2 addFilterWithoutLinking

  Usage      : $query->addFilterWithoutLinking($filt);
  Description: Adds a BioMart::Configuration::BaseFilter implementing object 
               to the Query.
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut


sub addFilterWithoutLinking{
  my ($self, $filter) = @_;
  BioMart::Exception::Query->throw("Tried to add nonexistent filter to query") 
      if (!defined($filter));
  my $filts = $self->get('filters');
  my $registry = $self->getRegistry();
  my $virtualSchema = $self->virtualSchema;

  push @{$filts}, $filter;
  $self->set('filters', $filts);
  $self->addDatasetName($filter->dataSetName,$filter->interface);
}



=head2 _addFilter

  Usage      : $query->_addFilter($filt);
  Description: Adds a BioMart::Configuration::BaseFilter implementing object 
               to the Query.
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut


sub _addFilter{
  my ($self, $filter) = @_;
  BioMart::Exception::Query->throw("Tried to add nonexistent filter to query") 
      if (!defined($filter));
  my $filts = $self->get('filters');
  my $registry = $self->getRegistry();
  my $virtualSchema = $self->virtualSchema;

  push @{$filts}, $filter;
  $self->set('filters', $filts);
  $self->addDatasetName($filter->dataSetName,$filter->interface);
  # add the link if a placeholder filter
  if ($filter->pointedFromDataset && $filter->pointedFromInterface){
      my @path = $registry->getPath($virtualSchema,
				    $filter->dataSetName,
				    $filter->pointedFromDataset);
      # if no path try other way round incase placeholder filter 
      # on attribute page
      if (@path == 1){
	  @path = $registry->getPath($virtualSchema,
				 $filter->pointedFromDataset,
				 $filter->dataSetName);
      }
      foreach (my $j = 1; $j < @path; $j++){
	  my $link = $registry->getLinkBetween($self->virtualSchema,
					       $path[$j-1], 
					       $path[$j]);
	  next if (!$link->validateLink($virtualSchema,
                                        $filter->interface,
					$filter->pointedFromInterface,
					$link->defaultLink));
	  $self->addLinks($link, $filter->interface,
			  $filter->pointedFromInterface);
      }
  }
}

sub finalProcess {
    my $self = shift;
    # add the otherFilters
    my $filters = $self->getAllFilters();
    my $registry = $self->getRegistry();
    my $virtualSchema = $self->virtualSchema;
    foreach my $filter(@$filters){
	# if filter is meant to set otherFilters handle it here
	# PROBLEMS - 1 - uses old style placeholder format
	#          - 2 - interface for placeholder not defined - HACKED FOR NOW
	if ($filter->isa("BioMart::Configuration::ValueFilter") 
	    && $filter->otherFilters()){
	    my $otherFilters = $filter->otherFilters;
	    my @otherFilts = split(/;/,$otherFilters);
	    foreach (@otherFilts){
		my @names = split(/\./,$_);
		my $otherDataset = $registry->getDatasetByName($virtualSchema,
							       $names[0]);
		next if (!$otherDataset);
		# should only add to query if otherDataset already 
		# involved in query
		my $datasetHash =  $self->get('dataset_names');
		next if (!$datasetHash->{$names[0]});
		my $otherFilter = $otherDataset->getConfigurationTree(
			  $filter->interface)->getFilterByName($names[1]);
		next if (!$otherFilter);
		my $att_table = BioMart::AttributeTable->new();
		my $rows = $filter->getTable()->getRows();
		$att_table->addRows($rows);
		next if ($otherFilter->
			 isa("BioMart::Configuration::BooleanFilter"));
		$otherFilter->setTable($att_table);
		
		my $dataSets = $self->getDatasetNames;
		foreach my $subName (@{$dataSets}) { 
		    if ($otherFilter->dataSetName eq $subName){
			$self->_addFilter($otherFilter);
			last;
		    }
		}
	    }

	}
    }
    # create a link between the second visible dataset and the first one 
    # if one does not exist. uses attribute and/or filter order to find 1st 
    # dataset added and 2nd and links 2nd->1st
    
    my ($sourceDataset,$targetDataset);

# removed the dataset order switching code - order should be that set on query->{'dataset_names'}
# driven by the api,webservices or interface code

#    my $attributes = $self->getAllAttributes();
#    foreach my $attribute (@$attributes){
#	my $datasetName = $attribute->pointedFromDataset() 
#	    || $attribute->dataSetName();
#	my $dataset = $registry->getDatasetByName($virtualSchema,$datasetName);
#	next if (!$dataset->visible);
#	if ($targetDataset && $datasetName ne $targetDataset){
#	    $sourceDataset = $datasetName;
#	} 
#	else{
#	    $targetDataset = $datasetName;
#	}
#	last if ($sourceDataset && $targetDataset);
#    }
#    if (!($sourceDataset && $targetDataset)){
#	    my $filters = $self->getAllFilters();
#	    foreach my $filter (@$filters){
#		my $datasetName = $filter->pointedFromDataset() 
#		    || $filter->dataSetName();
#		my $dataset = $registry->getDatasetByName($virtualSchema,
#							  $datasetName);
#		next if (!$dataset->visible);
#		if ($targetDataset && $datasetName ne $targetDataset){
#		    $sourceDataset = $datasetName;
#		} 
#		else{
#		    $targetDataset = $datasetName;
#		}
#		last if ($sourceDataset && $targetDataset);
#	    }
#    }
#

#    if (!($sourceDataset && $targetDataset)){
#	# may have a two dataset query with one of them having no filts/atts
#	$sourceDataset = '';
#	$targetDataset = '';
	my $datasets = $self->getOrderedDatasetNames; 
	foreach my $datasetName (reverse @{$datasets}) {
	    	my $dataset = $registry->getDatasetByName($virtualSchema,
							  $datasetName);
		next if (!$dataset->visible);
		if (!$sourceDataset || $sourceDataset eq ''){
		    $sourceDataset = $datasetName;
		}
		else{
		    $targetDataset = $datasetName;
		}
	}
#    }
#     warn("NOW TRY TO ADD A LINK FROM $sourceDataset TO $targetDataset");
    if ($sourceDataset && $targetDataset && 
	!$self->getLinks($sourceDataset,$targetDataset) && 
	!$self->getLinks($targetDataset,$sourceDataset)){
	# if link not already defined between the first and second visible 
	# datasets on query object
	my $link = $registry->getLinkBetween($virtualSchema,$sourceDataset, 
					     $targetDataset);
	my $sourceInterface = $self->getInterfaceForDataset($sourceDataset);
	my $targetInterface = $self->getInterfaceForDataset($targetDataset);
	next if (!$link->validateLink($virtualSchema,
                                        $sourceInterface,
					$targetInterface,
					$link->defaultLink));
	$self->addLinks($link, $sourceInterface,$targetInterface);
    }
}

=head2 addFilters

  Usage      : $query->addFilters($filts);
  Description: Adds a listref of BioMart::Configuration::Filter objects to 
               the Query
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut


sub addFilters{
  my ($self, $filters) = @_;

  foreach my $filter (@$filters){
      $self->_addFilter($filter);
  }
}

=head2 orderBy

  Usage      : my $orderByAtts = $query->orderBy(); $query->orderBy($atts_ref);

  Description: get/sets the order by attributes for this Query
  Returntype : listref of order by BioMart::Attribute objects
  Exceptions : none
  Caller     : caller

=cut

sub orderBy {
  my ($self, $atts) = @_;

  if ($atts) {
    $self->set('orderby', $atts);
  }

  return $self->get('orderby');
}

=head2 header

  Usage      : my $header = $query->header(); $query->header($header);
  Description: get/sets the current header settings on the Query 
  Returntype : scalar $header
  Exceptions : none
  Caller     : caller

=cut

sub header {
  my ($self, $header) = @_;

  if (defined $header) {
    $self->set('header', $header);
  }
  return $self->get('header');
}

=head2 count

  Usage      : my $count = $query->count(); $query->count($count);
  Description: get/sets the current count on the Query 
  Returntype : scalar $count
  Exceptions : none
  Caller     : caller

=cut

sub count {
  my ($self, $count) = @_;

  if (defined $count) {
    $self->set('count', $count);
  }
  return $self->get('count');
}

=head2 completionStamp

  Usage      : my $completionStamp = $query->completionStamp(); $query->completionStamp($completionStamp);
  Description: get/sets the completionStamp flag on the Query 
  Returntype : scalar $completionStamp
  Exceptions : none
  Caller     : caller

=cut

sub completionStamp {
  my ($self, $completionStamp) = @_;

  if (defined $completionStamp) {
    $self->set('completionStamp', $completionStamp);
  }
  return $self->get('completionStamp');
}


=head2 limitStart

  Usage      : my $limitStart = $query->limitStart(); 
               $query->limitStart($limitStart);
  Description: get/sets the limitStart for this Query
  Returntype : scalar $limitStart
  Exceptions : none
  Caller     : caller

=cut

sub limitStart {
  my ($self, $limitStart) = @_;

  if (defined($limitStart)) {
    $self->set('limitStart', $limitStart);
  }

  return $self->get('limitStart');
}

=head2 limitSize

  Usage      : my $limitSize = $query->limitSize(); 
               $query->limitSize($limitSize);
  Description: get/sets the limitSize for this Query
  Returntype : scalar $limitSize
  Exceptions : none
  Caller     : caller

=cut

sub limitSize {
  my ($self, $limitSize) = @_;

  if (defined($limitSize)) {
    $self->set('limitSize', $limitSize);
  }

  return $self->get('limitSize');
}


sub addDatasetName {
    my ($self, $dataSetName, $interface) = @_;
    
    my $dataSetNames = $self->get('dataset_names');
    $dataSetNames->{$dataSetName} = $interface;
    $self->set('dataset_names',$dataSetNames);
    
    my $orderedDatasetNames = $self->get('ordered_dataset_names');
    my $seen = 0;
    foreach (@{$orderedDatasetNames}){
	$seen = 1 if ($_ eq $dataSetName);
    }
    push @{$orderedDatasetNames}, $dataSetName if ($seen == 0);
    $self->set('ordered_dataset_names',$orderedDatasetNames);
    
}

=head2 finalDatasetOrder

  Usage      :  my $finalDatasetOrder = $query->finalDatasetOrder;  
                $query->finalDatasetOrder($finalDatasetOrder);
  Description:  get/set the FinalDatasetOrder decided by QueryRunner 
                for the Query.
  Returntype :  listref of names of the final dataset order.
  Exceptions :  none
  Caller     :  caller

=cut


sub finalDatasetOrder {
  my ($self, $finalDatasetOrder) = @_;

  if ($finalDatasetOrder) {
    $self->set('finalDatasetOrder', $finalDatasetOrder);
  }
  return $self->get('finalDatasetOrder');

}

=head2 formatter

  Usage      :  my $formatterName = $query->formatter;  
                $query->formatter($formatterName);
  Description:  get/set the name of a BioMart::FormatterI implementing 
                object to render the ResultTable resulting for the Query.
  Returntype :  scalar $formatterName.
  Exceptions :  none
  Caller     :  caller

=cut


sub formatter {
  my ($self, $formatterName) = @_;

  if ($formatterName) {
    $self->set('formatter', $formatterName);
  }
  return $self->get('formatter');
}



sub _populateFromXML {
    my ($self,$xml)=@_;

    my $registry = $self->getRegistry;
      
    my $config = XMLin($xml, forcearray=> [qw(Query Dataset Attribute 
					      ValueFilter BooleanFilter 
					      Filter Links)], keyattr => []);
       
    # overrides default settings
    
    my $virtualSchemaName =  $config->{'virtualSchemaName'} || 'default';
    $self->virtualSchema($virtualSchemaName);
    
    $self->formatter($config->{'formatter'}) if ($config->{'formatter'});
    
    $self->set('softwareVersion', $config->{'softwareVersion'});
    
    $self->limitStart($config->{'limitStart'});
    $self->limitSize($config->{'limitSize'});
    
	if ($config->{'count'} && $config->{'count'} > 1)
	{	    BioMart::Exception::Usage->throw ("INVALID COUNT VALUE");

	}
    
    $self->count($config->{'count'});

    if ($config->{'header'} && $config->{'header'} ne '1')
    {	    BioMart::Exception::Usage->throw ("INVALID HEADER VALUE");

    } 
    $self->header($config->{'header'});
    
	$self->completionStamp($config->{'completionStamp'});

    my ($sourceDataset, $sourceInterface, $targetDataset, $targetInterface);

    foreach my $dataset (@{$config->{'Dataset'}}) {
	
	my $interface = $dataset->{'interface'} || 'default';
	
	if (!$targetDataset){
	    $targetDataset = $dataset->{'name'};
	    $targetInterface = $interface;
	}
	elsif (!$sourceDataset){
	    $sourceDataset = $dataset->{'name'};
	    $sourceInterface = $interface;
	}
	# incase no filts or atts set
	$self->addDatasetName($dataset->{'name'},$interface);
	my $datasetObj = $registry->getDatasetByName($virtualSchemaName, 
						     $dataset->{'name'});
	if (!$datasetObj){
	    BioMart::Exception::Usage->throw ("WITHIN Virtual Schema : $virtualSchemaName, Dataset ".
			  $dataset->{'name'}." NOT FOUND");
	}
	my $confTree = $registry->getDatasetByName($virtualSchemaName, 
		    $dataset->{'name'})->getConfigurationTree($interface);
	
	if (!$confTree){
	    BioMart::Exception::Usage->throw ("Cannot find Configuration Tree for $virtualSchemaName.".$dataset->{'name'});
	}
		
	
		foreach my $attributeNode (@{$dataset->{'Attribute'}}){
	     	my $attribute = $confTree->
			getAttributeByName($attributeNode->{'name'});

		     if (!$attribute) {
				BioMart::Exception::Usage->throw ("Attribute ".
		     	$attributeNode->{'name'}." NOT FOUND");
			}
		     else {			 	
	    			## its an attribute list, so need to store some information about this attributeList 
				## which would help us recover the name of AttributeList in to_XML_latest as
				## we donot want to display the names of individual attributes there
				## The same logic goes into getAttribute
				my $tempArray = $self->get('attsAndAttListsForXMLDisplay');
				my $tempHash;
				$tempHash->{$attribute->name} = $attribute->dataSetName;
				push @{$tempArray}, $tempHash;
				$self->set('attsAndAttListsForXMLDisplay', $tempArray);
			
				if (UNIVERSAL::can($attribute,'getAllAttributes')) {
					my @attributes = @{$attribute->getAllAttributes};
					foreach my $attr (@attributes) {
						$self->_addAttribute($attr);
					}
				}
				else {
			    		$self->_addAttribute($attribute);
				}
				
	     	}	
	     }
	# reads Filter element
	foreach my $filterNode (@{$dataset->{'Filter'}}){
	    if (defined $filterNode->{'excluded'}){
		$self->_setBooleanFilter($confTree,$filterNode);
	    } elsif  (defined $filterNode->{'value'}){
		$self->_setValueFilter($confTree,$filterNode,
				       $virtualSchemaName,$dataset,$interface);
	    } else {
		  BioMart::Exception::Usage->throw ("Filter ".$filterNode->{'name'}." INVALID, FILTER NEEDS 'excluded' or 'value' attribute");
	      }
	}
	# Boolean and Value filter - to be phased out from xml
	foreach my $filterNode (@{$dataset->{'BooleanFilter'}}){
	    $self->_setBooleanFilter($confTree,$filterNode);
	}
	foreach my $filterNode (@{$dataset->{'ValueFilter'}}){
	    $self->_setValueFilter($confTree,$filterNode,$virtualSchemaName,
				   $dataset,$interface);
	}
    }
    
    # add links
    foreach my $linkNode (@{$config->{'Links'}}) {

    
	my $sourceInterface = $linkNode->{'sourceInterface'} || 'default';
        my $targetInterface = $linkNode->{'targetInterface'} || 'default';
	my $link = $registry->getLinkBetween($virtualSchemaName,
					     $linkNode->{'source'},
					     $linkNode->{'target'});
	$link->defaultLink($linkNode->{'defaultLink'}) 
	    if ($linkNode->{'defaultLink'}); 
	if (!$link || !$link->validateLink($virtualSchemaName,
					   $sourceInterface,
					   $targetInterface,
					   $link->defaultLink())) {
	    BioMart::Exception::Usage->throw("LINK FROM ".$linkNode->{'source'}." TO ".$linkNode->{'target'}." NOT FOUND");
	}
	$link->operation($linkNode->{'operation'}) 
	    if ($linkNode->{'operation'});
	$self->addLinks($link,$sourceInterface,$targetInterface);
    }  

}

sub _setBooleanFilter {
    
    my ($self,$confTree,$filterNode)=@_;
    
    my $filter = $confTree->getFilterByName($filterNode->{'name'});
    if (!$filter){
	$filter = $confTree->getOptionByName($filterNode->{'name'})->filter;
    }
    if ($filterNode->{'excluded'} eq "1"){
	$filter->setExcluded;
    }
    else{
	$filter->setIncluded;
    }
    
    if (!$filter) {
	BioMart::Exception::Usage->throw("Filter ".$filterNode->{'name'}." NOT FOUND");
    }
    else{
	$self->_addFilter($filter);
    }    
}

sub _setValueFilter {
    
    my ($self,$confTree,$filterNode,$virtualSchemaName,$dataset,$interface)=@_;
    
    my $registry = $self->getRegistry;
    my $filter = $confTree->getFilterByName($filterNode->{'name'});
    if (!$filter){
	my $option = $confTree->getOptionByName($filterNode->{'name'});
	$filter = $option->filter if ($option);
    }
    if (!$filter){# must be a filterlist importable
	$filter = $registry->getDatasetByName($virtualSchemaName, 
	    $dataset->{'name'})->getImportables($filterNode->{'name'},
						$interface);		
    }
    if (!$filter) {
	BioMart::Exception::Usage->throw("Filter ".$filterNode->{'name'}." NOT FOUND");
    }
    else{
	my $atable = BioMart::AttributeTable->new();
	my @values = split(",",$filterNode->{'value'});
	
	if($filter->isa("BioMart::Configuration::FilterList")){
	    foreach my $val(@values){

	     	my @data = split(/\|/,$val.'|end');
		pop @data;# without adding this arbitary end element and 
		          # removing it lose empty last elements
		$atable->addRow(\@data);
	    }
	}
	else{
	    foreach (@values){
		$atable->addRow([$_]);
	    }
	}
	
	$filter->setTable($atable);
	$self->_addFilter($filter);
    }
    
}

sub _hashCode {
  my $self = shift;

  my $digest = Digest::MD5->new;

  my $attributes = $self->get('attributes');
  foreach my $att (@{$attributes}) {
    $digest->add($att->hashCode);
  }

  my $alists = $self->get('attribute_lists');
  foreach my $alist (@{$alists}) {
    $digest->add($alist->hashCode);
  }

  my $filters = $self->get('filters');
  foreach my $filt (@{$filters}) {
    $digest->add($filt->hashCode);
  }

  my $links = $self->get('links');
  foreach my $link (@{$links}) {
    $digest->add($link->hashCode);
  }

  return $digest->hexdigest;
}

sub _equals {
  my ($self, $otherq) = @_;
  return ($self->hashCode == $otherq->hashCode);
}

=head2 toPerl

  Usage      :  my perlApiExample = $query->toPerl();

  Description:  display the PERL API Equivalent of Query
  Returntype :  string
  Exceptions :  none
  Caller     :  Web.pm

=cut
sub toPerl {
	my $self = shift;
	my $xml = $self->toXML(1,1,1,1);
	my $registry = $self->getRegistry;
	my $perl_string;
	$perl_string .= qq|

# An example script demonstrating the use of BioMart API.
# This perl API representation is only available for configuration versions >=  0.5 
use strict;
use BioMart::Initializer;
use BioMart::Query;
use BioMart::QueryRunner;

my \$confFile = "PATH TO YOUR REGISTRY FILE UNDER biomart-perl/conf/. For Biomart Central Registry navigate to
						http://www.biomart.org/biomart/martservice?type=registry";
#
# NB: change action to 'clean' if you wish to start a fresh configuration  
# and to 'cached' if you want to skip configuration step on subsequent runs from the same registry
#

my \$action='cached';
my \$initializer = BioMart::Initializer->new('registryFile'=>\$confFile, 'action'=>\$action);
my \$registry = \$initializer->getRegistry;

my \$query = BioMart::Query->new('registry'=>\$registry,'virtualSchemaName'=>'default');
|;
	# so far expecting to deal with only 0.5 style XML
	my $config = XMLin($xml, forcearray=> [qw(Query Dataset Attribute 
					      ValueFilter BooleanFilter 
					      Filter Links)], keyattr => []);

	my $virtualSchemaName =  $config->{'virtualSchemaName'} || 'default';

	my $formatter = $config->{'formatter'} if ($config->{'formatter'});
	#DATASETS
	foreach my $dataset (@{$config->{'Dataset'}}) {	
		my $interface = $dataset->{'interface'} || 'default';
		$perl_string .= qq|
		
	\$query->setDataset("|.$dataset->{'name'}.qq|");|;
		# FILTERS
		foreach my $filterNode (@{$dataset->{'Filter'}}) {
			if (defined $filterNode->{'excluded'}) {
				if($filterNode->{'excluded'} eq '1') {
					$perl_string .= qq| 
	\$query->addFilter("|.$filterNode->{'name'}.qq|", ["Excluded"]);|;
				}
				else {
					$perl_string .= qq| 
	\$query->addFilter("|.$filterNode->{'name'}.qq|", ["Only"]);|;
				}
			}
			elsif  (defined $filterNode->{'value'}) {
				my $temp_str = $filterNode->{'value'};
				$temp_str =~ s/\,/\"\,\"/g;
				$perl_string .= qq|
	\$query->addFilter("|.$filterNode->{'name'}.qq|", ["|.$temp_str.q|"]);|;
			}
		}
		# ATTRIBUTES
		foreach my $attributeNode (@{$dataset->{'Attribute'}}) {
			$perl_string .= qq|
	\$query->addAttribute("|.$attributeNode->{'name'}.qq|");|;			
		}
	}


$perl_string .= qq|

my \$query_runner = BioMart::QueryRunner->new();
############################## GET COUNT ############################
# \$query->count(1);
# \$query_runner->execute(\$query);
# print \$query_runner->getCount();
#####################################################################


############################## GET RESULTS ##########################
# to obtain unique rows only
# \$query_runner->uniqueRowsOnly(1);

\$query_runner->execute(\$query);
\$query_runner->printHeader();
\$query_runner->printResults();
\$query_runner->printFooter();
#####################################################################
|;
	return $perl_string;
}

1;

