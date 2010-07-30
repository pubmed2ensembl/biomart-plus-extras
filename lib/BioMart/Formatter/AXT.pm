#
# BioMart module for BioMart::Formatter::AXT
#
# You may distribute this module under the same terms as perl
# itself.

# POD documentation - main docs before the code.

=head1 NAME

BioMart::Formatter::AXT

=head1 SYNOPSIS

TODO: Synopsis here.

=head1 DESCRIPTION

  AXT Formatter
  AXT alignment files are produced from Blastz
  For more documentation see :
  http://bioperl.org/wiki/AXT_format 
  http://genome.ucsc.edu/goldenPath/help/axt.html 
    
=head1 EXAMPLE
    
  0 chr19 3001012 3001075 chr11 70568380 70568443 - 3500
  TCAGCTCATAAATCACCTCCTGCCACAAGCCTGGCCTGGTCCCAGGAGAGTGTCCAGGCTCAGA
  TCTGTTCATAAACCACCTGCCATGACAAGCCTGGCCTGTTCCCAAGACAATGTCCAGGCTCAGA

  1 chr19 3008279 3008357 chr11 70573976 70574054 - 3900
  CACAATCTTCACATTGAGATCCTGAGTTGCTGATCAGAATGGAAGGCTGAGCTAAGATGAGCGACGAGGCAATGTCACA
  CACAGTCTTCACATTGAGGTACCAAGTTGTGGATCAGAATGGAAAGCTAGGCTATGATGAGGGACAGTGCGCTGTCACA


=head1 AUTHORS

=over

=item *
benoit@ebi.ac.uk

=back

=head1 CONTACT

This module is part of the BioMart project
http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut

package BioMart::Formatter::AXT;

use strict;
use warnings;

# Extends BioMart::FormatterI
use base qw(BioMart::FormatterI);
my $aln_nb = 0 ;

sub _new {
    my ($self) = @_;
    $self->SUPER::_new();
    $aln_nb = 0 ;
}

sub processQuery {
    my ($self, $query) = @_;
    $self->set('original_attributes',[@{$query->getAllAttributes()}]) if ($query->getAllAttributes());
    $self->set('query',$query);
    return $query;
}

sub nextRow {
    my $self = shift;
    my @data ;
    my @array;
    #my $aln_nb = 0 ;
    my $PROCESSED_SEQS ;
    my $rtable = $self->get('result_table');
    my $row = $rtable->nextRow;
    if (!$row){
        return;
    }
    
    if ( ( ($$row[0]=~/^(A|C|G|T|N)/) && ($$row[0]!~/^(Chr)/) ) && ( ($$row[1]=~/^(A|C|G|T|N)/) && ($$row[1]!~/^(Chr)/) )   ){  # 15/08/06 removed /i
	# added a hack for 'Ch'
	@data = &preProcessRowMlagan(\@{$row});
	
	foreach my $foo (@data){
	    my $seq    = $foo->[0] ;
	    my $chr    = $foo->[1] ;
	    my $start  = $foo->[2] ;
	    my $end    = $foo->[3] ;
	    my $strand = $foo->[4] ;
	    my $length = $foo->[5] ;
	    my $genome = $foo->[6] ;
	    my $cigar  = $foo->[7] ;
	    my $score  = $foo->[8] ;
	
	    my @prearray = ($seq,$chr,$start,$end,$strand,$length,$cigar,$score);
	    ## Can be better coded ## need to change that like, add another for ($j=0..$j<=7){ push (@array, $data[$i][$j] )
	    push (@array, @prearray);
#	    if ($seq ne 'N'){
#		# do something
#		# in pairwise seq alignment you should always have a seq	       
#	    }
	}
	push (@array, $aln_nb);
	
	$PROCESSED_SEQS =  &returnAXTline(@array);
	$aln_nb++;
	return $PROCESSED_SEQS ;
    }
}

