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

=head1 AUTHOR - Syed Haider

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
use Cwd;
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
$CONF_FILE = '[TAG:conf]';

#the TAG:server_host below gets replaced by OPTIONS{server_host}
$server_host = '[TAG:server_host]';

#the TAG:server_port below gets replaced by OPTIONS{server_port}
$server_port = '[TAG:server_port]';

#the TAG:log_dir below gets replaced by path to log dir
$log_Dir = '[TAG:log_dir]';

#the TAG:cgiLocation below gets replaced by OPTIONS{cgiLocation}
$cgiLocation = '[TAG:cgiLocation]';

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

my $segment = $CGI->param('segment');
my $url_string = $CGI->self_url();
$url_string =~ m/.*?\/das\/(.*)\/features.*/;
my $dasDSNName = $1;
my @schema__DS = split(/__/, $1);
my $schemaName= $schema__DS[0];
my $dasDatasetName = $schema__DS[1];
my $dasExportableName = $schema__DS[2];

#print "MY DAS DATASET: ", $dasDatasetName;
#exit();

my $registry;
if (!$main::BIOMART_REGISTRY)
{
	my $initializer = BioMart::Initializer->new('registryFile'=>$CONF_FILE);
	$registry = $initializer->getRegistry;
} 
else 
{
	$registry = $main::BIOMART_REGISTRY;
}


