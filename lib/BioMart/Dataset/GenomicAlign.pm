# $Id: GenomicAlign.pm,v 1.2 2006-11-25 18:11:31 arek Exp $
#
# BioMart module for BioMart::Dataset::GenomicSequence
# You may distribute this module under the same terms as perl itself
# POD documentation - main docs before the code

=head1 NAME

BioMart::Dataset::GenomicAlign

=head1 SYNOPSIS

A hidden Dataset containing sequence attributes that can be imported to other
visible Datasets which are compatible with its required data input, based
on the presence of one or more importable-exportable relationships.

=head1 DESCRIPTION

Dataset providing Align Sequence attributes, which can be imported into
other Datasets.  AlignSequence is itself not a visible Dataset.

=head1 AUTHOR - Arek Kasprzyk, Darin London

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS


=head1 Developer Notes

  The peptide translation algorithm is taken directly
  from the CodonTable module that is part of the
  BioPerl project.  For more information about the
  BioPerl project, visit:

  http://www.bioperl.org 

=cut
package BioMart::Dataset::GenomicAlign;
# implements Dataset interface

use strict;
use warnings;
use base qw(BioMart::DatasetI);

use BioMart::Dataset::GenomicSequence::DNAAdaptor;
use BioMart::Configuration::ConfigurationTree;
use BioMart::Configuration::AttributeTree;
use BioMart::Configuration::FilterTree;
use BioMart::Configuration::AttributeGroup;
use BioMart::Configuration::FilterGroup;
use BioMart::Configuration::AttributeCollection;
use BioMart::Configuration::FilterCollection;
use BioMart::Configuration::Attribute;
use BioMart::Configuration::AttributeList;
use BioMart::Configuration::BooleanFilter;
use BioMart::Configuration::ValueFilter;
use BioMart::Configuration::FilterList;

#change this to change the size of each batch
use constant BATCHSIZE => 100;

my $i;

sub _new {
	
    my ($self, @param) = @_;
    $self->SUPER::_new(@param);
    
    my $i=1; ##
    
    $self->attr('dna', undef);
    $self->attr('dnaparams', undef);
    ######### modified
    $self->attr('recipe', 'raw_sequence'); ## this will hold a subRef
    $self->attr('ignore', undef);
    $self->attr('ignore_row', undef);
    $self->attr('seq_edits', undef); #will hold seq_edits to be applied after sequence has been produced  
    #$self->attr('codon_table_id', 1); #codon table   defaults to 1  
    $self->attr('seq_name', undef); #this is linked to the Attribute->name, determines which sequence recipe to run  
    $self->attr('translate', 0); # set to true for peptide  
    #$self->attr('downstream_flank', 0);  
    #$self->attr('upstream_flank', 0);
    $self->attr('importable', undef);
    $self->attr('lastPkey', undef);
    $self->attr('importable_names', undef); # initialized when first row   processed in first batch for a given query  
    $self->attr('importable_indices', undef); # initialized when first row   processed in first batch for a given query  
    $self->attr('returnRow_indices', undef); # initialized when first row processed in first batch for a given query  
    $self->attr('returnRow', undef);  
    $self->attr('batchIndex', 0); #increment each time a new pkey is encountered.
    $self->attr('seq_species', undef);

    #process rows   until this equals batchSize
    
    $self->attr('locations', {}); # not used by all sequences
    $self->attr('outRow', undef); # not used by all sequences
    
    #attributes calculated over sequence locations
    $self->attr('calc_location', undef);
    
    $self->attr('sequence', undef);
}

#private methods

sub _ignoreRow {
  my ($self, $curRow) = @_;

  my $ignore = $self->get('ignore');
  return 0 unless ($ignore);  

  my $ignore_row = $self->get('ignore_row');
  my $test = $self->_getLocationFrom($curRow, $ignore_row);
  
  #if the actual value is false, return false, else, return ignore for the value
  return $test->{ $ignore_row } && $ignore->{ $test->{ $ignore_row  } };
}

sub _editSequence {
  my ($self, $seqref) = @_;

  my $seq_edits = $self->get('seq_edits');

  if ($$seqref && $seq_edits) {
    foreach my $seq_edit (split /\;/, $seq_edits) {
      my ($start, $end, $alt_seq) = split /\,/, $seq_edit;

      my $len = $end - $start + 1;
      substr($$seqref, $start - 1, $len) = $alt_seq;
	}
  }
}

