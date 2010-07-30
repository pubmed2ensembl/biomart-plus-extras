#
# BioMart module for BioMart::QueryRunner
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::QueryRunner

=head1 SYNOPSIS

  The BioMart::QueryRunner contains a simple Query Planner to
  run a BioMart::Query query against one or more BioMart::DatasetI
  objects.

=head1 DESCRIPTION

  The BioMart::QueryRunner object contains a simple Query Planner
  to run a BioMart::Query query (or count) against one or more 
  BioMart::DatasetI implementing objects.  It uses the following Recursive 
  algorithm:

  Given a BioMart::Query object involving one or more BioMart::DatasetI
  implementing objects, and the directional Links information for multi 
  Dataset queries:

      if datasets.length < 2 :
        process the query and return the ResultTable
      else :
        dataset = shift dataset;

        if dataset can not import from another dataset by design
           or all datasets exporting to this dataset have been
           processed:
             create subquery involving this Datasets filters, and the 
             Attributes in the Exportable process the subuery and add the 
             ResultTable as an Importable to the main Query
             update this dataset as 'processed'
        else :
         pop dataset onto end of list

      recurse

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Darin London, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::QueryRunner;
use strict;
use warnings;
use Digest::MD5;
use Digest::SHA qw (sha256_base64);
use Log::Log4perl;
my $logger=Log::Log4perl->get_logger(__PACKAGE__);

use BioMart::Configuration::AttributeList;
use base qw(BioMart::Root);

=head2 new
  
  Usage      :  my $query_runner = BioMart::QueryRunner->new();
                $query_runner->execute($query);
                $query_runner->printResults();  

  Description:  Creates a BioMart::QueryRunner object.
                Can then be used to execute a BioMart::Query object
                and print the results in the format specified on
                the Query object.
                Can be reused to execute multiple queries

  Return type:  A BioMart::QueryRunner object.
  Exceptions :
  Caller     :  Any BioMart clients building up a mart query

=cut

sub _new {
  my $self = shift;

  #state variables
  $self->attr('query', undef);
  $self->attr('registry', undef);
  $self->attr('formatter', undef);

  $self->attr('count', undef);
  $self->attr('final_dataset_order', undef);

  $self->attr('batched_already', undef);
  $self->attr('processed_datasets', undef);
  $self->attr('datasets_encountered', undef);
  $self->attr('last_visible_exportable', undef);
  $self->attr('union_tables', undef);
  $self->attr('visibleDSCount', undef);
  $self->attr('uniqueResultsFlag', undef);
}

=head2 execute
  Usage      :
                $query_runner->execute($query);
                $query_runner->printResults();  

  Description:  Executes a BioMart::Query object leaving the QueryRunner ready
                to print the results in the format specified on
                the Query object.
                
  Return type:  none

  Exceptions :  BioMart::Exception::Query if there is not a possible path
                through the datasets in the query

  Caller     :  Any BioMart clients executing a mart query
=cut

sub execute {

    my ($self, $query) = @_;
	my $registry = $query->getRegistry;
	my $GMA_present = 0 ;
	my $visibleDSCount = 0;

	if (scalar (@{$query->getDatasetNames}) > 0)
	{
		foreach my $ds (@{$query->getDatasetNames})
		{
			# GenomicMAlign check, so Bens stuff would still keep working
			# All the sequence requests via GenomiMAlign cant work because of new hashing logic which requires 
			# a unique when results are being hashed. For Structure/GenomicSeq, the first attribute in the filterlist
			# of importable and exportables should be unique. In ComparaMarts, neither they have a unique column
			# in Mart nor they have filterList of exportable/importable accordingly.
			# for them merging/hashing should follow the old principle of concatenation of all the coordinates
			# to make a unique key, which may result in collisions.
			$GMA_present = 1  if ($registry->getDatasetByName($query->virtualSchema, $ds)->isa("BioMart::Dataset::GenomicMAlign")) ;

			# counting the visible DSs to use this number to avoid the merging of sequences as 
			# semi-colon separated in case of two dataset queries both involving Genomic Sequence
			$visibleDSCount++ if ($registry->getDatasetByName($query->virtualSchema, $ds)->visible);
		}
		$self->set('visibleDSCount', $visibleDSCount);
	}
	
	if ($GMA_present) ## flag to follow the old hashing/merging
	{
		foreach my $ds (@{$query->getDatasetNames})
		{
			$registry->getDatasetByName($query->virtualSchema, $ds)->GenomicMAlignHack(1);
		}
	}
        
	if (defined $query->getAllAttributes()){
    	foreach my $att (@{$query->getAllAttributes()}){
			$logger->warn("ATTRIBUTE: ", $att->dataSetName,"\t",$att->name,"\t",$att->table);
		} 
	} 
	else 
	{

		$logger->warn("NO ATTRIBUTES");

	} 
	if (defined $query->getAllFilters()){
        foreach my $filt (@{$query->getAllFilters()}){
     	   $logger->warn("FILTER TABLE: ", $filt->dataSetName,"\t",$filt->name,"\t",$filt->table);
		}
	}
	else 
	{           
		$logger->warn("NO FILTERS");             
	}

	$self->executionPlan($query);
  
    my $formatterName = $query->formatter() || 'TSV';
    my $module = "BioMart::Formatter::$formatterName";
    $self->loadModule($module);
    my $formatter = $module->new();
  
    $query = $formatter->processQuery($query);
  
    $self->executionPlan($query);# call again as formatter processQuery can 
	                         # change plan
    
    my $rtable = $self->_getResultTable($query);
  
    if ($query->count){
		$self->set('count',$rtable);
    }
    else{
		$formatter->resultTable($rtable);
		$self->set('formatter',$formatter); 
    }
}