eval{
	if($segment)
	{
		my $exportable_type = &exportableType($registry, $schemaName, $dasDatasetName, $dasExportableName);
		my $results;
		# print "EXP _TYPE: $exportable_type";
		if ($exportable_type eq 'dasGene') {
			$results = &get_geneAnnotation($registry, $schemaName, $dasDatasetName, $dasDSNName, $segment, $dasExportableName);
		}
		elsif ($exportable_type eq 'dasRegionFeature') {
			$results = &get_chromosomeAnnotationFeatures($registry, $schemaName, $dasDatasetName, $dasDSNName, $segment, $dasExportableName);
		}
		elsif ($exportable_type eq 'dasChr' || $exportable_type eq 'dasRegionGene') {	
			$results =  &get_chromosomeAnnotationGTE($registry, $schemaName, $dasDatasetName, $dasDSNName, $segment, $dasExportableName);
		}
		else {
		}
		
		# print results 
		if ($results)
		{
			print $CGI->header(	-'type' =>'text/xml',
								-'X-DAS-Version' => 'DAS/1.5',
								-'X-DAS-Status'  => '200',
								-'X-DAS-Capabilities' => 'dsn/1.0; features/1.0;',
								-'charset' => 'utf-8');
			print $results;
		}
		else {
			# print Error codes here
		}
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

# To decide if its a gene request or a chromosome request when segment=SOMETHING
# where SOMETHING could be chrName or a GeneName
# Algorithm requests all the chromosomes if dasChr exportable exists
# and checks if the requested chromosome exists. If it does, then its a Chromosome request
# otherwise its a gene Request
sub exportableType
{
	my ($registry, $schemaName, $dasDatasetName, $exportableName) = @_;
	
	foreach my $schema (@{$registry->getAllVirtualSchemas()}) {
		if ($schemaName eq $schema->name){	
			foreach my $mart (@{$schema->getAllMarts(0)}) {
				foreach my $dataset (@{$mart->getAllDatasets(0)}) {
					if ($dataset->name eq $dasDatasetName) {
						foreach my $exportable (@{$dataset->getExportables()}) {
							if($exportableName eq $exportable->name) {
								return $exportable->type();
							}
						}
					}
				}
			}
		}
	}
}



#GeneView

#DAS sources serving non-positional features (or GeneDAS sources) can be attached to GeneView (see
#example for human) which displays gene information. Non-positional feature DAS is a semantic extension 
#to the DAS protocol. It allows exchange of annotations tied to identifiers, such as a HUGO gene name or 
#an Ensembl gene ID, rather than to a segment of reference sequence. Positional data is irrelevant and 
#the annotation applies to the entire entity referenced by the request. GeneDAS annotations are defined 
#as having 'start' and 'end' attributes set to 0 (zero) and the annotation itself is carried in the 
#'note' attribute.

# Ensembl calls this as .../das/DSN/features?segment=ENSGid
sub get_geneAnnotation
{
	my ($registry, $schemaName, $dasDatasetName, $dasDSNName, $geneID, $exp_name) = @_;
	my $results;
	my $temp_results;
	my @resultRows;
	my $attributeList;
	my $linkURL;
	my $hrefURL;
	my $dsDisplayName; 
	
	my $query = BioMart::Query->new('registry'=>$registry,'virtualSchemaName'=>$schemaName);
     
	$query->setDataset($dasDatasetName);
	
	foreach my $schema (@{$registry->getAllVirtualSchemas()}) {
		if ($schemaName eq $schema->name){	
			foreach my $mart (@{$schema->getAllMarts(0)}) {
				foreach my $dataset (@{$mart->getAllDatasets(0)}) {
					if ($dataset->name eq $dasDatasetName) {
						$dsDisplayName = $dataset->displayName;
						foreach my $exportable (@{$dataset->getExportables()}) {
							if($exportable->name() eq $exp_name) {
								foreach my $importable (@{$dataset->getImportables()}) {
									if($importable->name() eq $exp_name) {
										$attributeList = $exportable->attributeString();
										foreach (split(/,/, $exportable->attributeString() ))
										{
											$query->addAttribute($_);	
										}
										# no need to split, this should strictly be a single filter GeneId
										foreach (split(/,/, $importable->filterString() ))
										{
											$query->addFilter($_, [$geneID]);	
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
	# GET THE URL LINK using the second attribute in attributeString, fetch its object and find link URL
	if ($attributeList)
	{
		my @portions = split (/,/,$attributeList);
		my $datasetObj = $registry->getDatasetByName($schemaName, $dasDatasetName);
		my $dataset_conf  = $datasetObj->getConfigurationTree('default');
		my $attributeObj = $dataset_conf->getAttributeByName($portions[1]);
		$linkURL = $attributeObj->link();
		$linkURL =~ s/^exturl\|//;
	}

	open(my $result_buffer, '>', \$temp_results);

	my $query_runner = BioMart::QueryRunner->new();
	$query_runner->uniqueRowsOnly(1);
	$query_runner->execute($query);
	#$query_runner->printHeader();
	$query_runner->printResults($result_buffer);
	#$query_runner->printFooter();		
	close($result_buffer);
	#&dummyResultsGene();
	
	$results .= &header();
	$results .= &GFF_open("http://[TAG:server_host]/[TAG:cgiLocation]/das/$dasDSNName/features");
	$results .= &segment_open($geneID, "1", ""); # first argument should be the same as sent by ensembl as geneID
	
	@resultRows = split(/\n/, $temp_results);
	foreach my $line (@resultRows) {
		my @portions = split (/\t/, $line);
	
		$results .= &feature_open($portions[1], $portions[1]);
		#$results .= &type($portions[1],"no","no","no", $portions[1]);
		$results .= &type($dsDisplayName,"no","no","no", $dsDisplayName);
		$results .= &method("methodID:unknown", "");
		$results .= &start("0");
		$results .= &end("0");
		$results .= &score("-");
		$results .= &orientation("0");
		$results .= &phase("-");
		$results .= &note($portions[2]);

		$hrefURL = sprintf ($linkURL, defined ($linkURL) ? $portions[1] : '');
		$results .= &link($hrefURL, $portions[1])  if($hrefURL);

		$results .= &feature_close();
	}	
	
	$results .= &segment_close();
	$results .= &GFF_close();
	$results .= &footer();
	
	return $results;
}

# ContigView
# retrieve annotation over a segment but results are independent features and
# doesnt follow strict grouping as of Gene Transcript Exon
sub get_chromosomeAnnotationFeatures
{
	
	my ($registry, $schemaName, $dasDatasetName, $dasDSNName, $coordinates_string, $exp_name) = @_;

	my $resultsHash;
	my $results;
	my $temp_results;
	my @resultRows;
	my $counter = 0;
	my	$attributeList;
	my $linkURL;
	my $hrefURL;	
	my $dsDisplayName; 
	my ($chromosome, $start, $end);
	
	if ($coordinates_string =~ m/:/) {
		my @portions = split( /:/, $coordinates_string);
		$chromosome =  $portions[0];
		($start , $end ) = split (/\,/, $portions[1]) ;
	}
	else {
		$chromosome = $coordinates_string;
	}
	
	my $query = BioMart::Query->new('registry'=>$registry,'virtualSchemaName'=>$schemaName);
     
	$query->setDataset($dasDatasetName);

	foreach my $schema (@{$registry->getAllVirtualSchemas()}) {
		if ($schemaName eq $schema->name){	
			foreach my $mart (@{$schema->getAllMarts(0)}) {
				foreach my $dataset (@{$mart->getAllDatasets(0)}) {
					if ($dataset->name eq $dasDatasetName) {
						$dsDisplayName = $dataset->displayName;
						foreach my $exportable (@{$dataset->getExportables()}) {
							if($exportable->name() eq $exp_name) {
								foreach my $importable (@{$dataset->getImportables()}) {
									if($importable->name() eq $exp_name) {
										$attributeList = $exportable->attributeString();									
										foreach (split(/,/, $exportable->attributeString() ))
										{
											$query->addAttribute($_);	
										}							
										my @temp_arr = split(/,/, $importable->filterString());
										$query->addFilter($temp_arr[0], [$chromosome]);
										$query->addFilter($temp_arr[1], [$start])		if ($start);
										$query->addFilter($temp_arr[2], [$end])		if ($end);									
									}
								}
							}
						}
					}
				}
			}
		}
	}
	
	# GET THE URL LINK using the first attribute in attributeString, fetch its object and find link URL
	if ($attributeList)
	{
		my @portions = split (/,/,$attributeList);
		my $datasetObj = $registry->getDatasetByName($schemaName, $dasDatasetName);
		my $dataset_conf  = $datasetObj->getConfigurationTree('default');
		my $attributeObj = $dataset_conf->getAttributeByName($portions[0]);
		$linkURL = $attributeObj->link();
		$linkURL =~ s/^exturl\|//;
	}
	
	open(my $result_buffer, '>', \$temp_results);

	my $query_runner = BioMart::QueryRunner->new();
	$query_runner->uniqueRowsOnly(1);
	$query_runner->execute($query);
	#$query_runner->printHeader();
	$query_runner->printResults($result_buffer);
	#$query_runner->printFooter();		
	close($result_buffer);

	$results .= &header();
	$results .= &GFF_open("http://[TAG:server_host]/[TAG:cgiLocation]/das/$dasDSNName/features");
	$results .= &segment_open($chromosome, $start, $end);
	
	
	
	@resultRows = split(/\n/, $temp_results);
	foreach my $line (@resultRows) {
		my @portions = split (/\t/, $line);
	
		$results .= &feature_open($portions[0], $portions[0]);
		#$results .= &type($portions[1],"no","no","no", $portions[1]);
		$results .= &type($dsDisplayName,"no","no","no", $dsDisplayName);
		$results .= &method("methodID:unknown", "");
		$results .= &start($portions[1]);
		$results .= &end($portions[2]);
		$results .= &score("-");
		$results .= &orientation($portions[3]);
		$results .= &phase("-");
		$results .= &note("");
		
		$hrefURL = sprintf ($linkURL, defined ($linkURL) ? $portions[0] : '');
		$results .= &link($hrefURL, $portions[0])  if($hrefURL);

		$results .= &feature_close();
	}	
	
	$results .= &segment_close();
	$results .= &GFF_close();
	$results .= &footer();
	
	return $results;
}


#ContigView and CytoView

#A genomic DAS source serves data in the format specified in the DAS/1.5 specification. In Ensembl, 
#genomic DAS sources can be attached to ContigView and CytoView (see examples in human) if the annotation 
#is in chromosomal coordinates, on contigs or on any basic assembly structure known to Ensembl for that 
#species. For genomic DAS sources the assembly version is important as otherwise features from a source 
#annotation (e.g. NCBI 34 human assembly) may be offset in ContigView.

#Please note that for most species, Ensembl chromosomes are named like "1", "2", "X", "Y" rather than 
#like "chr1", "chr2", "chrX", "chrY". The exceptions are the Drosophila melanogaster, Anopheles gambiae, 
#Caenorhabditis elegans, and Saccharomyces cerevisiae genomes which uses other naming conventions.

# Ensembl calls this as .../das/DSN/features?segment=13:31787617,31871805

sub get_chromosomeAnnotationGTE
{
	my ($registry, $schemaName, $dasDatasetName, $dasDSNName, $coordinates_string, $exp_name) = @_;
	my $resultsHash;
	my $results;
	my $temp_results;
	my @resultRows;
	my $counter = 0;
	my ($chromosome, $start, $end);
	
	if ($coordinates_string =~ m/:/) {
		my @portions = split( /:/, $coordinates_string);
		$chromosome =  $portions[0];
		($start , $end ) = split (/\,/, $portions[1]) ;
	}
	else {
		$chromosome = $coordinates_string;
	}
	
	my $query = BioMart::Query->new('registry'=>$registry,'virtualSchemaName'=>$schemaName);
     
	$query->setDataset($dasDatasetName);

	foreach my $schema (@{$registry->getAllVirtualSchemas()}) {
		if ($schemaName eq $schema->name){	
			foreach my $mart (@{$schema->getAllMarts(0)}) {
				foreach my $dataset (@{$mart->getAllDatasets(0)}) {
					if ($dataset->name eq $dasDatasetName) {
						foreach my $exportable (@{$dataset->getExportables()}) {
							if($exportable->name() eq $exp_name) {
								foreach my $importable (@{$dataset->getImportables()}) {
									if($importable->name() eq $exp_name) {
										foreach (split(/,/, $exportable->attributeString() ))
										{
											$query->addAttribute($_);	
										}							
										my @temp_arr = split(/,/, $importable->filterString());
										$query->addFilter($temp_arr[0], [$chromosome]);
										$query->addFilter($temp_arr[1], [$start])		if ($start);
										$query->addFilter($temp_arr[2], [$end])		if ($end);									
									}
								}
							}
						}
					}
				}
			}
		}
	}
	open(my $result_buffer, '>', \$temp_results);

	my $query_runner = BioMart::QueryRunner->new();
	$query_runner->uniqueRowsOnly(1);
	$query_runner->execute($query);
	#$query_runner->printHeader();
	$query_runner->printResults($result_buffer);
	#$query_runner->printFooter();		
	close($result_buffer);


	# establish a multi-dimensional hash to store all the structure table information for xml transformation
	@resultRows = split(/\n/, $temp_results);
	foreach my $line (@resultRows) {
		no warnings 'uninitialized';
		my @portions = split (/\t/, $line);
		
		$resultsHash->{$portions[0]}->{'start'} = $portions[1];
		$resultsHash->{$portions[0]}->{'end'} = $portions[2];
		$resultsHash->{$portions[0]}->{'strand'} = $portions[3];

		$resultsHash->{$portions[0]}->{'transcript'}->{$portions[4]}->{'start'} = $portions[5];
		$resultsHash->{$portions[0]}->{'transcript'}->{$portions[4]}->{'end'} = $portions[6];
		$resultsHash->{$portions[0]}->{'transcript'}->{$portions[4]}->{'strand'} = $portions[3];

		$resultsHash->{$portions[0]}->{'transcript'}->{$portions[4]}->{'exon'}->{$portions[7]}->{'start'} = $portions[8];
		$resultsHash->{$portions[0]}->{'transcript'}->{$portions[4]}->{'exon'}->{$portions[7]}->{'end'} = $portions[9];
		$resultsHash->{$portions[0]}->{'transcript'}->{$portions[4]}->{'exon'}->{$portions[7]}->{'strand'} = $portions[3];
	}
	
	#print Dumper($resultsHash);	
	
	####  represent $resultsHash in terms of DAS XML
		
	$results .= &header();
	$results .= &GFF_open("http://[TAG:server_host]/[TAG:cgiLocation]/das/$dasDSNName/features");	
	$results .= &segment_open($chromosome, $start, $end);

	################################### ADDING GENE FEATURES
	foreach my $geneID (keys %{$resultsHash}) {
	
		$results .= &feature_open($geneID, $geneID);
		$results .= &type("gene","no","no","no", "gene");
		$results .= &method("methodID:unknown", "");
		$results .= &start($resultsHash->{$geneID}->{'start'});
		$results .= &end($resultsHash->{$geneID}->{'end'});
		$results .= &score("-");
			
		$results .= &orientation("+") 
			if ($resultsHash->{$geneID}->{'strand'} == 1) ;
		$results .= &orientation("-") 
			if ($resultsHash->{$geneID}->{'strand'} == -1) ;
			
		$results .= &phase("-");
		$results .= &feature_close();
	}

	################################### ADDING TRANSCRIPT FEATURES
	foreach my $geneID (keys %{$resultsHash}) {
		foreach my $transcriptID (keys %{$resultsHash->{$geneID}->{'transcript'}}) {
		
			$results .= &feature_open($transcriptID, $transcriptID);
			$results .= &type("transcript","no","no","no", "transcript");
			$results .= &method("methodID:unknown", "");
			$results .= &start($resultsHash->{$geneID}->{'transcript'}->{$transcriptID}->{'start'});
			$results .= &end($resultsHash->{$geneID}->{'transcript'}->{$transcriptID}->{'end'});
			$results .= &score("-");
			
			$results .= &orientation("+") 
				if ($resultsHash->{$geneID}->{'transcript'}->{$transcriptID}->{'strand'} == 1) ;
			$results .= &orientation("-") 
				if ($resultsHash->{$geneID}->{'transcript'}->{$transcriptID}->{'strand'} == -1) ;
			
			$results .= &phase("-");
			$results .= &group($geneID, "gene", $geneID) ;
			$results .= &feature_close();
		}
	}
	################################### ADDING EXON FEATURES

	foreach my $geneID (keys %{$resultsHash}) {
		foreach my $transcriptID (keys %{$resultsHash->{$geneID}->{'transcript'}}) {
			foreach my $exonID (keys %{$resultsHash->{$geneID}->{'transcript'}
							->{$transcriptID}->{'exon'}}) {
							
				$results .= &feature_open($exonID, $exonID);
				$results .= &type("exon","no","no","no", "exon");
				$results .= &method("methodID:unknown", "");
				$results .= &start($resultsHash->{$geneID}->{'transcript'}->{$transcriptID}
											->{'exon'}->{$exonID}->{'start'});
				$results .= &end($resultsHash->{$geneID}->{'transcript'}->{$transcriptID}
											->{'exon'}->{$exonID}->{'end'});
				$results .= &score("-");
			
				$results .= &orientation("+") 
					if ($resultsHash->{$geneID}->{'transcript'}->{$transcriptID}->{'strand'} == 1) ;
				$results .= &orientation("-") 
					if ($resultsHash->{$geneID}->{'transcript'}->{$transcriptID}->{'strand'} == -1) ;
		
				$results .= &phase("-");
			
				$results .= &group($transcriptID, "transcript", $transcriptID) ;
				$results .= &group($geneID, "gene", $geneID) ;
				$results .= &feature_close();
			}
		}
	}
	
	
	###############################################################
	$results .= &segment_close();
	$results .= &GFF_close();
	$results .= &footer();
	
	return $results;
	#&dummyResultsContig();

}
##################################################################
################### FORMATTING SUBROUTINES #######################
##################################################################
sub header
{
	my $version;
	
	return qq|<?xml version="1.0" standalone="yes"?>
	<!DOCTYPE DASGFF SYSTEM "http://www.biodas.org/dtd/dasgff.dtd">
	<DASGFF>	|;
}

sub GFF_open
{
	my $hrefURL = shift;
	no warnings 'uninitialized';
	return qq|
	<GFF version="1.0" href="|.$hrefURL.qq|" >		|;
}
sub segment_open
{
	my ($id, $start, $end) = @_;
	no warnings 'uninitialized';
	return qq|
	<SEGMENT id="|.$id.qq|" version="1.0" start="|.$start.qq|" stop="|.$end.qq|">	|;
}

sub feature_open
{
	my ($id, $label) = @_;
	no warnings 'uninitialized';
	return qq|
		<FEATURE id="|.$id.qq|" label="|.$label.qq|">	|;
}
sub type
{
	my ($id, $reference, $subparts, $superparts, $val) = @_;
	no warnings 'uninitialized';
	# return qq|
	#	<TYPE id="|.$id.qq|"  reference="|.$reference.qq|" subparts="|.$subparts.qq|" superparts="|.$superparts.qq|">$val</TYPE>	|;
	return qq|
		<TYPE id="|.$id.qq|">$val</TYPE>	|;

}
sub method
{
	my ($id, $val) = @_;
	return qq|
		<METHOD id="|.$id.qq|">$val</METHOD>	|;
	

}
sub start
{
	my $val = shift;
	no warnings 'uninitialized';
	return qq|
		<START>$val</START>	|;
}
sub end
{
	my $val = shift;
	no warnings 'uninitialized';
	return qq|
		<END>$val</END>	|;

}
sub score
{
	my $val = shift;
	no warnings 'uninitialized';
	return qq|
		<SCORE>$val</SCORE>	|;

}
sub orientation
{
	my $val = shift;
	no warnings 'uninitialized';
	return qq|
		<ORIENTATION>$val</ORIENTATION>	|;
}
sub phase
{
	my $val = shift;
	no warnings 'uninitialized';
	return qq|
		<PHASE>$val</PHASE>	|;

}
sub note
{
	my $val = shift;
	no warnings 'uninitialized';
	return qq|
		<NOTE>$val</NOTE>	|;
}
sub link
{
	my ($url, $label) = @_;
	no warnings 'uninitialized';
	return qq|
		<LINK href="|.$url.qq|">$label</LINK>|;
}
sub target
{

}
sub group
{
	my ($id, $type, $label) = @_;
	no warnings 'uninitialized';
	return qq|
		<GROUP id="|.$id.qq|" type="|.$type.qq|" label="|.$label.qq|"/>	|;
}
sub feature_close
{
	return qq|
	</FEATURE>	|;
}
sub segment_close
{
	return qq|
    </SEGMENT>    |;

}
sub GFF_close
{
	return qq|
	</GFF>	|;
}
sub footer
{
	return qq|
	</DASGFF>	|;
}

##################################################################
##################################################################
sub dummyResultsGene
{
}
sub dummyResultsContig()
{
}
