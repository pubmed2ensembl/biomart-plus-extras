# $Id: HTML.pm,v 1.9 2008/04/09 12:52:34 syed Exp $
#
# BioMart module for BioMart::Formatter::HTML
#
# You may distribute this module under the same terms as perl
# itself.

# POD documentation - main docs before the code.

=head1 NAME

BioMart::Formatter::HTML

=head1 SYNOPSIS

The HTML Formatter returns data formatted into a HTML table
for a BioMart query's ResultTable

=head1 DESCRIPTION

When given a BioMart::ResultTable containing the results of 
a BioMart::Query the HTML Formatter will return HTML formatted tabular 
output. The getDisplayNames and getFooterText can be used to return 
appropiately formatted headers and footers respectively. If hyperlink
templates are defined for the attributes in the Dataset's ConfigurationTree
then appropiate hyperlinks will be calculated for each cell of the table.
Addition of any extra attributes to the Query that may be required for this
hyperlink formatting is handled in this Formatter

=head1 AUTHOR -  Syed Haider, Damian Smedley, Gudmundur Thorisson


=head1 CONTACT

This module is part of the BioMart project
http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut

package BioMart::Formatter::HTML;

use strict;
use warnings;
use Readonly;

# Extends BioMart::FormatterI
use base qw(BioMart::FormatterI);

# HTML templates
my $current_rowcount = 0; # keep track of number of rows printed out
my $last_rowfirstcolumn = ""; # refers to the last seen row data, first column only..
my $last_rowtemplate = 0; # index in @ROW_START_TMPLS of the last used template
Readonly my $FOOTER_TMPL => qq{</div>

</body>
</html>
};
Readonly my $HEADER_TMPL => q{<?xml version="1.0"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
<head>
  <title>%s</title>
  <link rel="stylesheet" type="text/css" href="/martview/martview.css" />
</head>
<body>

<table>
};
Readonly my $ROW_START_TMPL1 => qq{<tr style="background-color: #f0f0ff;">\n};
Readonly my $ROW_START_TMPL2 => qq{<tr style="background-color: #cacaef;">\n};
Readonly my $HEADERFIELD_TMPL1     => qq{  <th>%s</th>\n};
Readonly my $HEADERFIELD_TMPL2    => qq{  <th>%s</th>\n};
Readonly my $NORMALFIELD_TMPL1     => qq{  <td>%s</td>\n};
Readonly my $ROW_END_TMPL   => qq{</tr>\n};

Readonly my @ROW_START_TMPLS => ( $ROW_START_TMPL1, $ROW_START_TMPL2 );

sub format_excerpt {

	my ($excerpt_formatted, @excerpt_words) = @_;
	my $word_counter = 0;

	$excerpt_formatted = $excerpt_formatted."...";

	foreach my $excerpt_word (@excerpt_words) {

		$excerpt_formatted = $excerpt_formatted.$excerpt_word;
		$word_counter = $word_counter + 1;

		if ($word_counter <= $#excerpt_words) {

			$excerpt_formatted = $excerpt_formatted." ";

		}

	}

	$excerpt_formatted = $excerpt_formatted."...";

}

sub _new {
    my ($self) = @_;

    $self->SUPER::_new();  
}


sub processQuery {
    my ($self, $query) = @_;
    $self->set('original_attributes',[@{$query->getAllAttributes()}]) 
	if ($query->getAllAttributes());
    $query = $self->setHTMLAttributes($query);
    $self->set('query',$query);
    return $query;
}