=head2 getCount
  Usage      :  $query_runner->getCount;
                
  Description:  Returns the counts for BioMart::Query previously
                executed by the QueryRunner (see execute method above)
                
  Return type:  scalar $count
  Exceptions :
  Caller     :  Any BioMart clients executing up a mart query
=cut

sub getCount {
    my $self = shift;

    return $self->get('count');
}

=head2 printResults
  Usage      :  $query_runner->printResults;
                
  Description:  prints formatted results for BioMart::Query previously
                executed by the QueryRunner (see execute method above).
                Results will be printed in a batched manner
  Return type:  
  Exceptions :
  Caller     :  Any BioMart clients executing up a mart query
=cut

sub printResults {
	my ($self, $filehandle, $lines) = @_;
    
	$filehandle ||= \*STDOUT; # in case no fhandle is provided

	my $formatter = $self->get('formatter');
    
	if ($formatter->isa("BioMart::Formatter::XLS")) {
		$formatter->printResults($filehandle,$lines, $self->uniqueRowsOnly());    			
	}
	else
	{
		my $counter;
		my %collisions;
		no warnings 'uninitialized';
		while (my $row = $formatter->nextRow)
		{
		    next if ($row eq "\n");
			# send unique results only if its set on QueryRunner Object
			if ($self->uniqueRowsOnly()) {
				my $hash = sha256_base64($row);
				next if exists $collisions{$hash};
				$collisions{$hash} = undef;
			}
			$counter++;
			last if ($lines && $counter > $lines);
			print $filehandle $row;
		}
	}
}

=head2 printHeader
  Usage      :  $query_runner->printHeader;
                
  Description:  Prints a correctly formatted header (typically column
		display names) using a call to the getDisplayNames method
		of the Formatter defined in the original Query object.
                
  Return type:  
  Exceptions :
  Caller     :  Any BioMart clients executing up a mart query
=cut

sub printHeader {
    my ($self, $filehandle) = @_;
    
    my $formatter = $self->get('formatter');
    $filehandle ||= \*STDOUT; # in case no fhandle is provided
    my $text = $formatter->getDisplayNames;
    if ($text) { print $filehandle $text };
}

=head2 printFooter
  Usage      :  $query_runner->printFooter;
                
  Description:  Prints a correctly formatted footer using a call to the 
                getFooterText method of the Formatter defined in the 
                original Query object.
                
  Return type:  
  Exceptions :
  Caller     :  Any BioMart clients executing up a mart query
=cut

sub printFooter {
    my ($self, $filehandle) = @_;
    
    my $formatter = $self->get('formatter');
    $filehandle ||= \*STDOUT; # in case no fhandle is provided
    my $text = $formatter->getFooterText;
    if ($text) { print $filehandle $text };
}

=head2 printCompletionStamp
  Usage      :  $query_runner->printCompletionStamp;
                
  Description:  Prints a CompletionStamp [success]
                
  Return type:  [success]
  Exceptions :
  Caller     :  Any BioMart clients executing up a mart query
=cut

