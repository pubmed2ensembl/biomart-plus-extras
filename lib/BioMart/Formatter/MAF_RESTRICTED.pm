#
# BioMart module for BioMart::Formatter::MAF_RESTRICTED
#
# You may distribute this module under the same terms as perl
# itself.
# POD documentation - main docs before the code.

=head1 NAME

BioMart::Formatter::MAF_RESTRICTED

=head1 SYNOPSIS

TODO: Synopsis here.

=head1 DESCRIPTION

  MAF Formatter
  
  For more documentation see :
   
  http://genome.ucsc.edu/FAQ/FAQformat.html#format5 
    
=head1 EXAMPLE
    
 ##maf version=1 scoring=tba.v8 
 # tba.v8 (((human chimp) baboon) (mouse rat)) 
 # multiz.v7
 # maf_project.v5 _tba_right.maf3 mouse _tba_C
 # single_cov2.v4 single_cov2 /dev/stdin
                    
 a score=23262.0     
 s hg16.chr7    27578828 38 + 158545518 AAA-GGGAATGTTAACCAAATGA---ATTGTCTCTTACGGTG
 s panTro1.chr6 28741140 38 + 161576975 AAA-GGGAATGTTAACCAAATGA---ATTGTCTCTTACGGTG
 s baboon         116834 38 +   4622798 AAA-GGGAATGTTAACCAAATGA---GTTGTCTCTTATGGTG
 s mm4.chr6     53215344 38 + 151104725 -AATGGGAATGTTAAGCAAACGA---ATTGTCTCTCAGTGTG
 s rn3.chr4     81344243 40 + 187371129 -AA-GGGGATGCTAAGCCAATGAGTTGTTGTCTCTCAATGTG
 
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

package BioMart::Formatter::MAF_RESTRICTED;

use strict;
use warnings;
use Log::Log4perl;

#use Readonly;

# Extends BioMart::FormatterI
use base qw(BioMart::FormatterI);

my $logger;	 # master logger
my $aln_nb = 0 ;

