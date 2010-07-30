# $Id: GFF.pm,v 1.3.2.1 2008-07-19 22:13:37 syed Exp $
#
# BioMart module for BioMart::Formatter::GFF
#
# You may distribute this module under the same terms as perl
# itself.

# POD documentation - main docs before the code.

=head1 NAME

BioMart::Formatter::GFF

=head1 SYNOPSIS

The GFF Formatter returns GFF Formatter data for a BioMart query

=head1 DESCRIPTION

The GFF Formatter first of all removes any user chosen attributes from
the BioMart::Query object and adds the appropiate attributes required
for GFF data calculation. These attributes are defined in 'gtf' exportables
for the Dataset being processed. After this initial processing the query is 
run and the ResultTable is processed row by row to calculate the correct
structural data for GFF output

=head1 AUTHOR -  Syed Haider, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project
http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Formatter::GFF;

use strict;
use warnings;
use Data::Dumper;

# Extends BioMart::FormatterI
use base qw(BioMart::FormatterI);

sub _new {
	my ($self) = @_;
	$self->SUPER::_new();

	$self->attr('outRow', undef);
	$self->attr('lastPkey', undef);
	$self->attr('exon_idHash', undef);
}

 # overrides the same method from FormatterI
sub processQuery {
    my ($self, $query) = @_;

    $self->set('original_attributes',[@{$query->getAllAttributes()}]) 
	if ($query->getAllAttributes());
    # get exportable for terminal dataset from registry and set (attributes) 
    # on it and remove existing attribute - then set the list - may want a 
    # general method on FormatterI for doing all the rigid ones

    my $final_dataset_order = $query->finalDatasetOrder();
    my $registry = $query->getRegistry();
    
    	# remove all attributes from query
    	$query->removeAllAttributes();
	
    	foreach my $dataset_name(reverse @$final_dataset_order){	
    		my $dataset = $registry->getDatasetByName($query->virtualSchema, $dataset_name);
		if($dataset->visible)
		{		
			if ($dataset->getExportables('gtf', $query->getInterfaceForDataset($dataset_name))){
				$query->setDataset($dataset_name);
				my $attribute_list = $dataset->getExportables('gtf', $query->getInterfaceForDataset($dataset_name));
	    	
	    			my $temp_atts = $attribute_list->getAllAttributes;
	    	
	    			$query->addAttributes($attribute_list->getAllAttributes);
			}
		}
    	}
	$self->set('query',$query);
    	return $query;
}