sub _initializeDNAAdaptor {
    my $self = shift;
    
    my $dna_params = $self->getConfigurationTree()->optionalParameters;
    unless ($dna_params) {
	BioMart::Exception::Configuration->throw("GenomicSequence Dataset requires optional_parameters to be set in the DatasetConfig\n");
    }
    
    my $dna = {};

## from the has_mmu_align_sequence  dataset	
## need to parse the attributes - to get different DNAadaptor for each species  
## Attribute : optional parameters
## hsapiens_sequence,hsapiens_genomic_sequence__dna_chunks__main,chr_name,chr_start,sequence,100000;mmus_oriented_raw_sequence,mmusculus_genomic_sequence__dna_chunks__main,chr_name,chr_start,sequence,100000
##
	foreach  my $dna_params4specie  ( split /\;/, $dna_params ){

	    #print STDERR ("##GenomicAlign _initializeDNAAdaptor  ".localtime(time)."\n");

#	    print "\n+In subroutine __dnaAdaptor dna_params4specie  $dna_params4specie\n";
	    ## hsa_oriented_raw_sequence,hsapiens_genomic_sequence__dna_chunks__main,chr_name,chr_start,sequence,100000
	    my ($attribute_name, $dnatablename, $chunk_name_fieldname, $chunk_start_fieldname, $seqfieldname,$chunk_size) = split /\,/, $dna_params4specie ;

#	    print "\n\n\nstoring dna for $attribute_name $dnatablename $chunk_name_fieldname $chunk_start_fieldname $seqfieldname $chunk_size\n\n\n";

#	    print "chunk_size: $chunk_size\n";
	    $dna->{$attribute_name} = BioMart::Dataset::GenomicSequence::DNAAdaptor->new('seq_name' => $attribute_name,
									 'dna_tablename' => $dnatablename,                   ##hsapiens_genomic_sequence__dna_chunks__main
									 'seq_fieldname' => $seqfieldname,                   ##sequence
									 'chunk_name_fieldname' => $chunk_name_fieldname,    ##chr_name
									 'chunk_start_fieldname' => $chunk_start_fieldname,  ##chr_start
									 'chunk_size' => $chunk_size,                        ##100000
									 'configurator' => $self->getParam('configurator')
									 );
	    
	    unless ($dna->{$attribute_name}) {
		BioMart::Exception::Configuration->throw("Couldnt connect to DNAAdaptor for $attribute_name\n\n");
	    }	    
	}
#	print "dna: ",$dna,"\n";
        $self->set('dna', $dna);
        
#    print "\n+Out subroutine: __dnaAdaptor GenomicAlign\n";
}

sub __processNewQuery {
    my ($self, $query) = @_;

    #print STDERR ("##GenomicAlign  1_processNewQuery  ".localtime(time)."\n");
#    print "\nname:",$self->name," GenomicAlign\n";
#    print "\nquery: ",$query," GenomicAlign\n";
#    print "\ntableau: ",$query->getAllAttributes($self->name)," GenomicAlign\n";
    my $attribute = $query->getAllAttributes($self->name)->[0];
    my $seq_name = $attribute->name;
    $self->set('seq_name', $seq_name);
    ##$self->set('translate', ($seq_name =~ m/peptide$/));
    #print STDERR ("##GenomicAlign  2_processNewQuery  ".localtime(time)."\n");
    my $ignore = 'IGNORE';
    if ($seq_name =~ m/raw/){
	
	$self->set('recipe', '_rawSequences');
	
    } else {
	BioMart::Exception::Configuration->throw("Unsupported sequence name $seq_name recieved by GenomicAlign\n");    
    }
    #print STDERR ("##GenomicAlign  3_processNewQuery  ".localtime(time)."\n");
    #$self->set('downstream_flank', 0);
    #$self->set('upstream_flank', 0);
    $self->set('importable', undef);
    $self->set('lastPkey', undef);
    $self->set('importable_indices', undef);
    $self->set('returnRow_indices', undef);
    $self->set('locations', {});
    $self->set('outRow', undef);
    $self->set('calc_location', undef);
    $self->set('sequence', undef);
    
    #determine which BaseSequenceA object to create
    my $filters = $query->getAllFilters($self->name);
    #print STDERR ("##GenomicAlign  4_processNewQuery  ".localtime(time)."\n");
    foreach my $filt (@{$filters}) {
	if ($filt->isa("BioMart::Configuration::FilterList")) {
	    if ($filt->linkName) {
		if ($self->get('importable') ) {
		    BioMart::Exception::Configuration->throw("Recieved two importables, can only work with one\n");
		} else {
		    $self->set('importable', $filt);
		}
	    } else {
		BioMart::Exception::Configuration->throw("Recieved invalid linkName ".$filt->linkName."\n");
	    }
	} else {
	    #must be a downstream or upstream valueFilter
	    unless ($filt->isa("BioMart::Configuration::ValueFilter")) {
		BioMart::Exception::Configuration->throw("Recieved unknown filter ".$filt->name." in GenomicSequence Dataset!\n");
	    }
	    
	    if ($self->get($filt->name)) {
		BioMart::Exception::Configuration->throw("Recieved two ".$filt->name." flanking filters in GenomicSequence Dataset\n");
	    }
	    
	    #could still be some strange ValueFilter that is not upstream or downstream, but not likely
	    #will throw an exception if this is the case
	    my $table = $filt->getTable;
	    my $row = $table->nextRow;
	    my $value = $row->[0];
	    if ($value) {
		$self->set($filt->name, $value);
	    }
	}
    }
    #print STDERR ("##GenomicAlign  5_processNewQuery  ".localtime(time)."\n");
    unless ($self->get('importable')) {
	BioMart::Exception::Configuration->throw("No Importable Recieved in GenomicAlign\n");
    }
}


