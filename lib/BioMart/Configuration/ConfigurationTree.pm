# $Id: ConfigurationTree.pm,v 1.6 2008-04-09 12:52:33 syed Exp $
#
# BioMart module for BioMart::Configuration::ConfigurationTree
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::ConfigurationTree

=head1 SYNOPSIS

BioMart::Configuration::ConfigurationTree represent the whole of the
datasetConfig XML recovered from the mart database/server for a 
particluar dataset

=head1 DESCRIPTION

BioMart::Configuration::ConfigurationTree is the top level object of
the object hierarchy representing the datasetConfig XML which describes
the attributes, filters available for each dataset. 
The ConfigurationTree is a container for BioMart::Configuration::FilterTree 
and BioMart::Configuration::AttributeTree objects.

=head1 AUTHOR  Arek Kasprzyk, Syed Haider, Darin London, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::ConfigurationTree;
use strict;
use warnings;
use base qw(BioMart::Root);

use constant DATASETNAME => "dataSetName";
use constant OPTPARAM => "optional_parameters";
use constant RESTRICTEDPARAM => "primaryKeyRestriction";
use constant DEFDATASET => "default_dataset";
use constant VISIBLEFILTERPAGE => "visibleFilterPage";
use constant TITLES => [ DATASETNAME ];
use constant MARTUSERS => "martUsers";
use constant SOFTWAREVERSION => "softwareVersion";
use constant ENTRYLABEL => "entryLabel";

sub _new {
  my ($self, @param) = @_;

  $self->SUPER::_new(@param);

  $self->addParams(TITLES, @param);

  $self->attr('attTs', []);
  $self->attr('filtTs', []);
  $self->attr(OPTPARAM, undef);
  $self->attr(RESTRICTEDPARAM, undef);
  $self->attr(DEFDATASET, undef);
  $self->attr(VISIBLEFILTERPAGE, undef);
  $self->attr(MARTUSERS, 'default');
  $self->attr(SOFTWAREVERSION, undef);
  $self->attr(ENTRYLABEL, undef);
}

=head2 dataSetName

  Usage        :  my $subName = $ct->dataSetName; $ct->dataSetName($newName);
  Description  :  Gets/Sets the name of the Dataset from which this 
                  ConfigurationTree originates.
  Returntype   :  scalar $name
  Exceptions   :  none
  Caller       :  caller

=cut

sub dataSetName {
  my ($self, $name) = @_;

  if ($name) {
    $self->setParam(DATASETNAME, $name);
  }

  return $self->getParam(DATASETNAME);
}


=head2 optionalParameters

  Usage        :  my $subName = $ct->optionalParameters; 
                  $ct->optionalParameters($newName);
  Description  :  Gets/Sets the optionalParameters associated with this
                  configuration. Only used for GenomicSequence processing
                  at the moment.
  Returntype   :  scalar $optionalParameters
  Exceptions   :  none
  Caller       :  caller
=cut

sub optionalParameters {
  my ($self, $param) = @_;
  if ($param) {
    $self->set(OPTPARAM, $param);
  }
  return $self->get(OPTPARAM);
}


=head2 mart_Users

  Usage        :  my $subName = $ct->mart_Users; 
                  $ct->mart_Users($newName);
  Description  :  Gets/Sets the mart_Users associated with this
                  configuration. 
  Returntype   :  mart_Users comma separated list
  Exceptions   :  none
  Caller       :  caller
=cut

sub mart_Users {
  my ($self, $param) = @_;
  if ($param) {
    $self->set(MARTUSERS, $param);
  }
  return $self->get(MARTUSERS);
}

=head2 software_version

  Usage        :  my $subName = $ct->software_version; 
                  $ct->software_version($newName);
  Description  :  Gets/Sets the software_version associated with this
                  configuration. 
  Returntype   :  software_version
  Exceptions   :  none
  Caller       :  caller
=cut

sub software_version {
  my ($self, $param) = @_;
  if ($param) {
    $self->set(SOFTWAREVERSION, $param);
  }
  return $self->get(SOFTWAREVERSION);
}

=head2 entryLabel





  Usage        :  my $subName = $ct->entryLabel; 
                  $ct->entryLabel($newName);
  Description  :  Gets/Sets the entryLabel associated with this
                  configuration. 
  Returntype   :  entryLabel
  Exceptions   :  none
  Caller       :  caller
=cut

sub entryLabel {
  my ($self, $param) = @_;
  if ($param) {
    $self->set(ENTRYLABEL, $param);
  }
  return $self->get(ENTRYLABEL);
}

=head2 primaryKeyRestriction

  Usage        :  my $subName = $ct->primaryKeyRestriction; 
                  $ct->primaryKeyRestriction($newName);
  Description  :  Gets/Sets the primaryKeyRestriction associated with this
                  configuration. Can be used to restict data in the mart
                  available for querying by certain users
  Returntype   :  scalar $primaryKeyRestriction
  Exceptions   :  none
  Caller       :  caller
=cut


