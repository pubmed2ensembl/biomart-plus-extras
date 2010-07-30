# $Id: FASTACDNA.pm,v 1.2 2006-11-25 18:11:31 arek Exp $
#
# BioMart module for BioMart::Formatter::FASTACDNA
#
# You may distribute this module under the same terms as perl
# itself.

# POD documentation - main docs before the code.

=head1 NAME

BioMart::Formatter::FASTACDNA

=head1 SYNOPSIS

The FASTA Formatter returns whitespace separated tabular data
for a BioMart query's ResultTable


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

=back

=head1 CONTACT

This module is part of the BioMart project
http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut

package BioMart::Formatter::FASTACDNA;

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
    
     
    #my $array_length = @{$row};
    my ($OUTPUT, $SEQOUT, $tot,$firstexonstart);

    my $seq = ${$row}[0];
    my $structure = ${$row}[1];
    my $strand = ${$row}[2];
    my @exons = split(/\|/, $structure);
       
    #- reverse the array in the right order if strand -1
    if ($strand < 0){ @exons = reverse @exons}
    
    
    foreach my $exon (@exons){
	#print "$exon\n";
	my ($start, $end, $strand, $phase) = split (/:/,$exon);
	if (!$firstexonstart) {$firstexonstart = $start;}
	print "firstexonstart: $firstexonstart\n";
	
	#$firstexonstart = "178090562";
	my $tmp_start = $start - $firstexonstart ;print "tmp_start: $tmp_start\n";
	my $tmp_end = $end - $firstexonstart +1 ;print "tmp_end: $tmp_end\n";
	my $length =  $end - $start +1 ;

	$SEQOUT .=  substr($seq,$tmp_start,$length);
	#print "length: $length\n";
	#$tot += $length ;


    }
    #print "tot: $tot\n";

    
    my @tab = split (//,$SEQOUT);
    my $size = @tab ;
    if ($strand < 0){$SEQOUT = &rc($SEQOUT)}
    return $SEQOUT."\n";
    
    #map { $_ ||= ''; } @$row; # get rid of unitialized-value warning message
    #my $header_atts = join "|",@{$row}[1..$array_length-1];
    #chop $header_atts;
    #my $seq = ${$row}[0];
    #$seq =~ s/(\w{60})/$1\n/g;
    #return ">" . $header_atts . "\n"
#	       . $seq ."\n";
}
sub rc{
    my ($seq) = shift;
    #warn "Enter _rc\n";
    $seq = reverse($seq);
    $seq =~ tr/YABCDGHKMRSTUVyabcdghkmrstuv/RTVGHCDMKYSAABrtvghcdmkysaab/;
    return $seq;
}
sub getDisplayNames {
    my $self = shift;

    return '';
}

sub isSpecial {
    return 1;
}

1;



