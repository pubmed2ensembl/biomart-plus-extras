#$Id: GenomicSequence.pm,v 1.21.2.2 2009-11-06 00:44:03 syed Exp $
#
# BioMart module for BioMart::Dataset::GenomicSequence
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Dataset::GenomicSequence

=head1 SYNOPSIS

A hidden Dataset containing sequence attributes that can be imported to other
visible Datasets which are compatible with its required data input, based
on the presence of one or more importable-exportable relationships.

=head1 DESCRIPTION

Dataset providing Genomic Sequence attributes, which can be imported into
other Datasets.  GenomicSequence is itself not a visible Dataset.

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Darin London, Damian Smedley

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


package BioMart::Dataset::GenomicSequence;
# implements Dataset interface

use strict;
use warnings;
use base qw(BioMart::DatasetI);
use Log::Log4perl;
use Data::Dumper;

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

    $self->attr('recipe', undef); #this will hold a subRef
    $self->attr('ignore', undef);
    $self->attr('ignore_row', undef);
    $self->attr('seq_edits', undef); 
    $self->attr('codon_table_id', undef); #codon table defaults to undef
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

	# last set of structure rows in a batch are not processed as they may be incomplete
	# set of say all exons, so store them somewhere for next time around and also store the 
	# corresponding results for merging

	$self->attr('rowsFromLastBatch', undef);
	
	# these help us solve the problem when gene coding and flank sequnces are requested, and 
	# for more than one transcripts coming in different batches, it repeats the same sequence
	# with different header if transcript atts are requested.
	# $self->attr('rowsFromLastBatch', undef), works for this case too.
	$self->attr('seqStorageHash', undef);
	$self->attr('onHoldSeqsKeys', undef);
	
	#-- new GS development ---
	$self->attr('exon_idHash', undef);
	#-------------------------

	
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
	
	# important to clear if two seq_edit sequences come one after another
	$self->set('seq_edits', "");
}

