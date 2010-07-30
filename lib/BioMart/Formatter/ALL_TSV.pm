# $Id: ALL_TSV.pm,v 1.2 2007-10-02 11:43:32 ds5 Exp $
#
# BioMart module for BioMart::Formatter::ALL_TSV
#
# You may distribute this module under the same terms as perl
# itself.

# POD documentation - main docs before the code.

=head1 NAME

BioMart::Formatter::ALL_TSV

=head1 SYNOPSIS

The ALL_TSV Formatter returns tab separated tabular data
for a BioMart query's ResultTable

=head1 DESCRIPTION

When given a BioMart::ResultTable containing the results of 
a BioMart::Query the ALL_TSV Formatter will return tabular output
with one line for each row of data in the ResultTable and tabs
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

package BioMart::Formatter::ALL_TSV;

use strict;
use warnings;

# Extends BioMart::FormatterI
use base qw(BioMart::FormatterI);
use Readonly;

# Constants
Readonly my $FIELD_DELIMITER  => qq{\t};
Readonly my $RECORD_DELIMITER => qq{\n};

sub _new {
    my ($self) = @_;

    $self->SUPER::_new();
    $self->attr('reference',0);
}

sub getFormatterDisplayName {
    return 'All SNPs (tab separated)';
}


sub processQuery {
    my ($self, $query) = @_;

    my $filters = $query->getAllFilters();
    my @filts;
    foreach my $filter(@{$filters}){
        if ($filter->name eq 'reference_strain'){
            my $rows = $filter->get('attribute_table')->getRows();
            my $ref_strain = ${$$rows[0]}[0];
            # remove the filter

	$ref_strain =~ s/\//\_/g;
	$ref_strain =~ s/ /\_/g;
	$ref_strain =~ s/\+/\_/g;
	$ref_strain =~ s/\./\_/g;
	$ref_strain =~ s/\-/\_/g;
	$query->addAttribute(lc($ref_strain));
	$self->set('reference',1);
    }
    else{
	push @filts,$filter;
    }
}
$query->removeAllFilters();
$query->addFilters(\@filts);


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

    my $reference;
    if ($self->get('reference')){
	$reference= $$row[-1];

	if (!$reference){
	    return "\n";
	}
    }
    my $result_seen;


    # Escape delimiters in value-strings
    for (my $i = 0; $i < @{$row}; $i++) {

	if ($reference){
	    $result_seen = 1 if ($$row[$i] =~ /^[ACGT]$/ && ($i != @{$row} - 1));
	}
	else{
	    $result_seen = 1 if ($$row[$i] =~ /^[ACGT]$/ );
	}


	$$row[$i] = q{} unless defined ($$row[$i]);
	$$row[$i] =~ s/$FIELD_DELIMITER/\$FIELD_DELIMITER/g;
    }
    if ($result_seen){
	# Create the final record-string
	return join($FIELD_DELIMITER, @{$row}) . $RECORD_DELIMITER;
    }
    else{
	return "\n";
    }
}

sub getDisplayNames {
    my $self = shift;
    my @displayNames = $self->getTextDisplayNames();

    if ($self->get('reference')){
        $displayNames[-1] .= " (Reference)";
    }


    # Enclose non-numeric values in double quotes & escape the quotes already in them
    map { s/$FIELD_DELIMITER/\$FIELD_DELIMITER/g } @displayNames;
    
    # Create the final header string
    return join($FIELD_DELIMITER, @displayNames) . $RECORD_DELIMITER;
}

1;



