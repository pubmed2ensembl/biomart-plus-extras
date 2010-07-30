#!/usr/bin/perl -w

#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

A simple BioMart SOAP service CGI script 
requests: registry, dataset names, dataset configuration and query results

=head1 AUTHOR - Syed Haider
=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut

use SOAP::Transport::HTTP;

#---------------------------------------------------------#
# SOAP webservice dispatch directives
	SOAP::Transport::HTTP::CGI   
		-> dispatch_to('MartServiceSoap')     
		-> handle;

# MartService Soap based Implementation
#---------------------------------------------------------#

package MartServiceSoap;

use strict;
use warnings;
use Config;
use Readonly;

use XML::Simple qw(:strict);
use CGI;
use POSIX qw(strftime);
use Log::Log4perl;
use File::Basename qw(&basename &dirname);
use BioMart::Initializer;
use BioMart::Query;
use BioMart::AttributeTable;
use BioMart::QueryRunner;
use BioMart::ResultTable;
use BioMart::Exception;
use Data::Dumper;

use base qw(SOAP::Server::Parameters);

#the TAG:lib below gets replaced by OPTIONS{lib}, from user's PERL5LIB
[TAG:lib]

sub getConfPath {
	#the TAG:conf below gets replaced by OPTIONS{conf}, path to registry file
	my [TAG:conf]
	return $CONF_FILE;
}

sub getServerHost {
	#the TAG:server_host below gets replaced by OPTIONS{server_host}
	my [TAG:server_host]
	return $server_host;
}

sub getServerPort {
	#the TAG:server_port below gets replaced by OPTIONS{server_port}
	my [TAG:server_port]
	return $server_port;
}

sub getLogDir {
	#the TAG:log_dir below gets replaced by path to log dir
	my [TAG:log_dir]
	return $log_Dir;
}

sub getCGILocation {
	#the TAG:cgiLocation below gets replaced by OPTIONS{cgiLocation}
	my [TAG:cgiLocation]
	return $cgiLocation;
}

sub getPath {
	return "/".getCGILocation()."/martservice";
}

sub getRegistryObject
{
	my $registry;
	if (!$main::BIOMART_REGISTRY){
	my $initializer = BioMart::Initializer->new('registryFile'=>&getConfPath());
		$registry = $initializer->getRegistry;
	} 
	else {
		$registry = $main::BIOMART_REGISTRY;
	}
	return $registry;
}

sub getRegistry {

	my $self = shift;
	# return ("yAm", "Hello", "World");   
	# return SOAP::Data->name("return" => \SOAP::Data->value(
	#			SOAP::Data->name("username" => 'fred')->type('string'), 
	#			SOAP::Data->name("password" => 'yooo')->type('string')
	#			));
	my @marts;
	my @items;
	
eval {
	
	my $registry = $self->getRegistryObject();   
	my $xml = $registry->toXML();
	my $reg_file = XMLin($xml, forcearray=> [qw(virtualSchema RegistryURLLocation RegistryDBLocation MartDBLocation MartURLLocation)], keyattr => [],KeepRoot=>1);
   
	my $mr =$reg_file->{'MartRegistry'};
	
	while (my ($key,$value) = each (%{$mr})) {
		if ($mr->{'virtualSchema'}) {
		    foreach my $lr (@{$mr->{'virtualSchema'}}) {
				$self->_set_location($lr, $self->getPath());
		    }
		} 
		else {
		    $self->_set_location($mr, $self->getPath);
		}
	}   
	if ($mr->{'virtualSchema'}) {
		foreach my $lr (@{$mr->{'virtualSchema'}}) {
			$self->_reset_attributes($lr, $self->getPath);
		}
	}
	else {
		$self->_reset_attributes($mr, $self->getPath);
	}

	# SOAP work, only expects MartURLLocation in registry
	my $reg_XML =$reg_file->{'MartRegistry'};	
		
	foreach my $location_atts (@{$reg_XML->{'MartURLLocation'}}){
		@items = ();
		
		push @items, SOAP::Data->name('name' => $location_atts->{'name'})->type('string');
		push @items, SOAP::Data->name('displayName' => $location_atts->{'displayName'})->type('string');
		push @items, SOAP::Data->name('database' => $location_atts->{'database'})->type('string');
		push @items, SOAP::Data->name('host' => $location_atts->{'host'})->type('string');
		push @items, SOAP::Data->name('path' => $location_atts->{'path'})->type('string');
		push @items, SOAP::Data->name('port' => $location_atts->{'port'})->type('string');
		push @items, SOAP::Data->name('visible' => $location_atts->{'visible'})->type('int');
		push @items, SOAP::Data->name('default' => $location_atts->{'default'})->type('int');
		push @items, SOAP::Data->name('serverVirtualSchema' => $location_atts->{'serverVirtualSchema'})->type('string');
		push @items, SOAP::Data->name('includeDatasets' => $location_atts->{'includeDatasets'})->type('string');
		push @items, SOAP::Data->name('martUser' => $location_atts->{'martUser'})->type('string');
		push @items, SOAP::Data->name('redirect' => $location_atts->{'redirect'})->type('int');
		
		push @marts, SOAP::Data->name('mart' => \SOAP::Data->name("noName" => @items));
	}
	}; # end of eval
	if($@) {
		my $ex = Exception::Class->caught('BioMart::Exception');
		if(!$ex) {
		    $ex = BioMart::Exception->new('non-BioMart die(): '.$@);
		}
		return SOAP::Data->name("BioMartException" => \SOAP::Data->name("message" => $ex->error()));
	}
	
	# noName tagName is not returned in response, its just a dummy name NOT a keyword, 
	# use reference e.g \SOAP::Data if you want this to be printed
	return SOAP::Data->name("noName" => SOAP::Data->name("noName" => @marts));	
}


