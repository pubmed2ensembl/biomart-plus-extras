#!/usr/bin/perl -w

# $Id: 03das.t,v 1.1.1.1 2006-11-22 20:32:32 arek Exp $

use strict;

use FindBin qw($Bin);
use lib "$Bin/conf";
use lib "$Bin/../lib";

use Log::Log4perl;

use Test::More;  
use Test::Exception;

# Where do we live?
my $logConf = "$Bin/../conf/log4perl.conf";

# Test basic classes and formatters can be loaded
plan tests=>4;
ok(Log::Log4perl->init($logConf), 
	"Logger configuration")
or diag("Check $logConf");
	
SKIP: {
	eval("use Bio::Das::ProServer::SourceAdaptor::biomart");
	skip "Skipping as ProServer biomart plugin is not installed.\n\n".
	"****\n".
	"If you want to run this test, download ProServer, copy das/biomart.pm into\n".
	"lib/Bio/Das/ProServer/SourceAdaptor folder inside ProServer, then add\n".
	"the ProServer lib directory to \@INC.\n".
	"****", 3
		if $@;
	my %config = (
			"registryPath"=>"$Bin/conf/testRegistry.xml",
			"virtualSchema"=>"default",
			"dataset"=>"das",
			"mart"=>"mysqldb",
			"linkName"=>"das_test",
			"feature_keys"=>"id,start,end,type,method,ori"
		);
	my $das;
	lives_ok {$das = Bio::Das::ProServer::SourceAdaptor::biomart->new({"config"=>\%config})} "Instantiating client";
	my @features;
	lives_ok {@features = $das->build_features({"segment"=>"X", "start"=>"10", "end"=>"5000"})}
		"Getting features";
	ok(@features==1,"Checking feature count") or diag("Expected one feature - check the dataset contents.");
}
