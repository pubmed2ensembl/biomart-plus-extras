#!/usr/bin/perl -w

# $Id: 01formatters.t,v 1.1.1.1 2006-11-22 20:32:32 arek Exp $

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
my $formatterDir = "$Bin/../lib/BioMart/Formatter";
my $martservice = "http://test.biomart.org/biomart/martservice";
my $confDir = "$Bin/conf";
my $dataDir = "$Bin/data";
my $testFile = "$dataDir/test.txt";
my $logConf = "$Bin/../conf/log4perl.conf";

# Dataset combinations
my @datasetCombos = (["a"],["b"],["a","b"],["b","a"]);

# Attribute selections.
my %attributes = (
		"__default"=>["plain"],
		"FASTA"=>["plainseq","seqname"]
	);

# What formatters do we have available?
my @formatters = ();
opendir DIRHANDLE, $formatterDir;
(/(.*)\.pm/ and push @formatters, $1) foreach (readdir DIRHANDLE);
closedir DIRHANDLE;
				  
# Test basic classes and formatters can be loaded
my $totalTests = 0;
foreach my $formatter (@formatters) {
	my @attribs = $attributes{$formatter} ? @{$attributes{$formatter}} : @{$attributes{"__default"}};
	my $tests = (11+@attribs)*@datasetCombos;
	foreach (@datasetCombos) { $tests+=(1+@attribs)*(@$_-1) if (@$_>1); }
	$totalTests += $tests + 2;
}
plan tests=>(2+@requires)+$totalTests;
ok(Log::Log4perl->init($logConf), 
	"Logger configuration")
or diag("Check $logConf");
use_ok($_) foreach (@requires);
my $registry;
ok($registry = BioMart::Initializer->new('action'=>'clean','registryFile'=>"$confDir/testRegistry.xml")->getRegistry(),
	"Loading registry") 
or diag("Check that the registry file $confDir/testRegistry.xml exists and is valid");
test_formatter($_) foreach (@formatters);

#------------
# Subroutines
#------------

sub test_formatter {
	my $formatter = shift;
	
	# Does the module load?
	use_ok("BioMart::Formatter::$formatter");
	
	# Does it instantiate?
	my $formatterObj;
	ok(eval("\$formatterObj=BioMart::Formatter::$formatter->new()"), "Instantiate $formatter");
	
	SKIP: {
		# Get the attributes we want for it.
		my $attribs;
		if ($formatterObj->isSpecial()) {
			# Get special attributes.
			$attribs = $attributes{$formatter};
		} else {
			# Get normal attributes.
			$attribs = $attributes{"__default"};
		}
		
		my @testAttribs = $attribs ? @$attribs : @{$attributes{"__default"}};
		my $tests = (11+@testAttribs)*@datasetCombos;
		foreach (@datasetCombos) { $tests+=(1+@testAttribs)*(@$_-1) if (@$_>1); }
		
		skip "Unrecognised format $formatter", $tests
			unless $attribs;
			
		my $binary = $formatterObj->isBinary();
	
		# For each dataset combo, build a query object.
		foreach my $datasetCombo (@datasetCombos) {
			my @datasets = @$datasetCombo;
			# Create query object.
			my $query;
			ok($query = BioMart::Query->new('registry'=>$registry,'virtualSchemaName'=>"default"),
				"Creating query");
			# Attach datasets and attributes.
			foreach (@datasets) {     
    			lives_ok {$query->setDataset($_)}
    				"Setting dataset $_";
    			(lives_ok {$query->addAttribute($_)}
    				"Setting attribute $_") foreach (@$attribs);
			}
			# Set format.
     		ok($query->formatter($formatter), 
     			"Setting format $formatter");
     		my $expFile = "$dataDir/formatter_${formatter}_@{datasets}.txt";
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
				compareFiles($testFile,$expFile,$binary,
					"Comparing API output for $formatter and @datasets");
   			} 
			TODO: {
				local $TODO = "Test web services server not implemented";
				# Get XML.
				my $queryXML = $query->toXML();
				# Execute XML query and compare output
				comparePostQuery($queryXML,
					$expFile,
					$binary,
					"Comparing web services output for $formatter and @datasets");
			}
		}
	}
	
	# Tidy up.
	unlink($testFile);
}

sub compareFiles {
	my ($testFile, $expFile, $binary, $msg) = @_;
	SKIP: {
		skip "File $expFile not found", 1
			if not -e $expFile;
		my $testContent = readFile($testFile,$binary);
		my $expContent = readFile($expFile,$binary);
		ok($testContent eq $expContent, $msg);
	}
}

sub comparePostQuery {
	my ($queryXML, $expFile, $binary, $msg) = @_;
	SKIP: {
		skip "File $expFile not found", 2
			if not -e $expFile;
		my $wsContent = downloadPost($queryXML);
		my $expContent = readFile($expFile,$binary);
		ok($wsContent eq $expContent, $msg);
	}
}

sub readFile {
	my ($file, $binary) = @_;
	open DATA, "<".$file;
	my $content;
	if ($binary) {
		$content = <DATA>;
	} else {
		while (<DATA>) {$content.=$_}
	}
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