sub _set_location {
    
    my ($self, $lr, $path)=@_;
        
    my $serverVirtualSchema = 'default';
    
    if (defined  $lr->{'name'})
    {
		$serverVirtualSchema=$lr->{'name'};
    }
    
    my @new_location;
    my @to_ignore = qw (schema databaseType user password);
    foreach my $location_atts (@{$lr->{'MartDBLocation'}}){
	
		while (my ($att,$val) = each (%{$location_atts})){
		   delete $$location_atts{$att} if (grep $att eq $_, @to_ignore);
		}
		my %new_location_atts= %$location_atts;
		# not required anymore as being set by Initializer now
		# $new_location_atts{'serverVirtualSchema'} = $serverVirtualSchema;
		push (@new_location,\%new_location_atts);
	}
    
    # keep existing MartURLLocations as it is, just remove proxy 
    foreach my $dblc (@{ $lr->{'MartURLLocation'} }) {
		unless ($dblc->{'redirect'} && $dblc->{'redirect'}==1){
		    	$dblc->{'host'}=$self->getServerHost;
	    		$dblc->{'port'}=$self->getServerPort;
		    	$dblc->{'path'}=$path;
		}
		delete $dblc->{'proxy'} if (exists $dblc->{'proxy'});
		push (@new_location,$dblc);
	}
    
    if (@new_location > 0) {
		$lr->{'MartURLLocation'}=\@new_location;
    }
    delete ($lr->{'MartDBLocation'});  
} 


sub _reset_attributes {
	my ($self, $lr, $path)=@_;
    
	foreach my $dblc (@{ $lr->{'MartURLLocation'} }) {
		unless ($dblc->{'redirect'} && $dblc->{'redirect'}==1) {
			$dblc->{'host'}=$self->getServerHost;
			$dblc->{'port'}=$self->getServerPort;
			$dblc->{'path'}=$path;
		}
	}
}