sub printCompletionStamp {
    my ($self, $filehandle) = @_;
    
    $filehandle ||= \*STDOUT; # in case no fhandle is provided
	print $filehandle "[success]\n";
}

=head2 _getResultTable
  
  Usage      : usage
  Description: Uses a recursive algorithm to
               process all primary and intermediate queries
               into exportables with the correct batching
               logic, and returns the ResultTable from
               the terminal dataset.  If query->count is
               defined, then the a count of the objects
               in the focus_dataset given all other filters
               is returned instead of the BioMart::ResultTable.
               Note, for queries involving visible, upstream
               datasets, the count is not run for efficiency
               reasons, and an exception is thrown.
  Returntype : BioMart::ResultTable object, or scalar $count
  Exceptions : BioMart::Exception::Query if try a count on a 
               query with more than one visible dataset
  Caller     : caller

=cut

sub _getResultTable {

    my ($self,$query) = @_;
    if (!defined($query->limitSize)){
	# ie do not validate webservices originating subqueries as they are
	# not user generated and will not have usage errors
	# also likely to have attributes from a link_attribute page and
	# normal user page and hence throw a usage exception
	$query->validate();
    }
    my $registry = $query->getRegistry;
    $self->set('query', $query);
    $self->set('registry', $registry);

    #reset recursion state
    $self->set('union_tables', {});
    $self->set('batched_already', undef);

    if ($query->count){
	# test if two visible datasets involved, in which case no count
	my $allDsets = $query->getDatasetNames;
	my $visibleDatasetCounter = 0;
	foreach my $dset (@{$allDsets}) {
	    $visibleDatasetCounter++ if ($registry->getDatasetByName
		($query->virtualSchema, $dset)->visible);
	    BioMart::Exception::Usage->throw("count unavailable for this query\n") if ($visibleDatasetCounter == 2);
	}
    }

    my $datasetsToProcess = [@{$self->get('final_dataset_order')}];
    my $results = $self->_processPath($datasetsToProcess);
    return defined($results) ? $results:undef;
}