sub primaryKeyRestriction {
  my ($self, $param) = @_;
  if ($param) {
    $self->set(RESTRICTEDPARAM, $param);
  }
  return $self->get(RESTRICTEDPARAM);
}


=head2 visibleFilterPage

  Usage        :  my $subName = $ct->visibleFilterPage; 
                  $ct->visibleFilterPage($newName);
  Description  :  Gets/Sets the visibleFilterPage associated with this
                  configuration.
  Returntype   :  scalar $visibleFilterPage
  Exceptions   :  none
  Caller       :  caller
=cut


sub visibleFilterPage {
  my ($self, $param) = @_;
  if ($param) {
    $self->set(VISIBLEFILTERPAGE, $param);
  }
  return $self->get(VISIBLEFILTERPAGE);
}

=head2 defaultDataset

  Usage        :  my $subName = $ct->defaultDataset; 
                  $ct->defaultDataset($newName);
  Description  :  Gets/Sets the defaultDataset setting. If set to true
                  the the dataset using this configuration becomes the 
                  default.
  Returntype   :  scalar $defaultDataset
  Exceptions   :  none
  Caller       :  caller
=cut


sub defaultDataset {
  my ($self, $param) = @_;
  if ($param) {
    $self->set(DEFDATASET, $param);
  }
  return $self->get(DEFDATASET);
}

=head2 addAttributeTree

  Usage      : $ct->addAttributeTree($atree);
  Description: adds an AttributeTree to this ConfigurationTree. The
               order of addition of each AttributeTree is maintained.
  Returntype : na
  Exceptions : none
  Caller     : caller

=cut

sub addAttributeTree {
  my ($self, $attTree) = @_;

  my $attTs = $self->get('attTs');
  push @{$attTs}, $attTree;
}

=head2 addFilterTree

  Usage      : $ct->addFilterTree($ag);
  Description: adds a FilterTree to this ConfigurationTree. The
               order of addition of each FilterTree is maintained.
  Returntype : na
  Exceptions : none
  Caller     : caller

=cut

sub addFilterTree {
  my ($self, $filtTree) = @_;

  my $filtTs = $self->get('filtTs');
  push @{$filtTs}, $filtTree;
}

sub getAttributeTreeByName {
  my ($self, $name) = @_;

  my $retTree;

  my $attTs = $self->get('attTs');

  foreach my $attT (@{$attTs}) {
    if (($attT->name() && $name) && $attT->name() eq $name) {
      $retTree = $attT;
      last;
	}
  }

  return $retTree;
}

sub getFilterTreeByName {
  my ($self, $name) = @_;

  my $retTree;

  my $filtTs = $self->get('filtTs');

  foreach my $filtT (@{$filtTs}) {
    if ($filtT->name() eq $name) {
      $retTree = $filtT;
      last;
	}
  }

  return $retTree;
}


sub getAllAttributeTrees {
  my $self = shift;

  return $self->get('attTs');
}

sub getAllFilterTrees {
  my $self = shift;

  return $self->get('filtTs');
}

sub getAttributeByName {
  my ($self, $name) = @_;

  my $retAtt;

  my $attTs = $self->get('attTs');
  foreach my $attT (@{$attTs}) {
    $retAtt = $attT->getAttributeByName($name);
    last if ($retAtt);
  }

  return $retAtt;
}

sub getAttributeByNameKey {
  my ($self, $name, $key) = @_;

  my $retAtt;

  my $attTs = $self->get('attTs');
  foreach my $attT (@{$attTs}) {
    $retAtt = $attT->getAttributeByNameKey($name,$key);
    last if ($retAtt);
  }

  return $retAtt;
}

sub getFilterByName {
  my ($self, $name) = @_;

  my $retFilt;

  my $filtTs = $self->get('filtTs');
  foreach my $filtT (@{$filtTs}) {
    $retFilt = $filtT->getFilterByName($name);
  
    unless ($retFilt) {
	#then try option
	my $opt = $filtT->getOptionByName($name);
	if ($opt) {
	    $retFilt = $opt->filter;
	}
    }
    last if ($retFilt);
  }

  return $retFilt if ($retFilt);
  # if not found may be a filter in an attributePage
  my $attTs = $self->get('attTs');
  foreach my $attT (@{$attTs}) {
    my $potFilt = $attT->getFilterByName($name);
    if ($potFilt && $potFilt->isa("BioMart::Configuration::ValueFilter")){
	$retFilt = $potFilt;
	last;
    }
  }

  return $retFilt;
}

sub getOptionByName {
  my ($self, $name) = @_;

  my $retOption;

  my $filtTs = $self->get('filtTs');
  foreach my $filtT (@{$filtTs}) {
    $retOption = $filtT->getOptionByName($name);
    last if ($retOption);
  }

  return $retOption;
}

sub toXML {
  my ($self, $xml) = @_;

  if ($xml) {
     $self->{'datasetConfigXML'}=$xml;
  }
  return $self->{'datasetConfigXML'};
}






1;