sub _new {
    my ($self) = @_;
    $self->SUPER::_new();
    $aln_nb = 0 ;
    # Get reference to logger
    $logger = Log::Log4perl->get_logger(__PACKAGE__);
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
    my $HEADER = "";
    my $PROCESSED_SEQS ;
    my $SCORE2 ;
    my $new_start_time = time();
    $logger->debug("START NEXT ROW ");
    my $rtable = $self->get('result_table');
    my $row = $rtable->nextRow;
    if (!$row){
        return;
    } 
    #**********
    #my $aln_nb = 0;
    #rint "\n\n+++++++++++++++++++  $aln_nb   \n\n";  
    ### Print maf comments using the $aln_nb variable 
    $HEADER = &_printHeader if ($aln_nb == 0);
   
    # Need to test if the data comes from MLAGAN
    # in that case the row contain [seq1 seq2 seqN data1 data2 dataN]
    
    if ( ( ($$row[0]=~/^(A|C|G|T|N)/) && ($$row[0]!~/^(Chr)/) ) && ( ($$row[1]=~/^(A|C|G|T|N)/) && ($$row[1]!~/^(Chr)/) )   ){  # 15/08/06 removed /i
	                                                                   # added a hack for 'Ch'
	@data = &preProcessRowMlagan(\@{$row});

	my $score ; # score is now in data[$i][8]

	my $size_chro = 0 ; # calculate the size of the longuest chro # for sprintf
	foreach my $value (@data){
	    my $chr    = $value->[1];
	    if ($size_chro < length($chr) ){$size_chro = length($chr);} 
	}

	
	foreach my $foo (@data){
	    my $seq    = $foo->[0] ;
	    my $chr    = $foo->[1] ;
	    my $start  = $foo->[2] ;
	    my $end    = $foo->[3] ;
	    my $strand = $foo->[4] ;
	    my $length = $foo->[5] ;
	    my $genome = $foo->[6] ;
	    my $cigar  = $foo->[7] ;
	    $score     = $foo->[8] ;

	    if (($score) && (!$SCORE2)){
		$SCORE2 .= "a score=$score\n";
	    }

	    if ($seq ne 'N'){ # means that there is no data for that species 
		$PROCESSED_SEQS .=  &returnMAFline4Mlagan($seq,$chr,$start,$end,$strand,$length,$genome,$size_chro,$cigar);
	    }
	}
	$aln_nb++; 
	
	#-- if score is undefined, put 0 instead of nothing
	if (!$SCORE2){ $SCORE2 .= "a score=0\n";}
	return $HEADER . $SCORE2 . $PROCESSED_SEQS . "\n";
	
    } else {
	warn "MAF.pm -- Error processing data (attribute list)\n";
    }
    my $time_elapsed = round(time() - $new_start_time);
    $logger->debug("END NEXT ROW : $time_elapsed to format in MAF ");
}
#--------------------------------------------
sub returnMAFline4Mlagan{
    my $size = @_;
    my ($seq,$chr,$start,$end,$strand,$length,$gdb_id,$size_chro,$cigar) = @_;
    my $chr2;
    
    if (length($gdb_id) > 3){
	$gdb_id = &trimspe($gdb_id);
    }else{
	$gdb_id = "sp".$gdb_id ;
    }
    
    if (length($chr) > 2){ $chr2 = $chr; }# add 'chr' to the chromosome name if <=2
    else { $chr2 = "chr".$chr; }

    my ($length_seq,$hstrand,$hstart,$hend);
    if ($strand > 0){                   
	$length_seq = length($seq);
	$hstrand = "+";
	$hstart = $start;
	
    } elsif ($strand < 0){
	$length_seq = length($seq);
	$hstrand = "-";
	$hstart = $length - $end + 1;
	    
    } else { warn "\n\n\nProblem in returning maf formated lines \n\n\n";}
    
    my $formated_seq = _get_aligned_sequence_from_original_sequence_and_cigar_line($seq, $cigar);
    # was                    "%1s %16s %10d %10d %-5s %10d %10s \n","s",$chr etc.
    # $size_chro+8 mean that I add 8 to make some space for 'hsap'+'.chr' 
    my $maf_line = sprintf  ("%1s %-".($size_chro+8)."s %10d %7d %-5s %10s %5s \n","s",$gdb_id.".".$chr2 ,$hstart ,$length_seq ,$hstrand ,$length ,$formated_seq);
    return $maf_line;
}
#--------------------------------------------
sub returnMAFline{
    my $size = @_;
    my ($seq,$chr,$start,$end,$strand,$length,$cigar) = @_;
    #warn "\n\n######  size returnMAFline $size  \n\n";
   
    my ($length_seq,$hstrand,$hstart,$hend);
    if ($strand > 0){                   
	$length_seq = length($seq);
	$hstrand = "+";
	$hstart = $start;
	
    } elsif ($strand < 0){
	$length_seq = length($seq);
	$hstrand = "-";
	$hstart = $length - $end + 1;
	    
    } else { warn "\n\n\nProblem in returning maf formated lines \n\n\n";}
    
    my $formated_seq = _get_aligned_sequence_from_original_sequence_and_cigar_line($seq, $cigar);
    # was                    "%1s %16s %10d %10d %-5s %10d %10s \n","s",$chr etc.
    my $maf_line = sprintf  ("%1s %5s %10d %5s %-5s %10s %5s \n","s",$chr ,$hstart ,$length_seq ,$hstrand ,$length ,$formated_seq);
    return $maf_line;
}
#--------------------------------------------
sub getDisplayNames {
    my $self = shift;
    return '' ;
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
	#print "rentre loop while $to \n";	
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
sub preProcessRowMlagan{
    my $row =  shift ;
    my @want ;
    my $score;
    my $k = 0;
    my $size_row = @{$row};
 #   print "\nsize_row subroutine :  $size_row\n";
    while ( ($$row[0]=~/^(A|C|G|T|N)/) && ($$row[0]!~/^Chr/i) && ($$row[0]!~/\_/) ){ # get all seq out
	$want[$k][0] = shift (@{$row});
	$k++;
    }
#    my $o = 0;
#   # $k-1 is equal to the number of seqs (=nb of species)
    for  (my $j=0;$j<=$k-1;$j++){ 
#	print "== $j 0 ";print "    ->>--- $want[$j][0]\n";
	for (my $i=1;$i<=8;$i++){       #IMPORTANT changed from 7 to 8, as I have now a score for all species
#	    print "== $j $i ";
	    $want[$j][$i] = shift (@{$row});
#	    $want[$j][$i] = $row->[$o];
#	    print "    ->>--- $want[$j][$i]\n";
#	    $o++;
	}
####	#if ($j == 0){#if ($j == 0){ #for the first species which contain the score 
####	#    $score = shift (@{$row}); 
####	#    print "==score $j $score\n";
####	#}

    }
    return (@want);
}
#--------------------------------------------
sub preProcessRowMlaganOLD{
    my $row =  shift ;
    my @want ;
    my $score;
    my $k = 0;
    my $size_row = @{$row};
    print "\nsize_row subroutine :  $size_row\n";
    
    while ( ($$row[0]=~/^(A|C|G|T|N)/i) && ($$row[0]!~/^Chr/i) ) { # get all seq out
	
	$want[$k][0] = shift (@{$row});
	print "Get seq out: $want[$k][0]\n";
	$k++;
	print "k= $k\n\n";
    }
    
    # $k-1 is equal to the number of seqs (=nb of species)
    for  (my $j=0;$j<=$k-1;$j++){ 
	print "== $j 0 ";print "    ---- $want[$j][0]\n";
	for (my $i=1;$i<=7;$i++){
	    print "== $j $i ";
	    $want[$j][$i] = shift (@{$row});
	    print "    ---- $want[$j][$i]\n";
	}
	if ($j == 0){#if ($j == 0){ #for the first species which contain the score 
	    $score = shift (@{$row}); 
	    print "==score $j $score\n";
	}
    }
    return (@want, $score);
}
#--------------------------------------------
sub preProcessRow2{
    my @row =  @_ ;
    my @want ;
    my $to = 0;
    my $score;
    my $size_row = @row;
    print "size_row subroutine :  $size_row\n";
    while ($size_row > 0) {
	#print "rendre loop while $to \n";	
	if ($to == 0) {
	    for (my $i=0;$i<=6;$i++){
	    #print "==$to $i\n";
	    $want[$to][$i] = shift (@row);
	    #print "    ---- $want[$to][$i]\n";
	}
	    $score = shift (@row); 
	    #print "==score $to $score\n";
	    $to++;
	}
	else {
	    for (my $i=0;$i<=6;$i++){
		#print "==$to $i\n";
		$want[$to][$i] = shift (@row);
		#print "    ---- $want[$to][$i]\n";
	    }
	    $to++;
	}
	$size_row =  @row;
    }
    my $size = @want;
    return (@want, $score);
}
#--------------------------------------------
sub _printHeader {
    my $date = localtime();
    my $p1 = sprintf "##maf version=1\n";
    my $p2 = sprintf "#".localtime()."\n";
    my $p3 = sprintf "#The start coordinate is a zero-based number.\n";
    my $p4 = sprintf "#For segments in the negative strand, the start\n";
    my $p5 = sprintf "#is relative to the end of the chromosome. Please, refer to\n";
    my $p6 = sprintf "#http://genome.ucsc.edu/FAQ/FAQformat#format5 for a\n";
    my $p7 = sprintf "#description of this file format.\n\n";
    #print $p1;
    #print $p2;
    return $p1.$p2.$p3.$p4.$p5.$p6.$p7;
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
    warn ("Cigar line ($seq_pos) does not match sequence lenght (".length($original_sequence).")") if 
	($seq_pos != length($original_sequence));
    
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
#-----------------------------------------
sub trimspe {
    my $short_spec;
    my $spec = $_[0];

    $spec =~ tr[A-Z][a-z];
    if ($spec =~ /(\w+)\s+(\w+)/){
	$short_spec = substr($1,0,1).substr($2,0,3) ;
    }
    return $short_spec;        
}
#--------------------------------------------


sub isSpecial {
    return 1;
}
1;