sub getDatasets {
	my $self = shift;
	# retrieving incoming params by name, to get this to work, you must inherit 
	# this class from SOAP::Server::Parameters
	my $mart_name = @{pop->method}{qw(martName)};	
	my $registry = $self->getRegistryObject();
	my ($vschema_name, $mart_user) = '';
	
	my @datasets;
	my @items;
	
	my $output;
	
eval{
	if (!$vschema_name || $vschema_name eq ''){
		my $seen;
		foreach my $virtualSchema (@{$registry->getAllVirtualSchemas}){
			foreach my $location (@{$virtualSchema->getAllLocations}){
				next unless ($location->name eq $mart_name);
				if ($seen){
					# duplicated mart name as virtual_schema_name not set
					#print "\nMart name conflict for $mart_name. Need to further qualify with the virtualSchema param well\n";
					BioMart::Exception::Usage->throw("Mart name conflict for $mart_name. Need to further qualify with the virtualSchema param well");
				}
				$vschema_name = $virtualSchema->name;
				$seen++;
			}
		}
	}

	my $names=$registry->getAllDatasetNames($vschema_name);
    
	foreach my $ppname (@$names){
		my $dataset = $registry->getDatasetByName($vschema_name, $ppname,$mart_user);
		next if (!$dataset);
		@items = ();
		if ($mart_name eq $dataset->locationName) {
			my $type;
			if ($dataset->isa("BioMart::Dataset::TableSet")) {
				$type="TableSet";
			}
			else {
				$type ="GenomicSequence";
			}
		   push @items, SOAP::Data->name('name' => $dataset->name())->type('string');
			push @items, SOAP::Data->name('displayName' => $dataset->displayName())->type('string');
			push @items, SOAP::Data->name('type' => $type)->type('string');
			push @items, SOAP::Data->name('visible' => $dataset->visible)->type('int');
			push @items, SOAP::Data->name('interface' => $dataset->interfaces())->type('string'); 
			
			push @datasets, SOAP::Data->name('datasetInfo' => \SOAP::Data->name("noName" => @items));
		}		
	}
	
	if (!@datasets) {
		BioMart::Exception::Usage->throw("Problem retrieving datasets for mart $mart_name, check your parameters");
	}
	
	}; # end of eval
	if($@) {
		my $ex = Exception::Class->caught('BioMart::Exception');
		if(!$ex) {
		    $ex = BioMart::Exception->new('non-BioMart die(): '.$@);
		}
		return SOAP::Data->name("BioMartException" => \SOAP::Data->name("message" => $ex->error()));
	}
	
	# noName tagName is not returned in response, its just a dummy name NOT a keyword, 
	# use reference e.g \SOAP::Data if you want this to be printed
	return SOAP::Data->name("noName" => SOAP::Data->name("noName" => @datasets));
}

