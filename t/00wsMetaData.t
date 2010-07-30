#!/usr/bin/perl -w

# $Id: 00wsMetaData.t,v 1.1.1.1 2006-11-22 20:32:32 arek Exp $

use strict;

use FindBin qw($Bin);
use lib "$Bin";

use LWP::UserAgent;

use Test::More; 

# Where do we live?
my $martservice = "http://test.biomart.org/biomart/martservice";
my $confDir = "$Bin/conf";
my $dataDir = "$Bin/data";
my $testFile = "$dataDir/test.txt";

# How do we see the world?
my $ua = LWP::UserAgent->new();

plan tests=>4*2;

TODO: {
	local $TODO = "Test web services server not implemented";
	
	# Attributes vs. our stored copy of the response?
	compareFileURL("?type=attributes&dataset=a", 
		"$dataDir/wsAttAContent.txt",
		"Attributes for dataset a match");
	compareFileURL("?type=attributes&dataset=b", 
		"$dataDir/wsAttBContent.txt",
		"Attributes for dataset b match");

	# Filters vs. our stored copy of the response?
	compareFileURL("?type=filters&dataset=a", 
		"$dataDir/wsFiltAContent.txt",
		"Filters for dataset a match");
	compareFileURL("?type=filters&dataset=b", 
		"$dataDir/wsFiltBContent.txt",
		"Filters for dataset b match");
}

#------------
# Subroutines
#------------

sub compareFileURL {
	my ($url, $file, $msg) = @_;
	SKIP: {
		skip "File $file not found", 2 if not -e $file;
		my $wsContent = downloadGet($url);
		my $expContent = readFile($file);
		is($wsContent, $expContent, $msg);
	}
}

sub readFile {
	my $file = shift;
	open DATA, "<".$file;
	my $content=<DATA>;
	close DATA;
	return $content;
}

sub downloadGet {
	my $url = shift;
	my $content;
	ok ($content = $ua->get($martservice.$url)->content(), "Downloading $martservice.$url")
	or diag("Check that $martservice is accessible from this machine.");
	return $content;
}