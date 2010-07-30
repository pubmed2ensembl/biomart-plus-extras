#!/usr/bin/perl -w

#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

A simple BioMart service CGI script 
requests: registry, dataset names, dataset configuration and query results

=head1 AUTHOR - Syed Haider, Gudmundur Arni Thorisson

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;

#the TAG:lib below gets replaced by OPTIONS{lib}, from user's PERL5LIB
[TAG:lib]

use Config;
use Readonly;

use XML::Simple qw(:strict);
use CGI;
use POSIX qw(strftime);
use Log::Log4perl;
use File::Basename qw(&basename &dirname);
use BioMart::Web;
use BioMart::Initializer;
use BioMart::Query;
use BioMart::AttributeTable;
use BioMart::QueryRunner;
use BioMart::ResultTable;
use BioMart::Exception;
use Data::Dumper;


use vars qw/ $VERSION $revision $server_host $server_port $log_Dir $cgiLocation $CONF_FILE $LOGGER $WEBQUERY $BIOMART_REGISTRY/;

#the TAG:conf below gets replaced by OPTIONS{conf}, path to registry file
[TAG:conf]

#the TAG:server_host below gets replaced by OPTIONS{server_host}
[TAG:server_host]

#the TAG:server_port below gets replaced by OPTIONS{server_port}
[TAG:server_port]

#the TAG:log_dir below gets replaced by path to log dir
[TAG:log_dir]

#the TAG:cgiLocation below gets replaced by OPTIONS{cgiLocation}
[TAG:cgiLocation]

# Initialize master logger for this wrapper script, but only if it's not defined
# already. Other components of system will use the same logger-setup but with 
# different configurations.
if(!defined($LOGGER)) {
    Log::Log4perl->init(dirname($CONF_FILE) . '/log4perl.conf');
    my $script = basename($0);
    $LOGGER = Log::Log4perl->get_logger($script);
    $LOGGER->debug("initialized logger for $script");
}
else {
    $LOGGER->debug("Using existing logger $LOGGER");
}

my $CGI = $ENV{MOD_PERL} ? CGI->new(shift @_) : CGI->new();

#my $CGI       = CGI->new();
my $type          = $CGI->param('type');
my $vschema_name  = $CGI->param('virtualschema') || $CGI->param('virtualSchema');# || 'default'; 
my $dataset_name  = $CGI->param('dataset');
my $version       = $CGI->param('version');
my $atts          = $CGI->param('attribute');
my $attGroups     = $CGI->param('attributeGroup');
my $attColls      = $CGI->param('attributeCollection');
my $attPages      = $CGI->param('attributePage');
my $fils          = $CGI->param('filter');
my $filGroups     = $CGI->param('filterGroup');
my $filColls      = $CGI->param('filterCollection');
my $filPages      = $CGI->param('filterPage');
my $mart_name     = $CGI->param('mart');
my $martuser      = $CGI->param('martuser') || 'default';
my $interface     = $CGI->param('interface') || 'default';
my $xml           = $CGI->param('query');
my $path = "/".$cgiLocation."/martservice";



my $registry;
if (!$main::BIOMART_REGISTRY){
my $initializer = BioMart::Initializer->new('registryFile'=>$CONF_FILE);
$registry = $initializer->getRegistry;
} else {
$registry = $main::BIOMART_REGISTRY;
}





eval{
	if($type)
	{	
    		if ($type eq "registry") {
			&get_registry($registry,$server_host,$server_port,$path);
		}	  
		elsif ($type eq "datasets") {
			&get_datasets($registry,$vschema_name,$mart_name,$martuser);
		}  
		elsif ($type eq "interfaces"){
			&get_interfaces($registry,$vschema_name,$mart_name,$martuser,$dataset_name);
		}
		elsif ($type eq "configuration") {
			&get_configuration($registry,$vschema_name,$mart_name,$dataset_name,$interface,$martuser);
		} 
		elsif ($type eq "filters") {
			&get_filters($registry,$vschema_name,$dataset_name,$interface,$martuser,$filPages,$filGroups,$filColls);
		}
		elsif ($type eq "attributes") {
			&get_attributes($registry,$vschema_name,$dataset_name,$interface,$martuser,$attPages,$attGroups,$attColls);
		}
		elsif ($type eq "versioncheck") {	
			&version_check($registry,$vschema_name,$mart_name,$version);
		} 
		elsif ($type eq "version") {
			&version($registry,$vschema_name,$mart_name);
		}
		
				# biomaRt registry, static contents
   		elsif ($type eq "registry_archive") {
			&printBiomaRtRegistry();
		}	  
				
                # TEST SERVER
		elsif ($type eq "listVirtualSchemas") {
			&listVirtualSchemas($registry);
		}
		elsif ($type eq "listMarts") {
			&listMarts($registry,$vschema_name);
		}
		elsif ($type eq "listDatasets") {
			&listDatasets($registry,$vschema_name,$mart_name);
		}
		elsif ($type eq "listInterfaces") {
			&listInterfaces($registry,$vschema_name,$mart_name,$dataset_name);
		}
		elsif ($type eq "listAttributePages") {
			&listAttributePages($registry,$vschema_name,$mart_name,$dataset_name,$interface);
		}
		elsif ($type eq "listAttributeGroups") {
			&listAttributeGroups($registry,$vschema_name,$mart_name,$dataset_name,$interface,$attPages);
		}
		elsif ($type eq "listAttributeCollections") {
			&listAttributeCollections($registry,$vschema_name,$mart_name,$dataset_name,$interface,$attPages,$attGroups);
		}
		elsif ($type eq "listAttributes") {
			&listAttributes($registry,$vschema_name,$mart_name,$dataset_name,$interface,$attPages,$attGroups,$attColls);
		}
		elsif ($type eq "listFilterPages") {
			&listFilterPages($registry,$vschema_name,$mart_name,$dataset_name,$interface);
		}
		elsif ($type eq "listFilterGroups") {
			&listFilterGroups($registry,$vschema_name,$mart_name,$dataset_name,$interface,$filPages);
		}
		elsif ($type eq "listFilterCollections") {
			&listFilterCollections($registry,$vschema_name,$mart_name,$dataset_name,$interface,$filPages,$filGroups);
		}
		elsif ($type eq "listFilters") {
			&listFilters($registry,$vschema_name,$mart_name,$dataset_name,$interface,$filPages,$filGroups,$filColls);
		}
		elsif ($type eq "listFilterOptions") {
			&listFilterOptions($registry,$vschema_name,$mart_name,$dataset_name,$interface,$filPages,$filGroups,$filColls,$fils);
		}
	} 
    	elsif ($xml){
		my $ip = $CGI->remote_host();
		&createLog($registry, $xml, $ip);
		&run_query($registry,$xml);
    	}
	else{
		&printMartServiceHelp($registry);
	}

};
if($@) {
	my $ex = Exception::Class->caught('BioMart::Exception');
	if(!$ex) {
	    $ex = BioMart::Exception->new('non-BioMart die(): '.$@);
	}
	print $ex->error()."\n";
	return;
}


