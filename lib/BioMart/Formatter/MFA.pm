#
# BioMart module for BioMart::Formatter::MFA
#
# You may distribute this module under the same terms as perl
# itself.

# POD documentation - main docs before the code.

=head1 NAME

BioMart::Formatter::MFA

=head1 SYNOPSIS

TODO: Synopsis here.

=head1 DESCRIPTION

  MFA Formatter
  Multiple Fasta Alignment File
  
  For more documentation see :
  http://bioperl.org/wiki/FASTA_multiple_alignment_format

=head1 EXAMPLE
    
  >chr:21|start:20941549|end:20941788|strand:1
  TTTGCAGATATTGCAGCTTTTTACAAATTGAAGGTTTGTGGCAACCCTGC----------------ATGCAACCAGTCTG
  TTGGCATC---ATTTTGTGT--------------TATATT--TTGGTAATTCTCTCAATATTTCAGACTGTTTCATTATC
  ATTATATCTGTTATGGTGTTGTATAATCAGTGACCTTTGATG---TTACTATTGTAATTGTTTTAGAGTGCCAAGGTCTG
  TGCCCCAAAAAAGGTGGCTAACATATTCAGTAAATAAA
  >chr:1|start:4265565|end:4265824|strand:-1
  TTTACTGATGT-GTAGTTTTATTTTAATTGAAAGTGGG-GACAACCGTGTTGCACTGGTCTTATAAGTGCCATCATTCCA
  TTAATGTCTTTACTTTGTGTGTGCCCCCATGTCTCATTTTGCTTGGTATTTTTAATAATATTCCAAATGTTTTCATGTTT
  ATT--------CATTATGTTATATCATCTGTGATCTTTGATGTTATTATTATTATAACTATTTTAAGGCACCACAAACTA
  TGTAC--------ATAATTAACAAGCTTAATAAACAAA
  #

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

package BioMart::Formatter::MFA;

use strict;
use warnings;

# Extends BioMart::FormatterI
use base qw(BioMart::FormatterI);

sub _new {
    my ($self) = @_;
    $self->SUPER::_new();
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

	    my @prearray = ($seq,$chr,$start,$end,$strand,$length,$genome,$cigar,$score);
	    ## Can be better coded ## need to change that like, add another for ($j=0..$j<=7){ push (@array, $data[$i][$j] )
	    
	    $PROCESSED_SEQS .=  &returnMFAline(@prearray);
	}
    }
    return $PROCESSED_SEQS . "#\n";
}
#--------------------------------------------
sub returnMFAline{
    my ($seq,$chr,$start,$end,$strand,$length,$genome,$cigar,$score) = @_;
    my ($length_seq,$hstrand,$hstart,$hend);
    my $fasta_seq;
    if ($strand > 0){                   
	$length_seq = length ($seq);
	$hstrand = "+";
	$hstart = $start;
	$hend = $end;
	
    } elsif ($strand < 0){
	$length_seq = length ($seq);
	$hstrand = "-";
	$hstart = $length - $end + 1;
	$hend =  $length - $start + 1;
	
    } else { warn "\n\n\nProblem in returning mfa formated lines \n\n\n";}
    
    my $header = ">" . join("|",("chr:".$chr),"start:".$start,"end:".$end,"strand:".$strand,"score:".$score,$genome);
    my $formated_seq = _get_aligned_sequence_from_original_sequence_and_cigar_line($seq, $cigar);
   
    while ($formated_seq =~ /(.{1,80})/g) {
	$fasta_seq .= $1 ."\n";
    }
    return ($header."\n".$fasta_seq);
		     
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
sub preProcessRow{
    my $row =  shift ;
    my @want ;
    my $to = 0;
    my $score;
    my $size_row = @{$row};
    #print "size_row subroutine $size_row\n";
    while ($size_row > 0) {
	#print "rendre loop while $to \n";	
	if ($to == 0) {
	    for (my $i=0;$i<=6;$i++){
	    #print "==$to $i\n";
	    $want[$to][$i] = shift (@{$row});
	    #print "    ---- $want[$to][$i]\n";
	}
	    $score = shift (@{$row}); 
	    #print "==score $to $score\n";
	    $to++;
	}
	else {
	    for (my $i=0;$i<=6;$i++){
		#print "==$to $i\n";
		$want[$to][$i] = shift (@{$row});
		#print "    ---- $want[$to][$i]\n";
	    }
	    $to++;
	}
	$size_row =  @{$row};
    }
    my $size = @want;
    return (@want, $score);
}
#--------------------------------------------
#sub getDisplayNames {
#    my $self = shift;
#    return $self->getTextDisplayNames("\t");
#}
sub getDisplayNames {
    my $self = shift;
    return '' ;
}
#---------------------------------------

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