sub nextRow {
	my $self = shift;

	my $rtable = $self->get('result_table');
	
	my $formatted_rows;
	my $attr_tmpl = 'gene_id "%s"; transcript_id "%s"; exon_id "%s"';
	my $exon_tmpl = "%s\tEnsEMBL\texon\t%s\t%s\t.\t%s\t.\t%s";
	my $cds_tmpl = "%s\tEnsEMBL\tCDS\t%s\t%s\t.\t%s\t%s\t%s";
	my $start_tmpl = "%s\tEnsEMBL\tstart_codon\t%s\t%s\t.\t%s\t.\t%s";
	my $stop_tmpl =  "%s\tEnsEMBL\tstop_codon\t%s\t%s\t.\t%s\t.\t%s"; 

	my $curRow = $rtable->nextRow;
	#print "\n","@$curRow";	
	if( !$curRow && !$self->get('lastPkey')){
		return;
	}


	my $pkey = ($curRow) ? $curRow->[0].$curRow->[1] : undef ;
	my $lastPkey = $self->get('lastPkey') || $pkey;
	my $outRow = $self->get('outRow');
	if(($lastPkey && !$pkey) || ($pkey ne $lastPkey)) {
		#		print "\n\n [$lastPkey]\n\n";
		#		print Dumper($outRow);
		# process saved rows and send some results back
	
		my ($previous_frame, $previous_cds_start, $previous_cds_end) = 0;
    	foreach my $true_rank (sort { $a <=> $b } keys %$outRow ) {
			no warnings 'uninitialized';
		
			my $rank = $outRow->{$true_rank}->{'exon_id'};# dodgy
			my $start_rank = $outRow->{$true_rank}->{'start_exon_id'};
			my $end_rank = $outRow->{$true_rank}->{'end_exon_id'};
			my $exon_start = $outRow->{$true_rank}->{'exon_chrom_start'};
			my $exon_end = $outRow->{$true_rank}->{'exon_chrom_end'};
			my $strand = $outRow->{$true_rank}->{'strand'};			
			my $coding_start_offset = $outRow->{$true_rank}->{'coding_start_offset'};
			my $coding_end_offset = $outRow->{$true_rank}->{'coding_end_offset'};
			my ($coding_start, $coding_end);
			
			my ($attributes, $exon_line, $cds_line, $start_codon_line, $stop_codon_line);	
			#print "rank: ", $outRow->{$true_rank}->{'rank'}," : " , $outRow->{$true_rank}->{'geneId'} , 
			#	" : ", $outRow->{$true_rank}->{'transcriptId'} , "[$rank:$start_rank:$end_rank]", "\n";
		
			my $exon_idHash = $self->get('exon_idHash');
			if ($start_rank && $end_rank) {
			# this includes sequence types : coding_gene_flank, coding_transcript_flank, coding, peptide
				if ($rank == $start_rank && $rank == $end_rank) {
					# coding start and finish on the same exon
					if ($strand == 1) {
						$coding_start = $exon_start + $coding_start_offset - 1;
						$coding_end = $exon_start + $coding_end_offset - 1;
					}
					if ($strand == -1) {
						$coding_start = $exon_end - $coding_end_offset + 1;
						$coding_end = $exon_end - $coding_start_offset + 1;
					}
				}
				elsif ($rank == $start_rank) {
					if ($strand == 1) {
						$coding_start = $exon_start + $coding_start_offset - 1;
						$coding_end = $exon_end;
					}
					if ($strand == -1) {	
						$coding_start = $exon_start;
						$coding_end = $exon_end - $coding_start_offset + 1;
					}
					# encountered coding START exon. storing as transcriptId.start_exonId to make it unique
					$self->_setCodingExonFlag($pkey.$start_rank, 1);
				}
				elsif ($rank == $end_rank) {
					if ($strand == 1) {
						$coding_start = $exon_start;
						$coding_end = $exon_start + $coding_end_offset - 1;
					}
					if ($strand == -1) {
						$coding_start = $exon_end - $coding_end_offset + 1;
						$coding_end = $exon_end;
					}
					# encountered coding END exon. clear ranscriptId.start_exonId stored earlier
					$self->_setCodingExonFlag($pkey.$start_rank, 0);
				}
				else {
					if ($exon_idHash->{$pkey.$start_rank} == 1) {
						$coding_start = $exon_start;
						$coding_end = $exon_end;
					}
					else {
						$coding_start = undef;
						$coding_end = undef;
					}
				}

				# sanity check
				if ($coding_start > $coding_end) {
					$coding_start = undef;
					$coding_end = undef;
				}
				# update the coordinates to be returned by this function - now similar to old coordinates
				$outRow->{$true_rank}->{'coding_start'} = $coding_start;
				$outRow->{$true_rank}->{'coding_end'} = $coding_end;
			}
			else { # no coding start/end set the vals to NULL	
				$outRow->{$true_rank}->{'coding_start'} = undef;
				$outRow->{$true_rank}->{'coding_end'} = undef;
			}


	
			#$attributes = $outRow->{$true_rank}->{'transcriptId'};
			$attributes = sprintf($attr_tmpl, $outRow->{$true_rank}->{'geneId'}, $outRow->{$true_rank}->{'transcriptId'}, $outRow->{$true_rank}->{'exonId'}); 
			# exon line
			$exon_line = sprintf($exon_tmpl, 
									$outRow->{$true_rank}->{'chr'},
									$outRow->{$true_rank}->{'exon_chrom_start'},
									$outRow->{$true_rank}->{'exon_chrom_end'},
									($outRow->{$true_rank}->{'strand'} == -1)? '-':'+');

			# CDS line
			if ($outRow->{$true_rank}->{'coding_start'} && $outRow->{$true_rank}->{'coding_end'}) {
				if ($outRow->{$true_rank}->{'strand'} == 1) {
					if ($rank == $end_rank 
							&& $outRow->{$true_rank}->{'exon_chrom_end'} == $outRow->{$true_rank}->{'coding_end'}) {
						$outRow->{$true_rank}->{'coding_end'} -= 3;
					}
				}
				else{ # -1					
					if ($rank == $end_rank 
							&& $outRow->{$true_rank}->{'exon_chrom_start'} == $outRow->{$true_rank}->{'coding_start'}) {
						$outRow->{$true_rank}->{'coding_start'} += 3;		
					}
				}
				
				# adding frame info, this goes only in CDS line
				if ($rank == $start_rank) {
					$outRow->{$true_rank}->{'frame'} = 0;
				}
				else {
					# NEW/THIS frame = (previous_frame - length) % 3 
					my $length = ($outRow->{$true_rank}->{'strand'} == 1) ? 
												($previous_cds_end - $previous_cds_start)
											: 	($previous_cds_start - $previous_cds_end);
					$length += 1;
					$outRow->{$true_rank}->{'frame'} = ($previous_frame - $length) % 3;
				}
				
				$previous_frame = $outRow->{$true_rank}->{'frame'};
				$previous_cds_start = $outRow->{$true_rank}->{'coding_start'};
				$previous_cds_end = $outRow->{$true_rank}->{'coding_end'};

					$cds_line = sprintf($cds_tmpl,
									$outRow->{$true_rank}->{'chr'},
									$outRow->{$true_rank}->{'coding_start'},
									$outRow->{$true_rank}->{'coding_end'},
									($outRow->{$true_rank}->{'strand'} == -1)? '-':'+',
									$outRow->{$true_rank}->{'frame'});

			}
			
			# start_codon line
			if ($rank == $start_rank) {
				if ($outRow->{$true_rank}->{'strand'} == 1) {
					$start_codon_line = sprintf($start_tmpl,
									$outRow->{$true_rank}->{'chr'},
									$outRow->{$true_rank}->{'coding_start'},
									$outRow->{$true_rank}->{'coding_start'} + 2,
									($outRow->{$true_rank}->{'strand'} == -1)? '-':'+');
				}
				else { # -1
					$start_codon_line = sprintf($start_tmpl,
									$outRow->{$true_rank}->{'chr'},
									$outRow->{$true_rank}->{'coding_end'} - 2 ,
									$outRow->{$true_rank}->{'coding_end'},
									($outRow->{$true_rank}->{'strand'} == -1)? '-':'+');
				}
			}
			
			# stop_codon line
			if ($rank == $end_rank) {
				if ($outRow->{$true_rank}->{'strand'} == 1) {
					$stop_codon_line = sprintf($stop_tmpl,
									$outRow->{$true_rank}->{'chr'},
									$outRow->{$true_rank}->{'coding_end'} + 1,
									$outRow->{$true_rank}->{'coding_end'} + 3,
									($outRow->{$true_rank}->{'strand'} == -1)? '-':'+');
				}
				else { # -1
					$stop_codon_line = sprintf($stop_tmpl,
									$outRow->{$true_rank}->{'chr'},
									$outRow->{$true_rank}->{'coding_start'} - 3,
									$outRow->{$true_rank}->{'coding_start'} - 1,
									($outRow->{$true_rank}->{'strand'} == -1)? '-':'+');				
				}
			}				
			
	
			#$formatted_rows .= $outRow->{$true_rank}->{'has_stop_codon'}.' > ';
			$formatted_rows .= $exon_line.$attributes."\n";
			$formatted_rows .= $cds_line.$attributes."\n" if ($cds_line);
			$formatted_rows .= $start_codon_line.$attributes."\n" if ($start_codon_line);
			$formatted_rows .= $stop_codon_line.$attributes."\n" if ($stop_codon_line);		
			
		
		}	
		undef $outRow;
		
		# lets release the last set of rows. when $pkey is NULL and we have lastPkey
		if (!$pkey) {
		   $self->set('outRow', undef);
			$self->set('lastPkey', undef);
			return $formatted_rows;
		}		
	}

	#########################################################
	
	my $rowHash = ();
	my $rowIndex = 0;
	# atts from gtf exportable
	foreach my $name ( "geneId","transcriptId","exonId","chr", "exon_chrom_start","exon_chrom_end", "coding_start_offset", "coding_end_offset", 
								"strand", "exon_id", "rank", "start_exon_id", "end_exon_id", "transcript_count", "has_m_start", "has_stop_codon")	 {
		$rowHash->{$name} = $curRow->[$rowIndex++];	
	}
	
	foreach my $name ( "coding_start", "coding_end", "frame") {
		$rowHash->{$name} = "";
	}
	
	$outRow->{$rowHash->{'rank'}} = $rowHash;
	#push @$outRow, $rowHash;
	# now save the current row
   $self->set('outRow', $outRow);
	$self->set('lastPkey', $pkey);
	
	
	return $formatted_rows || "\n";	

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


sub getDisplayNames {
    my $self = shift;

    return '';# no header required for GFF
}

sub isSpecial {
    return 1;
}


1;



