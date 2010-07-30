
# BioMart module for BioMart::Formatter::ADF
#
# You may distribute this module under the same terms as perl
# itself.

# POD documentation - main docs before the code.

=head1 NAME

BioMart::Formatter::ADF

=head1 SYNOPSIS

The ADF Formatter returns ADF Formatter data for a BioMart query

=head1 DESCRIPTION

The ADF Formatter first of all removes any user chosen attributes from
the BioMart::Query object and adds the appropiate attributes required
for ADF data calculation. These attributes are defined in 'adf' exportables
for the Dataset being processed. After this initial processing the query is 
run and the ResultTable is processed row by row to calculate the correct
structural data for ADF output

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


package BioMart::Formatter::ADF;

use strict;
use warnings;

# Extends BioMart::FormatterI
use base qw(BioMart::FormatterI);

sub _new {
    my ($self) = @_;

    $self->SUPER::_new();
}

 # overrides the same method from FormatterI
sub processQuery {
    my ($self, $query) = @_;

    $self->set('original_attributes',[@{$query->getAllAttributes()}]) 
	if ($query->getAllAttributes());
    # get exportable for terminal dataset from registry and set (attributes) 
    # on it and remove existing attribute - then set the list - may want a 
    # general method on FormatterI for doing all the rigid ones

    my $final_dataset_order = $query->finalDatasetOrder();
    my $registry = $query->getRegistry();
    
    # remove all attributes from query
    $query->removeAllAttributes();

    foreach my $dataset_name(reverse @$final_dataset_order){	
	my $dataset = $registry->getDatasetByName($query->virtualSchema,
						  $dataset_name);
	if ($dataset->getExportables('adf',
		  $query->getInterfaceForDataset($dataset_name))){

	    # add the attribute corresponding to the id list being used
	    # if id list not set set error
	    
	    my $id_list_filter;
	    my $dset_filters = $query->getAllFilters($dataset_name);
	    foreach my $dset_filter (@{$dset_filters}){
		if ($dset_filter->multipleValues eq '1') {
		    $id_list_filter = $dset_filter;
                    last;
	        }
	    }
	    if ($id_list_filter){			     
		my $attribute_entry = $id_list_filter->attribute;
		$query->addAttributeWithoutLinking($attribute_entry) if ($attribute_entry);
	    }
	    else{
		BioMart::Exception::Usage->throw("ADF format can only be used with uploaded IDs");
	    }

	    my $attribute_list = $dataset->getExportables('adf',
		      $query->getInterfaceForDataset($dataset_name));
	    $query->addAttributes($attribute_list->getAllAttributes);

	    last;
	}
    }
    if (!$query->getAllAttributes()){
	BioMart::Exception::Usage->throw("ADF format not applicable for this dataset");
    }
    $self->set('query',$query);
    return $query;
}

sub resultTable {
    my ($self,$result_table) = @_;
    if ($result_table){
	# ADF has to produce 1 row for every uploaded ID
        # hence rejig resultTable at this stage so nextRow call
	# just returns the reformatted row
	my $new_result_table = BioMart::AttributeTable->new();
	my %results;
	while (my $row = $result_table->nextRow){
	    # need to concatenate gene, transcript and family ids as well
	    if ($results{$$row[0]}){
		my @entries;
		if ($results{$$row[0]} !~ /$$row[2]/){# new transcript
		    chop $results{$$row[0]};
		    @entries = split(/\t/,$results{$$row[0]});
		    for (my $k=1; $k <= @entries; $k++){
			$entries[$k] .= ';'.$$row[$k] if ($$row[$k] ne $entries[$k]);
		    }
		    $results{$$row[0]} = join("\t",@entries);
		}
		
	    }
	    else{
		$results{$$row[0]} = join("\t",@$row);
	    }
	}
	
	my @id_filter_list;
	my $query = $self->get('query');
	my $final_dataset_order = $query->finalDatasetOrder();
	my $registry = $query->getRegistry();

	foreach my $dataset_name(reverse @$final_dataset_order){	
	    my $dataset = $registry->getDatasetByName($query->virtualSchema,
						  $dataset_name);
	    if ($dataset->getExportables('adf',
		  $query->getInterfaceForDataset($dataset_name))){

		my $dset_filters = $query->getAllFilters($dataset_name);
		foreach my $dset_filter (@{$dset_filters}){
		    if ($dset_filter->multipleValues eq '1') {
			my $val_table = $dset_filter->getTable;
			my $rows = $val_table->getRows();
			foreach my $row (@{$rows}){
			    next unless (defined($$row[0]));#avoid NULL entries
				push @id_filter_list, $$row[0];
			}
			last;
		    }
		}
	    }
	}

	foreach (@id_filter_list){
	    if ($results{$_}){
		$new_result_table->addRow([$results{$_}]);
	    }
	    else{
		$new_result_table->addRow([$_]);
	    }
	}

	$self->set('result_table',$new_result_table);
    }
    return $self->get('result_table');
}

sub nextRow {
    my $self = shift;

    my $rtable = $self->get('result_table');
    my $row = $rtable->nextRow;
    if (!$row){
        return;
    }
    return $$row[0]."\n";
}


sub getDisplayNames {
    my $self = shift;

    my $atts = $self->get('query')->getAllAttributes;
    my $header = "Reporter Name\t";
    foreach my $att(@{$atts}){
	$header .= "Reporter BioSequence Database Entry [".$att->displayName."]\t";
    }
    return "$header\n";
}

sub isSpecial {
    return 1;
}


1;



