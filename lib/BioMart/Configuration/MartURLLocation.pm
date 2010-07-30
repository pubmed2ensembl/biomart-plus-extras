# $Id: 
#
# BioMart module for BioMart::Configuration::MartURLLocation
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::MartURLLocation

=head1 SYNOPSIS

A Location that represents the configuration for a mart database accessed
via a mart server

=head1 DESCRIPTION


=head1 AUTHOR - Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::MartURLLocation;

use strict;
use warnings;

use base qw(BioMart::Configuration::URLLocation);


=head2 _new

  Usage      : see Usage for BioMart::Configuration::Location.
  Description: creates a new MartURLLocation object which ...
  Returntype : BioMart::Configuration::MartURLLocation
  Exceptions : none
  Caller     : general

=cut

sub _new {
  my ($self, @param) = @_;
  $self->SUPER::_new(@param);
}


=head2 getXMLWeb

  Usage      :  my $xml = $configurator->getXMLWeb($dataset);
  Description:  Gets XML from the web server
  Return type:  xml hash
  Exceptions :
  Caller     :

=cut

sub getDatasetConfigXML{
    my ($self,$virtualSchema,$dataSetName,$interface,$dsCounter, $noMessage)=@_;
    $virtualSchema = $self->serverVirtualSchema;
    my $dbhost = $self->host; 
    my $dbport = $self->port;
	if (!$noMessage)
	{
	    $self->configureMessage($virtualSchema,$dataSetName,"WEB",$dsCounter);
	}
     
    my $qualifier="type=configuration&virtualschema=".$virtualSchema.
	"&dataset=".$dataSetName."&interface=".$interface."&martuser=".
	$self->martUser;
    my $xml = join "",$self->getResultSet($qualifier,"GET");
    return $xml;
}


sub versionCheck{
    my ($self,$version)=@_;
    my $virtualSchema = $self->serverVirtualSchema;
    my $qualifier="type=versioncheck&virtualschema=".$virtualSchema.
	"&mart=".$self->name."&version=".$version;
    my $count = join "",$self->getResultSet($qualifier,"GET");
    return $count;
}


sub version{
    my ($self)=@_;
    my $virtualSchema = $self->serverVirtualSchema;
    my $qualifier="type=version&virtualschema=".$virtualSchema."&mart=".
	$self->name;
    my $version = join "",$self->getResultSet($qualifier,"GET");
    return $version;
}


sub interfaces{
     my ($self,$dataset)=@_;
     my $qualifier ="type=interfaces&virtualschema=".
	 $self->serverVirtualSchema."&mart=".$self->name."&martuser=".
	 $self->martUser."&dataset=".$dataset;
     my $interfaces = join "",$self->getResultSet($qualifier,"GET");
     return $interfaces;
}


sub _retrieveDatasetInfo {

    my ($self,$vSchemaName, $virtualSchemaDefault)=@_;
    
    $vSchemaName = $self->serverVirtualSchema;

    my @datasets;     
    my $qualifier ="type=datasets&virtualschema=".$vSchemaName."&mart=".
	$self->name."&martuser=".$self->martUser;    
    my @include_datasets=split(/\,/,$self->includeDatasets);
    
    foreach my $el ($self->getResultSet($qualifier,"GET")){
	unless ($el  =~/^\s/){
	    
	    my @line = split(/\t/,$el);

	    if (scalar (@include_datasets)>0){
		foreach my $ds (@include_datasets){	
		    if ($ds eq $line[1]){
			my %data = ('type'             => $line[0],
				    'dataset'          => $line[1],
				    'displayName'      => $line[2],
				    'visible'          => $line[3],
				    'version'          => $line[4],
				    'initialBatchSize' => $line[5],
				    'maxBatchSize'     => $line[6],
				    'interfaces'       => $line[7] ,
				    'modified' 	=> $line[8]);
			push (@datasets, \%data);
		    }	
		}
	    } else {
		my %data = ('type'             => $line[0],
			    'dataset'          => $line[1],
			    'displayName'      => $line[2],
			    'visible'          => $line[3],
			    'version'          => $line[4],
			    'initialBatchSize' => $line[5],
			    'maxBatchSize'     => $line[6],
				'interfaces'       => $line[7],
				'modified' 	=> $line[8]);
	
		push (@datasets, \%data);
	    }
	}
    }
    
    $self->datasetNumber(scalar @datasets);

    return @datasets;		   
}


1;