#------------------------
sub returnAXTline{
    my ($seq1,$chr1,$start1,$end1,$strand1,$length1,$cigar1,$score1,$seq2,$chr2,$start2,$end2,$strand2,$length2,$cigar2,$score2,$aln_nb) = @_;
    
    if ($strand1 > 0){                    ## If the qy specie is forward
	
	my ($hstart2, $hend2, $hstrand2);
	if ($strand2 < 0)  {
	    $hstrand2 = "-";
	    $hstart2 = $length2 - $end2 + 1;
	    $hend2 =  $length2 - $start2 + 1;
	} else {
	    $hstrand2 = "+";
	    $hstart2 = $start2;
	    $hend2 = $end2;
	}
	
	my $line1 =   sprintf("%d %5s %10d %10d %5s %10d %10d %-1s %s", $aln_nb,$chr1,$start1,$end1,$chr2,$hstart2,$hend2,$hstrand2,$score1);
	my $line2 =   sprintf( _get_aligned_sequence_from_original_sequence_and_cigar_line($seq1, $cigar1));
	my $line3 =   sprintf( _get_aligned_sequence_from_original_sequence_and_cigar_line($seq2, $cigar2));
	return ("$line1\n$line2\n$line3\n\n");
 	
	#-------
	
    } elsif ($strand1 < 0){                   ## If the qy specie is reverse
	
	my $length_seq1 = length ($seq1);
	my $length_seq2 = length ($seq2);
	
	my ($hstart1, $hend1, $hstrand1);
	#$hstrand1 = "-";  #the strand1 is always forward in AXT format
	$hstart1 =  $start1 ;
	$hend1   =  $end1 ;
	
	
	my ($hstart2, $hend2, $hstrand2); #recalculate coordinate if strand +
	if ($strand2 > 0)  {
	    # if strand + make it - !
	    $hstrand2 = "-";
	    $hstart2 = $length2 - $end2 + 1;
	    $hend2 =  $length2 - $start2 + 1;
	} else { 
	    # if strand - make it + !
	    $hstrand2 = "+";
	    $hstart2 = $start2;
	    $hend2 = $end2;
	}
	
	my $line1 = sprintf   ("%d %5s %10d %10d %5s %10d %10d %-1s %s ", $aln_nb,$chr1,$start1,$end1,$chr2,$hstart2,$hend2,$hstrand2,$score1);
	my $line2 = sprintf  ( _get_aligned_sequence_from_original_sequence_and_cigar_line( _rc($seq1), _rcCigarLine($cigar1)));
	my $line3 = sprintf  ( _get_aligned_sequence_from_original_sequence_and_cigar_line( _rc($seq2), _rcCigarLine($cigar2)));
	return ("$line1\n$line2\n$line3\n\n");
	
    } else {
	warn  "\n\n Problem with 1st species strand \n\n";
    }
}
#--------------------------------------------
sub preProcessRowMlagan{
    my $row =  shift ;
    my @want ;
    my $score;
    my $k = 0;
    my $size_row = @{$row};
    
    #-- Get all the seq in $want[$k][0]
    while ( ($$row[0]=~/^(A|C|G|T|N)/) && ($$row[0]!~/^Chr/i) && ($$row[0]!~/\_/) ){ # get all seq out
	$want[$k][0] = shift (@{$row});
	$k++;
    }
    
    #-- then put the rest of it into $want[$j][??]
    for  (my $j=0;$j<=$k-1;$j++){ 
	for (my $i=1;$i<=8;$i++){       #IMPORTANT changed from 7 to 8, as I have now a score for all species
	    $want[$j][$i] = shift (@{$row});
	}
    }
    return (@want);
}
#--------------------------------------------
#sub getDisplayNames {
#// WARNING
#// This return the number of attribute in the attribute list. (eg: 17)
#    my $self = shift;
#    return $self->getTextDisplayNames("\t");
#}
#--------------------------------------------
sub getDisplayNames {
    my $self = shift;
    return '' ;
}
# subroutines from AXT.pm <alpha version>
#--------------------------------------------
sub _get_aligned_sequence_from_original_sequence_and_cigar_line  {
    
    my ($original_sequence, $cigar_line) = @_;
    my $aligned_sequence = "";

    return undef if (!$original_sequence or !$cigar_line);
    
    my $seq_pos = 0;
    
    my @cig = ( $cigar_line =~ /(\d*[GMD])/g );
    for my $cigElem ( @cig ) {
	
	my $cigType = substr( $cigElem, -1, 1 );
	my $cigCount = substr( $cigElem, 0 ,-1 );
	$cigCount = 1 unless ($cigCount =~ /^\d+$/);
	#print "-- $cigElem $cigCount $cigType\n";
	if( $cigType eq "M" ) {
	    $aligned_sequence .= substr($original_sequence, $seq_pos, $cigCount);
	    $seq_pos += $cigCount;
	} elsif( $cigType eq "G" or $cigType eq "D") {
	    
	    $aligned_sequence .=  "-" x $cigCount;
	    
	}
    }
    warn ("Cigar line ($seq_pos) does not match sequence lenght (".length($original_sequence).")") if ($seq_pos != length($original_sequence));
    
    return $aligned_sequence;

}
#--------------------------------------------
sub _rc{
    my ($seq) = @_;

    $seq = reverse($seq);
    $seq =~ tr/YABCDGHKMRSTUVyabcdghkmrstuv/RTVGHCDMKYSAABrtvghcdmkysaab/;

    return $seq;
}
#--------------------------------------------
sub _rcCigarLine{
    my ($cigar_line) = @_;
        
    #print STDERR "###cigar_line $cigar_line\n";
    my @cig = ( $cigar_line =~ /(\d*[GMD])/g );
    my @rev_cigar = reverse(@cig);
    my $rev_cigar;
    for my $cigElem ( @rev_cigar ) { 
	  $rev_cigar.=$cigElem;
    }			 
    #print STDERR "###rev_cigar $rev_cigar\n";
    return $rev_cigar;
    
}
#--------------------------------------------


sub isSpecial {
    return 1;
}
1;