sub _processPath {
    my ($self, $datasetsToProcess)  = @_;

    my $query = $self->get('query');
    my %union_tables = %{$self->get('union_tables')};
    my $last_visible_exportable = $self->get('last_visible_exportable');
    
  
    # $datasetsToProcess length > 1
    unless (scalar(@{$datasetsToProcess}) > 1) {
	# base case, process the query and return the ResulTable or count
	my $dset = shift @{$datasetsToProcess};
	my $datasetToProcess = $self->get('registry')->
	    getDatasetByName($query->virtualSchema, $dset);
	return if (!$datasetToProcess);
	#determine batching logic
	my $virtualSchemaNameForQuery = $query->virtualSchema;
	if ($datasetToProcess->serverType eq "web"){    
	    my $location = $datasetToProcess->getParam('configurator')
		->get('location');
	    $virtualSchemaNameForQuery = $location->serverVirtualSchema;
	}
	
	my $subquery = 
	  BioMart::Query->new('registry' => $self->get('registry'),
	       		      'virtualSchemaName'=>$virtualSchemaNameForQuery);
	
	# don't use addAttributes and _addAttribute method as 
	# these automatically link placeholder atts and this will
	# produce a 2 dataset subquery which messes up batching and
	# web services mode - same problem for filters below
	#$subquery->addAttributes($query->getAllAttributes($dset)) 
	#    if ($query->getAllAttributes($dset)); 
	my $subquery_atts = $query->getAllAttributes($dset);
	if ($subquery_atts){
	    foreach my $subquery_att(@{$subquery_atts}){
		$subquery->addAttributeWithoutLinking($subquery_att);
	    $logger->debug("Added attribute $subquery_att to bottom dataset ".$datasetToProcess->name);
	    }
	}

	#$subquery->addFilters($query->getAllFilters($dset)) 
	#    if ($query->getAllFilters($dset));
	my $subquery_filts = $query->getAllFilters($dset);
	if ($subquery_filts){
	    foreach my $subquery_filter(@{$subquery_filts}){
		$subquery->addFilterWithoutLinking($subquery_filter);
	    $logger->debug("Added filter $subquery_filter to bottom dataset ".$datasetToProcess->name);
	    }
	}


	$subquery->orderBy($query->orderBy()) 
	    if ($query->orderBy());
    $logger->debug("Added orderBy ".$query->orderBy." to bottom dataset ".$datasetToProcess->name)
	    if ($query->orderBy());
	# add dataset name incase no atts/filts eg start page count
	$subquery->addDatasetName($dset,
				  $query->getInterfaceForDataset($dset));
    $logger->debug("Added dataset $dset interface ".$query->getInterfaceForDataset($dset)." to bottom dataset ".$datasetToProcess->name);
	
	my %params = ('query' => $subquery);

	if ($query->count) {
	    return $datasetToProcess->getCount(%params);
	} 
	else {
            if (defined($query->limitSize)){
                # martservices originating query. Therefore want to just 
		# get a single batch of results back from the 
		# dataset->getResultTable call corresponding to the passed 
		# in values set on the Query object for limitStart and 
		# limitSize
	    	$params{'batch_size'} = $query->limitSize;
                $params{'batch_start'} = $query->limitStart;
	    	$params{'web_origin'} = 1;
		$self->set('batched_already', 1);
	    }
	    else{
		unless ($self->get('batched_already')) {
		    $self->set('batched_already', 1);
		    $params{'batch_size'} = 
			$datasetToProcess->initialBatchSize;
		    $params{'batch_start'} = 0;
		}
	    }
	    # call for a single dataset query
	    $logger->debug("Bottom dataset ".$datasetToProcess->name." query params are: ".keys(%{$params{'query'}}));
		
		## to see if its GS and its the last one, so the expected results would be
		## in FASTA format, and should be comma separated
		$datasetToProcess->lastDS(1) if ($self->get('visibleDSCount') == 1);
		$datasetToProcess->lastDS(2) if ($self->get('visibleDSCount') > 1);

	    my $rtable = $datasetToProcess->getResultTable(%params);

	    $logger->debug("Bottom dataset ".$datasetToProcess->name." gave ".scalar(@{$rtable->get('columns')}));

	    # perform union if appropiate entry exists in union_tables hash
	    if ($union_tables{$datasetToProcess->name}){
		my $tableToAdd = $union_tables{$datasetToProcess->name};
		if ($tableToAdd->getNumFields == $rtable->getNumFields){
		    $rtable->addRows($tableToAdd->getRows);
		    $union_tables{$datasetToProcess->name} = undef;
		    $self->set('union_tables',\%union_tables);
		}
	    }
	    return $rtable;
	}
    }
    
    # more than one dataset - this one is an exportable
    my ($links, $targetDataset, $exportable, $invisible_exportable);

    my $dset = shift @{$datasetsToProcess};
    my $datasetToProcess = $self->get('registry')->
	getDatasetByName($query->virtualSchema, $dset); 
    my @current_visible_links;
    my @current_invisible_links;
    foreach my $odset (@{$datasetsToProcess}) {
      my $li = $query->getLinks($dset, $odset);
      if ($li) {
	  $links = $li;
	  $targetDataset = $self->get('registry')->
	      getDatasetByName($query->virtualSchema, $odset);	  
	  if ($links->operation eq 'join'){
	      $exportable = $targetDataset->
		  getImportables($links->defaultLink,
				 $query->getInterfaceForDataset($odset))->new;
	      if ($targetDataset->visible){
		  push @current_visible_links,$links;
		  $self->set('last_visible_exportable',$exportable);
	      }
	      else{
		  $invisible_exportable = $targetDataset-> 	 
                       getImportables($links->defaultLink, 	 
                                 $query->getInterfaceForDataset($odset))->new;
		  push @current_invisible_links,$links;
	      }
	  }
      }
    }
	$exportable = $invisible_exportable if ($invisible_exportable);
    if (!$exportable){
	# in the situation where first dataset placeholder dataset needs to 
	# export the data to the second v dataset need to store the original 
	# visible exportable from mouse to human and use that
	$exportable = $last_visible_exportable;
	$exportable->batching(1);# propogate batching through
	my $exportable_size = @{$exportable->getAllFilters};
	$datasetToProcess->forceHash($exportable_size);# going to have to export data from 1st dataset placeholder to second visible dataset
    }


    #create subquery
    my $virtualSchemaNameForQuery = $query->virtualSchema;
    if ($datasetToProcess->serverType eq "web"){    
	my $location = $datasetToProcess->
	    getParam('configurator')->get('location');
	$virtualSchemaNameForQuery = $location->serverVirtualSchema;
    }
    my $subquery = BioMart::Query->new('registry' => $self->get('registry'),
			     'virtualSchemaName'=>$virtualSchemaNameForQuery);
    # don't use addAttributes and _addAttribute method as 
    # these automatically link placeholder atts and this will
    # produce a 2 dataset subquery which messes up batching and
    # web services mode - same problem for filters below
    #$subquery->addAttributes($query->getAllAttributes($dset)) 
    #    if ($query->getAllAttributes($dset)); 
    my $subquery_atts = $query->getAllAttributes($dset);
    if ($subquery_atts){
	foreach my $subquery_att(@{$subquery_atts}){
	    $subquery->addAttributeWithoutLinking($subquery_att);
	}
    }

    #$subquery->addFilters($query->getAllFilters($dset)) 
    #    if ($query->getAllFilters($dset));
    my $subquery_filts = $query->getAllFilters($dset);
    if ($subquery_filts){
	foreach my $subquery_filter(@{$subquery_filts}){
	    $subquery->addFilterWithoutLinking($subquery_filter);
	}
    }

    # incase on start page count
    $subquery->addDatasetName($dset,$query->getInterfaceForDataset($dset));

    foreach my $links(@current_invisible_links){	
	if ($links && $links->operation eq 'join'){
	    $subquery->addAttributeList($datasetToProcess->
		       getExportables($links->defaultLink,
				      $query->getInterfaceForDataset($dset)))
	}
	#determine batching logic
	if ($links->operation eq 'union'){
	    $self->set('batched_already',1);# turn off batching for unions
	} 
    }
    
    foreach my $links(@current_visible_links){	
	if ($links && $links->operation eq 'join'){
	    my $att_list = $datasetToProcess->
		       getExportables($links->defaultLink,
				      $query->getInterfaceForDataset($dset));
	    if (@current_invisible_links){
		$subquery->addAttributes($att_list->getAllAttributes);# works for placeholder 1st dset atts
	    }
	    else{
		$subquery->addAttributeList($att_list);# works for non-placeholder scenario
	    }
	}
	#determine batching logic
	if ($links->operation eq 'union'){
	    $self->set('batched_already',1);# turn off batching for unions
	} 
    }

    my %params = ('query' => $subquery);
    if ($datasetToProcess->visible) {
	#propogate batching through all visible datasets
	$exportable->batching(1) if ($exportable);

	if ($query->limitSize && $query->limitSize > 0){
	    # martservices originating query. Therefore want to just get a 
	    # single batch of results back from the dataset->getResultTable 
	    # call corresponding to the passed in values  set on the Query 
	    # object for limitStart and limitSize
	    $params{'batch_size'} = $query->limitSize;
	    $params{'batch_start'} = $query->limitStart;
	    $params{'web_origin'} = 1;
	    $self->set('batched_already', 1);	
	}
	else{
	    unless ($self->get('batched_already')) {
		$self->set('batched_already', 1);
		$params{'batch_size'} = $datasetToProcess->initialBatchSize;
		$params{'batch_start'} = 0;
	    }
	}
    } 
    else {	    
	# intermediate invisible datasets must also propogate batches
	$exportable->batching(1) if ($exportable 
				     && $self->get('batched_already') 
				     && $datasetToProcess->exportableFrom  
				     && $datasetToProcess->importableTo);
    }

    # execute and add exportable to Query

	$datasetToProcess->lastDS(0); ## thats not the lastDS as the last one gets called from previous block
    my $tempTable = $datasetToProcess->getResultTable(%params);		
	$logger->debug("Non-bottom dataset ".$datasetToProcess->name." gave ".scalar(@{$tempTable->get('columns')}));
    
    # perform union if appropiate entry exists in union_tables hash
    if ($union_tables{$datasetToProcess->name}){
	my $tableToAdd = $union_tables{$datasetToProcess->name};
	if ($tableToAdd->getNumFields == $tempTable->getNumFields){
	    $tempTable->addRows($tableToAdd->getRows);
	    $union_tables{$datasetToProcess->name} = undef;
	    $self->set('union_tables',\%union_tables);
	}
    }
    if ( $exportable){# JOIN
	if ($tempTable != -1){
	     $exportable->setTable($tempTable);
	     $query->_addFilter($exportable);
	 }
    }
    else{# UNION
	 $union_tables{$targetDataset->name} = $tempTable;
	 $self->set('union_tables',\%union_tables);
    }

    $self->set('query', $query);
    return $self->_processPath($datasetsToProcess) || undef;
}