sub nextRow {
   my $self = shift;

   my $query = $self->get('query');
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
   #my $filterColumn = $self->{'esearchFilterColumn'};
   #my @filterValues = split (/, /, $self->{'esearchFilterString'});

   #my $dataset1_end = $self->get('dataset1_end');

   for (my $i = 0; $i < @{$attribute_positions}; $i++){

#	   if ($i == $filterColumn) {

#		my $currentValue = $$row[$$attribute_positions[$i]];

#		chomp($currentValue);

#		${$query->{'esearchBag'}}{ $currentValue } = "1";

#	   }

       # superscripting for emma mart
       $$row[$$attribute_positions[$i]] =~ s/\<(.*)\>/<span style="vertical-align:super;font-size:0.8em">$1<\/span>/;
	   
       if ($$attribute_url[$i]){
	   my @url_data = map {$$row[$_]} @{$$attribute_url_positions[$i]};
	   my $url_string;
	   if ($$attribute_url[$i] =~ m/^(list:)/i) {
	       my $attr_url = substr($$attribute_url[$i], 5);
	       my @items;
	       if ($$row[$$attribute_positions[$i]] =~ m/,&thinsp;/) {
	           @items = split(',&thinsp;', $$row[$$attribute_positions[$i]]);
	       } else {
		   @items = split(',', $$row[$$attribute_positions[$i]]);
	       }
	       my $html_string = "";
	       foreach(@items) {
		   $url_string = sprintf($attr_url,$_);
	           $html_string = $html_string.', <a href="'.$url_string.'" target="_blank">'.$_."</a>";
	       }
	       push @{$new_row}, '<div style="width: 200px;">'.substr($html_string, 2)."</div>";
	   } elsif ($$attribute_url[$i] =~ m/^(coloring:max=)/i) {
	       my $max_value = substr($$attribute_url[$i], 13);
	       my $ratio = $url_data[0] / $max_value;
	       if ($ratio > 1 || $ratio < 0) {
	           $ratio = 1;
	       }
	       my @new_data = ( $ratio ** 7 * 255, 0, 255 - $ratio ** 7 * 255, @url_data );
	       $url_string = sprintf("<div style=\"color: #%02x%02x%02x; width: 40px;\">%s</div>", @new_data);
	       push @{$new_row}, $url_string;
	   } elsif ($$attribute_url[$i] =~ m/^(coloring:min=)/i) {
	       my $min_value = substr($$attribute_url[$i], 13);
	       my $ratio = 1;
	       if ($url_data[0] != 0 && $url_data[0] < $min_value) {
		   $ratio = $url_data[0] / $min_value;
	       }
	       my @new_data = ( 255 - $ratio ** 7 * 255, 0, $ratio ** 7 * 255, @url_data );
	       $url_string = sprintf("<div style=\"color: #%02x%02x%02x; width: 40px;\">%s</div>", @new_data);
	       push @{$new_row}, $url_string;
   	   } elsif ($$attribute_url[$i] =~ m/^(pmcconversion:)/i) {
	       my $attr_url = substr($$attribute_url[$i], 14);
	       if ($$row[$$attribute_positions[$i]] =~ m/\|/i) {
	           my @items = split('\|', $$row[$$attribute_positions[$i]]);
		   $url_string = sprintf($attr_url, substr($items[0], 3));
		   my $max_idx = 6;
		   my @excerpts = @items[2..($max_idx<$#items?$max_idx:$#items)];
		   my $excerpt_formatted;
		   foreach my $excerpt_item (@excerpts) {
		       my $excerpt = $excerpt_item; # substr($excerpt_item, 1, -1);
		       $excerpt =~ s/\'/&rsquo\;/g;
		       $excerpt =~ s/\"/&quot\;/g;
		       $excerpt =~ s/$items[1]/<b>$items[1]<\/b>/g;
		       my @excerpt_words = split('&nbsp;', $excerpt);
		       if (!($excerpt_formatted eq "")) {
		           $excerpt_formatted = $excerpt_formatted."<br><br>";
		       }
		       $excerpt_formatted = format_excerpt($excerpt_formatted, @excerpt_words);
		   }
		   if ($max_idx < $#items) {
		       $excerpt_formatted = $excerpt_formatted."<br><br>(".($#items - $max_idx)." more)";
	           }
		   push @{$new_row}, '<a href="'.$url_string.'" target="_blank" '.
		       'onmouseover="Tip(\'<i>'.$excerpt_formatted.'</i>\', OPACITY, 92, WIDTH, -400, TITLE, \''.$items[1].'\')" '.
		       'onmouseout="UnTip()">'.$items[0]."</a>";
	       } else {
		   $url_string = sprintf($attr_url, substr($$row[$$attribute_positions[$i]], 3));
		   push @{$new_row}, '<a href="'.$url_string.'" target="_blank">'.
		       $$row[$$attribute_positions[$i]]."</a>";
	       }
           } elsif ($$attribute_url[$i] =~ m/^(pmconversionlist:)/i) {
	       my $attr_url = substr($$attribute_url[$i], 17);
	       my @list_items = split(',&thinsp;', $$row[$$attribute_positions[$i]]);
	       my $html_string = "";
	       foreach my $list_item (@list_items) {
	           if ($list_item =~ m/\|/i) {
		       my @items = split('\|', $list_item);
		       my $url_string = sprintf($attr_url, $items[0]);
		       my $max_idx = 6;
		       my @excerpts = @items[2..($max_idx<$#items?$max_idx:$#items)];
		       my $excerpt_formatted = "";
		       foreach my $excerpt_item (@excerpts) {
		           my $excerpt = $excerpt_item;
			   $excerpt =~ s/\'/&rsquo\;/g;
			   $excerpt =~ s/\"/&quot\;/g;
			   $excerpt =~ s/$items[1]/<b>$items[1]<\/b>/g;
			   my @excerpt_words = split('&nbsp;', $excerpt);
			   if (!($excerpt_formatted eq "")) {
			       $excerpt_formatted = $excerpt_formatted."<br><br>";
		           }
                           $excerpt_formatted = format_excerpt($excerpt_formatted, @excerpt_words);
		       }
		       if ($max_idx < $#items) {
		           $excerpt_formatted = $excerpt_formatted."<br><br>(".($#items - $max_idx)." more)";
		       }

		       $html_string = $html_string.', <a href="'.$url_string.'" target="_blank" '.
		           'onmouseover="Tip(\'<i>'.$excerpt_formatted.'</i>\', OPACITY, 92, WIDTH, -400, TITLE, \''.$items[1].'\')" '.
			   'onmouseout="UnTip()">'. $items[0]."</a>";
                   } else {
			   $url_string = sprintf($attr_url, $list_item);
			   $html_string = $html_string.', <a href="'.$url_string.'" target="_blank">'.$list_item."</a>";
		   }
	       }
               push @{$new_row}, '<div style="width: 200px;">'.substr($html_string, 2)."</div>";
	   } elsif ($$attribute_url[$i] =~ m/^(pmcconversionlist:)/i) {
               my $attr_url = substr($$attribute_url[$i], 18);
	       my @list_items = split(',&thinsp;', $$row[$$attribute_positions[$i]]);
	       my $html_string = "";
	       foreach my $list_item (@list_items) {
		   if ($list_item =~ m/\|/i) {
		       my @items = split('\|', $list_item);
		       my $url_string = sprintf($attr_url, substr($items[0], 3));
		       my $max_idx = 6;
		       my @excerpts = @items[2..($max_idx<$#items?$max_idx:$#items)];
		       my $excerpt_formatted = "";
		       foreach my $excerpt_item (@excerpts) {
		           my $excerpt = $excerpt_item; # substr($excerpt_item, 1, -1);
			   $excerpt =~ s/\'/&rsquo\;/g;
			   $excerpt =~ s/\"/&quot\;/g;
			   $excerpt =~ s/$items[1]/<b>$items[1]<\/b>/g;
			   my @excerpt_words = split('&nbsp;', $excerpt);
			   if (!($excerpt_formatted eq "")) {
			       $excerpt_formatted = $excerpt_formatted."<br><br>";
		           }
			   $excerpt_formatted = format_excerpt($excerpt_formatted, @excerpt_words);
		       }
                       if ($max_idx < $#items) {
		           $excerpt_formatted = $excerpt_formatted."<br><br>(".($#items - $max_idx)." more)";
		       }

	               $html_string = $html_string.', <a href="'.$url_string.'" target="_blank" '.
		           'onmouseover="Tip(\'<i>'.$excerpt_formatted.'</i>\', OPACITY, 92, WIDTH, -400, TITLE, \''.$items[1].'\')" '.
			   'onmouseout="UnTip()">'. $items[0]."</a>";
	           } else {
		       $url_string = sprintf($attr_url, substr($list_item, 3));
		       $html_string = $html_string.', <a href="'.$url_string.'" target="_blank">'.$list_item."</a>";
	           }
	       }
	       push @{$new_row}, '<div style="width: 200px;">'.substr($html_string, 2)."</div>";
           } else {
	       # unknown attribute
	       my @url_data = map {$$row[$_]} @{$$attribute_url_positions[$i]};
               my $url_string = sprintf($$attribute_url[$i],@url_data);
               push @{$new_row}, '<a href="'.$url_string.'" target="_blank">'.
                   $$row[$$attribute_positions[$i]]."</a>";
	   }
       }
       else{
	   push @{$new_row},$$row[$$attribute_positions[$i]];
       }
   } # end for

   $current_rowcount++;
   my $fields_string = '';
   map{ $fields_string .= sprintf ($NORMALFIELD_TMPL1, defined ($_) ? $_ : ''); } @{$new_row};

   if ($current_rowcount < 2){
       $last_rowtemplate = 0;
   }

   if ($current_rowcount > 1 && !($last_rowfirstcolumn eq $$row[$$attribute_positions[0]])){
       $last_rowtemplate++;
       $last_rowtemplate %= 2;
   }

   $last_rowfirstcolumn = $$row[$$attribute_positions[0]];
   return $ROW_START_TMPLS[$last_rowtemplate % 2] . $fields_string . $ROW_END_TMPL;

   return ($current_rowcount % 2 == 0 ? $ROW_START_TMPL1 : $ROW_START_TMPL2)
	                              . $fields_string
                                      . $ROW_END_TMPL;
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

    # print the display names    
    my $header_string = sprintf $HEADER_TMPL, '';
    
    $self->{'esearchFilterString'} = $query->{'esearchFilterString'};

    $header_string .= $ROW_START_TMPL1;
#    map{ $header_string .= 
#	     sprintf $HEADERFIELD_TMPL, $_ } @attribute_display_names;
    map{ $header_string .= sprintf $HEADERFIELD_TMPL1, $_ } @attribute_display_names[0..$dataset1_end];
    map{ $header_string .= sprintf $HEADERFIELD_TMPL2, $_ } @attribute_display_names[$dataset1_end+1..@attribute_display_names-1];

    $header_string .= $ROW_END_TMPL;
    print STDERR $header_string;
    return $header_string;
}

# Override empty-string returning method in superclass, to return proper 
# table- and document-closing tags (to keep HTML valid).
sub getFooterText {   
    $current_rowcount = 0; 
    $last_rowfirstcolumn = "";
    $last_rowtemplate = 0; 

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