sub _continueWithBatch {
    my ($self, $batchSize, $rtable) = @_;
    
    #always true if underlying table is an AttributeTable and it has rows
    my $continue = ($rtable->isa("BioMart::ResultTable")) 
	? $rtable->inCurrentBatch() 
	: $rtable->hasMoreRows;
    
    if ($continue && $batchSize) {
	my $batchIndex = $self->get('batchIndex');
	$continue = ($batchIndex < $batchSize);
    }
    
    return $continue;
}

sub _incrementBatch {
  my $self = shift;

  my $batchIndex = $self->get('batchIndex');
  $batchIndex++;

  $self->set('batchIndex', $batchIndex);
}

sub _initializeIndices {
  my ($self, $numFields) = @_;

  my $importable_names = [];
  my $returnRow_indices = {};
  my $importable_indices = {};
  
  my $filts = $self->get('importable')->getAllFilters;

  #define where the importable fields are in rtable
  my $index = 0;
  foreach my $filt (@{$filts}) {
    push @{$importable_names}, $filt->name;
    $importable_indices->{$filt->name} = $index;
    $index++;
  }

  #define where fields needing to be merged into final returnRow are in rtable
  my $resultIndex = 0;
  while ($index < $numFields) {
    $returnRow_indices->{$index} = $resultIndex;
    $index++;
    $resultIndex++;
  }

  $self->set('importable_indices', $importable_indices);
  $self->set('returnRow_indices', $returnRow_indices);
  $self->set('importable_names', $importable_names);
}

sub _initializeReturnRow {
      my ($self, $curRow) = @_;

      #This does __NOT__ concatenate fields that are many<->one with the pkey
      my $returnRow = [];
      
      foreach my $val (@{$curRow}) {
	push @{$returnRow}, $val;
      }
      return $returnRow;
}

sub _processRow {
  my ($self, $atable, $curRow) = @_;

  # if this is the very first row for a new query, initialize the indices using its length as numFields
  unless ($self->get('importable_indices')) {
      if ($self->get('exhausted')) {
	  $atable->addRow(["No Sequence Returned"]);
      } else {
        my $numFields = @{$curRow};
        $self->_initializeIndices($numFields);
    }
  }

  my $method = $self->get('recipe');
  $self->$method($atable, $curRow);
}

sub _calcSeqOverLocations {
  my ($self, $this_location) = @_;
  $this_location->{start} || return; # Sanity check
  $this_location->{end}   || return; # Sanitt check

  my $calc_location = $self->get('calc_location');

  if ($calc_location) {
    $calc_location->{"start"} = $this_location->{"start"}  if ($this_location->{"start"} < $calc_location->{"start"});
    $calc_location->{"end"} = $this_location->{"end"}  if ($this_location->{"end"} > $calc_location->{"end"});
  } else {
    $calc_location = {};
    foreach my $key (keys %{$this_location}) {
      $calc_location->{$key} = $this_location->{$key};
	}
  }
  
  $self->set('calc_location', $calc_location);
}

sub _getLocationFrom {
    my ($self, $curRow, @expectedFields) = @_;
    
    my $importable_indices = $self->get('importable_indices');
    my $location = {};
    
    foreach my $expectedField (@expectedFields) {
    $location->{$expectedField} = ( exists( $importable_indices->{$expectedField}  ) ) ? $curRow->[ $importable_indices->{$expectedField} ] : undef;
}
    
    return $location;
}


