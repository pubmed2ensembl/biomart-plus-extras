#
# BioMart module for BioMart::Dataset::GenomicMAlign
#
# You may distribute this module under the same terms as perl itself



# POD documentation - main docs before the code

=head1 NAME

BioMart::Dataset::GenomicMALign

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR - Darin London, Damian Smedley

=head1 CONTACT

=head1 METHODS

=head1 Developer Notes

=cut


package BioMart::Dataset::GenomicMAlign;
# implements Dataset interface

use strict;
use warnings;
use base qw(BioMart::DatasetI);
use Log::Log4perl;

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

#change this if want a different default Codon Table ID
use constant DEFAULTCODONTABLEID => 1;

#exon will build their ignore keys if necessary
use constant IGNORE => { 
                        q(gene_exon) => {} 
                       };

use vars qw(@NAMES @TABLES $CODONS $TRCOL %IUPAC_DNA);

BEGIN {
    @NAMES =            #id
    (
     'Standard',        #1
     'Vertebrate Mitochondrial',#2
     'Yeast Mitochondrial',# 3
     'Mold, Protozoan, and CoelenterateMitochondrial and Mycoplasma/Spiroplasma',#4
     'Invertebrate Mitochondrial',#5
     'Ciliate, Dasycladacean and Hexamita Nuclear',# 6
     '', '',
     'Echinoderm Mitochondrial',#9
     'Euplotid Nuclear',#10
     '"Bacterial"',# 11
     'Alternative Yeast Nuclear',# 12
     'Ascidian Mitochondrial',# 13
     'Flatworm Mitochondrial',# 14
     'Blepharisma Nuclear',# 15
     'Chlorophycean Mitochondrial',# 16
     '', '',  '', '',
     'Trematode Mitochondrial',# 21
     'Scenedesmus obliquus Mitochondrial', #22
     'Thraustochytrium Mitochondrial' #23
     );

    @TABLES =
    qw(
       FFLLSSSSYY**CC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG
       FFLLSSSSYY**CCWWLLLLPPPPHHQQRRRRIIMMTTTTNNKKSS**VVVVAAAADDEEGGGG
       FFLLSSSSYY**CCWWTTTTPPPPHHQQRRRRIIMMTTTTNNKKSSRRVVVVAAAADDEEGGGG
       FFLLSSSSYY**CCWWLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG
       FFLLSSSSYY**CCWWLLLLPPPPHHQQRRRRIIMMTTTTNNKKSSSSVVVVAAAADDEEGGGG
       FFLLSSSSYYQQCC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG
       '' ''
       FFLLSSSSYY**CCWWLLLLPPPPHHQQRRRRIIIMTTTTNNNKSSSSVVVVAAAADDEEGGGG
       FFLLSSSSYY**CCCWLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG
       FFLLSSSSYY**CC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG
       FFLLSSSSYY**CC*WLLLSPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG
       FFLLSSSSYY**CCWWLLLLPPPPHHQQRRRRIIMMTTTTNNKKSSGGVVVVAAAADDEEGGGG
       FFLLSSSSYYY*CCWWLLLLPPPPHHQQRRRRIIIMTTTTNNNKSSSSVVVVAAAADDEEGGGG
       FFLLSSSSYY*QCC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG
       FFLLSSSSYY*LCC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG
       '' '' '' ''
       FFLLSSSSYY**CCWWLLLLPPPPHHQQRRRRIIMMTTTTNNNKSSSSVVVVAAAADDEEGGGG
       FFLLSS*SYY*LCC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG
       FF*LSSSSYY**CC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG
       );

    my @nucs = qw(t c a g);
    my $x = 0;
    ($CODONS, $TRCOL) = ({}, {});

    for my $i (@nucs) {
	for my $j (@nucs) {
	    for my $k (@nucs) {
		my $codon = "$i$j$k";

		$CODONS->{$codon} = $x;
		$TRCOL->{$x} = $codon;
		$x++;
	    }
	}
    }

    %IUPAC_DNA = ( A => [qw(A)],
		   C => [qw(C)],
		   G => [qw(G)],
		   T => [qw(T)],
		   U => [qw(U)],
		   M => [qw(A C)],
		   R => [qw(A G)],
		   W => [qw(A T)],
		   S => [qw(C G)],
		   Y => [qw(C T)],
		   K => [qw(G T)],
		   V => [qw(A C G)],
		   H => [qw(A C T)],
		   D => [qw(A G T)],
		   B => [qw(C G T)],
		   X => [qw(G A T C)],
		   N => [qw(G A T C)]
		   );
}