sub _initializeDNAAdaptor {
    my ($self,$interface) = @_;
    
    my $dna_params = $self->getConfigurationTree($interface)->
	optionalParameters;
    unless ($dna_params) {
	BioMart::Exception::Configuration->throw("GenomicSequence Dataset requires optional_parameters to be set in the DatasetConfig\n");
    }

	my ($dnatablename, $chunk_name_fieldname, $chunk_start_fieldname, 
	    $seqfieldname,$chunk_size) = split /\,/, $dna_params;
	my $dna = BioMart::Dataset::GenomicSequence::DNAAdaptor->new(
		'seq_name' => $self->name,
		'dna_tablename' => $dnatablename,
		'seq_fieldname' => $seqfieldname,
		'chunk_name_fieldname' => $chunk_name_fieldname,
		'chunk_start_fieldname' => $chunk_start_fieldname,
		'chunk_size' => $chunk_size,
		'configurator' => $self->getParam('configurator'),
								     );

	unless ($dna) {
	    BioMart::Exception::Configuration->throw("Couldnt connect to DNAAdaptor\n");
	}

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
    $self->set('translate', ($seq_name =~ m/peptide$/));

    my $ignore = IGNORE;
    if ($seq_name =~ m/(coding|cdna|peptide)$/) {
	# this is not actually going to ignore anything, but is
	# simply used to determine translation table for each gene
	# without creating a second instance variable
	$self->set('ignore_row', "type");
	$self->set('recipe', '_codingCdnaPeptideSequences');
    } 
    elsif ($seq_name =~ m/(transcript_exon_intron|transcript_flank|coding_transcript_flank)$/) {
	$self->set('recipe', '_transcript_exonIntronFlankSequences');
    } 
	elsif ($seq_name =~ m/(gene_exon_intron|gene_flank|coding_gene_flank)$/) {
	$self->set('recipe', '_gene_exonIntronFlankSequences');
    } 
    elsif ($seq_name =~ m/raw/){
	$self->set('recipe', '_rawSequences');
    } 
    elsif ($seq_name =~ m/(gene_exon|transcript_exon|transcript_intron)$/) {
	# set the system to ignore rows with duplicate pkeys
	# for gene_exon
	$self->set('ignore', $ignore->{$1}); #undef for transcript_exon
	$self->set('ignore_row', "pkey");
	$self->set('recipe', '_exonSequences');
    } 
    elsif ($seq_name =~ m/utr$/ or
           $seq_name =~ m/intergenic$/) {
	$self->set('recipe', '_utrSequences');
    } 
    elsif ($seq_name =~ m/snp$/) {
	$self->set('recipe', '_snpSequences');
    } 
    else {
	BioMart::Exception::Configuration->throw("Unsupported sequence name $seq_name recieved by GenomicSequence\n");
    }
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

	$self->set('rowsFromLastBatch', undef);
	$self->set('seqStorageHash', undef);
	$self->set('onHoldSeqsKeys', undef);
	
	#-- new GS development ---
	$self->set('exon_idHash', undef);
	#-------------------------

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
		BioMart::Exception::Configuration->throw("Recieved unknown filter ".$filt->name." in GenomicSequence Dataset!\n");
	    }

	    if ($self->get($filt->name)) {
		BioMart::Exception::Configuration->throw("Recieved two ".$filt->name." flanking filters in GenomicSequence Dataset\n");
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
	BioMart::Exception::Configuration->throw("No Importable Recieved in GenomicSequence\n");
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
		$location->{$expectedField} = ( exists( $importable_indices->{$expectedField}  ) ) ? 
			$curRow->[ $importable_indices->{$expectedField} ] : undef;
	}

	# (New-1) hack for MartBuilder built marts. different set of exportables importables
	# need to calculate start/end w.r.t old system
	# here we tamper start and end values of $location so they correspond to 
	# the old system whereby they meant coding_start/end or 3/5utr_start/end
	# this is executed only for coding_gene_flank, coding_transcript_flank
	# 5utr, 3utr, coding and peptide sequence types.
	my $newCalculationsRequired = 0;
	foreach my $key (keys %$importable_indices) {
		$newCalculationsRequired = 1 if ($key eq 'coding_start_offset');
	}
	
	if($newCalculationsRequired) {
		my $pkey = $curRow->[$importable_indices->{'pkey'}];
		my $rank = $curRow->[$importable_indices->{'exon_id'}];
		my $start_rank = $curRow->[$importable_indices->{'start_exon_id'}];
		my $end_rank = $curRow->[$importable_indices->{'end_exon_id'}];
		my $exon_start = $curRow->[$importable_indices->{'start'}];
		my $exon_end = $curRow->[$importable_indices->{'end'}];
		my $strand = $curRow->[$importable_indices->{'strand'}];
		my $coding_start_offset = $curRow->[$importable_indices->{'coding_start_offset'}];
		my $coding_end_offset = $curRow->[$importable_indices->{'coding_end_offset'}];
		my ($new_start, $new_end);
		#foreach (%$location) {
		#	print "<br/>KEY=$_ : VALUE=", $location->{$_};
		#}
		#exit;
		my $exon_idHash = $self->get('exon_idHash');
		if ($start_rank && $end_rank) {
			if ($self->get('seq_name') eq '5utr') {
				if ($rank == $start_rank) {
					if ($strand == 1) {
						$new_start = $exon_start;
						$new_end = $exon_start + $coding_start_offset - 2;
					}
					if ($strand == -1) {
						$new_start = $exon_end - $coding_start_offset + 2;
						$new_end = $exon_end;
					}
					# encountered coding START exon. storing as transcriptId.start_exonId to make it unique
					$self->_setCodingExonFlag($pkey.$start_rank, 1);
				}
				else {
					if ($exon_idHash->{$pkey.$start_rank} && $exon_idHash->{$pkey.$start_rank} == 1) {
						$new_start = undef;
						$new_end = undef;
					}
					else {
						$new_start = $exon_start;
						$new_end = $exon_end;
					}
				}
			}
			elsif ($self->get('seq_name') eq '3utr') {
				if ($rank == $end_rank) {
					if ($strand == 1) {
						$new_start = $exon_start + $coding_end_offset;
						$new_end = $exon_end;
					}
					if ($strand == -1) {
						$new_start = $exon_start;
						$new_end = $exon_end - $coding_end_offset;
					}
					# encountered coding END exon. storing as transcriptId.end_exonId to make it unique
					$self->_setCodingExonFlag($pkey.$end_rank, 1);
				}
				else {
					if ($exon_idHash->{$pkey.$end_rank} && $exon_idHash->{$pkey.$end_rank} == 1) {
						$new_start = $exon_start;
						$new_end = $exon_end;
					}
					else {
						$new_start = undef;
						$new_end = undef;
					}
				}
			}
			if ($self->get('seq_name') =~ m/^coding.*?|peptide/) {
			# this includes sequence types : coding_gene_flank, coding_transcript_flank, coding, peptide
				if ($rank == $start_rank && $rank == $end_rank) {
					# coding start and finish on the same exon
					if ($strand == 1) {
						$new_start = $exon_start + $coding_start_offset - 1;
						$new_end = $exon_start + $coding_end_offset - 1;
					}
					if ($strand == -1) {
						$new_start = $exon_end - $coding_end_offset + 1;
						$new_end = $exon_end - $coding_start_offset + 1;
					}
				}
				elsif ($rank == $start_rank) {
					if ($strand == 1) {
						$new_start = $exon_start + $coding_start_offset - 1;
						$new_end = $exon_end;
					}
					if ($strand == -1) {
						$new_start = $exon_start;
						$new_end = $exon_end - $coding_start_offset + 1;
					}
					# encountered coding START exon. storing as transcriptId.start_exonId to make it unique
					$self->_setCodingExonFlag($pkey.$start_rank, 1);
				}
				elsif ($rank == $end_rank) {
					if ($strand == 1) {
						$new_start = $exon_start;
						$new_end = $exon_start + $coding_end_offset - 1;
					}
					if ($strand == -1) {
						$new_start = $exon_end - $coding_end_offset + 1;
						$new_end = $exon_end;
					}
					# encountered coding END exon. clear ranscriptId.start_exonId stored earlier
					$self->_setCodingExonFlag($pkey.$start_rank, 0);
				}
				else {
					if ($exon_idHash->{$pkey.$start_rank} && $exon_idHash->{$pkey.$start_rank} == 1) {
						$new_start = $exon_start;
						$new_end = $exon_end;
					}
					else {
						$new_start = undef;
						$new_end = undef;
					}
				}
			}
			# sanity check
			if ($new_start && $new_end && ($new_start > $new_end)) {
				$new_start = undef;
				$new_end = undef;
			}
			# update the coordinates to be returned by this function - now similar to old coordinates
			$location->{'start'} = $new_start;
			$location->{'end'} = $new_end;
		}
		else { # no coding start/end set the vals to NULL
			$location->{'start'} = undef;
			$location->{'end'} = undef;
		}		
	}

	return $location;
}