sub getAttributes
{
	my $self = shift;
	# retrieving incoming params by name, to get this to work, you must inherit 
	# this class from SOAP::Server::Parameters
	my ($dataset_name, $vschema_name) = @{pop->method}{qw(datasetName virtualSchema)};
	my ($interface,$mart_user) = 'default';
	my ($attPages,$attGroups,$attColls) = '';
	undef $vschema_name if ($vschema_name eq '?');	
	my @attributePagesSoap;
	my @attributeGroupsSoap;
	my @attributeCollectionsSoap;
	my @attributesSoap;
	my @itemsSoap;
	my %semanticAnnotations = $self->getSettings('semanticAnnotations');
	
eval{
	my $registry = $self->getRegistryObject();
        
	if (!$vschema_name || $vschema_name eq ''){
		my $seen;
		foreach my $virtualSchema (@{$registry->getAllVirtualSchemas}){
			foreach my $dsetName (@{$registry->getAllDatasetNames($virtualSchema->name)}){
				next unless ($dsetName eq $dataset_name);
				if ($seen){
					# duplicated mart name as vschema_name not set
					BioMart::Exception::Usage->throw("Dataset name conflict for $dataset_name. Need to further qualify with the virtualSchema param as well");
				}
				$vschema_name = $virtualSchema->name;
				$seen++;
			}
		}
	}

	my $dset = $registry->getDatasetByName($vschema_name, $dataset_name, $mart_user);
	unless ($dset) {
		BioMart::Exception::Usage->throw("Problem retrieving attributes for dataset $dataset_name in schema $vschema_name, check your parameters");
	}
	my @main_tables = @{$dset->get('mains')};
	my @keys = @{$dset->get('keys')};
	my %key_to_main = ();
	foreach(@keys){
		$key_to_main{$_} = shift @main_tables;
	}
	my $ct = $dset->getConfigurationTree($interface) if ($dset);

	if ($ct){
		no warnings 'uninitialized';
		foreach my $apage (@{$ct->getAllAttributeTrees}){
			next if ($apage->hideDisplay eq 'true'); 
			next if ($attPages && $attPages ne $apage->name);
			@attributeGroupsSoap = ();
			foreach my $agroup (@{$apage->getAllAttributeGroups}){
				next if ($attGroups && $attGroups ne $agroup->name);
				@attributeCollectionsSoap = ();
				foreach my $acollection(@{$agroup->getAllCollections}){
					next if ($attColls && $attColls ne $acollection->name);
					@attributesSoap = ();
					foreach my $attribute(@{$acollection->getAllAttributes}){
						@itemsSoap= ();					
						$attribute = $attribute->attribute if (ref($attribute) eq "BioMart::Configuration::ValueFilter");
						my $table = $attribute->table;
						$table = $key_to_main{$attribute->key} if ($table eq 'main');
						
						push @itemsSoap, SOAP::Data->name('name' => $attribute->name())->type('string');
						push @itemsSoap, SOAP::Data->name('displayName' => $attribute->displayName())->type('string');
						push @itemsSoap, SOAP::Data->name('description' => $attribute->description())->type('string');
						push @itemsSoap, SOAP::Data->name('modelReference' => $semanticAnnotations{$attribute->name()} || "")->type('anyURI');
						push @attributesSoap, SOAP::Data->name('attributeInfo' => \SOAP::Data->name("noName" => @itemsSoap));
					}
					
					unshift @attributesSoap, SOAP::Data->name('attributeCollection' 
							=> SOAP::Data->name("maxSelect"=> ($acollection->maxSelect==0) ? undef : $acollection->maxSelect));
					unshift @attributesSoap, SOAP::Data->name('attributeCollection' 
							=> SOAP::Data->name("displayName" => $acollection->displayName));
					unshift @attributesSoap, SOAP::Data->name('attributeCollection' 
							=> SOAP::Data->name("name" => $acollection->name));
					push @attributeCollectionsSoap, SOAP::Data->name('attributeCollection' => \SOAP::Data->name("noName" => @attributesSoap));
				}
				unshift @attributeCollectionsSoap, SOAP::Data->name('attributeGroup' 
						=> SOAP::Data->name("maxSelect" => ($agroup->maxSelect == 0) ? undef : $agroup->maxSelect));
				unshift @attributeCollectionsSoap, SOAP::Data->name('attributeGroup' 
						=> SOAP::Data->name("displayName" => $agroup->displayName));
				unshift @attributeCollectionsSoap, SOAP::Data->name('attributeGroup' 
						=> SOAP::Data->name("name" => $agroup->name));
				push @attributeGroupsSoap, SOAP::Data->name('attributeGroup' => \SOAP::Data->name("noName" => @attributeCollectionsSoap));
			}
			unshift @attributeGroupsSoap, SOAP::Data->name('attributePage' 
					=> SOAP::Data->name("formatters" => $apage->outFormats));
			unshift @attributeGroupsSoap, SOAP::Data->name('attributePage' 
					=> SOAP::Data->name("maxSelect" => ($apage->maxSelect == 0) ? undef : $apage->maxSelect));
			unshift @attributeGroupsSoap, SOAP::Data->name('attributePage' 
					=> SOAP::Data->name("displayName" => $apage->displayName));
			unshift @attributeGroupsSoap, SOAP::Data->name('attributePage' 
					=> SOAP::Data->name("name" => $apage->name));
			push @attributePagesSoap, SOAP::Data->name('attributePage' => \SOAP::Data->name("noName" => @attributeGroupsSoap));
		}
	}
	}; # end of eval
	if($@) {
		my $ex = Exception::Class->caught('BioMart::Exception');
		if(!$ex) {
		    $ex = BioMart::Exception->new('non-BioMart die(): '.$@);
		}
		return SOAP::Data->name("BioMartException" => \SOAP::Data->name("message" => $ex->error()));
	}
	
	# noName tagName is not returned in response, its just a dummy name NOT a keyword, 
	# use reference e.g \SOAP::Data if you want this to be printed
	return SOAP::Data->name("noName" => SOAP::Data->name("noName" => @attributePagesSoap));

}

