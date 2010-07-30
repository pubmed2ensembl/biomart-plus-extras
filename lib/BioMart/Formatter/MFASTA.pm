#
# BioMart module for BioMart::Formatter::MFASTA
#
# You may distribute this module under the same terms as perl
# itself.

# POD documentation - main docs before the code.

=head1 NAME

BioMart::Formatter::MFASTA

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
Benoit Ballester
Damian Smedley
Arek Kasprzyk

=back

=head1 CONTACT

This module is part of the BioMart project
http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut

package BioMart::Formatter::MFASTA;

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
    #my @row = \@{$row};
    #map { $_ ||= ''; } @$row; # get rid of unitialized-value warning message
    #return @{$row}."\n";
    my $array_length = @{$row};
    
    
    
#    my $header_atts = join "|",@{$row}[1..5];
#    #chop $header_atts;
#    my $seq = ${$row}[0];
#    $seq =~ s/(\w{60})/$1\n/g;
#    
#    print ">" . $header_atts . "\n"
#	    . $seq ."\n";
 #   
 #   my $header_atts2 = join "|",@{$row}[7..12];
 ##   chop $header_atts2;
 #   my $seq2 = ${$row}[6];
  #  $seq2 =~ s/(\w{60})/$1\n/g;
  #  
#   print ">>" . $header_atts2 . "\n"
	#    . $seq2 ."\n";  
    
  
#   print "##\n";
    my $output;
    
    until ($array_length == 0){

	my $header_atts = join "|",@{$row}[1..5];
	#chop $header_atts;
	my $seq = @{$row}[0];
	$seq =~ s/(\w{60})/$1\n/g;
	$output .= ">" . $header_atts . "\n". $seq ."\n";
	#return ">" . $header_atts . "\n". $seq ."\n";
	
	for (0..5){shift @{$row};}
	#print "nb after shift : ".@{$row}."\n";
	$array_length = $array_length - 6 ;
   }
    if ($array_length == 0){
        $output .= "##\n";
    }

    return $output;

    #my $array_length = @{$row};
    #map { $_ ||= ''; } @$row; # get rid of unitialized-value warning message
    #my $header_atts = join "|",@{$row}[1..$array_length-1];
    #chop $header_atts;
    #my $seq = ${$row}[0];
    #$seq =~ s/(\w{60})/$1\n/g;
    #return ">" . $header_atts . "\n"
    #. $seq ."\n";
}

sub getDisplayNames {
    my $self = shift;

    return '';
}

sub isSpecial {
    return 1;
}

1;