sub _setCodingExonFlag {
	my ($self, $key, $val) = @_;
	# the key value is pkey.start_exonId OR pkey.end_exonId
	# doesnt matter if its start or end exon id as the corresponding
	# value is always the same for each exon.
	my $exon_idHash = $self->get('exon_idHash');
	$exon_idHash->{$key} = $val;
	$self->set('exon_idHash', $exon_idHash);
}

sub _modFlanks {
    my ($self, $location, $shift, $flank) = @_;
    
    $location->{start} || return $location; # Sanity check
    $location->{end}   || return $location; # Sanity check
      
    if ($shift == 1) 
    {
	# shift for flanks only - if user accidentally chooses both flanks, 
	# assume upstream as the original martview

	if ($self->get('upstream_flank') && $self->get('downstream_flank')){
	    BioMart::Exception::Usage->throw("For this sequence option choose upstream OR downstream gene flanking sequence, NOT both, as makes no sense to simply concatenate them together.\n");
	}


	if ($self->get('upstream_flank')) 
	{


	    if ($location->{"strand"} < 0)  {


		$location->{"start"} = $location->{"end"} + 1;
		$location->{"end"} += $self->get('upstream_flank');
	    } 
	    else 
	    {
		$location->{"end"} = $location->{"start"} - 1;
		$location->{"start"} -= $self->get('upstream_flank');
	    }
	} 
	elsif ($self->get('downstream_flank')) 
	{
	    if ($location->{"strand"} < 0) 
	    {
		$location->{"end"} = $location->{"start"} - 1;
		$location->{"start"} -= $self->get('downstream_flank'); 
	    } 
	    else 
	    {
		$location->{"start"} = $location->{"end"} + 1;
		$location->{"end"} += $self->get('downstream_flank');
	    }
	} 
	else 
	{
	    BioMart::Exception::Usage->throw("Requests for flank sequence must be accompanied by an upstream_flank or downstream_flank request\n");
	  }
    } 
    elsif ($shift == 2) #-- this is specific for: flanks + coding|cdna  [ben]
    {
	if ($self->get('upstream_flank') && ($flank eq "up")) {
	    #-- the flank variable is used here, in case the user ask for both upstream 
	    #-- and downstream flank. With $flank you are sure, you don't enter in 
	    #-- the upstream loop when you should get in the downstream loop. 
	    #-- or you don't enter twice the upstream loop when you ask for both up+down
	    #-- or you get a single exon gene/transcript
	    if ($location->{"strand"} < 0) 
	    {
		$location->{"end"} += $self->get('upstream_flank');
	    } 
	    else 
	    {
		$location->{"start"} -= $self->get('upstream_flank');
	    }
	}
	elsif ($self->get('downstream_flank') && ($flank eq "down")) {
	    if ($location->{"strand"} < 0) 
	    {
		$location->{"start"} -= $self->get('downstream_flank');
	    } 
	    else 
	    {
		$location->{"end"} += $self->get('downstream_flank');
	    }
	}
    }
    else #-- if shift = 0
    {
	if ($location->{"strand"} < 0) 
	{
	    $location->{"start"} -= $self->get('downstream_flank');
	    $location->{"end"} += $self->get('upstream_flank');
	} 
	else 
	{
	    $location->{"start"} -= $self->get('upstream_flank');
	    $location->{"end"} += $self->get('downstream_flank');
	}
    }
    
    #sometimes users request more flanking sequence than is avaiable
    $location->{"start"} = 1 if ($location->{"start"} < 1);
    return $location;
}