#
# returns registry XML
#

### END OF MAIN PROGRAM ###

sub get_registry {
    
    my ($registry,$server_host,$server_port,$path)=@_;
    
    my $xml = $registry->toXML();
    my $reg_file = XMLin($xml, forcearray=> [qw(virtualSchema RegistryURLLocation RegistryDBLocation MartDBLocation MartURLLocation)], keyattr => [],KeepRoot=>1);   
   
	my $mr =$reg_file->{'MartRegistry'};
	
    while (my ($key,$value) = each (%{$mr}))
    {
		if ($mr->{'virtualSchema'}){	
		    foreach my $lr (@{$mr->{'virtualSchema'}})
		    {
				&_set_location($lr, $path);
		    }
		} 
		else 
		{
		    &_set_location($mr, $path);
		}
	}   
    if ($mr->{'virtualSchema'}){
		foreach my $lr (@{$mr->{'virtualSchema'}})
		{
			&_reset_attributes($lr, $path);
		} 	
    } 
    else 
    {
		&_reset_attributes($mr, $path);
    }
    

    my $newconfig=XMLout($reg_file, keyattr => [],KeepRoot=>1);
    
    #pprint STDERR "\n$newconfig";
    if ($newconfig) {
		print "\n$newconfig";
    }
    else{
		BioMart::Exception::Usage->throw("Problem retrieving registry");
    }

}


sub _set_location {
    
    my ($lr, $path)=@_;
    
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
		    	$dblc->{'host'}=$server_host;
	    		$dblc->{'port'}=$server_port;
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
    my ($lr, $path)=@_;
    
    foreach my $dblc (@{ $lr->{'MartURLLocation'} })
    {
	unless ($dblc->{'redirect'} && $dblc->{'redirect'}==1){
	    
	    $dblc->{'host'}=$server_host;
	    $dblc->{'port'}=$server_port;
	    $dblc->{'path'}=$path;
	    
	}
    }
    
}


#
# returns datasets tab delimited
#

