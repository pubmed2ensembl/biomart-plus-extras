# $Id: FASTAA.pm,v 1.3 2007-01-09 17:16:00 rh4 Exp $
#
# BioMart module for BioMart::Formatter::FASTAH
#
# You may distribute this module under the same terms as perl
# itself.

# POD documentation - main docs before the code.

=head1 NAME

BioMart::Formatter::FASTAA

=head1 SYNOPSIS

Formatter specicific to homologues 

FASTA A for  (Aligned)

The FASTA Formatter returns whitespace separated tabular data
for a BioMart query's ResultTable
This is a FASTA formatter for Compara_homology which is very specific 
for the compara_mart project

=head1 DESCRIPTION

When given a BioMart::ResultTable containing the results of 
a BioMart::Query the FASTA Formatter will return tabular output
with one line for each row of data in the ResultTable and single spaces
separating the individual entries in each row. The getDisplayNames
and getFooterText can be used to return appropiately formatted
headers and footers respectively

=head1 AUTHORS

=over

=item *
Damian Smedley
=item *
Benoit Ballester
=back

=head1 CONTACT

This module is part of the BioMart project
http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut

package BioMart::Formatter::FASTAA;

use strict;
use warnings;

# Extends BioMart::FormatterI
use base qw(BioMart::FormatterI);

# from CodonTable.pm in BioPerl
use vars qw(@NAMES @TABLES $TRCOL $CODONS %IUPAC_DNA 
	    $CODONGAP $GAP);# removed $TERMINATOR

