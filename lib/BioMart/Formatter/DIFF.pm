# $Id: DIFF.pm,v 1.3 2007-10-16 16:03:17 ds5 Exp $
#
# BioMart module for BioMart::Formatter::DIFF
#
# You may distribute this module under the same terms as perl
# itself.

# POD documentation - main docs before the code.

=head1 NAME

BioMart::Formatter::DIFF

=head1 SYNOPSIS

The DIFF Formatter returns data formatted into a DIFF table
for a BioMart query's ResultTable

=head1 DESCRIPTION

When given a BioMart::ResultTable containing the results of 
a BioMart::Query the DIFF Formatter will return DIFF formatted tabular 
output. The getDisplayNames and getFooterText can be used to return 
appropiately formatted headers and footers respectively. If hyperlink
templates are defined for the attributes in the Dataset's ConfigurationTree
then appropiate hyperlinks will be calculated for each cell of the table.
Addition of any extra attributes to the Query that may be required for this
hyperlink formatting is handled in this Formatter

=head1 AUTHORS

=over

=item *
Damian Smedley

=item *
Gudmundur Thorisson

=back

=head1 CONTACT

This module is part of the BioMart project
http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut

package BioMart::Formatter::DIFF;

use strict;
use warnings;
use Readonly;

# Extends BioMart::FormatterI
use base qw(BioMart::FormatterI);

# DIFF templates
my $current_rowcount = 0; # keep track of number of rows printed out
Readonly my $FOOTER_TMPL => qq{</div>

</body>
</html>
};
Readonly my $HEADER_TMPL => q{<?xml version="1.0"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XDIFF 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
<head>
  <title>%s</title>
  <link rel="stylesheet" type="text/css" href="/martview/martview.css" />
</head>
<body>

<table>
};
Readonly my $ROW_START_TMPL1 => qq{<tr>\n};
Readonly my $ROW_START_TMPL2 => qq{<tr>\n};
Readonly my $HEADERFIELD_TMPL1     => qq{  <th>%s</th>\n};
Readonly my $HEADERFIELD_TMPL2    => qq{  <th>%s</th>\n};
Readonly my $NORMALFIELD_TMPL1     => qq{  <td %s</td>\n};
Readonly my $ROW_END_TMPL   => qq{</tr>\n};


sub _new {
    my ($self) = @_;

    $self->SUPER::_new();
    $self->attr('reference',0);
}

sub getFormatterDisplayName {
    return 'Diff to reference';
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


    $query = $self->setHTMLAttributes($query);
    $self->set('query',$query);
    return $query;
}

sub nextRow {
   my $self = shift;

   my $rtable = $self->get('result_table');

   # print the data with urls if available
   my $new_row;
   my $row = $rtable->nextRow;
   if (!$row){
       return;
   }
   map { $_ = q{} unless defined ($_); } @$row;
   my $attribute_positions = $self->get('attribute_positions');
   my $attribute_url_positions = $self->get('attribute_url_positions');
   my $attribute_url = $self->get('attribute_url');

   #my $dataset1_end = $self->get('dataset1_end');

   my $reference;

   if ($self->get('reference')){
       $reference = $$row[$$attribute_positions[-1]];
   
       if (!$reference){
	   return "\n";
       }
   }
   my $result_seen;

   for (my $i = 0; $i < @{$attribute_positions}; $i++){


       if (($i != @{$attribute_positions} - 1) && ($$row[$$attribute_positions[$i]] eq $reference) && $$row[$$attribute_positions[$i]] && $reference){
          $$row[$$attribute_positions[$i]] = '';
       }

       if ($reference){
	   $result_seen = 1 if ($$row[$$attribute_positions[$i]] =~ /^[ACGT]$/ && ($i != @{$attribute_positions} - 1));  
       }
       else{
	   $result_seen = 1;
       }

       if ($$row[$$attribute_positions[$i]] eq 'C'){
	   $$row[$$attribute_positions[$i]] = qw(bgcolor="yellow">).'C';
       }
       elsif ($$row[$$attribute_positions[$i]] eq 'G'){
           $$row[$$attribute_positions[$i]] = qw(bgcolor="green">).'G';
       }
       elsif ($$row[$$attribute_positions[$i]] eq 'A'){
           $$row[$$attribute_positions[$i]] = qw(bgcolor="red">).'A';
       }
       elsif ($$row[$$attribute_positions[$i]] eq 'T'){
           $$row[$$attribute_positions[$i]] = qw(bgcolor="orange">).'T';
       }


       else{
	   $$row[$$attribute_positions[$i]] = qw(>).$$row[$$attribute_positions[$i]];
       }

	   


       if ($$attribute_url[$i]){
	   my @url_data = map {$$row[$_]} @{$$attribute_url_positions[$i]};
	   my $url_string = sprintf($$attribute_url[$i],@url_data);
	   $url_string =~ s/>//g;
	   push @{$new_row}, '<a href="'.$url_string.'" target="_blank"'.
	       $$row[$$attribute_positions[$i]]."</a>";
       }
       else{
	   push @{$new_row},$$row[$$attribute_positions[$i]];
       }
   }
   


   if ($result_seen){
       $current_rowcount++;
       my $fields_string = '';
       map{ $fields_string .= sprintf ($NORMALFIELD_TMPL1, defined ($_) ? $_ : ''); } @{$new_row};
       return ($current_rowcount % 2 == 0 ? $ROW_START_TMPL1 : $ROW_START_TMPL2)
	                              . $fields_string
                                      . $ROW_END_TMPL;
   }
   else{
       return "\n";
   }
}

sub getDisplayNames {
    my $self = shift;

    my $original_attributes = $self->get('original_attributes');
    my $dataset1_end = $self->get('dataset1_end');
    my $query = $self->get('query');
    my $registry = $query->getRegistry;
    my $final_dataset_order = $query->finalDatasetOrder;
    
    my @attribute_display_names;
    my @original_dataset_attributes;
    foreach my $dataset(reverse @$final_dataset_order){
	foreach (@{$original_attributes}){
	    push @original_dataset_attributes,$_ 
		if ($_->dataSetName eq $dataset);
	}
    }
    foreach my $original_attribute(@original_dataset_attributes){
	push @attribute_display_names, $original_attribute->displayName;
    }
    if ($self->get('reference')){
	$attribute_display_names[-1] .= " (Reference)";
    }
    # print the display names    
    my $header_string = sprintf $HEADER_TMPL, '';
    $header_string .= $ROW_START_TMPL1;
#    map{ $header_string .= 
#	     sprintf $HEADERFIELD_TMPL, $_ } @attribute_display_names;
    map{ $header_string .= sprintf $HEADERFIELD_TMPL1, $_ } @attribute_display_names[0..$dataset1_end];
    map{ $header_string .= sprintf $HEADERFIELD_TMPL2, $_ } @attribute_display_names[$dataset1_end+1..@attribute_display_names-1];
    $header_string .= $ROW_END_TMPL;
    return $header_string;
}

# Override empty-string returning method in superclass, to return proper 
# table- and document-closing tags (to keep DIFF valid).
sub getFooterText {   
    return q{
</table>
</body>
</html>
};
}

sub getMimeType {
    return 'text/html';
}


1;