sub get_datasets {
    
    my ($registry,$vschema_name,$mart_name,$mart_user)=@_;
    my $output; 
    if (!$vschema_name || $vschema_name eq ''){
	my $seen;
	foreach my $virtualSchema (@{$registry->getAllVirtualSchemas}){
	    foreach my $location (@{$virtualSchema->getAllLocations}){
		next unless ($location->name eq $mart_name);
		if ($seen){
		    # duplicated mart name as virtual_schema_name not set
		    print "\nMart name conflict for $mart_name. Need to further qualify with the virtualSchema param well\n";
		    return;
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
	if ($mart_name eq $dataset->locationName) {
	    my $type;
	    if ($dataset->isa("BioMart::Dataset::TableSet")) {
		$type="TableSet";
	    }
	    else {
		$type ="GenomicSequence";
	    }
	    
	    $output .= " \n";
	    
	    $output .=  "$type\t".$dataset->name."\t".$dataset->displayName."\t".$dataset->visible."\t".$dataset->version."\t".$dataset->initialBatchSize."\t".$dataset->maxBatchSize."\t".$dataset->interfaces."\t".$dataset->modified."\n";
	    
	}
    }
    if ($output) {
	print "$output";
    }
    else{
	BioMart::Exception::Usage->throw("Problem retrieving datasets for mart $mart_name, check your parameters");
    }
}

sub get_interfaces{
    my ($registry,$vschema_name,$mart_name,$mart_user,$dataset_name)=@_;
    my $dataset=$registry->getDatasetByName($vschema_name, $dataset_name,$mart_user);
    my $output;
    if ($dataset){
	$output .= "\n".$dataset->interfaces."\n";
    }

    if ($output) {
	print "$output";
    }
    else{
	BioMart::Exception::Usage->throw("Problem retrieving interfaces for dataset $dataset_name in mart $mart_name and schema $vschema_name, check your parameters");
    }

    return;
}


#
# check if mart config version matches client version - returns boolean
#

sub version_check {
    my ($registry,$vschema_name,$mart_name,$version)=@_;
    
    my $mart=&_find_mart($registry,$vschema_name,$mart_name);
    print "\n".$mart->versionCheck($version)."\n";
    return;
    
    
}

#
# returns mart config version
#

sub version {
    my ($registry,$vschema_name,$mart_name)=@_;
    
    my $mart=&_find_mart($registry,$vschema_name,$mart_name);
    print $mart->version()."\n";
    return;
       
}



sub _find_mart {

    my ($registry,$vschema_name,$mart_name)=@_;


 my $found_location;
    my $seen;
    foreach my $virtualSchema (@{$registry->getAllVirtualSchemas}){
	next unless (!$vschema_name || $vschema_name eq '' || $virtualSchema->name eq $vschema_name);
	foreach my $location (@{$virtualSchema->getAllLocations}){
	    next unless ($location->name eq $mart_name);
	    if ($seen){
		# duplicated mart name as vschema_name not set
		print "\nMart name conflict for $mart_name. Need to further qualify with the virtualSchema param as well\n";
		return;
	    }
	    $found_location = $location;
	    $seen++;
            #print "\n".$location->versionCheck($version)."\n";
	    #return;
	}
    }
    if (!$found_location){
	print "\nMart name $mart_name not found on server for the serverVirtualSchema specified\n";
	return;
    }

    return $found_location;

}


sub get_configuration {
    
	my ($registry,$vschema_name, $mart_name, $dataset_name,$interface,$mart_user)=@_;
    
    
    if (!$vschema_name || $vschema_name eq ''){
	my $seen;
	foreach my $virtualSchema (@{$registry->getAllVirtualSchemas}){
	    foreach my $dsetName (@{$registry->getAllDatasetNames($virtualSchema->name)}){
		next unless ($dsetName eq $dataset_name);
		if ($seen){
		    # duplicated mart name as vschema_name not set
		    print "\nDataset name conflict for $dataset_name. Need to further qualify with the virtualSchema param as well\n";
		    return;
		}
		$vschema_name = $virtualSchema->name;
		$seen++;
	    }
	}
    }
    
    my $xmlTree;
    my $dset = $registry->getDatasetByName($vschema_name, $dataset_name,$mart_user);
    $xmlTree = $dset->getConfigurationTree($interface)->toXML() if ($dset);

    if ($xmlTree){
	print  "$xmlTree\n";
    }
    else{
	BioMart::Exception::Usage->throw("Problem retrieving configuration for dataset $dataset_name in mart $mart_name and schema $vschema_name, check your parameters");
    }

}

sub get_filters {
    
    my ($registry,$vschema_name,$dataset_name,$interface,$mart_user,$filPages,$filGroups,$filColls)=@_;
    
    
    if (!$vschema_name || $vschema_name eq ''){
	my $seen;
	foreach my $virtualSchema (@{$registry->getAllVirtualSchemas}){
	    foreach my $dsetName (@{$registry->getAllDatasetNames($virtualSchema->name)}){
		next unless ($dsetName eq $dataset_name);
		if ($seen){
		    # duplicated mart name as vschema_name not set
		    print "\nDataset name conflict for $dataset_name. Need to further qualify with the virtualSchema param as well\n";
		    return;
		}
		$vschema_name = $virtualSchema->name;
		$seen++;
	    }
	}
    }
    
    my $dset = $registry->getDatasetByName($vschema_name, $dataset_name,$mart_user);
    unless ($dset) {
        BioMart::Exception::Usage->throw("Problem retrieving attributes for dataset $dataset_name in schema $vschema_name, check your parameters");
        return;
    }
    my @main_tables = @{$dset->get('mains')};
    my @keys = @{$dset->get('keys')};
    my %key_to_main = ();
    foreach(@keys){
        $key_to_main{$_} = shift @main_tables;
    }
    my $ct = $dset->getConfigurationTree($interface) if ($dset);
    my $output;
    my $trueContainer=0;
    if ($ct){
	foreach my $fpage (@{$ct->getAllFilterTrees}){
	    next if ($fpage->hideDisplay eq 'true'); 
	    next if ($filPages && $filPages ne $fpage->name);
	    foreach my $fgroup (@{$fpage->getAllFilterGroups}){
		next if ($filGroups && $filGroups ne $fgroup->name);
		foreach my $fcollection(@{$fgroup->getAllCollections}){
		    next if ($filColls && $filColls ne $fcollection->name);
		    foreach my $filter(@{$fcollection->getAllFilters}){
		    	$trueContainer=0;
			if ($filter->displayType eq 'container'){
			    foreach my $option(@{$filter->getAllOptions}){
				#print $option->filter->name."\t".$option->filter->displayName."\t[]"."\n";
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
				$output .= $option->filter->name."\t".$option->filter->displayName."\t[".join(",",@vals)."]\t".$option->filter->description."\t".$fpage->name."\t".$filter->type."\t".$option->filter->legalQualifiers."\t".join(",",@table)."\t".join(",",@relationalAttribute)."\n";
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
			    $output .= $filter->name."\t".$filter->displayName."\t[".join(",",@vals)."]\t".$filter->description."\t".$fpage->name."\t".$filter->type."\t".$filter->legalQualifiers."\t".join(",",@table)."\t".join(",",@relationalAttribute)."\n";
			}
		    }
		}
	    }
	}
	$output .=  "\n";
    }
    if ($output) {
	print "$output";
    }
    else{
	BioMart::Exception::Usage->throw("Problem retrieving filters for dataset $dataset_name in schema $vschema_name, check your parameters");
    }
}

sub get_attributes {
    
    my ($registry,$vschema_name,$dataset_name,$interface,$mart_user,$attPages,$attGroups,$attColls)=@_;
        
    if (!$vschema_name || $vschema_name eq ''){
	my $seen;
	foreach my $virtualSchema (@{$registry->getAllVirtualSchemas}){
	    foreach my $dsetName (@{$registry->getAllDatasetNames($virtualSchema->name)}){
		next unless ($dsetName eq $dataset_name);
		if ($seen){
		    # duplicated mart name as vschema_name not set
		    print "\nDataset name conflict for $dataset_name. Need to further qualify with the virtualSchema param as well\n";
		    return;
		}
		$vschema_name = $virtualSchema->name;
		$seen++;
	    }
	}
    }
    
    my $dset = $registry->getDatasetByName($vschema_name, $dataset_name,$mart_user);
    unless ($dset) {
        BioMart::Exception::Usage->throw("Problem retrieving attributes for dataset $dataset_name in schema $vschema_name, check your parameters");
        return;
    }
    my @main_tables = @{$dset->get('mains')};
    my @keys = @{$dset->get('keys')};
    my %key_to_main = ();
    foreach(@keys){
        $key_to_main{$_} = shift @main_tables;
    }
    my $ct = $dset->getConfigurationTree($interface) if ($dset);
    my $output;
    #print "\n";
    if ($ct){
	foreach my $apage (@{$ct->getAllAttributeTrees}){
	    next if ($apage->hideDisplay eq 'true'); 
	    next if ($attPages && $attPages ne $apage->name);
	    foreach my $agroup (@{$apage->getAllAttributeGroups}){
		next if ($attGroups && $attGroups ne $agroup->name);
		foreach my $acollection(@{$agroup->getAllCollections}){
		    next if ($attColls && $attColls ne $acollection->name);
		    foreach my $attribute(@{$acollection->getAllAttributes}){
		    	$attribute = $attribute->attribute if (ref($attribute) eq "BioMart::Configuration::ValueFilter");
			my $table = $attribute->table;
			$table = $key_to_main{$attribute->key} if ($table eq 'main');
			$output .= $attribute->name."\t".$attribute->displayName."\t".$attribute->description."\t".$apage->name."\t".$apage->outFormats."\t".$table."\t".$attribute->relationalAttribute."\n";
		    }
		}
	    }
	}
	$output .=  "\n";
    }
    if ($output){
	print "$output";
    }
    else{
	BioMart::Exception::Usage->throw("Problem retrieving attributes for dataset $dataset_name in schema $vschema_name, check your parameters");
    }
}


# TEST SERVER STUFF

sub listVirtualSchemas {
    
    my ($registry)=@_;

    my $output;
    foreach my $vs(@{$registry->getAllVirtualSchemas}){
        $output .= $vs->name."\n";
    }
    if ($output){
	print "$output";
    }
}

sub listMarts {
    
    my ($registry,$vschema_name)=@_;

    my $output;
    my $vs = $registry->getVirtualSchemaByName($vschema_name);
    if ($vs) {
    	foreach my $mart(@{$vs->getAllMarts(1)}){
       	 	$output .= $mart->name."\n";
   	 }
    }
    if ($output){
	print "$output";
    }
}

sub listDatasets {
    
    my ($registry,$vschema_name,$mart_name)=@_;

    my $output;
    my $vs = $registry->getVirtualSchemaByName($vschema_name);
    if ($vs) {
        my $mart = $vs->getMartByName($mart_name);
        if ($mart) {
    		foreach my $ds(@{$mart->getAllDatasets(1)}){
       	 		$output .= $ds->name."\n";
   	 	}
	}
    }
    if ($output){
	print "$output";
    }
}

sub listInterfaces {

    my ($registry,$vschema_name,$mart_name,$dataset_name)=@_;

    my $output;
    my $vs = $registry->getVirtualSchemaByName($vschema_name);
    if ($vs) {
        my $mart = $vs->getMartByName($mart_name);
        if ($mart) {
	        my $ds = $mart->getDatasetByName($dataset_name);
		if ($ds) {
                	foreach my $i(split(',',$ds->interfaces)){
                       	 	$output .= $i."\n";
                	}
		}
        }
    }
    if ($output){
	print "$output";
    }
}

sub listAttributePages {
    
    my ($registry,$vschema_name,$mart_name,$dataset_name,$interface)=@_;

    my $output;
    my $vs = $registry->getVirtualSchemaByName($vschema_name);
    if ($vs) {
        my $mart = $vs->getMartByName($mart_name);
        if ($mart) {
	        my $ds = $mart->getDatasetByName($dataset_name);
		if ($ds) {
                	foreach my $ap(@{$ds->getConfigurationTree($interface)->getAllAttributeTrees()}){
                       	 	$output .= $ap->name."\t".$ap->maxSelect."\t".$ap->outFormats()."\n" unless $ap->hideDisplay eq 'true';
                	}
		}
        }
    }
    if ($output){
	print "$output";
    }
}

sub listAttributeGroups {
    
    my ($registry,$vschema_name,$mart_name,$dataset_name,$interface,$attPages)=@_;

    my $output;
    my $vs = $registry->getVirtualSchemaByName($vschema_name);
    if ($vs) {
        my $mart = $vs->getMartByName($mart_name);
        if ($mart) {
	        my $ds = $mart->getDatasetByName($dataset_name);
                if ($ds) {
			my $ap = $ds->getConfigurationTree($interface)->getAttributeTreeByName($attPages);
			if ($ap) {
                        	foreach my $ag(@{$ap->getAllAttributeGroups()}){
                                	$output .= $ag->name."\t".$ag->maxSelect."\n";
                       	 	}
			}
                }
        }
    }
    if ($output){
	print "$output";
    }
}

sub listAttributeCollections {
    
    my ($registry,$vschema_name,$mart_name,$dataset_name,$interface,$attPages,$attGroups)=@_;

    my $output;
    my $vs = $registry->getVirtualSchemaByName($vschema_name);
    if ($vs) {
        my $mart = $vs->getMartByName($mart_name);
        if ($mart) {
	        my $ds = $mart->getDatasetByName($dataset_name);
                if ($ds) {
                        my $ap = $ds->getConfigurationTree($interface)->getAttributeTreeByName($attPages);
                        if ($ap) {
				my $ag = $ap->getAttributeGroupByName($attGroups);
				if ($ag) {
                                	foreach my $ac(@{$ag->getAllCollections()}){
                                        	$output .= $ac->name."\t".$ac->maxSelect."\n";
                               	 	}
				}
                        }
                }
        }
    }
    if ($output){
	print "$output";
    }
}

sub listAttributes {
    
    my ($registry,$vschema_name,$mart_name,$dataset_name,$interface,$attPages,$attGroups,$attColls)=@_;

    my $output;
    my $vs = $registry->getVirtualSchemaByName($vschema_name);
    if ($vs) {
        my $mart = $vs->getMartByName($mart_name);
        if ($mart) {
	        my $ds = $mart->getDatasetByName($dataset_name);
                if ($ds) {
                        my $ap = $ds->getConfigurationTree($interface)->getAttributeTreeByName($attPages);
                        if ($ap) {
                                my $ag = $ap->getAttributeGroupByName($attGroups);
                                if ($ag) {
					my $ac = $ag->getAttributeCollectionByName($attColls);
					if ($ac) {
                                        	foreach my $a(@{$ac->getAllAttributes()}){
                                                	$output .= $a->name."\n" unless $a->isa("BioMart::Configuration::BaseFilter");
                                        	}
					}
                                }
                        }
                }
        }
    }
    if ($output){
	print "$output";
    }
}

sub listFilterPages {
    
    my ($registry,$vschema_name,$mart_name,$dataset_name,$interface)=@_;

    my $output;
    my $vs = $registry->getVirtualSchemaByName($vschema_name);
    if ($vs) {
        my $mart = $vs->getMartByName($mart_name);
        if ($mart) {
	        my $ds = $mart->getDatasetByName($dataset_name);
		if ($ds) {
                	foreach my $ap(@{$ds->getConfigurationTree($interface)->getAllFilterTrees()}){
                       	 	$output .= $ap->name."\n" unless $ap->hideDisplay eq 'true';
                	}
		}
        }
    }
    if ($output){
	print "$output";
    }
}

sub listFilterGroups {
    
    my ($registry,$vschema_name,$mart_name,$dataset_name,$interface,$attPages)=@_;

    my $output;
    my $vs = $registry->getVirtualSchemaByName($vschema_name);
    if ($vs) {
        my $mart = $vs->getMartByName($mart_name);
        if ($mart) {
	        my $ds = $mart->getDatasetByName($dataset_name);
                if ($ds) {
			my $ap = $ds->getConfigurationTree($interface)->getFilterTreeByName($attPages);
			if ($ap) {
                        	foreach my $ag(@{$ap->getAllFilterGroups()}){
                                	$output .= $ag->name."\n";
                       	 	}
			}
                }
        }
    }
    if ($output){
	print "$output";
    }
}

sub listFilterCollections {
    
    my ($registry,$vschema_name,$mart_name,$dataset_name,$interface,$attPages,$attGroups)=@_;

    my $output;
    my $vs = $registry->getVirtualSchemaByName($vschema_name);
    if ($vs) {
        my $mart = $vs->getMartByName($mart_name);
        if ($mart) {
	        my $ds = $mart->getDatasetByName($dataset_name);
                if ($ds) {
                        my $ap = $ds->getConfigurationTree($interface)->getFilterTreeByName($attPages);
                        if ($ap) {
				my $ag = $ap->getFilterGroupByName($attGroups);
				if ($ag) {
                                	foreach my $ac(@{$ag->getAllCollections()}){
                                        	$output .= $ac->name."\n";
                               	 	}
				}
                        }
                }
        }
    }
    if ($output){
	print "$output";
    }
}

sub listFilters {
    
    my ($registry,$vschema_name,$mart_name,$dataset_name,$interface,$attPages,$attGroups,$attColls)=@_;

    my $output;
    my $vs = $registry->getVirtualSchemaByName($vschema_name);
    if ($vs) {
        my $mart = $vs->getMartByName($mart_name);
        if ($mart) {
	        my $ds = $mart->getDatasetByName($dataset_name);
                if ($ds) {
                        my $ap = $ds->getConfigurationTree($interface)->getFilterTreeByName($attPages);
                        if ($ap) {
                                my $ag = $ap->getFilterGroupByName($attGroups);
                                if ($ag) {
					my $ac = $ag->getFilterCollectionByName($attColls);
					if ($ac) {
                                        	foreach my $a(@{$ac->getAllFilters()}){
                                                	$output .= $a->name."\t".$a->type."\n";
                                        	}
					}
                                }
                        }
                }
        }
    }
    if ($output){
	print "$output";
    }
}

sub listFilterOptions {
    
    my ($registry,$vschema_name,$mart_name,$dataset_name,$interface,$attPages,$attGroups,$attColls,$fils)=@_;

    my $output;
    my $vs = $registry->getVirtualSchemaByName($vschema_name);
    if ($vs) {
        my $mart = $vs->getMartByName($mart_name);
        if ($mart) {
	        my $ds = $mart->getDatasetByName($dataset_name);
                if ($ds) {
                        my $ap = $ds->getConfigurationTree($interface)->getFilterTreeByName($attPages);
                        if ($ap) {
                                my $ag = $ap->getFilterGroupByName($attGroups);
                                if ($ag) {
					my $ac = $ag->getFilterCollectionByName($attColls);
					if ($ac) {
                                                my $f = $ac->getFilterByName($fils);
                                                if ($f) {
                                                        foreach my $o(@{$f->getAllOptions()}){
								if ($o->filter) {
                                                                	$output .= $o->filter->name."\n";
								} else {
                                                                	$output .= $o->value."\n";
								}
                                                        }
                                                }
					}
                                }
                        }
                }
        }
    }
    if ($output){
	print "$output";
    }
}

# END OF TEST SERVER STUFF

sub run_query {
    my ($registry,$xml) = @_;
    my $query;	
   
    $LOGGER->warn("RECEIVED QUERY:$xml\n");
      
	eval{
	    $query = BioMart::Query->new(
				 'registry' => $registry,
				 'virtualSchemaName' => 'default',
				 'xml'      => $xml);
    
    		my $query_planner = BioMart::QueryRunner->new();
    		
    		# check if uniqueResults are requested
    		my $config = XMLin($xml, forcearray=> [qw(Query Dataset Attribute 
					      ValueFilter BooleanFilter 
					      Filter Links)], keyattr => []);
    		$query_planner->uniqueRowsOnly(1) if ($config->{'uniqueRows'} && $config->{'uniqueRows'} eq '1');
    		
    		$query_planner->execute($query);
    
    		if ($query->count eq '1'){
			my $count = $query_planner->getCount();
			print "$count\n"; 
    		}
			else{	
		        if ($query->header && $query->header eq '1') {
				    $query_planner->printHeader();
				}
				$query_planner->printResults();
				$query_planner->printFooter();
			    if ($query->completionStamp && $query->completionStamp eq '1') {
				    $query_planner->printCompletionStamp();
				}
	    	}
	};

    
	if($@) {
    		my $ex = Exception::Class->caught('BioMart::Exception');
	   	if(!$ex) {
			$ex = BioMart::Exception->new('non-BioMart die(): '.$@);
	    	}
	    	my $errmsg = "Query ERROR: caught ".ref($ex) . ": " . $ex->error();
	    	print $errmsg;
	}    }

sub createLog
{
	my ($registry,$xml, $ip) = @_;
	## extraction of requestid, not removing it from query as its ignored even if it
	## travels down to the query engine
	my ($mode, $log_query, $log_ip);

	my $hash = $registry->settingsParams();
     foreach(keys %$hash) {     	
	     if($_ eq "webserviceLogging") {
	     	foreach my $param (keys %{$hash->{$_}}) {
     			#print "\n\t\t\t$param \t", $hash->{$_}->{$param};
     			$mode = 1 	if($param eq 'mode' && $hash->{$_}->{$param} eq 'ON');
	    			$log_query = 1 if($param eq 'log_query' && $hash->{$_}->{$param} eq 'ON');
     			$log_ip = 1  	if($param eq 'log_IP' && $hash->{$_}->{$param} eq 'ON');     			
     		}
     	}
     }

	if($mode) ## do logging
	{
		my $reqLogFile = $log_Dir."request_log";
		open(STDREQLOG, ">>$reqLogFile");
	
		$xml =~ m/.*?requestid.*?\"(.*?)\".*/im;
	
		my $theTime = strftime "%Y-%m-%d %H:%M:%S", localtime;
	
		print STDREQLOG "\n";
		print STDREQLOG "$ip\t" 		if ($ip && $log_ip);
		print STDREQLOG "$theTime\t" 	if ($theTime);
		print STDREQLOG "$1"	 	if ($1);
		print STDREQLOG "\n$xml"		if ($xml && $log_query); ## only log xml query if told to do so
                #print STDREQLOG "\n$xml" if ($xml);
	
		close(STDREQLOG);
	}
}


sub printMartServiceHelp
{
		my $registry = shift;
	    my $port = '';
	    $port = ":$server_port" if ($server_port != 80);
	    
	     

	    my $first_schema = ${$registry->getAllVirtualSchemas}[0];
	    my $first_location = ${$first_schema->getAllLocations}[0];
	    my $first_mart_name = $first_location->name;
	    my $first_dataset = ${$first_location->getAllDatasets}[0];
			my $first_dataset_name = $first_dataset->name;

	    # causing warnings.CGI will not stay shared.
	    # print $CGI->header(-type=>'text/html');
	    	    
	    print qq(
<html><!-- InstanceBegin template="/Templates/biomart_standalone.dwt" codeOutsideHTMLIsLocked="false" -->	
	<head> 
		<!-- InstanceBeginEditable name="doctitle" -->
<meta name="Description" content="BioMart is a simple and robust data integration system for large scale data querying. It has been designed to provide researchers with an easy and interactive access to both the wealth of data available on the Internet and for in house data integration.">
<meta name="keywords" content="BioMart, DATABASE, SEARCHES, protein">

<title>BioMart Webservice</title>
<script language = "javascript">
var currentTab="Martservice";
</script>

<!-- InstanceEndEditable -->
<link rel="stylesheet" href="/$cgiLocation/mview/martview.css" type="text/css" />
 <script language="javascript" type="text/javascript">

	function colourTab(){
		if((document.getElementById(currentTab))){
			(document.getElementById(currentTab)).className='menuh';
		}
	}

	function rollOver(overTab){
		if(currentTab!=overTab){
			(document.getElementById(overTab)).className='menuh';
		}
	}
	function rollOut(overTab){
		if(currentTab!=overTab){
			(document.getElementById(overTab)).className='menu';
		}
	}

</script>

</head>
<body style="margin: 0px;" onLoad="colourTab()" >

<div style=" width:100%; height:15%;">
<table height="65%" width="100%" border="0" cellspacing="0" cellpadding="0">
	<tr>
		
    <td width="270" align="right">
    <a href="index.html">
    		<img style = "margin: 15px 0px 5px 8px;" height="33" width="105" src="/martview/images/biomart-logo.gif" alt="EBI Home Page" border="0" />
    </a>
    </td>
		 <td valign="top" align="right" width="100%">

  	</td>
	</tr>
</table>


<table border="0"  valign="bottom" cellpadding="" cellspacing="2" height="35%" width="1000">
        <tr>
        
			<td align="center" valign="bottom" width="14%">
	          <div class="menu" id="BioMart Home" onClick="location='/martview/../index.html'" onmouseover="rollOver(this.id)" onMouseout="rollOut(this.id)">HOME</div> 
			</td>
			
			<td align="center" valign="bottom" width="14%">
          <div   class="menu"  id="Documentation" onClick="location='/martview/../install.html'" onmouseover="rollOver(this.id)" onMouseout="rollOut(this.id)">DOCS</div> 
			</td>
			
			<td align="center" valign="bottom" width="14%">
		  <div   class="menu"  id="News" onClick="location='/martview/../news.html'" onmouseover="rollOver(this.id)" onMouseout="rollOut(this.id)">NEWS</div> 
			</td>
			
			<td align="center" valign="bottom" width="14%">
          <div   class="menu"  id="Contact" onClick="location='/martview/../contact.html'" onmouseover="rollOver(this.id)" onMouseout="rollOut(this.id)">CONTACT</div> 
			</td>
			
			
			<td align="center" valign="bottom" width="14%">
			<div    class="menu"  id="Credits" onClick="location='/martview/../credits.html'" onmouseover="rollOver(this.id)" onMouseout="rollOut(this.id)">CREDITS</div> 
			</td>

			<td align="center" valign="bottom" width="14%">
			<div     class="menuh" id="Service" onClick="location='/biomart/martservice'" onmouseover="rollOver(this.id)" onMouseout="rollOut(this.id)">MARTSERVICE</div>
			</td>
			
			<td align="center" valign="bottom" width="14%">
			<div    class="menu"  id="Query" onClick="location='/biomart/martview'" onmouseover="rollOver(this.id)" onMouseout="rollOut(this.id)">MARTVIEW</div>    
			</td>
			
		</tr>
</table>

</div>

<div class="mart_header" style=" width:100%; height:85%;">
<table bgcolor="black" width="100%" height="5" border="0" cellspacing="0" cellpadding="0">
             <tr> 
                <td bgcolor="black" width="100%" height="20" align="center"><!-- InstanceBeginEditable name="topnav" --><nobr></nobr><!-- InstanceEndEditable --></td>
              </tr> 
</table>


<h3>Martservices usage:</h3><br>
(a) Querying BioMart<br><br>
To submit a query using our webservices generate an XML document conforming to our Query XML syntax. This can be achieved simply by building up your query using MartView and hitting the XML button. This XML should be posted to http://$server_host$port/martservice attached to a single parameter of <b>query</b>. For example you could either:<br><br> 
- save your query as Query.xml and then POST this using the <a href="http://cvs.sanger.ac.uk/cgi-bin/viewcvs.cgi/*checkout*/biomart-perl/scripts/webExample.pl?root=BioMart&content-type=text%2Fplain">webExample.pl</a> script in our biomart-perl/scripts installation.<br>
- submit using wget: wget -O results.txt 'http://$server_host$port/biomart/martservice?query=MY_XML' replacing MY_XML with the XML obtained above, first removing any new lines.<br>
<br>
(b) Retrieving Meta Data<br>
<br>
- to retrieve registry information: <a href="/biomart/martservice?type=registry">http://$server_host$port/biomart/martservice?type=registry</a><br>
- to retrieve datasets available for a mart: <a href="/biomart/martservice?type=datasets&mart=$first_mart_name">http://$server_host$port/biomart/martservice?type=datasets&mart=$first_mart_name</a><br>
- to retrieve attributes available for a dataset: <a href="/biomart/martservice?type=attributes&dataset=$first_dataset_name">http://$server_host$port/biomart/martservice?type=attributes&datatset=$first_dataset_name</a><br>
- to retrieve filters available for a dataset: <a href="/biomart/martservice?type=filters&dataset=$first_dataset_name">http://$server_host$port/biomart/martservice?type=filters&datatset=$first_dataset_name</a><br>
- to retrieve configuration for a dataset: <a href="/biomart/martservice?type=configuration&dataset=$first_dataset_name">http://$server_host$port/biomart/martservice?type=configuration&datatset=$first_dataset_name</a><br>
<br>
For more information see the webservices section of our <a href="http://www.biomart.org/user-docs.pdf">documentation</a>.
</div>
</body>
</html>
);   
}

sub printBiomaRtRegistry
{
print qq(
<MartRegistry>


<MartURLLocation database="ensembl_mart_51" default="1" displayName="Ensembl 51" host="nov2008.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_ENSEMBL" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />

  <MartURLLocation database="sequence_mart_51" default="" displayName="Sequence" host="nov2008.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_SEQUENCE" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="" />

  <MartURLLocation database="ontology_mart_51" default="" displayName="Ontology" host="nov2008.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_ONTOLOGY" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="" />

  <MartURLLocation database="genomic_features_mart_51" default="" displayName="Genomic Features 51" host="nov2008.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_GENOMIC" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="" />

  <MartURLLocation database="snp_mart_51" default="" displayName="SNP 51" host="nov2008.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_SNP" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />

  <MartURLLocation database="vega_mart_51" default="" displayName="Vega 32" host="nov2008.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_VEGA" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />



<MartURLLocation database="ensembl_mart_50" default="1" displayName="Ensembl 50" host="july2008.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_ENSEMBL" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />

  <MartURLLocation database="sequence_mart_50" default="" displayName="Sequence" host="july2008.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_SEQUENCE" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="" />

  <MartURLLocation database="ontology_mart_50" default="" displayName="Ontology" host="july2008.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_ONTOLOGY" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="" />

  <MartURLLocation database="genomic_features_mart_50" default="" displayName="Genomic Features 50" host="july2008.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_GENOMIC" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="" />

  <MartURLLocation database="snp_mart_50" default="" displayName="SNP 50" host="july2008.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_SNP" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />

  <MartURLLocation database="vega_mart_50" default="" displayName="Vega 32" host="july2008.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_VEGA" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />


 <MartURLLocation database="ensembl_mart_49" default="1" displayName="ENSEMBL GENES 49 (SANGER)" host="mar2008.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_ENSEMBL" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />

  <MartURLLocation database="sequence_mart_49" default="" displayName="Sequence" host="mar2008.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_SEQUENCE" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="" />

  <MartURLLocation database="genomic_features_mart_49" default="" displayName="Genomic Features" host="mar2008.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_GENOMIC" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />

  <MartURLLocation database="snp_mart_49" default="" displayName="SNP" host="mar2008.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_SNP" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />

  <MartURLLocation database="vega_mart_49" default="" displayName="Vega" host="mar2008.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_VEGA" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />


 <MartURLLocation database="ensembl_mart_48" default="1" displayName="ENSEMBL GENES 48 (SANGER)" host="dec2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_ENSEMBL" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />

  <MartURLLocation database="sequence_mart_48" default="" displayName="Sequence" host="dec2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_SEQUENCE" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="" />

  <MartURLLocation database="genomic_features_mart_48" default="" displayName="Genomic Features" host="dec2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_GENOMIC" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />

  <MartURLLocation database="snp_mart_48" default="" displayName="SNP" host="dec2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_SNP" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />

  <MartURLLocation database="vega_mart_48" default="" displayName="Vega" host="dec2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_VEGA" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />



  <MartURLLocation database="ensembl_mart_47" default="1" displayName="ENSEMBL GENES 47 (SANGER)" host="oct2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_ENSEMBL" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="sequence_mart_47" default="" displayName="Sequence" host="oct2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_SEQUENCE" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="" />
  <MartURLLocation database="genomic_features_mart_47" default="" displayName="Genomic Features" host="oct2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_GENOMIC" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="snp_mart_47" default="" displayName="SNP" host="oct2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_SNP" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="vega_mart_47" default="" displayName="Vega" host="oct2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_VEGA" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="compara_mart_homology_47" default="" displayName="Compara homology" host="oct2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_COMPARA_MART_HOMOLOGY" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="compara_mart_multiple_ga_47" default="" displayName="Compara multiple alignments" host="oct2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_COMPARA_MART_MULTIPLE" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="compara_mart_pairwise_ga_47" default="" displayName="Compara pairwise alignments" host="oct2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_COMPARA_MART_PAIRWISE" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />

  <MartURLLocation database="ensembl_mart_46" default="1" displayName="ENSEMBL GENES 46 (SANGER)" host="aug2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_ENSEMBL" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="sequence_mart_46" default="" displayName="Sequence" host="aug2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_SEQUENCE" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="" />
  <MartURLLocation database="genomic_features_mart_46" default="" displayName="Genomic Features" host="aug2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_GENOMIC" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="snp_mart_46" default="" displayName="SNP" host="aug2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_SNP" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="vega_mart_46" default="" displayName="Vega" host="aug2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_VEGA" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="compara_mart_homology_46" default="" displayName="Compara homology" host="aug2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_COMPARA_MART_HOMOLOGY" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="compara_mart_multiple_ga_46" default="" displayName="Compara multiple alignments" host="aug2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_COMPARA_MART_MULTIPLE" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="compara_mart_pairwise_ga_46" default="" displayName="Compara pairwise alignments" host="aug2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_COMPARA_MART_PAIRWISE" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />

  <MartURLLocation database="ensembl_mart_45" default="1" displayName="ENSEMBL GENES 45 (SANGER)" host="jun2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_ENSEMBL" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="sequence_mart_45" default="" displayName="Sequence" host="jun2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_SEQUENCE" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="" />
  <MartURLLocation database="snp_mart_45" default="" displayName="SNP" host="jun2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_SNP" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="vega_mart_45" default="" displayName="Vega" host="jun2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_MART_VEGA" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="compara_mart_homology_45" default="" displayName="Compara homology" host="jun2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_COMPARA_MART_HOMOLOGY" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="compara_mart_multiple_ga_45" default="" displayName="Compara multiple alignments" host="jun2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_COMPARA_MART_MULTIPLE" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="compara_mart_pairwise_ga_45" default="" displayName="Compara pairwise alignments" host="jun2007.archive.ensembl.org" includeDatasets="" martUser="" name="ENSEMBL_COMPARA_MART_PAIRWISE" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />

  <MartURLLocation database="ensembl_mart_44" default="1" displayName="ENSEMBL GENES 44 (SANGER)" host="apr2007.archive.ensembl.org" includeDatasets="" includeMarts="" martUser="" name="ENSEMBL_MART_ENSEMBL" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="sequence_mart_44" default="" displayName="Sequence" host="apr2007.archive.ensembl.org" includeDatasets="" includeMarts="" martUser="" name="ENSEMBL_MART_SEQUENCE" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="" />
  <MartURLLocation database="snp_mart_44" default="" displayName="SNP" host="apr2007.archive.ensembl.org" includeDatasets="" includeMarts="" martUser="" name="ENSEMBL_MART_SNP" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="vega_mart_44" default="" displayName="Vega" host="apr2007.archive.ensembl.org" includeDatasets="" includeMarts="" martUser="" name="ENSEMBL_MART_VEGA" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="compara_mart_homology_44" default="" displayName="Compara homology" host="apr2007.archive.ensembl.org" includeDatasets="" includeMarts="" martUser="" name="ENSEMBL_COMPARA_MART_HOMOLOGY" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="compara_mart_pairwise_ga_44" default="" displayName="Compara pairwise alignments" host="apr2007.archive.ensembl.org" includeDatasets="" includeMarts="" martUser="" name="ENSEMBL_COMPARA_MART_PAIRWISE" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />

  <MartURLLocation database="ensembl_mart_43" default="1" displayName="ENSEMBL GENES 43 (SANGER)" host="feb2007.archive.ensembl.org" includeDatasets="" includeMarts="" martUser="" name="ENSEMBL_MART_ENSEMBL" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="sequence_mart_43" default="" displayName="Sequence" host="feb2007.archive.ensembl.org" includeDatasets="" includeMarts="" martUser="" name="ENSEMBL_MART_SEQUENCE" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="" />
  <MartURLLocation database="snp_mart_43" default="" displayName="SNP" host="feb2007.archive.ensembl.org" includeDatasets="" includeMarts="" martUser="" name="ENSEMBL_MART_SNP" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="vega_mart_43" default="" displayName="Vega" host="feb2007.archive.ensembl.org" includeDatasets="" includeMarts="" martUser="" name="ENSEMBL_MART_VEGA" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="compara_mart_homology_43" default="" displayName="Compara homology" host="feb2007.archive.ensembl.org" includeDatasets="" includeMarts="" martUser="" name="ENSEMBL_COMPARA_MART_HOMOLOGY" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />
  <MartURLLocation database="compara_mart_pairwise_ga_43" default="" displayName="Compara pairwise alignments" host="feb2007.archive.ensembl.org" includeDatasets="" includeMarts="" martUser="" name="ENSEMBL_COMPARA_MART_PAIRWISE" path="/biomart/martservice" port="80" serverVirtualSchema="default" visible="1" />

</MartRegistry>
);
}