sub _processSequence {
    my ($self, $locations) = @_;
    my $seq = '';
    my $temp_Seq = '';
    my $first_coding_exon_flag = 0;
	
    my $dna = $self->get('dna');

    foreach my $rank (sort { $a <=> $b } keys %{$locations}) {
	my $location = $locations->{$rank};
	my $chr = $location->{'chr'};
	my $start = $location->{'start'};
	my $end = $location->{'end'};
	my $strand = exists( $location->{'strand'}) ? 
	    $location->{'strand'} : 1;
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

sub _addRow {
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
        
        my $logger=Log::Log4perl->get_logger(__PACKAGE__);
        $logger->info("QUERY XML:  $xml");

	
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
    
   		
    	my %avoidDuplication = ();
		NEXTROW: while ($has_rows && $self->_continueWithBatch($batch_size, $rtable)) {
		my $curRow = $rtable->nextRow;
		my $rowAsString = $self->toString($curRow); # avoid using "@A" eq "@B" type comparison, it floods error log
		next NEXTROW if (!$rowAsString || exists $avoidDuplication{$rowAsString} ) ; # no point retrieving sequence for same coordinates
		$avoidDuplication{$rowAsString} = '';
		$self->_processRow( $atable, $curRow);
		
		#print "<BR> BAtch: $batch_size [ ", $self->_continueWithBatch($batch_size, $rtable), " ] [ ", $self->get('batchIndex'), " ]";
		
	}
	
    # the last and final call to GenomicSequence, after the call which 
    # exhausts the importable, will result in the last sequence being 
    # processed and added to the resultTable.
    # the next call after this returns undef.
    unless ($has_rows) {
	$self->_setExhausted(1);
	$self->_processRow($atable);
		## additional logic to send all ORPHAN sequences at the end where the total number
		## of transcripts encountered is not equal transcript_count. that may happen when you request a
		## GENE type sequence with a filter restricting some transcripts. consequently you donot see all the
		## transcripts and the sequence should not be kept by GS, so lets release them all at the end
		my $storageHash = $self->get('seqStorageHash');
		if ($storageHash)
		{
			foreach my $fkey (%$storageHash)
			{
				my $sequence = $storageHash->{$fkey}->{'seq'};
				my $outRow = $storageHash->{$fkey}->{'outRow'};
				$self->_addRow($atable, $outRow, $sequence);				
			}
		}
	
    }
    $importable->setTable($rtable);
    $self->set('importable', $importable);

  		$self->get('dna')->close;

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
	#-- NOTE:
	#-- upstream and downstream sequences are added only once, and 
	#-- not for every exons, as it used to be before. So _modFlank is
	#-- ran only at the very end, and once (once if upsream, once if 
	#-- downstream) to modify $locations. [ben]

	#-- This is very important especially if you ask for both up AND downstream flanks
	#-- so you are sure that you enter only once in each _modFlank loop, and not twice 
	#-- in the upstream as it was before. 
	my ($up, $down);
	if ($self->get('upstream_flank')){$up = "up"}
	if ($self->get('downstream_flank')){$down = "down"}
	
	#-- get exons rank info 
	my @ranks = sort { $a <=> $b } keys %{$locations};
	my $array_size = scalar @ranks;
	my ($firstExon,$lastExon);
	
	if ($array_size == 1){
	    #-- if the gene/transcript has 1 exon only
	    #-- so you can get a downstream flank even if rank = 1
	    $firstExon = shift @ranks; # firstExon and lastExon are both set to 1
	    $lastExon = $firstExon ;
	    
	}else {
	    #-- if the gene/transcript has more than 1 exon
	    $firstExon = shift @ranks; #get first exon
	    $lastExon = pop @ranks;    #get last exon
    }
	
	#-- then run _modflank for the first and/or last exons
	if ($self->get('upstream_flank'))
	{
	    my $location = $locations->{$firstExon};
	    $location = $self->_modFlanks($location, 2, $up);
	    $locations->{$firstExon} = $location if ($location->{"start"});	
	} 
	if ($self->get('downstream_flank')) 
	{
	    my $location = $locations->{$lastExon}; 
	    $location = $self->_modFlanks($location, 2, $down);
	    $locations->{$lastExon} = $location if ($location->{"start"});
	}
	
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
	# Ns in the beginning - [syed]
	my $location = $self->_getLocationFrom($curRow, "chr", "start", "end", 
					       "strand", "phase", "codon_table_id", "seq_edits"); 
	
	$self->set('codon_table_id',$location->{"codon_table_id"});	
	# $self->set('seq_edits',$location->{"seq_edits"});	
	# (New-2) hack for MartBuilder built marts. different set of exportables importables
	# need to store seq_edits as 12,12,U;14,14:U which is old formart
	# new exportable passes it in ensembl core format 12 12 U per row
	
	$self->set_seq_edits($location->{"seq_edits"});
	
	
	
	# $location = $self->_modFlanks($location, 0);
	#-- This was soo wrong - it added a flank (upstream and/or downstream) 
	#-- for every exons, instead of once, at the 5' or 3' end  - [ben]
	
	$locations->{$rank} = $location if ($location->{"start"} && $rank);
    } 
    $outRow ||= $self->_initializeReturnRow($curRow);
    $self->set('locations', $locations);
    $self->set('lastPkey', $pkey);
    $self->set('outRow', $outRow);
}
sub set_seq_edits
{
    my ($self, $seq_edits) = @_;
    if ($seq_edits) {
    	my $temp_str;
    	# old format 12,12,U;14,14,M
    	if ($seq_edits =~ m/\,/) {
    		$temp_str = $seq_edits;
    	}
    	else { # new format 12 12 U
    		$temp_str = $self->get('seq_edits');
    		$seq_edits =~ s/\s/\,/g;
    		if ($temp_str) {
    			$temp_str = $temp_str.';'.$seq_edits if($temp_str !~ m/$seq_edits/);
    		}
    		else {
    			$temp_str = $seq_edits;
    		}
    	}
    	$self->set('seq_edits', $temp_str);
    }
    else {
    	$self->set('seq_edits', "");
    }
}

sub _transcript_exonIntronFlankSequences {
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

sub _gene_exonIntronFlankSequences {
    my ($self, $atable, $curRow) = @_;
    
	
    my $rank = 1;
    # Determine this and last primary keys
    my $importable_indices = $self->get('importable_indices');
    # Get the primary sequence ID from this row. Use DUMMY if missing
    my $pkey     = $curRow ? 
	($curRow->[$importable_indices->{"pkey"}] || 'DUMMY') : undef;
    my $lastPkey = $self->get('lastPkey') || $pkey;

    my $outRow = $self->get('outRow');

    if( ( ! defined $pkey ) or ( $pkey ne $lastPkey ) )
    {
		# Start of new row, or end of results; Dump the current sequence
		my $shift = ($self->get('seq_name') =~ m/flank/);

		my $location = $self->_modFlanks( $self->get('calc_location'), $shift );
		$self->set('calc_location', undef); # Reset location cache

		my $sequence;
		if ($location->{"start"}) {
		    my $locations = { $rank => $location };
		    $sequence = $self->_processSequence($locations);
			$self->_editSequence(\$sequence);
		}

		my $storageHash = $self->get('seqStorageHash');


		# This IF statement is just there to keep those in sink who have Ensembl 42 or earlier
		# and this new code. They should not expect transcript_pkey and transcript_count from XML
		if (exists $storageHash->{$lastPkey})
		{
			# this is well tricky. lastDS is 2 when its a two DS query adn its the second DS's GS.
			# we do not wait for all transcripts to arrive because in a two DS query HUMAN/MSD, there is a chance
			# few transcripts are absent for not having any PDBids. So we should not stop such sequences. 
			# The sequences are meant to stop till all the transcripts are seen when its a single DS query
			if (($storageHash->{$lastPkey}->{'transcriptCount'} >= $storageHash->{$lastPkey}->{'totalTranscripts'}) 
				|| $self->lastDS() == 2)
			{
				# use the old sequence from previous batch, the new one in some case (f_gene,c_f_gene,u_gene is different)
				$sequence = $storageHash->{$lastPkey}->{'seq'} if ($storageHash->{$lastPkey}->{'seq'});
				if ($sequence)
				{ 
				    $self->_addRow($atable, $outRow, $sequence);
				}
				else 
				{
				    $self->_addRow($atable, $outRow, "Sequence unavailable");
				}
				delete $storageHash->{$lastPkey}; # over with this Gene.			
			}
			else
			{
				# sequences gets an update, as and when a transcript of a gene
				# arrives in a separate batch. In principle this should always be the same

				#my $onHoldkeys = $self->get('onHoldSeqsKeys');
					
				$storageHash->{$lastPkey}->{'seq'} = $sequence;
				$storageHash->{$lastPkey}->{'outRow'} = $outRow;

				#$onHoldkeys->{$lastPkey} = "";
				#$self->set('onHoldSeqsKeys', $onHoldkeys);
				$self->set('seqStorageHash', $storageHash);

			    $self->_incrementBatch;
			}
		}
		else 
		{
			if ($sequence)
			{ 
			    $self->_addRow($atable, $outRow, $sequence);
			}
			else 
			{
			    $self->_addRow($atable, $outRow, "Sequence unavailable");
			}
		}
		$outRow = undef;
    } # End sequence dumping

    if ($curRow) 
    {
		# Update the location corresponding to this row
		my $location = $self->_getLocationFrom($curRow,"pkey","transcript_pkey","chr", "start", "end", "strand", "transcript_count");
		$self->_calcSeqOverLocations( $location );
		
		
		# This IF statement is just there to keep those in sink who have Ensembl 42 or earlier
		# and this new code. They should not expect transcript_pkey and transcript_count from XML
		if ($location->{'transcript_pkey'})
		{
			my $storageHash = $self->get('seqStorageHash');
			my $prkey = $location->{'pkey'};
			my $transcript_key = $location->{'transcript_pkey'};
			#print "<BR>TRANS KEY: $transcript_key", " == ", $location->{'transcript_count'};
			$storageHash->{$prkey}->{'totalTranscripts'} = $location->{'transcript_count'} || 1; # there are NULL vals in DB
			if(exists $storageHash->{$prkey}->{'transcriptKeys'}) {		
				if ($storageHash->{$prkey}->{'transcriptKeys'} !~ m/$transcript_key/) {
					$storageHash->{$prkey}->{'transcriptKeys'} .= $transcript_key.',';
					$storageHash->{$prkey}->{'transcriptCount'} ++;
				#	print "<BR> I WAS HERE", $storageHash->{$prkey}->{'transcriptCount'};
				}
			}
			else
			{
				$storageHash->{$prkey}->{'transcriptKeys'} = $transcript_key.',';
				$storageHash->{$prkey}->{'transcriptCount'}++;
			}
			#print "<BR>",Dumper ($storageHash);
			$self->set('seqStorageHash', $storageHash);
		}
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

sub _rawSequences {
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
	    $self->_addRow($atable, $self->_initializeReturnRow($curRow), 
			   $sequence);
	}
    }
}

sub _utrSequences {
    my ($self, $atable, $curRow) = @_;

    my $locations = $self->get('locations');
    my $outRow = $self->get('outRow');
    



    if ($curRow) {
	my $importable_indices = $self->get('importable_indices');

	my $pkey = $curRow->[ $importable_indices->{"pkey"} ];

	my $lastPkey = $self->get('lastPkey');
	if ( $lastPkey && ($pkey ne $lastPkey) ) {
	    my $hasUtr = keys %{$locations};
	    if ($hasUtr) {
		my @ranks = sort { $a <=> $b } keys %{$locations};
		my $low_rank = shift @ranks;
		my $hi_rank = ($hasUtr > 1) ? pop @ranks : $low_rank;

		my $calc_location = $self->get('calc_location');
		
		my $low_loc_strand = $locations->{$low_rank}->{"strand"};
		if ($self->get('upstream_flank')) {
		    if ($low_loc_strand < 0) {
			$calc_location->{"start"} = 
			    $calc_location->{"end"} + 1;
			$calc_location->{"end"} = 
			    $calc_location->{"start"} + 
			    $self->get('upstream_flank') - 1;
		    } 
		    else {
			$calc_location->{"end"} = 
			    $calc_location->{"start"} - 1;
			 $calc_location->{"start"} = 
			    $calc_location->{"start"} - 
			    $self->get('upstream_flank');# lose a base if include this + 1;
			$calc_location->{"start"} = 1 
			    if ($calc_location->{"start"} < 1);
		    }
		  

		    #prepend to sequence
		    $locations->{$low_rank - 1} = $calc_location;
		} 
		elsif ($self->get('downstream_flank')) {
		    if ($low_loc_strand < 0) {
			$calc_location->{"end"} = 
			    $calc_location->{"start"} - 1;
			$calc_location->{"start"} = 
			    $calc_location->{"end"} - 
			    $self->get('downstream_flank') + 1;
		    } 
		    else {
			$calc_location->{"start"} = 
			    $calc_location->{"end"} + 1;
			$calc_location->{"end"} = 
			    $calc_location->{"start"} + 
			    $self->get('downstream_flank') -1; # positive strand & downstream flank, wont lose the base.
		    }
		    
		    #append to sequence
		    $locations->{$hi_rank + 1} = $calc_location;
		}      
		
		my $sequence = $self->_processSequence($locations);
		$self->_editSequence(\$sequence);
		if ($sequence) {
		    $locations = {};
		    $hasUtr = 0;
		    $self->_addRow($atable, $outRow, $sequence);
		    $outRow = undef;
		    $self->set('calc_location', undef);
		}
	    } 
	    else {
		$self->_addRow($atable, $outRow, 
			       "Sequence unavailable");
		$outRow = undef;
	    }
	}

	unless ($outRow) { 
	    $outRow = $self->_initializeReturnRow($curRow);
	}

	#for this one we build and calc
	my $rank = $curRow->[ $importable_indices->{"rank"} ];
	my $location = $self->_getLocationFrom($curRow, "chr", "start", 
					       "end", "strand");
	if ($location->{"start"}) {
	    $locations->{$rank} = $location;  
	    $self->_calcSeqOverLocations($location);
	}

	$self->set('lastPkey', $pkey);
    } 
    else {
	# last entry
	my $hasUtr = keys %{$locations};
	if ($hasUtr) {
	    my @ranks = sort { $a <=> $b } keys %{$locations};
	    my $low_rank = shift @ranks;
	    my $hi_rank = ($hasUtr > 1) ? pop @ranks : $low_rank;
	    
	    my $calc_location = $self->get('calc_location');

	    my $low_loc_strand = $locations->{$low_rank}->{"strand"};
	    if ($self->get('upstream_flank')) {
		if ($low_loc_strand < 0) {
		    $calc_location->{"start"} = $calc_location->{"end"} + 1;
		    $calc_location->{"end"} = 
			$calc_location->{"start"} + 
			$self->get('upstream_flank') - 1;
		} 
		else {
		    $calc_location->{"end"} = $calc_location->{"start"} - 1;
		    $calc_location->{"start"} = 
			$calc_location->{"start"} - 
			$self->get('upstream_flank') + 1;
		    $calc_location->{"start"} = 1 
			if ($calc_location->{"start"} < 1);
		}

		#prepend to sequence
		$locations->{$low_rank - 1} = $calc_location;
	    } 
	    elsif ($self->get('downstream_flank')) {
		if ($low_loc_strand < 0) {
		    $calc_location->{"end"} = $calc_location->{"start"} - 1;
		    $calc_location->{"start"} = $calc_location->{"end"} - 
			$self->get('downstream_flank') + 1;
		} 
		else {
		    $calc_location->{"start"} = $calc_location->{"end"} + 1;
		    $calc_location->{"end"} = $calc_location->{"start"} + 
			$self->get('downstream_flank') - 1;
		}

		#append to sequence
		$locations->{$hi_rank + 1} = $calc_location;
	    }

	    my $sequence = $self->_processSequence($locations);
	    $self->_editSequence(\$sequence);
	    if ($sequence) {
		$locations = {};
		$hasUtr = 0;
		$self->_addRow($atable, $outRow, $sequence);
		$outRow = undef;
		$self->set('calc_location', undef);
	    }
	} 
	else {
	    $self->_addRow($atable, $outRow, 
			   "No UTR is annotated for this transcript");
	    $outRow = undef;
	}
    }
    
    $self->set('locations', $locations);
    $self->set('outRow', $outRow);
}

sub _snpSequences {
    my ($self, $atable, $curRow) = @_;
  
    my $rank = 1;
    if ($curRow) {
	#since locations are just hashes, hack them
	my $location = $self->_getLocationFrom($curRow, "chr", "pos", 
					       "strand", "allele");
	
	if ($location->{"strand"} < 0) {
	    $location->{"start"} = $location->{"pos"} - 
		$self->get('downstream_flank');
	    $location->{"start"} = 1 
		if ($location->{"start"} < 1);
	    $location->{"end"} = $location->{"pos"} + 
		$self->get('upstream_flank');
	    $location->{"off"} = $self->get('upstream_flank');
	} 
	else {

	    $location->{"start"} = $location->{"pos"} - 
		$self->get('upstream_flank');
	    $location->{"end"} = $location->{"pos"} + 
		$self->get('downstream_flank');
	    $location->{"off"} = $self->get('upstream_flank');
	    if ($location->{"start"} < 1) {
		$location->{"off"} = $self->get('upstream_flank') + 
		    $location->{"start"} - 1;
		$location->{"start"} = 1;
	    }
	}


	my $locations = {};
	$locations->{$rank} = $location;
	my $sequence = $self->_processSequence($locations);
	$self->_editSequence(\$sequence);
	if ($sequence) {
	    #indels, insertions really. special case of allele of type hyphen/bp e.g -/A 
	    if ($location->{"allele"} =~ m/-\//){
	    	chop($sequence);
	    	substr($sequence, $location->{"off"}, 0) = "%".$location->{"allele"}."%";
	    }
	    else{
	    	substr($sequence, $location->{"off"}, 1) = "%".$location->{"allele"}."%";
	    }
	    $self->_addRow($atable, $self->_initializeReturnRow($curRow), 
			   $sequence);
	}    
    }

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

1;