sub getFilters
{
	my $self = shift;
	# retrieving incoming params by name, to get this to work, you must inherit 
	# this class from SOAP::Server::Parameters
	my ($dataset_name, $vschema_name) = @{pop->method}{qw(datasetName virtualSchema)};
	my ($interface,$mart_user) = 'default';
	my ($filPages,$filGroups,$filColls) = '';
	undef $vschema_name if ($vschema_name eq '?');	

	my @filterPagesSoap;
	my @filterGroupsSoap;
	my @filterCollectionsSoap;
	my @filtersSoap;
	my @itemsSoap;
	my %semanticAnnotations = $self->getSettings('semanticAnnotations');

eval {
		
	my $registry = $self->getRegistryObject();

	if (!$vschema_name || $vschema_name eq ''){
		my $seen;
		foreach my $virtualSchema (@{$registry->getAllVirtualSchemas}){
			foreach my $dsetName (@{$registry->getAllDatasetNames($virtualSchema->name)}){
				next unless ($dsetName eq $dataset_name);
				if ($seen){
					# duplicated mart name as vschema_name not set
					BioMart::Exception::Usage->throw("Dataset name conflict for $dataset_name. Need to further qualify with the virtualSchema param as well");
				}
				$vschema_name = $virtualSchema->name;
				$seen++;
			}
		}
	}
    
	my $dset = $registry->getDatasetByName($vschema_name, $dataset_name,$mart_user);
	unless ($dset) {
		BioMart::Exception::Usage->throw("Problem retrieving filters for dataset $dataset_name in schema $vschema_name, check your parameters");
		
	}
	my @main_tables = @{$dset->get('mains')};
	my @keys = @{$dset->get('keys')};
	my %key_to_main = ();
	foreach(@keys){
		$key_to_main{$_} = shift @main_tables;
	}
	my $ct = $dset->getConfigurationTree($interface) if ($dset);
	
	my $trueContainer=0;
	if ($ct){
		no warnings 'uninitialized';
		foreach my $fpage (@{$ct->getAllFilterTrees}){
			next if ($fpage->hideDisplay eq 'true'); 
			next if ($filPages && $filPages ne $fpage->name);
			@filterGroupsSoap = ();
			foreach my $fgroup (@{$fpage->getAllFilterGroups}){
				next if ($filGroups && $filGroups ne $fgroup->name);
				@filterCollectionsSoap = ();
				foreach my $fcollection(@{$fgroup->getAllCollections}){
					next if ($filColls && $filColls ne $fcollection->name);
					@filtersSoap = ();
					foreach my $filter(@{$fcollection->getAllFilters}){
						@itemsSoap = ();
						$trueContainer=0;
						if ($filter->displayType eq 'container'){
							foreach my $option(@{$filter->getAllOptions}){
								#print $option->filter->name."\t".$option->filter->displayName."\t[]"."\n";
								@itemsSoap = ();
								next if (!$option->filter);
								my $options = $option->filter->getAllOptions;
								my @vals;
								foreach (@$options){
									push @vals,$_->value;
								}
								my @filters = ($option->filter);
								@filters = @{$option->filter->getAllFilters} if (ref($option->filter) eq "BioMart::Configuration::FilterList_List");
								my @table = ();
								my @relationalAttribute = ();
								foreach (@filters) {
									next unless ($_);
									my $table = $_->table;
									$table = $key_to_main{$_->attribute->key} if ($table eq 'main');
									$table = "pointer dataset" unless $table;
									push @table, $table;
									push @relationalAttribute, $_->attribute->relationalAttribute;
								}
								#$output .= $option->filter->name."\t".$option->filter->displayName."\t[".join(",",@vals)."]\t".$option->filter->description."\t".$fpage->name."\t".$filter->type."\t".$option->filter->legalQualifiers."\t".join(",",@table)."\t".join(",",@relationalAttribute)."\n";
								
								push @itemsSoap, SOAP::Data->name('name' => $option->filter->name())->type('string');
								push @itemsSoap, SOAP::Data->name('displayName' => $option->filter->displayName())->type('string');
								push @itemsSoap, SOAP::Data->name('description' => $option->filter->description())->type('string');
								push @itemsSoap, SOAP::Data->name('qualifier' => $option->filter->legalQualifiers())->type('string');
								push @itemsSoap, SOAP::Data->name('options' => join(",",@vals))->type('string');
								push @itemsSoap, SOAP::Data->name('modelReference' => $semanticAnnotations{$option->filter->name()} || "")->type('anyURI');

								push @filtersSoap, SOAP::Data->name('filterInfo' => \SOAP::Data->name("noName" => @itemsSoap));
					
								$trueContainer=1;
							}
						}
						if(!$trueContainer){
							my $options = $filter->getAllOptions;
							my @vals;
							foreach (@$options){
								push @vals,$_->value;
							}
							my @filters = ($filter);
							@filters = @{$filter->getAllFilters} if (ref($filter) eq "BioMart::Configuration::FilterList_List");
							my @table = ();
							my @relationalAttribute = ();
							foreach (@filters) {
								next unless ($_);
								my $table = $_->table;
								$table = $key_to_main{$_->attribute->key} if ($table eq 'main');
								$table = "pointer dataset" unless $table;
								push @table, $table;
								push @relationalAttribute, $_->attribute->relationalAttribute;
							}
							#$output .= $filter->name."\t".$filter->displayName."\t[".join(",",@vals)."]\t".$filter->description."\t".$fpage->name."\t".$filter->type."\t".$filter->legalQualifiers."\t".join(",",@table)."\t".join(",",@relationalAttribute)."\n";
							
							push @itemsSoap, SOAP::Data->name('name' => $filter->name())->type('string');
							push @itemsSoap, SOAP::Data->name('displayName' => $filter->displayName())->type('string');
							push @itemsSoap, SOAP::Data->name('description' => $filter->description())->type('string');
							push @itemsSoap, SOAP::Data->name('qualifier' => $filter->legalQualifiers())->type('string');
							push @itemsSoap, SOAP::Data->name('options' => join(",",@vals))->type('string');
							push @itemsSoap, SOAP::Data->name('modelReference' => $semanticAnnotations{$filter->name()} || "")->type('anyURI');

							push @filtersSoap, SOAP::Data->name('filterInfo' => \SOAP::Data->name("noName" => @itemsSoap));
						}
					}
					unshift @filtersSoap, SOAP::Data->name('filterCollection' 
							=> SOAP::Data->name("displayName" => $fcollection->displayName));
					unshift @filtersSoap, SOAP::Data->name('filterCollection' 
							=> SOAP::Data->name("name" => $fcollection->name));
					push @filterCollectionsSoap, SOAP::Data->name('filterCollection' => \SOAP::Data->name("noName" => @filtersSoap));
				}
				unshift @filterCollectionsSoap, SOAP::Data->name('filterGroup' 
						=> SOAP::Data->name("displayName" => $fgroup->displayName));
				unshift @filterCollectionsSoap, SOAP::Data->name('filterGroup' 
						=> SOAP::Data->name("name" => $fgroup->name));
				push @filterGroupsSoap, SOAP::Data->name('filterGroup' => \SOAP::Data->name("noName" => @filterCollectionsSoap));
			}
			unshift @filterGroupsSoap, SOAP::Data->name('filterPage' 
					=> SOAP::Data->name("displayName" => $fpage->displayName));
			unshift @filterGroupsSoap, SOAP::Data->name('filterPage' 
					=> SOAP::Data->name("name" => $fpage->name));
			push @filterPagesSoap, SOAP::Data->name('filterPage' => \SOAP::Data->name("noName" => @filterGroupsSoap));
		}		
	}
	}; # end of eval
	if($@) {
		my $ex = Exception::Class->caught('BioMart::Exception');
		if(!$ex) {
		    $ex = BioMart::Exception->new('non-BioMart die(): '.$@);
		}
		return SOAP::Data->name("BioMartException" => \SOAP::Data->name("message" => $ex->error()));
	}
	
	# noName tagName is not returned in response, its just a dummy name NOT a keyword, 
	# use reference e.g \SOAP::Data if you want this to be printed
	return SOAP::Data->name("noName" => SOAP::Data->name("noName" => @filterPagesSoap));

}