# from CodonTable.pm in BioPerl
BEGIN { 
    use constant CODONSIZE => 3;
    #$GAP = '-';
    $CODONGAP = $GAP x CODONSIZE;

    @NAMES =			#id
	(
	 'Standard',		#1
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
    #$TERMINATOR = '*';
}
#--- END from bioperl / GenomicSequence.pm

sub _new {
    my ($self) = @_;

    $self->SUPER::_new();
}

sub processQuery {
    my ($self, $query) = @_;

    $self->set('original_attributes',[@{$query->getAllAttributes()}]) 
	if ($query->getAllAttributes());
    $self->set('query',$query);
    return $query;
}

sub nextRow {
    my $self = shift;

    my $rtable = $self->get('result_table');
    my $row = $rtable->nextRow;
    if (!$row){
        return;
    }
#    my $array_length = @{$row};
    
    #-- determine  which coordinate we are using
    my ($tag1, $tag2);
    my (@coorarray1, @coorarray2);
    my ($finalseq1, $finalseq2, $cigar1, $cigar2, $header_atts1, $header_atts2);

    my $k = 0;
    my $j = 0;
    foreach my $attribute  (@$row){
	#print "attribute: $attribute\n";
	if (not defined $attribute){$attribute = "NULL"}
	if ($attribute =~ m/tagPeptide/){
	    $j++;
	    if ($j == 1){
		#print " attribute1::  $attribute\n";
		@coorarray1 = split(/\|/, $attribute);
		$tag1  = shift (@coorarray1); # remove the tags
	    }
	    if ($j == 2){
		#print " attribute2::  $attribute\n";
		@coorarray2 = split(/\|/, $attribute);
		$tag2  = shift (@coorarray2);
	    }
	  }  
	$k++;
    } 
#    print "TAGS : $tag1 $tag2\n";
    if ($tag1 ne $tag2){return "Tag are not the same:".$tag1." - ".$tag2."\n\n";}
    
    #-- then format depending of the tag (cdna, peptide, etc.)
    if ($tag1  =~ m/tagPeptide/){
	
	($finalseq1, $finalseq2, $cigar1, $cigar2, $header_atts1, $header_atts2) = &formatseqPep($row);
	
	$finalseq1  = &_get_aligned_sequence_from_original_sequence_and_cigar_line($finalseq1, $cigar1);
	$finalseq2  = &_get_aligned_sequence_from_original_sequence_and_cigar_line($finalseq2, $cigar2);
	
	#-- format the seq whith a 60bp width
	$finalseq1 =~ s/(\S{60})/$1\n/g;
	$finalseq2 =~ s/(\S{60})/$1\n/g;
	
	#--  Then return the whole thing
	return ">" . $header_atts1 . "\n"
	    . $finalseq1 ."\n"
	    . ">" . $header_atts2 . "\n"
	    . $finalseq2 ."\n"
	    . "#\n";
    }else {
	return "tags not supported by the formater FASTAH.pm  tags(tag1:$tag1 tag2:$tag2)\n";
    }
}
#------------------
sub formatseqPep {
    my ($row)= shift;
    my ($finalseq1, $finalseq2, $header_atts1, $header_atts2, 
	$strand1, $strand2, $tag1, $tag2, $chro1, $chro2,
	$seqedits1, $seqedits2, $cigar1, $cigar2) ;
    my @atts1 = ();
    my @atts2 = ();
    my @coorarray = ();
    my @coorarray1;
    my @coorarray2;
    
    #--  get sequences
    my $seq1 = shift @$row;
    my $seq2 = shift @$row;

    my $i = 0 ;
    my $k = 0;
    my $j = 0;
    foreach my $attribute  (@$row){
	#print "attribute: $attribute\n";
	#-- Get the attributes 
	if (!$attribute){$attribute = "NULL"}
	if ($attribute eq "tagHeader"){
	    push (@atts1, $row->[$i+1]);
	    push (@atts2, $row->[$i+2]);
	}
	$i++;
	
	#-- Get the coordinates
	if ($attribute =~ /^(tagPeptide)/){
	    $j++;
	    if ($j == 1){
#		print " attribute1::  $attribute\n";
		@coorarray1 = split(/\|/, $attribute);
		$strand1 = $row->[$k+2];
		$seqedits1 = $row->[$k+4];
		$chro1 = $row->[$k+6];
		$cigar1 = $row->[$k+8];
		
	    }
	    if ($j == 2){
#		print " attribute2::  $attribute\n";
		@coorarray2 = split(/\|/, $attribute);
		$tag1  = shift (@coorarray1); # remove the tags
		$tag2  = shift (@coorarray2);
		$strand2 = $row->[$k+2];
		$seqedits2 = $row->[$k+4];
		$chro2 = $row->[$k+6];
		$cigar2 = $row->[$k+8];
	    }
	  }  
	$k++;
    } 

#    print "tag1:$tag1 strand1:$strand1 seqedits1:$seqedits1  chro1:$chro1\n";
#    print "tag2:$tag2 strand2:$strand2 seqedits2:$seqedits2  chro2:$chro2\n";

    
    #-- Chop the seq according to the given coordinate
    foreach my $coors1 (@coorarray1){
	    my @coor1 = split(/:/,$coors1);
	    $finalseq1 .= substr ($seq1, $coor1[0], $coor1[1]);
    }
    
    foreach my $coors2 (@coorarray2){
	    my @coor2 = split(/:/,$coors2);
	    $finalseq2 .= substr ($seq2, $coor2[0], $coor2[1]);
    }


    #-- RC the seq if needed !
    if ($strand1 < 0) {$finalseq1 = &rc($finalseq1);}
    if ($strand2 < 0) {$finalseq2 = &rc($finalseq2);}
	
    #-- Translated it
    $finalseq1 = &translate($finalseq1,$chro1);
    $finalseq2 = &translate($finalseq2,$chro2);

    #-- Post process the seq with seqedits
    if ($finalseq1 =~ /\*$/){ chop $finalseq1 }
    if ($finalseq2 =~ /\*$/){ chop $finalseq2 }
    
    #-- Apply seq edits if exists
    if ($seqedits1  ne 'NULL'){
	my @seqed = split (/\|/,$seqedits1);
	shift @seqed; #remove tag
	foreach my $se (@seqed) {
	    &apply_edit($se, \$finalseq1);
	}
    }
     if ($seqedits2  ne 'NULL'){
	 my @seqed = split (/\|/,$seqedits2);
	shift @seqed; #remove tag
	foreach my $se (@seqed) {
	    &apply_edit($se, \$finalseq2);
	}
    }
    
    #-- format the seq whith a 60bp width
#    $finalseq1 =~ s/(\w{60})/$1\n/g;
#    $finalseq2 =~ s/(\w{60})/$1\n/g;

    #-- Join the attributes together
    $header_atts1 = join ("|", @atts1);
    $header_atts2 = join ("|", @atts2);

    #--  Then return the whole thing
    return ($finalseq1, $finalseq2, $cigar1, $cigar2, $header_atts1, $header_atts2);
    
}

#---------------------
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
#----------------------
sub rc{
    my ($seq) = @_;

    $seq = reverse($seq);
    $seq =~ tr/YABCDGHKMRSTUVyabcdghkmrstuv/RTVGHCDMKYSAABrtvghcdmkysaab/;

    return $seq;
}
#----------------------
#----------------------
sub getDisplayNames {
    my $self = shift;
    return '';
}

sub isSpecial {
    return 1;
}
#------------------
sub apply_edit  {
    my $seqeds   = shift;
    my $seqref = shift;
    my @seqedits = split (/:/,$seqeds);
    
    #if(ref($seqref) ne 'SCALAR') {
    #  throw("Reference to scalar argument expected");
    #}
    
    if(!defined($seqedits[0]) || !defined($seqedits[1])) {
	return $seqref;
    }
    
    my $len = $seqedits[1] - $seqedits[0] + 1;
    substr($$seqref, $seqedits[0] - 1, $len) = $seqedits[2];
    
    return $seqref;
}
#-----------------------------------------
#-------From Bioperl CodonTable.pm -------
#-------Modified like GenomicSequence ----
sub translate {
    my ($seq, $chro) = @_;
    #warn("Calling translate without a seq argument!") unless defined $seq;
    return '' unless $seq;

    #my $id = $self->id;
    # 1 = vertebrate  2= Vertebrate Mitochondrial
    my $id;#my $id = '1'; # by default it's1
    if ($chro =~ /MT/g){$id = '2'}else{$id = '1'}
 
    my ($partial) = 0;
    $partial = 2 if length($seq) % CODONSIZE == 2;
    
    $seq = lc $seq;
    $seq =~ tr/u/t/;
    my $protein = "";
    if ($seq =~ /[^actg]/ ) { #ambiguous chars
        for (my $i = 0; $i < (length($seq) - (CODONSIZE-1)); $i+= CODONSIZE) {
            my $triplet = substr($seq, $i, CODONSIZE);
#	    if( $triplet eq $CODONGAP ) {
#		$protein .= $GAP;
#	    } els
	    if (exists $CODONS->{$triplet}) {
		$protein .= substr($TABLES[$id-1], 
				   $CODONS->{$triplet},1);
	    } else {
		$protein .= _translate_ambiguous_codon($triplet, $id);
	    }
	}
    } else { # simple, strict translation
	for (my $i = 0; $i < (length($seq) - (CODONSIZE -1)); $i+=CODONSIZE) {
            my $triplet = substr($seq, $i, CODONSIZE); 
#            if( $triplet eq $CODONGAP ) {
#		$protein .= $GAP;
#	    } 
	    if (exists $CODONS->{$triplet}) {
                $protein .= substr($TABLES[$id-1], $CODONS->{$triplet}, 1);
	    } else {
                $protein .= 'X';
            }
        }
    }
    if ($partial == 2) { # 2 overhanging nucleotides
	my $triplet = substr($seq, ($partial -4)). "n";
#	if( $triplet eq $CODONGAP ) {
#	    $protein .= $GAP;
#	} elsif (exists $CODONS->{$triplet}) {
	
	if (exists $CODONS->{$triplet}) {
	    my $aa = substr($TABLES[$id-1], $CODONS->{$triplet},1);       
	    $protein .= $aa;
	} else {
	    $protein .= _translate_ambiguous_codon($triplet, $id, $partial);
	}
    }
    return $protein;
}
#----------------------
sub _translate_ambiguous_codon {
    my ($triplet, $id, $partial) = @_;
    $partial ||= 0;
    #my $id = '1';
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
	} else {
	    $partial ? ($aa = '') : ($aa = 'X');
	}
    } else {
	$partial ? ($aa = '') :  ($aa = 'X');
    }
    return $aa;
}
#----------------------
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

1;
