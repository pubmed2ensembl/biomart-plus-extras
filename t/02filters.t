#!/usr/bin/perl -w

# $Id: 02filters.t,v 1.1.1.1 2006-11-22 20:32:32 arek Exp $

use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use LWP::UserAgent;
use Log::Log4perl;

use Test::More;  
use Test::Exception;

# What classes do we need to load?
my @requires = qw/BioMart::Initializer
				  BioMart::Query
				  BioMart::QueryRunner/;

# How do we see the world?
my $ua = LWP::UserAgent->new();

# Where do we live?
my $martservice = "http://test.biomart.org/biomart/martservice";
my $confDir = "$Bin/conf";
my $dataDir = "$Bin/data";
my $testFile = "$dataDir/test.txt";
my $logConf = "$Bin/../conf/log4perl.conf";

# What filters are we testing?
my @datasetCombos = (["a"],["b"],["a","b"],["b","a"]);
my @attribs = (
		"plain"
	);
my %filters = (
		"attrfilt" => ["afval1"],
		"plain" => ["mvala1","mvalb1"],
		"with_dim1_bool" => ["only"],
		"with_dim2_bool" => ["excluded"],
		"localph" => ["localph1"],
		"remoteph" => ["remoteph1"]
	);
	
# Test basic classes and formatters can be loaded
my $testsPerFilter = (12+@attribs)*@datasetCombos;
foreach (@datasetCombos) { $testsPerFilter+=(1+@attribs)*(@$_-1) if (@$_>1); }
plan tests=>(2+@requires)+($testsPerFilter*keys(%filters));
ok(Log::Log4perl->init($logConf), 
	"Logger configuration")
or diag("Check $logConf");
use_ok($_) foreach (@requires);
my $registry;
ok($registry = BioMart::Initializer->new('action'=>'clean','registryFile'=>"$confDir/testRegistry.xml")->getRegistry(),
	"Loading registry") 
or diag("Check that the registry file $confDir/testRegistry.xml exists and is valid");
while (my ($filterName,$filterValue) = each(%filters)) { 
	test_filter($filterName, $filterValue);
}

#------------
# Subroutines
#------------

sub test_filter {
	my ($filterName, $filterValue) = @_;

	# For each dataset combo, build a query object.
	foreach my $datasetCombo (@datasetCombos) {
		my @datasets = @$datasetCombo;
		# Create query object.
		my $query;
		ok($query = BioMart::Query->new('registry'=>$registry,'virtualSchemaName'=>"default"),
			"Creating query");		
		# Attach datasets and attributes and filters.
		foreach (@datasets) {     
    		lives_ok {$query->setDataset($_)}
    			"Setting dataset $_";
    		(lives_ok {$query->addAttribute($_)}
    			"Setting attribute $_") foreach (@attribs);
    		if ($_ eq $datasets[0]) {
    			my $newFilterName = $filterName;
    			$newFilterName = "plain".$_."filt" if ($filterName eq "attrfilt");
    			$newFilterName = "plain".$_ if ($filterName eq "localph");
    			$newFilterName = "plain".($_ eq 'a' ? 'b' : 'a') if ($filterName eq "remoteph");
    			lives_ok {$query->addFilter($newFilterName, $filterValue)}
    				"Setting filter $filterName=>@$filterValue";
    		}
		}
		# Set format.
   		ok($query->formatter("TXT"),
   			"Setting formatter to TXT");
   		my $expFile = "$dataDir/filter_${filterName}_@{datasets}.txt";
		# Execute query.
  	  	my $query_runner;
  	  	ok($query_runner = BioMart::QueryRunner->new(), 
  	  		"Creating query runner");
   		SKIP: {
   			skip "Query failed", 4
   				unless lives_ok {$query_runner->execute($query)}
							"Executing query";
  	  		open my $TESTFILE, ">$testFile";
   			lives_ok {$query_runner->printHeader($TESTFILE)} 
   				"Printing header";
	   		lives_ok {$query_runner->printResults($TESTFILE)}
   				"Printing results";
   			lives_ok {$query_runner->printFooter($TESTFILE)} 
   				"Printing footer";
	   		close $TESTFILE;
			# Compare output.
			compareFiles($testFile,$expFile,
				"Comparing API output for $filterName and @datasets");
   		} 
		TODO: {
			local $TODO = "Test web services server not implemented";
			# Get XML.
			my $queryXML = $query->toXML();
			# Execute XML query and compare output
			comparePostQuery($queryXML,
				$expFile,
				"Comparing web services output for $filterName and @datasets");
		}
	}

	# Tidy up.
	unlink($testFile);
}

sub compareFiles {
	my ($testFile, $expFile, $msg) = @_;
	SKIP: {
		skip "File $expFile not found", 1
			if not -e $expFile;
		my $testContent = readFile($testFile);
		my $expContent = readFile($expFile);
		ok($testContent eq $expContent, $msg);
	}
}

sub comparePostQuery {
	my ($queryXML, $expFile, $msg) = @_;
	SKIP: {
		skip "File $expFile not found", 2
			if not -e $expFile;
		my $wsContent = downloadPost($queryXML);
		my $expContent = readFile($expFile);
		ok($wsContent eq $expContent, $msg);
	}
}

sub readFile {
	my $file = shift;
	open DATA, "<".$file;
	my $content;
	while (<DATA>) {$content.=$_}
	close DATA;
	return $content;
}

sub downloadPost {
	my ($queryXML) = @_;
	my $content;
	ok ($content = $ua->post($martservice,{'query'=>$queryXML."\n"})->content(), 
		"Executing web query")
	or diag("Check that $martservice is accessible from this machine.");
	return $content;
}
