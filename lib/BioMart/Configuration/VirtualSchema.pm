# $Id: 
#
# BioMart module for BioMart::Configuration::VirtualSchema
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::VirtualSchema

=head1 SYNOPSIS

Represents the virtualSchema defined in the martRegistry XML

=head1 DESCRIPTION

All BioMart::Configuration::Location implementing objects are contained
within a BioMart::Configuration::VirtualSchema objects in the
BioMart::Registry. At the very least if no virtualSchema is defined in the
registry configuration a single "default" virtualSchema is generated to 
contain all Locations and Dataset. Datasets contained in different 
virtualSchemas cannot be used in the same BioMart::Query.

=head1  AUTHOR - Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::VirtualSchema;

use strict;
use warnings;
use base qw(BioMart::Root);

use constant NAME => "name";
use constant DISPLAYNAME => "displayName";

use constant TITLES => [ NAME,
			 DISPLAYNAME,
			 ];

sub _new {
  my ($self, @param) = @_;
  $self->SUPER::_new(@param);

  $self->addParams(TITLES, @param);
  $self->attr('default', 0);
  $self->attr('locations', []);
  $self->attr('visible',1);
}

=head2 name

  Usage      : my $name = $virtualSchema->name(); 
               $virtualSchemaName->name($newname);
  Description: sets/gets the name of the VirtualSchema
  Returntype : string name
  Exceptions : none
  Caller     : caller

=cut

sub name {
  my ($self, $newName) = @_;

  if ($newName) {
    $self->setParam(NAME, $newName);
  }
  return $self->getParam(NAME);
}

=head2 displayName

  Usage      : my $displayName = $virtualSchema->displayName(); 
               $virtualSchemaDisplayName->displayName($newdisplayName);
  Description: sets/gets the displayName of the VirtualSchema
  Returntype : string displayName
  Exceptions : none
  Caller     : caller

=cut

sub displayName {
  my ($self, $newDisplayName) = @_;

  if ($newDisplayName) {
    $self->setParam(DISPLAYNAME, $newDisplayName);
  }
  return $self->getParam(DISPLAYNAME);
}

=head2 default

  Usage      : my $default = $virtualSchema->default(); 
               $virtualSchemaDefault->default($newname);
  Description: sets/gets the default flag of the VirtualSchema
  Returntype : string name
  Exceptions : none
  Caller     : caller

=cut

sub default {
  my ($self, $newName) = @_;

  if ($newName) {
    $self->set('default', $newName);
  }
  return $self->get('default');
}


=head2 visible

  Usage      : my $visible = $virtualSchema->visible(); 
               $virtualSchema->visible($newname);
  Description: sets/gets the visible flag of the VirtualSchema
  Returntype : string name
  Exceptions : none
  Caller     : caller

=cut

sub visible {
  my ($self, $newName) = @_;

  if (defined($newName)) {
    $self->set('visible', $newName);
  }
  return $self->get('visible');
}

=head2 addLocation

  Usage      : usage
  Description: Description
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub addLocation {
  my ($self, $location) = @_;
  my $locations = $self->get('locations');
  push @{$locations}, $location;
}


=head2 removeLocation

  Usage      : usage
  Description: Description
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub removeLocation {
  my ($self,$location) = @_;
  my $locations = $self->getAllLocations;
  my $i = 0;
  foreach my $loc (@$locations){
      if ($loc->name eq $location->name){
	  splice @$locations,$i,1;
	  last;
      }
      $i++;
  }
}

=head2 getAllLocations

  Usage      : usage
  Description: [deprecated] to be replaced with getAllMarts
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub getAllLocations {
  my $self = shift;
  return $self->get('locations');
}

=head2 getAllMarts

  Usage      : getAllMarts(martusers-required, visible as 1-optional)
  Description: Replaced the old getAllLocations call
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub getAllMarts {
  	my ($self, $visible) = @_;

	if(!$visible)
	{
		return  $self->get('locations');
	}
	if ($visible == 1)
	{
		my $allMarts = $self->get('locations');
		my $Marts;
		foreach my $mart(@$allMarts)
  		{				
			if($visible eq $mart->visible()) 
			{
  				push @{$Marts}, $mart;  			
  			}
  		}
  		return $Marts;  
	}
}

sub getMartByName {
  	my ($self, $name) = @_;

		my $allMarts = $self->get('locations');
		my $Marts;
		foreach my $mart(@$allMarts)
  		{				
			if($name eq $mart->name()) 
			{
				return $mart;
  			}
  		}
  		return undef;  
}

=head2 getDatasetByName

  Usage      : usage
  Description: Description
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub getDatasetByName {
  my ($self,$datasetName) = @_;
  my $retDataset;
  LOC:foreach my $location(@{$self->getAllLocations}){
      foreach my $dataset(@{$location->getAllDatasets}){
	  if ($dataset->name eq $datasetName){
	      $retDataset = $dataset;
	      last LOC;
	  }
      }
  }
  return $retDataset;
}



1;