sub query
{
	my $self = shift;
	
	# retrieving incoming params by name, to get this to work, you must inherit 
	# this class from SOAP::Server::Parameters
	my ($vschema_name, $formatter, $header, $count, $uniqueRows, $datasets) = 
		@{pop->method}{qw(virtualSchemaName formatter header count uniqueRows Dataset)};

	my $interface = 'default';
	#user cant specify formatter anymore, because of resutls post processing into XML Tags
	$formatter = 'TSV';
	undef $vschema_name if ($vschema_name eq '?');

	my @allAttributes = ();
	my @resultsRows = ();
	my $resultsCount;
	my %attsPerDS = ();
	my $dsCount = 0;

eval{	
	my $registry = $self->getRegistryObject();

	my $query = BioMart::Query->new('registry'=>$registry,'virtualSchemaName'=>$vschema_name);
	if ($datasets) {
		if (ref($datasets) eq "ARRAY"){
			foreach my $dataset (@{$datasets}) {
				$query->setDataset($dataset->{'name'});
				if ($dataset->{'Filter'} && ref($dataset->{'Filter'}) eq "ARRAY"){
					foreach my $filter (@{$dataset->{'Filter'}}) {
						my @filtVals =	split (/\,/, $filter->{'value'});
						$query->addFilter($filter->{'name'}, \@filtVals);
					}
				}
				if ($dataset->{'Filter'} && ref($dataset->{'Filter'}) ne "ARRAY"){
					my @filtVals =	split (/\,/, $dataset->{'Filter'}->{'value'});
					$query->addFilter($dataset->{'Filter'}->{'name'}, \@filtVals);
				}
				if ($dataset->{'Attribute'}){
					if (ref($dataset->{'Attribute'}) eq "ARRAY"){
						foreach my $attribute (@{$dataset->{'Attribute'}}) {
							$query->addAttribute($attribute->{'name'});
							push @allAttributes, $attribute->{'name'};
							$attsPerDS{$dsCount}++;
						}
					}
					else {
						$query->addAttribute($dataset->{'Attribute'}->{'name'});
						push @allAttributes, $dataset->{'Attribute'}->{'name'};
						$attsPerDS{$dsCount}++;
					}
				}
				else {
					BioMart::Exception::Usage->throw("No Attribute Specified, please set at least 1 Attribute");
				}
				$dsCount++;
			}
		}
		else {
			$query->setDataset($datasets->{'name'});
			if ($datasets->{'Filter'} && ref($datasets->{'Filter'}) eq "ARRAY"){
				foreach my $filter (@{$datasets->{'Filter'}}) {
					my @filtVals =	split (/\,/, $filter->{'value'});
					$query->addFilter($filter->{'name'}, \@filtVals);
				}
			}
			if ($datasets->{'Filter'} && ref($datasets->{'Filter'}) ne "ARRAY"){
				my @filtVals =	split (/\,/, $datasets->{'Filter'}->{'value'});
				$query->addFilter($datasets->{'Filter'}->{'name'}, \@filtVals);
			}
			if ($datasets->{'Attribute'}){
				if (ref($datasets->{'Attribute'}) eq "ARRAY"){
					foreach my $attribute (@{$datasets->{'Attribute'}}) {
						$query->addAttribute($attribute->{'name'});
						push @allAttributes, $attribute->{'name'};
						$attsPerDS{$dsCount}++;
					}
				}
				else {
					$query->addAttribute($datasets->{'Attribute'}->{'name'});
					push @allAttributes, $datasets->{'Attribute'}->{'name'};
					$attsPerDS{$dsCount}++;
				}
			}
			else {
				BioMart::Exception::Usage->throw("No Attribute Specified, please set at least 1 Attribute");
			}				
		}
	}
	else {
		BioMart::Exception::Usage->throw("No Datasets Specified, please set at least 1 Dataset");
	}
	
	$query->formatter(uc($formatter));

	my $query_runner = BioMart::QueryRunner->new();

	if ($count && $count eq '1')	{
		############################## GET COUNT ############################
		$query->count(1);
		$query_runner->execute($query);
		$resultsCount = $query_runner->getCount();
	}
	else {
		############################## GET RESULTS ##########################
		# to obtain unique rows only
		$query_runner->uniqueRowsOnly(1) if ($uniqueRows && $uniqueRows eq '1');
		$query_runner->execute($query);
		my $result_string;
		open(my $result_buffer, '>', \$result_string);
		$query_runner->printHeader($result_buffer) if ($header && $header eq '1');
		$query_runner->printResults($result_buffer);
		close($result_buffer);
		#####################################################################
	
		############################## POST PROCESSING ######################
	
		my %semanticAnnotations = $self->getSettings('semanticAnnotations');
		my $sequenceFlag = 0;
		my $offset = 0;
		my %swapColumns = ();
		foreach my $key (sort keys %attsPerDS) {
			for (my $i=0; $i < $attsPerDS{$key}; $i++) {
			if($allAttributes[$offset+$i] eq "transcript_exon_intron"|| $allAttributes[$offset+$i] eq "gene_exon_intron"|| 				$allAttributes[$offset+$i] eq "transcript_flank" || $allAttributes[$offset+$i] eq "gene_flank" ||
				$allAttributes[$offset+$i] eq "coding_transcript_flank"||$allAttributes[$offset+$i] eq "coding_gene_flank"||
				$allAttributes[$offset+$i] eq "5utr" || $allAttributes[$offset+$i] eq "3utr" ||
				$allAttributes[$offset+$i] eq "gene_exon" || $allAttributes[$offset+$i] eq "coding" || 
				$allAttributes[$offset+$i] eq "cdna" || $allAttributes[$offset+$i] eq "peptide")
				{
					$sequenceFlag = 1;
					# swap sequence to its original location and all others atts in this dataset up to the seq attribute
					# can be found one position on right side
					$swapColumns{$offset+$i} = $offset;
					for (my $j=$offset; $j < ($offset+$i); $j++) {
						$swapColumns{$j} = $j+1;
					}
				}
			}
			$offset= $attsPerDS{$key};
		}
	
		my @rows = split (/\n/, $result_string);	

		foreach my $row (@rows) {
			my @cells = split (/\t/, $row);
			my @itemsSoap = ();
			if ($sequenceFlag) {
				# dark magic required because TAB separated sequence results come as sequence being the first column ALWAYS
				# %swapColumns hash contains the correct lookups/mappings based on columns indices
				# BioMart::Exception::Usage->throw(Dumper(\%swapColumns));
				foreach (my $i=0; $i < scalar(@cells); $i++) {
					my $j=$i;
					$j = $swapColumns{$i} if (defined $swapColumns{$i}); # change the lookup index
					push @itemsSoap, SOAP::Data->name('item' => $cells[$j])
								->attr({'attribute'=>$allAttributes[$i],
										  'modelReference'=>$semanticAnnotations{$allAttributes[$i]} || ""  })
								->type('string');
				}		
			}
			else {
				foreach (my $i=0; $i < scalar(@cells); $i++) {
					push @itemsSoap, SOAP::Data->name('item' => $cells[$i])
							->attr({'attribute'=>$allAttributes[$i],
										  'modelReference'=>$semanticAnnotations{$allAttributes[$i]} || ""  })
							->type('string');
				}
			}
			push @resultsRows, SOAP::Data->name('resultsRow' => \SOAP::Data->name("noName" => @itemsSoap));
		}	
	}  # end of else
	}; # end of eval
	if($@) {
		my $ex = Exception::Class->caught('BioMart::Exception');
		if(!$ex) {
		    $ex = BioMart::Exception->new('non-BioMart die(): '.$@);
		}
		return SOAP::Data->name("BioMartException" => \SOAP::Data->name("message" => $ex->error()));
	}
	
	if ($count && $count eq '1') {
		return SOAP::Data->name('resultsRow', $resultsCount);
	}
	else {
		# noName tagName is not returned in response, its just a dummy name NOT a keyword, 
		# use reference e.g \SOAP::Data if you want this to be printed
		return SOAP::Data->name("noName" => SOAP::Data->name("noName" => @resultsRows));
	}
}

sub getSettings
{
	my ($self, $attribute) = @_;
	my $mart_registry = $self->getRegistryObject();
	my $hash = $mart_registry->settingsParams();
	foreach(keys %$hash) {     	
		if($_ eq $attribute) {
			return %{$hash->{$_}};
		}
	}
}
# TODO: automatic addition of sub routines if ontology terms are present in settings.conf
[TAG:IF_ONTOLOGY_TERMS]

1;

