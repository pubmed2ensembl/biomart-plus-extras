# $Id: FormatterI.pm,v 1.4 2008-04-09 12:52:33 syed Exp $
#
# BioMart module for BioMart::FormatterI
#
# You may distribute this module under the same terms as perl
# itself.

# POD documentation - main docs before the code.

=head1 NAME

BioMart::FormatterI

=head1 SYNOPSIS

TODO: Synopsis here.

=head1 DESCRIPTION

An abstract class for Formatters

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Richard Holland, Damian Smedley, Gudmundur Arni Thorisson


=head1 CONTACT

This module is part of the BioMart project
http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::FormatterI;

use strict;
use warnings;

# Extends BioMart::Root
use base qw(BioMart::Root);

use BioMart::Web::SiteDefs;

sub _new {
    my ($self) = @_;

    $self->SUPER::_new();
    $self->attr('query',undef);
    $self->attr('original_attributes',undef);
    $self->attr('result_table',undef);
    $self->attr('attribute_positions',undef);# for hyperlink processing
    $self->attr('attribute_url_positions',undef);# for hyperlink processing
    $self->attr('attribute_url',undef);# for hyperlink processing
    $self->attr('dataset1_end',undef);#for result table color highlighting
}

# must be implemented for every formatter implementation
sub processQuery {   
    my $self = shift;

    $self->unimplemented_method();
}

# must be implemented for every formatter implementation
sub nextRow {   
    my $self = shift;

    $self->unimplemented_method();
}

# must be implemented for every formatter implementation
sub getDisplayNames {   
    my $self = shift;

    $self->unimplemented_method();
}

# can be implemented in formatter implementations
sub getFooterText {   
    return undef;
}

sub resultTable {
    my ($self,$result_table) = @_;

    if ($result_table){
	$self->set('result_table',$result_table);
    }
    return $self->get('result_table');
}

sub getTextDisplayNames {
    my ($self,$separator) = @_;
    my $original_attributes = $self->get('original_attributes');
    my $final_dataset_order = $self->get('query')->finalDatasetOrder;
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
    return @attribute_display_names;
}

sub setHTMLAttributes {
    my ($self, $query) = @_;
    
    # add extra url attributes on query if required (eg) for HTML, XLS
   if($query->getAllAttributes())
   {

    my $registry = $query->getRegistry;
    my $attributes = [@{$query->getAllAttributes()}];
		foreach my $attribute (@$attributes){
			if ($attribute->link){	
			    my @link = split(/\|/,$attribute->link);
			    if (@link > 2){# multi attribute link
				for (my $i = 2; $i < @link; $i++){
				    next if ($link[$i] eq $attribute->name);
				    # skip broken hyperlink URL templates for now
				    # use long winded method call to avoid exception throwing
				    next if (!$query->getRegistry
					     ->getDatasetByName($query->virtualSchema, $attribute->dataSetName)
					     ->getConfigurationTree($attribute->interface)
					     ->getAttributeByName($link[$i]));
					if($query->get('currentDS') ne $attribute->dataSetName)
			     	{
						my $tempDS = $query->get('currentDS');
					  	$query->setDataset($attribute->dataSetName); 
					 	$query->addAttribute($link[$i], $attribute->interface);
					 	$query->setDataset($tempDS); 
					}
					else
					{
						$query->addAttribute($link[$i], $attribute->interface);
					}
				}		
	    		}
		}
    }


   # set @attribute_positions, @attribute_url_positions and and @attribute_url 
   # so nextRow can process hyperlinks

   my $final_dataset_order = $query->finalDatasetOrder;

   # establish the position of attributes and URL-only attributes in 
   # final ResultTable
   my $original_attributes = $self->get('original_attributes');
   my @attribute_positions;
   my @attribute_url_positions;
   my @attribute_url;

   my $att_counter = 0;
   my $extra_att_counter = 0;
   my $dataset_start = 0;
   my $extra_att_start = 0;
   
   foreach my $dataset(reverse @$final_dataset_order){
       my @original_dataset_attributes;
       foreach (@{$original_attributes}){
	   push @original_dataset_attributes,$_ 
	       if ($_->dataSetName eq $dataset);
       }

       $dataset_start =  $extra_att_start + $extra_att_counter;
       $extra_att_start = $dataset_start + @original_dataset_attributes;
       $att_counter = 0;
       $extra_att_counter = 0;
       
       foreach my $original_attribute(@original_dataset_attributes){
	   my @url_positions;
	   my @link;
	   if ($original_attribute->link){	
	       @link = split(/\|/,$original_attribute->link);
	       if (@link > 2){# multi attribute link
		    for (my $i = 2; $i < @link; $i++){
			# skip any that had broken links as above
			next if (!$query->getRegistry
			     ->getDatasetByName($query->virtualSchema,
						$original_attribute->dataSetName)
			     ->getConfigurationTree($original_attribute->interface)
			     ->getAttributeByName($link[$i]));


			if ($link[$i] eq $original_attribute->name){
			    push @url_positions, $dataset_start+$att_counter;
			}
			else{
			    push @url_positions, 
			        $extra_att_start+$extra_att_counter;
			    $extra_att_counter++;
			}		  
		    }
		}
	        else{
		    push @url_positions,$dataset_start+$att_counter;
	        }
	   }
	   else{
	       push @url_positions,$dataset_start+$att_counter;
	   }
	   
	   push @attribute_url_positions, \@url_positions;
	   push @attribute_positions, $dataset_start+$att_counter;

		# Check $link[0] to find out what kind of link
		# this is. Then, look up the prefix for links of that kind
		# in SiteDefs.pm. If found, prefix it. If not, leave as-is.
		#my %prefixes = BioMart::Web::SiteDefs->getSettings('urlPrefixes');
		my %prefixes;
		my $mart_registry = $query->getRegistry();
		my $hash = $mart_registry->settingsParams();
	     foreach(keys %$hash) {     	
		     if($_ eq "urlPrefixes") {
 			    	%prefixes = %{$hash->{$_}};
     		}
     	}
		my $resolvedLink = 
			$link[1]
			? 	(	
					(substr($link[1],0,1) eq '/')
					? $prefixes{$link[0]} . $link[1]
					: $link[1]
				)
			: $link[0];

	   push @attribute_url, $resolvedLink;
	   $att_counter++;
       }
    }
    
    $self->set('attribute_positions',\@attribute_positions);
    $self->set('attribute_url_positions',\@attribute_url_positions);
    $self->set('attribute_url',\@attribute_url);

    # set dataset1_end
    #my $original_attributes = $self->get('original_attributes');
 
    my @original_dataset_attributes;
    foreach my $dataset(reverse @$final_dataset_order){
	foreach (@{$original_attributes}){
	    push @original_dataset_attributes,$_ 
		if ($_->dataSetName eq $dataset);
	}
    }
    my ($first_dataset,$dataset1_end);
    foreach my $original_attribute(@original_dataset_attributes){
	my $dataset_name = $original_attribute->pointedFromDataset || 
	    $original_attribute->dataSetName;
	if ($first_dataset && $first_dataset ne $dataset_name){
	    $self->set('dataset1_end',$dataset1_end-1);
	    last;
	}
	$dataset1_end++;
	$self->set('dataset1_end',$dataset1_end-1);
	$first_dataset = $dataset_name;
    }
    }
    return $query;
}

sub getMimeType {
    return 'text/plain';
}

sub getFileType {
    return 'txt';
}

sub getFormatterDisplayName {
    return undef;
}


sub isBinary {
    return 0;
}

sub isSpecial {
    return 0;
}

1;