######################################################
sub _processSequence {    ############################
  my ($self, $location, $attribute_name, $count) = @_;
  #@species_attribute_name contains hsa et mmu
  #print STDERR ("##GenomicAlign  _processSequence  starting ".localtime(time)."\n");
  #print "attribute_name $attribute_name\n";
  #print "count  $count\n";
 # my $i=1;

  my $seq    = ''; 
  my $dna    = $self->get('dna')->{$attribute_name};
  my $chr    = $location->{'chr'.$count};
  my $start  = $location->{'start'.$count};
  my $end    = $location->{'end'.$count};
  my $strand = $location->{'strand'.$count};
  #------------------------
  #my $seq = '';
  #my $dna = $self->get('dna')->{$attribute_name};
  #my $chr = $location->{'chr1'};
  #$chr = $location->{'chr2'} unless (defined $chr);
  #my $start = $location->{'start1'};
  #$start = $location->{'start2'} unless (defined $start);
  #my $end = $location->{'end1'};
  #$end = $location->{'end2'} unless (defined $end);
  #my $strand = $location->{'strand1'};
  #$strand = $location->{'strand2'} unless (defined $strand);
  #$strand = 1 unless (defined $strand);
  #print "coucou $chr $start $end $strand\n";
  
  
  if ($strand < 0) {
      #print STDERR ("##GenomicAlign  NO rc \n".$dna->getSequence( $chr, $start, $end )."\n");
      #print STDERR ("#GenomicAlign  start rc \n"._rc( $dna->getSequence( $chr, $start, $end ))."\n");
      $seq .= $self->_rc( $dna->getSequence( $chr, $start, $end ) );
      #print STDERR ("##GenomicAlign  start end ".localtime(time)."\n");
      #print STDERR ("##GenomicAlign  RC  \n".$seq."\n");
  } else {
      #print STDERR ("##GenomicAlign  start getSequence ".localtime(time)."\n");
      $seq .= $dna->getSequence( $chr, $start, $end );
      #print STDERR ("##GenomicAlign  start getSequence ".localtime(time)."\n");
  }
  $i++;
  #print STDERR ("##GenomicAlign  3_processSequence   $attribute_name ".localtime(time)."\n");
  
  if (length($seq)) {
      return $seq;
  }
 # print STDERR ("##GenomicAlign  4_processSequence   $attribute_name ".localtime(time)."\n");
  return undef;
  
}

sub _addRow {
    my ($self, $atable, $outRow) = @_;
    $atable->addRow($outRow);
    $self->_incrementBatch;
}

sub _rc{
    my ($self, $seq) = @_;

    #print STDERR "GenomicAlign reverse start ".localtime(time)."\n";
    $seq = reverse($seq);
    #print STDERR "GenomicAlign reverse end tr start ".localtime(time)."\n";
    $seq =~ tr/YABCDGHKMRSTUVyabcdghkmrstuv/RTVGHCDMKYSAABrtvghcdmkysaab/;
    #print STDERR "GenomicAlign tr end _rc end ".localtime(time)."\n";
    return $seq;
}

#interface methods
sub _getConfigurationTree {
  my $self = shift;
  return $self->getParam('configurator')->getConfigurationTree($self->virtualSchema, $self->name);
}

sub _getExportables {
    my ($self, $linkName) = @_;

    my $exportables = $self->get('exportables');
    if ($linkName) {
      return [ $exportables->{$linkName} ];
	}

    my $ref = [];
    push @{$ref}, values %{$exportables};
    return $ref;
}


sub _getImportables {
  my ($self, $linkName) = @_;

  my $importables = $self->get('importables');
  if ($linkName) {
    #return [ $importables->{$linkName} ];
    return $importables->{$linkName};
  }

  my $ref = [];
  push @{$ref}, values %{$importables};

  return $ref;
}