sub _new {
    my ($self, @param) = @_;
    $self->SUPER::_new(@param);

    $self->attr('dna', undef);
    $self->attr('dnaparams', undef);

    #$self->attr('recipe', undef); #this will hold a subRef
    $self->attr('recipe', undef); # bb2 - uses directly 'raw_sequence' ## need to put undef
    $self->attr('ignore', undef);
    $self->attr('ignore_row', undef);
    $self->attr('seq_edits', undef); 
    $self->attr('codon_table_id', 1); #codon table defaults to 1
    $self->attr('seq_name', undef); # this is linked to the Attribute->name, 
                                    # determines which sequence recipe to run
    $self->attr('translate', 0); # set to true for peptide
    $self->attr('downstream_flank', 0);
    $self->attr('upstream_flank', 0);
    $self->attr('importable', undef);
    $self->attr('lastPkey', undef);
    $self->attr('importable_indices', undef); # initialized when first row 
                                              # processed in first batch for a 
                                              # given query
    $self->attr('returnRow_indices', undef); # initialized when first row 
                                             # processed in first batch for a 
                                             # given query
    $self->attr('returnRow', undef);
    $self->attr('batchIndex', 0); # increment each time a new pkey is seen
    
    $self->attr('locations', {}); # not used by all sequences
    $self->attr('outRow', undef); # not used by all sequences
    
    #attributes calculated over sequence locations
    $self->attr('calc_location', undef);

    $self->attr('sequence', undef);
    $self->attr('attribute_merge_required', 0);
}

#private methods

sub _rc{
    my ($self, $seq) = @_;

    $seq = reverse($seq);
    $seq =~ tr/YABCDGHKMRSTUVyabcdghkmrstuv/RTVGHCDMKYSAABrtvghcdmkysaab/;
    return $seq;
}

sub _ignoreRow {
  my ($self, $curRow) = @_;

  my $ignore = $self->get('ignore');
  return 0 unless ($ignore);  

  my $ignore_row = $self->get('ignore_row');
  my $test = $self->_getLocationFrom($curRow, $ignore_row);
  
  #if the actual value is false, return false, 
  # else, return ignore for the value
  return $test->{ $ignore_row } && $ignore->{ $test->{ $ignore_row  } };
}

sub _translate {
   my ($self, $seq) = @_;
   
   BioMart::Exception::Configuration->throw("Calling translate without a seq argument!") 
       unless defined $seq;
   return '' unless $seq;

   my $id = $self->get('codon_table_id') || DEFAULTCODONTABLEID;
   my ($partial) = 0;
   $partial = 2 if length($seq) % 3 == 2;

   $seq = lc $seq;
   $seq =~ tr/u/t/;
   my $protein = "";
   if ($seq =~ /[^actg]/ ) { #ambiguous chars
       for (my $i = 0; $i < (length($seq) - 2 ); $i+=3) {
	   my $triplet = substr($seq, $i, 3);
	   if (exists $CODONS->{$triplet}) {
	       $protein .= substr($TABLES[$id-1],
				  $CODONS->{$triplet},1);
	   } 
	   else {
	       $protein .= $self->_translate_ambiguous_codon($triplet);
	   }
       }
   } 
   else { # simple, strict translation
       for (my $i = 0; $i < (length($seq) - 2 ); $i+=3) {
	   my $triplet = substr($seq, $i, 3);
	   if (exists $CODONS->{$triplet}) {
	       $protein .= substr($TABLES[$id-1], $CODONS->{$triplet}, 1);
	   } 
	   else {
	       $protein .= 'X';
	   }
       }
   }
   if ($partial == 2) { # 2 overhanging nucleotides
       my $triplet = substr($seq, ($partial -4)). "n";
       if (exists $CODONS->{$triplet}) {
	   my $aa = substr($TABLES[$id-1], $CODONS->{$triplet},1);
	   $protein .= $aa;
       } else {
	   $protein .= $self->_translate_ambiguous_codon($triplet, $partial);
       }
   }
   return $protein;
}

sub _translate_ambiguous_codon {
    my ($self, $triplet, $partial) = @_;
    $partial ||= 0;
    my $id = $self->get('codon_table_id') || DEFAULTCODONTABLEID;
    my $aa;
    my @codons = _unambiquous_codons($triplet);

    my %aas =();
    foreach my $codon (@codons) {
	$aas{substr($TABLES[$id-1],$CODONS->{$codon},1)} = 1;
    }
    my $count = scalar keys %aas;
    
    if ( $count == 1 ) {
	$aa = (keys %aas)[0];
    }
    elsif ( $count == 2 ) {
	if ($aas{'D'} and $aas{'N'}) {
	    $aa = 'B';
	}
	elsif ($aas{'E'} and $aas{'Q'}) {
	    $aa = 'Z';
	} 
	else {
	    $partial ? ($aa = '') : ($aa = 'X');
	}
    } 
    else {
	$partial ? ($aa = '') :  ($aa = 'X');
    }
    return $aa;
}