sub executionPlan{

    my ($self,$query) = @_;
    
    $query->finalProcess();# needed before every executionPlan 
	                   # as creates links if not there

    # ? why below needed rather than just $query->getRegistry;
    # if not there error checking should be in Query as all Query objects 
    # should have a registry?
    my $registry;
    use Carp;
    eval{ $registry = $query->getRegistry; };
    if($@) { confess(); }

    $self->set('query', $query);
    $self->set('registry', $registry);

    #reset recursion state
    $self->set('processed_datasets', {});
    $self->set('datasets_encountered', {});
    $self->set('final_dataset_order', []);

	if (scalar (@{$query->getDatasetNames}) > 0)
	{
		$self->_executionPlan($query->getDatasetNames) || undef;
	}
	else
	{
		BioMart::Exception::Usage->throw('Query Runner - Problematic Query: No dataset names in the Query');
	}
}

sub _executionPlan {
    my ($self, $datasetsToProcess)  = @_;

    my $query = $self->get('query');
    my $processed_datasets = $self->get('processed_datasets');
    my $datasets_encountered = $self->get('datasets_encountered');

    my $final_dataset_order = $self->get('final_dataset_order');

    if (scalar(@{$datasetsToProcess}) == 1) {
	my $dset = shift @{$datasetsToProcess};
	push @{$final_dataset_order},$dset;
	$query->finalDatasetOrder($final_dataset_order);
    }
    else { # more than one dataset - this one is an exportable
	my @targetDatasets;
	my $dset = shift @{$datasetsToProcess};
	if ( $datasets_encountered->{$dset} 
	     && ( scalar(@{$datasetsToProcess}) == 
		  $datasets_encountered->{$dset} ) ) {
	    # degenerate base case, this is designed to prevent infinite recursion
	    BioMart::Exception::Query->throw("Problematic Query, unable to determine finite path through Datasets\n");
	}
	
	$datasets_encountered->{$dset} = scalar(@{$datasetsToProcess});
    
	my $datasetToProcess = $self->get('registry')->
	    getDatasetByName($query->virtualSchema, $dset); 
    
        ODSET: foreach my $odset (@{$datasetsToProcess}) {
	    if ($query->getLinks($odset, $dset) && 
		!( $processed_datasets->{$odset} )) {
		push @{$datasetsToProcess}, $dset;
		$datasetToProcess = 0;
		# essentially go to end of method and recursively call again
		# with the new dataset order
		last ODSET;
	    }
	    # if here, determine if this is the targetDataset query guarantees 
	    # that for any dataset, there will only be one target dataset thus, 
	    # only one combination of (dset, odset) where $query->getLinks 
	    # returns a defined value

	    if ($query->getLinks($dset, $odset)) {
		my $targetDataset = $self->get('registry')->
		    getDatasetByName($query->virtualSchema, $odset);
		push @targetDatasets, $targetDataset;
	    }
	}

	if ($datasetToProcess) {
	    push @{$final_dataset_order},$dset;
	    $processed_datasets->{$dset} = 1;

	    if (@targetDatasets > 1){
		foreach my $targetDataset(@targetDatasets){
		    if (!$targetDataset->visible){
			my $target_name = $targetDataset->name;
			# this deals with mouse seq when mouse is the first
			# visible dataset in a query for example
			push @{$final_dataset_order},$target_name;
			$processed_datasets->{$target_name} = 1;
			
			my @new_datasetsToProcess;
			foreach my $odset (@{$datasetsToProcess}){
			    next if ($odset eq $target_name);
			    if ($query->getLinks($target_name, $odset)){
				push @{$final_dataset_order},$odset;
			    }
			    else{
				push @new_datasetsToProcess, $odset;
			    }
			}
			@{$datasetsToProcess} = @new_datasetsToProcess;	      
		    }
		}
	    }
	}
	# at this point, either datasetsToProcess is one dataset shorter, 
	# after processing a dataset or the order of datasets has changed
	# set state and recurse
    
	$self->set('processed_datasets', $processed_datasets);
	$self->set('datasets_encountered', $datasets_encountered);
	$self->_executionPlan($datasetsToProcess) || undef;
    }
}

sub uniqueRowsOnly
{
	my ($self, $val)  = @_;
	if($val) {
		$self->set('uniqueResultsFlag', 1);	
	}
	return $self->get('uniqueResultsFlag');
	
	
}

1;