sub _getResultTable { 
  my ($self, @param) = @_;
  $self->set('batchIndex', 0);
  local($^W) = 0;  # prevent "odd number of elements" warning with -w.
  my(%param) = @param;

  my $query = $param{'query'};

  my $atable = $param{'table'};
  my $batch_size = $param{'batch_size'};
  
    if ($self->serverType eq "web"){  
	my $batch_start = $param{'batch_start'} || 0;
	
	my $location = $self->getParam('configurator')->get('location');
	my $xml = $query->toXML($batch_start,$batch_size,0);    
        	
	foreach my $el($location->getResultSet("","POST",$xml)){
	    if ($el =~ /No Sequence Returned/) {
		$self->_setExhausted(1);
		last;
	    }
	    my @clean=split(/\t/,$el);
	    $atable->addRow([@clean]);
	}
	
	return $atable;
    } else {
		$self->_initializeDNAAdaptor($query->
				     getInterfaceForDataset($self->name));
    }
    
# print STDERR ("##BATCH SIZE FOR ".$self->name." IS ".$batch_size."\n");
  
  my $importable = $self->get('importable');
  my $rtable = $importable->getTable();
  
  my $has_rows = $rtable->hasMoreRows;
  
  while ($has_rows && $self->_continueWithBatch($batch_size, $rtable)) {
      $self->_processRow( $atable, $rtable->nextRow );
  }
  
  # the last and final call to GenomicSequence, after the call which exhausts the importable,  
  # will result in the last sequence being processed and added to the resultTable.  
  # the next call after this returns undef.
  unless ($has_rows) {
      $self->_setExhausted(1);
#      $self->_processRow($atable);
  }
  
  $importable->setTable($rtable);
  $self->set('importable', $importable); 
  
  		my $dna = $self->get('dna');
		foreach my $attribute_name (keys %$dna) {
			 $dna->{$attribute_name}->close;
		}
  
  return $atable;
}

### sequence __recipes__
sub _rawSequencesOriginal {           ## SHOULD BE REMOVED 
  my ($self, $atable, $curRow) = @_;  ## AS IT WAS FROM GENOMICSEQUENCE.PM
  my $rank = 1;
  
  if ($curRow) {
      my $importable_indices = $self->get('importable_indices');
      my $locations = {};
      my $location = $self->_getLocationFrom($curRow, "chr", "start", "end");
      
      $location->{"strand"} = ( exists( $importable_indices->{"strand"} ) ) ?  $curRow->[  $importable_indices->{"strand"} ] : 1;
      $locations->{$rank} = $location if ($location->{"start"});
      my $sequence = $self->_processSequence($locations);
      $self->_editSequence(\$sequence);
      if ($sequence) {
	  $self->_addRow($atable, $self->_initializeReturnRow($curRow), $sequence);
      }
  }
  #else there is no last entry
}

sub _rawSequences {
    my ($self, $atable, $curRow) = @_;
    my $rank             = 1;
    my $overall_count    = 0;
    my $local_count      = 0;
    my $species_numbers  = 0;
    my $count            = 1;
    my $n = 0;
    my @importable_names = @{$self->get('importable_names')};
    my $dna_params = $self->getConfigurationTree()->optionalParameters;
    my @species_dna_params = split(/\;/, $dna_params);
    my @species_attribute_name;

#    print STDERR ("##GenomicAlign  1_rawSequences   ".localtime(time)."\n");
    foreach my $sdp (@species_dna_params) {
	my ($attribute_name) = split(/\,/,$sdp);
	push @species_attribute_name, $attribute_name;
	#print "## $attribute_name\n";
    }
#    print STDERR ("##GenomicAlign  2_rawSequences   ".localtime(time)."\n");

    my $initRow =  $self->_initializeReturnRow($curRow);
    
#    print STDERR ("##GenomicAlign  3_rawSequences   ".localtime(time)."\n");
	
    while (my $attribute_name = shift @species_attribute_name){
	
	my $importable_indices = $self->get('importable_indices');
#	print STDERR ("##GenomicAlign  4_rawSequences   ".localtime(time)."\n");
	
	my ($name, $start, $end, $strand);
	    foreach my $var (\$name, \$start, \$end, \$strand) {
		$$var = shift @importable_names;
		last if (defined $strand);
		#print "strand $strand";
		#shift @importable_names;
	    }
#	print STDERR ("##GenomicAlign  5_rawSequences   $attribute_name".localtime(time)."\n");
	
	my $location = $self->_getLocationFrom($curRow, ($name, $start, $end, $strand));
	
#	print STDERR ("##GenomicAlign  6_rawSequences   $attribute_name ".localtime(time)."\n");
	#print "$attribute_name $name, $start, $end, $strand\n";
	my $sequence = $self->_processSequence($location, $attribute_name, $count);
#	print STDERR ("##GenomicAlign  7_rawSequences   $attribute_name ".localtime(time)."\n");
	if ($sequence) {
	    push @{$initRow}, $sequence;
	}
	## IMPORTANT remove the length as the coordinate aer as folow
	## name, start, end, strand, length
	shift @importable_names ;
#	print STDERR ("##GenomicAlign  8_rawSequences  $attribute_name ".localtime(time)."\n");
	$count++;
    }
    $self->_addRow($atable, $initRow);
#    print STDERR ("##GenomicAlign  9_rawSequences   ".localtime(time)."\n");
}
1;