sub _unambiquous_codons{
    my ($value) = @_;
    my @nts = ();
    my @codons = ();
    my ($i, $j, $k);

    @nts = map { $IUPAC_DNA{uc $_} }  split(//, $value);

    for my $i (@{$nts[0]}) {
	for my $j (@{$nts[1]}) {
	    for my $k (@{$nts[2]}) {
		push @codons, lc "$i$j$k";
	    }
	}
    }
    return @codons;
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
    my ($self,$interface) = @_; 
    #warn "######### INTERFACE : $interface\n";   # $interface = 'default'   !!!
    my $dna_params = $self->getConfigurationTree($interface)->optionalParameters;

    unless ($dna_params) {
	BioMart::Exception::Configuration->throw("GenomicMAlign Dataset requires optional_parameters to be set in the DatasetConfig\n");
    }
    my $dna = {};## new
	
foreach  my $dna_params4specie  ( split /\;/, $dna_params ){##


 my ($attribute_name, $dnatablename, $chunk_name_fieldname, $chunk_start_fieldname, $seqfieldname,$chunk_size) = split /\,/, $dna_params4specie ; ##

	#my ($dnatablename, $chunk_name_fieldname, $chunk_start_fieldname, 
	#    $seqfieldname,$chunk_size) = split /\,/, $dna_params;

	#warn "\n::_initializeDNAAdaptor\nattribute_name:$attribute_name\nseq_name: ".$self->name."\ndnatablename: $dnatablename\nchunk_name_fieldname: $chunk_name_fieldname\nchunk_start_fieldname: $chunk_start_fieldname\nseqfieldname: $seqfieldname\nchunk_size: $chunk_size\n\n";

	$dna->{$attribute_name} = BioMart::Dataset::GenomicSequence::DNAAdaptor->new( ##
	#my $dna = BioMart::Dataset::GenomicSequence::DNAAdaptor->new(
		'seq_name' => $attribute_name,  ## $self->name
		#'seq_name' => $self->name,	## from original				     
		'dna_tablename' => $dnatablename,
		'seq_fieldname' => $seqfieldname,
		'chunk_name_fieldname' => $chunk_name_fieldname,
		'chunk_start_fieldname' => $chunk_start_fieldname,
		'chunk_size' => $chunk_size,
		'configurator' => $self->getParam('configurator'),
								     );
	unless ($dna->{$attribute_name}) { ##
	#unless ($dna) {##
	    BioMart::Exception::Configuration->throw("Couldnt connect to DNAAdaptor\n");
	}
    }##
	$self->set('dna', $dna);
}

sub __processNewQuery {
    my ($self, $query) = @_;

    my $attribute = $query->getAllAttributes($self->name)->[0];
    my $seq_name = $attribute->name;
    
    # hack to keep webservices working for 0_5 originating query XML
    if ($seq_name eq 'pkey'){
	$attribute = $query->getAllAttributes($self->name)->[-1];
	$seq_name = $attribute->name;
	
    }

    $self->set('seq_name', $seq_name);
    #$self->set('translate', ($seq_name =~ m/peptide$/));

    my $ignore = IGNORE;

    if ($seq_name =~ m/oriented_raw_sequence/i){
	
	$self->set('recipe', '_rawSequences'); ## here it calls the _rawSeq query ...
	
    } elsif (($seq_name =~ m/nonOrientedRawSequence/i)){
	
	$self->set('recipe', '_nonOrientedRawSequences'); ## here it calls the _nonOrientedRawSeq query ...
	
    }
    else {
	BioMart::Exception::Configuration->throw("Unsupported sequence name $seq_name recieved by GenomicMAlign\n");
    }

############ WAS FROM ORIGINAL GenomicSequence ##############    
#    if ($seq_name =~ m/(coding|cdna|peptide)$/) {
#	# this is not actually going to ignore anything, but is
#	# simply used to determine translation table for each gene
#	# without creating a second instance variable
#	$self->set('ignore_row', "type");
#	$self->set('recipe', '_codingCdnaPeptideSequences');
#    } 
#    elsif ($seq_name =~ m/(exon_intron|flank)$/) {
#	$self->set('recipe', '_exonIntronFlankSequences');
#    } 
#    elsif ($seq_name =~ m/raw/){
#	#my $interface = $query->getInterfaceForDataset($self->name); ## 
#	$self->set('recipe', '_rawSequences'); ## here it calls the _rawSeq query ...
#    } 
#    elsif ($seq_name =~ m/(gene_exon|transcript_exon|transcript_intron)$/) {
#	# set the system to ignore rows with duplicate pkeys
#	# for gene_exon
#	$self->set('ignore', $ignore->{$1}); #undef for transcript_exon
#	$self->set('ignore_row', "pkey");
#	$self->set('recipe', '_exonSequences');
#    } 
#    elsif ($seq_name =~ m/utr$/) {
#	$self->set('recipe', '_utrSequences');
#    } 
#    elsif ($seq_name =~ m/snp$/) {
#	$self->set('recipe', '_snpSequences');
#    } 
#    else {
#	BioMart::Exception::Configuration->throw("Unsupported sequence name $seq_name recieved by GenomicSequence\n");
#    }
    $self->set('downstream_flank', 0);
    $self->set('upstream_flank', 0);
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
    
    foreach my $filt (@{$filters}) {
	
	if ($filt->isa("BioMart::Configuration::FilterList")) {
	    if ($filt->linkName) {
		if ($self->get('importable') ) {
		    BioMart::Exception::Configuration->throw("Recieved two importables, can only work with one\n");
		} 
		else {
		    $self->set('importable', $filt);
		}
	    } 
	    else {
		BioMart::Exception::Configuration->throw("Recieved invalid linkName ".
			     $filt->linkName."\n");
	    }
	} 
	else {
	    #must be a downstream or upstream valueFilter
	    unless ($filt->isa("BioMart::Configuration::ValueFilter")) {
		BioMart::Exception::Configuration->throw("Recieved unknown filter ".$filt->name." in GenomicMAlign Dataset!\n");
	    }

	    if ($self->get($filt->name)) {
		BioMart::Exception::Configuration->throw("Recieved two ".$filt->name." flanking filters in GenomicMAlign Dataset\n");
	    }

	    #could still be some strange ValueFilter that is not upstream or 
	    # downstream, but not likely. Will throw an exception if this is 
	    # the case
	    my $table = $filt->getTable;
	    my $row = $table->nextRow;
	    my $value = $row->[0];
	    if ($value) {
		$self->set($filt->name, $value);
	    }
	}
    }
    
    unless ($self->get('importable')) {
	BioMart::Exception::Configuration->throw("No Importable Recieved in GenomicMAlign\n");
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

    
    my $returnRow_indices = {};
    my $importable_indices = {};

    my $filts = $self->get('importable')->getAllFilters;

    #define where the importable fields are in rtable
    my $index = 0;
    foreach my $filt (@{$filts}) {
	
	#warn ("++++++++++++++++++   filt : ".$filt->name."  index : $index\n");
	$importable_indices->{$filt->name} = $index;
	$index++;
    }

    # define where fields needing to be merged into final returnRow are 
    # in rtable
    my $resultIndex = 0;
    while ($index < $numFields) {
	$returnRow_indices->{$index} = $resultIndex;
	$index++;
	$resultIndex++;
    }

    $self->set('importable_indices', $importable_indices);
    $self->set('returnRow_indices', $returnRow_indices);
    #$self->set('importable_names', $importable_names); ## added from GenomicAlign
}

sub _initializeReturnRow {
      my ($self, $curRow) = @_;

      # this method used to handle the structure attributes as FASTA headers
      # no longer necessary with new attribute merging code in DatasetI.pm

      # if hashed attributes exist from previous structure dataset then just 
      # return $curRow, otherwise return []
      # my $importable = $self->get('importable');
      # my $rtable = $importable->getTable();

      return $self->get('attribute_merge_required') ? $curRow : [];

      #my $returnRow = [];
      
      #foreach my $val (@{$curRow}) {
#	push @{$returnRow}, $val;
      #}
      #return $returnRow;
}

sub _processRow {
    my ($self, $atable, $curRow) = @_;
    
    # if this is the very first row for a new query, initialize the indices 
    # using its length as numFields
    unless ($self->get('importable_indices')) {
	if ($self->get('exhausted')) {
	    $atable->addRow(["No Sequence Returned"]);
	} 
	else {
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
	$calc_location->{"start"} = $this_location->{"start"}  
	      if ($this_location->{"start"} < $calc_location->{"start"});
	$calc_location->{"end"} = $this_location->{"end"}  
	      if ($this_location->{"end"} > $calc_location->{"end"});
    } 
    else {
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
	$location->{$expectedField} = 
	    ( exists( $importable_indices->{$expectedField}  ) ) ? 
	    $curRow->[ $importable_indices->{$expectedField} ] : undef;
    }
    
    return $location;
}

sub _modFlanks {
    my ($self, $location, $shift) = @_;
    
    $location->{start} || return $location; # Sanity check
    $location->{end}   || return $location; # Sanity check

    if ($shift) {
	#shift for flanks only - if user accidentally chooses both flanks, 
	# assume upstream as the original martview
	if ($self->get('upstream_flank')) {
	    if ($location->{"strand"} < 0) {
		$location->{"start"} = $location->{"end"} + 1;
		$location->{"end"} += $self->get('upstream_flank');
	    } 
	    else {
		$location->{"end"} = $location->{"start"} - 1;
		$location->{"start"} -= $self->get('upstream_flank');
	    }
	} 
	elsif ($self->get('downstream_flank')) {
	    if ($location->{"strand"} < 0) {
		$location->{"end"} = $location->{"start"} - 1;
		$location->{"start"} -= $self->get('downstream_flank'); 
	    } 
	    else {
		$location->{"start"} = $location->{"end"} + 1;
		$location->{"end"} += $self->get('downstream_flank');
	    }
	} 
	else {
	    BioMart::Exception::Configuration->throw("Requests for flank sequence must be accompanied by an upstream_flank or downstream_flank request\n");
	}
    } 
    else {
	if ($location->{"strand"} < 0) {
	    $location->{"start"} -= $self->get('downstream_flank');
	    $location->{"end"} += $self->get('upstream_flank');
	} else {
	    $location->{"start"} -= $self->get('upstream_flank');
	    $location->{"end"} += $self->get('downstream_flank');
	}
    }

    #sometimes users request more flanking sequence than is avaiable
    $location->{"start"} = 1 if ($location->{"start"} < 1);
    return $location;
}

sub _processSequenceOriginal {
    my ($self, $locations) = @_;

    my $seq = '';
    my $temp_Seq = '';
    my $first_coding_exon_flag = 0;
	
    my $dna = $self->get('dna');

    foreach my $rank (sort { $a <=> $b } keys %{$locations}) {
	my $location = $locations->{$rank}; #warn "_pS_1  location: $location $rank $a $b\n";
	my $chr = $location->{'chr'};       #warn "_pS_2  chr: $chr\n";
	my $start = $location->{'start'};   #warn "_pS_3  start: $start\n";
	my $end = $location->{'end'};       #warn "_pS_4  end: $end\n";
	my $strand = exists( $location->{'strand'}) ? 
	    $location->{'strand'} : 1;      #warn "_pS_5  strand: $strand\n";
   	my $phase = $location->{'phase'} || 0;
	
	if ($first_coding_exon_flag == 0) {
	    if ($strand < 0) {
		    $temp_Seq = $self->_rc( $dna->
			  getSequence( $chr, $start, $end ) );
	        }
		else {
		    $temp_Seq = $dna->getSequence( $chr, $start, $end );
  		}
		if($temp_Seq) { # incase its not the first coding exon, 
		                # undef is returned by DNAAdapter
		    if ($phase > 0) { # copying Ns in beginning, exactly as the
			              # value of phase of first coding exon.
			$seq = 'N'x$phase;
		    }	
		    $seq .= $temp_Seq;
		    $first_coding_exon_flag = 1;
		}
		
        }
	else {
	    if ($strand < 0) {
		$seq .= $self->_rc( $dna->getSequence( $chr, $start, $end ) );
	    } 
	    else {
		$seq .= $dna->getSequence( $chr, $start, $end );
	    }
    	}
     }

    if (length($seq)) {
	return $seq;
    
    }
    return undef
}
######################################################
sub _processSequence {    ############################ RETURN ORIENTED SEQ

  my ($self, $location, $attribute_name, $count) = @_;
  #@species_attribute_name contains hsa et mmu
  #warn ("##GenomicMAlign  _processSequence  starting ".localtime(time)."\n");
  #warn  "##GenomicMAlign  _processSequence  attribute_name : $attribute_name\n";
  #warn   "##GenomicMAlign  _processSequence  count          : $count\n";
  my $i=1;

  my $seq    = ''; 
  my $dna    = $self->get('dna')->{$attribute_name};
  my $chr    = $location->{'chr'.$count};    #warn "##GenomicMAlign  _processSequence_2  chr: $chr\n";
  my $start  = $location->{'start'.$count};  #warn "##GenomicMAlign  _processSequence_3  start: $start\n";
  my $end    = $location->{'end'.$count};    #warn "##GenomicMAlign  _processSequence_4  end: $end\n";
  my $strand = $location->{'strand'.$count}; #warn "##GenomicMAlign  _processSequence_5  strand: $strand\n";
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
      $seq .= $self->_rc( $dna->getSequence( $chr, $start, $end ) );
  } else {
      $seq .= $dna->getSequence( $chr, $start, $end );
  }
  $i++;
  
  if (length($seq)) {
      return $seq;
  }
  return undef;
  
}
######################################################
sub _processSequenceNonOriented {    ################# RETURN NON-ORIENTED SEQ (like the PERL API)
  my ($self, $location, $attribute_name, $count) = @_;
  #@species_attribute_name contains hsa et mmu
  #warn ("##GenomicMAlign  _processSequence  starting ".localtime(time)."\n");
  #warn  "##GenomicMAlign  _processSequence  attribute_name : $attribute_name\n";
  #warn   "##GenomicMAlign  _processSequence  count          : $count\n";
  my $i=1;

  my $seq    = ''; 
  my $dna    = $self->get('dna')->{$attribute_name};
  my $chr    = $location->{'chr'.$count};    #warn "##GenomicMAlign  _processSequence_2  chr: $chr\n";
  my $start  = $location->{'start'.$count};  #warn "##GenomicMAlign  _processSequence_3  start: $start\n";
  my $end    = $location->{'end'.$count};    #warn "##GenomicMAlign  _processSequence_4  end: $end\n";
  my $strand = $location->{'strand'.$count}; #warn "##GenomicMAlign  _processSequence_5  strand: $strand\n";
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
  
  
 # if ($strand < 0) {
 #     $seq .= $self->_rc( $dna->getSequence( $chr, $start, $end ) );
 # } else {
  $seq .= $dna->getSequence( $chr, $start, $end );
 # }
  $i++;
  
  if (length($seq)) {
      return $seq;
  }
  return undef;
  
}

#-------------------------------------------
sub _addRow {
    my ($self, $atable, $outRow) = @_;
    #my ($self, $atable, $outRow, $sequence) = @_;
    #push @{$outRow}, $sequence; ## removed this as it was adding an empty sequence at the end of mine
    
    $atable->addRow($outRow);
    $self->_incrementBatch;
}
sub _addRow_Original {
    my ($self, $atable, $outRow, $sequence) = @_;
    push @{$outRow}, $sequence; 
    
    $atable->addRow($outRow);
    $self->_incrementBatch;
}
#interface methods

sub _getConfigurationTree {
    my ($self,$interface,$dsCounter)=@_;;

    return $self->getParam('configurator')->getConfigurationTree(
       $self->virtualSchema, 
       $self->name,
       $interface,
       $dsCounter);
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

    my $importable = $self->get('importable');
    my $rtable = $importable->getTable();

    my $attribute_count = @{$query->getAllAttributes};
    if ($rtable->hashedResults || $attribute_count > 1){
	$self->set('attribute_merge_required','1');
    }

    my $has_rows = $rtable->hasMoreRows;
    while ($has_rows && $self->_continueWithBatch($batch_size, $rtable)) {
	$self->_processRow( $atable, $rtable->nextRow);
    }
    # the last and final call to GenomicSequence after the call which 
    # exhausts the importable, will result in the last sequence being 
    # processed and added to the resultTable.
    # the next call after this returns undef.
    unless ($has_rows) {
	$self->_setExhausted(1);
	$self->_processRow($atable);
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

sub _codingCdnaPeptideSequences {
    my ($self, $atable, $curRow) = @_;
    
    # Determine this and last primary keys
    my $importable_indices = $self->get('importable_indices');
    # Get the primary sequence ID from this row. Use DUMMY if missing
    my $pkey     = $curRow ? 
	($curRow->[$importable_indices->{"pkey"}] || 'DUMMY') : undef;
    my $lastPkey = $self->get('lastPkey') || $pkey;
    
    my $locations = $self->get('locations');
    
    my $outRow = $self->get('outRow');
    
    if( ( ! defined $pkey ) or ( $pkey ne $lastPkey ) ){
	# Start of new row, or end of results; Dump the current sequence
  
	my $sequence;
	if( grep{ $locations->{$_}->{"start"} } keys %$locations ) {
	    $sequence = $self->_processSequence($locations);
	    $sequence = $self->_translate($sequence) 
		if ($self->get('translate'));
	    $self->_editSequence(\$sequence);
	}
    
	if ($sequence) { 
	    $self->_addRow($atable, $outRow, $sequence);
	} 
	else {      
	    $self->_addRow($atable, $outRow, "Sequence unavailable");
	}
	$locations = {};
	$outRow = undef;
    } # End sequence dumping

    if ($curRow) {
	# Update the location corresponding to this row
	my $rank = $curRow->[ $importable_indices->{"rank"} ];

	# Requesting for phase info as well, to fix the bug of additional 
	# Ns in the beginning - syed
	my $location = $self->_getLocationFrom($curRow, "chr", "start", "end", 
					       "strand", "phase"); 
    
	$location = $self->_modFlanks($location, 0);
	$locations->{$rank} = $location if ($location->{"start"});
    } 
    
    $outRow ||= $self->_initializeReturnRow($curRow);
    $self->set('locations', $locations);
    $self->set('lastPkey', $pkey);
    $self->set('outRow', $outRow);
}

sub _exonIntronFlankSequences {
    my ($self, $atable, $curRow) = @_;
    
    my $rank = 1;
    
    # Determine this and last primary keys
    my $importable_indices = $self->get('importable_indices');
    # Get the primary sequence ID from this row. Use DUMMY if missing
    my $pkey     = $curRow ? 
	($curRow->[$importable_indices->{"pkey"}] || 'DUMMY') : undef;
    my $lastPkey = $self->get('lastPkey') || $pkey;

    my $outRow = $self->get('outRow');

    if( ( ! defined $pkey ) or ( $pkey ne $lastPkey ) ){
	# Start of new row, or end of results; Dump the current sequence
	my $shift = ($self->get('seq_name') =~ m/flank/);
	my $location = $self->_modFlanks( $self->get('calc_location'), 
					  $shift );
	$self->set('calc_location', undef); # Reset location cache

	my $sequence;
	if ($location->{"start"}) {
	    my $locations = { $rank => $location };
	    $sequence = $self->_processSequence($locations);
	    $self->_editSequence(\$sequence);
	}

	if ($sequence) { 
	    $self->_addRow($atable, $outRow, $sequence);
	} 
	else {      
	    $self->_addRow($atable, $outRow, "Sequence unavailable");
	}
	$outRow = undef;
    } # End sequence dumping

    if ($curRow) {
	# Update the location corresponding to this row
	my $location = $self->_getLocationFrom($curRow, "chr", "start", 
					       "end", "strand");
	$self->_calcSeqOverLocations( $location );
    }

    $outRow ||= $self->_initializeReturnRow($curRow);
    $self->set('lastPkey', $pkey);
    $self->set('outRow', $outRow);
}

sub _exonSequences {
    my ($self, $atable, $curRow) = @_;

    $curRow || return; # Process row-by-row; can discard last (empty) call
    
    return if ($self->_ignoreRow($curRow)); #ignore duplicate exons 
    my $rank = 1;

    my $locations = {};
    $locations->{$rank} = $self->_modFlanks( $self->_getLocationFrom($curRow, 
	   "chr", "start", "end", "strand"), 0 );

    my $sequence;
    if ($locations->{1}->{"start"}) {
	$sequence = $self->_processSequence($locations);
	$self->_editSequence(\$sequence);
    }
    if ($sequence) {
	$self->_addRow($atable, $self->_initializeReturnRow($curRow), 
		       $sequence);
    } 
    else {      
	$self->_addRow($atable, $self->_initializeReturnRow($curRow), 
		       "Sequence unavailable");
    }
  
    if ($self->get('ignore')) {
	#will only be true for gene_exon
	my $ignore = $self->get('ignore');
	my $ignore_row = $self->get('ignore_row');
	my $ref = $self->_getLocationFrom($curRow, $ignore_row);
	$ignore->{ $ref->{ $ignore_row  } } = 1; #skip duplicate pkeys
	$self->set('ignore', $ignore);
    }
    #else there will be no last entry
}

sub _rawSequencesOriginal {
    my ($self, $atable, $curRow) = @_;
    my $rank = 1;
    
    if ($curRow) {
	my $importable_indices = $self->get('importable_indices');
	my $locations = {};
	my $location = $self->_getLocationFrom($curRow, "chr", "start", "end");
	
	$location->{"strand"} = ( exists( $importable_indices->{"strand"} ) ) ?
	    $curRow->[  $importable_indices->{"strand"} ] : 1;
	
	$locations->{$rank} = $location if ($location->{"start"});
	my $sequence = $self->_processSequence($locations);
	$self->_editSequence(\$sequence);
	if ($sequence) {
	    $self->_addRow($atable, $self->_initializeReturnRow($curRow), $sequence);
	}
    }
}

sub _rawSequences {
    my ($self, $atable, $curRow) = @_;
    my $rank             = 1;
    my $overall_count    = 0;
    my $local_count      = 0;
    my $species_numbers  = 0;
    my $count            = 1;
    my $n = 0;
    my $interface = "default";
   
if ($curRow) {

    #my @importable_names = $self->get('importable_indices'); ## was importable_names GenomicAlign
    my @importable_names ;
    #my $dna_params = $self->getConfigurationTree()->optionalParameters; ## was in GenomicAlign
    my $dna_params = $self->getConfigurationTree($interface)->
	optionalParameters;  ## bb2 - hacked $interface
    
    my @species_dna_params = split(/\;/, $dna_params);
    my @species_attribute_name;
    
    foreach my $sdp (@species_dna_params) {
	my ($attribute_name) = split(/\,/,$sdp);
	push @species_attribute_name, $attribute_name; # @species_attribute_ = (hsap_seq ptro_seq)
	#warn ("##GenomicMAlign  1_rawSequences  attribute_name: $attribute_name\n");
    }
    my $initRow =  $self->_initializeReturnRow($curRow);
    
    # get the filters from compara_genomic_seq (chr1,start1,end1,strand1,chr2,start2,...)
    # push them into @importable_names for further processing
    my $filters = $self->get('importable')->getAllFilters;
    foreach my $filter (@{$filters}) {
	push (@importable_names, $filter->name) ; # here $filter->name = chr1, ...
    }
    
    while (my $attribute_name = shift @species_attribute_name){
	
	my ($name, $start, $end, $strand);
	foreach my $var (\$name, \$start, \$end, \$strand) {
	    $$var = shift @importable_names;
	    last if (defined $strand);
	    # shift @importable_names;
	}
	#warn ("##GenomicMAlign 43_rawSequence $attribute_name $name, $start, $end, $strand \n");
	
	## my $location = $self->_getLocationFrom($curRow, "chr2", "start2","end2", "strand2");
	my $location = $self->_getLocationFrom($curRow, ($name, $start, $end, $strand)); 
	
	#warn "$attribute_name $name, $start, $end, $strand\n";
	my $sequence = $self->_processSequence($location, $attribute_name, $count);
	
	if ($sequence) {
	    #warn "## _rawSequences ENTER PUSH sequence \n\n";
	    push @{$initRow}, $sequence;
	     
	}
	## IMPORTANT remove the length as the coordinate aer as folow
	## name, start, end, strand, length
	# shift @importable_names ;

	$count++;
    }
    my $size = @{$initRow}; #warn "## size of initrow $size \n\n";
    $self->_addRow($atable, $initRow);
}
}

sub _nonOrientedRawSequences {
    my ($self, $atable, $curRow) = @_;
    my $rank             = 1;
    my $overall_count    = 0;
    my $local_count      = 0;
    my $species_numbers  = 0;
    my $count            = 1;
    my $n = 0;
    my $interface = "default";
   
if ($curRow) {

    #my @importable_names = $self->get('importable_indices'); ## was importable_names GenomicAlign
    my @importable_names ;
    #my $dna_params = $self->getConfigurationTree()->optionalParameters; ## was in GenomicAlign
    my $dna_params = $self->getConfigurationTree($interface)->
	optionalParameters;  ## bb2 - hacked $interface
    
    my @species_dna_params = split(/\;/, $dna_params);
    my @species_attribute_name;
    
    foreach my $sdp (@species_dna_params) {
	my ($attribute_name) = split(/\,/,$sdp);
	push @species_attribute_name, $attribute_name; # @species_attribute_ = (hsap_seq ptro_seq)
	#warn ("##GenomicMAlign  1_rawSequences  attribute_name: $attribute_name\n");
    }
    my $initRow =  $self->_initializeReturnRow($curRow);
    
    # get the filters from compara_genomic_seq (chr1,start1,end1,strand1,chr2,start2,...)
    # push them into @importable_names for further processing
    my $filters = $self->get('importable')->getAllFilters;
    foreach my $filter (@{$filters}) {
	push (@importable_names, $filter->name) ; # here $filter->name = chr1, ...
    }
    
    while (my $attribute_name = shift @species_attribute_name){
	
	my ($name, $start, $end, $strand);
	foreach my $var (\$name, \$start, \$end, \$strand) {
	    $$var = shift @importable_names;
	    last if (defined $strand);
	    # shift @importable_names;
	}
	#warn ("##GenomicMAlign 43_rawSequence $attribute_name $name, $start, $end, $strand \n");
	
	## my $location = $self->_getLocationFrom($curRow, "chr2", "start2","end2", "strand2");
	my $location = $self->_getLocationFrom($curRow, ($name, $start, $end, $strand)); 
	
	#warn "$attribute_name $name, $start, $end, $strand\n";
	my $sequence = $self->_processSequenceNonOriented($location, $attribute_name, $count);
	
	if ($sequence) {
	    #warn "## _rawSequences ENTER PUSH sequence \n\n";
	    push @{$initRow}, $sequence;
	     
	}
	## IMPORTANT remove the length as the coordinate aer as folow
	## name, start, end, strand, length
	# shift @importable_names ;

	$count++;
    }
    my $size = @{$initRow}; #warn "## size of initrow $size \n\n";
    $self->_addRow($atable, $initRow);
}
}


1;
