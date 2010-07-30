# $Id: 
#
# BioMart module for BioMart::Configuration::PushAction
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::PushAction

=head1 SYNOPSIS

Object responsible for PushActions

=head1 DESCRIPTION

PushActions represent the values (BioMart::Configuration::Options) that are
placed onto another filter when a particular value 
(BioMart::Configuration::Option) is chosen for a particular filter. The
driving filter contains Options which in turn contain one or more PushAction
objects. These PushActions contain the Options to place on the other filter
when chosen. An example of this is the chromosome name and band filters for
the gene datasets in ensembl (www.ensembl.org/biomart/martview). When a
particular option is chosen for the chromosome drop down the options available
in the band menus. The javascript driving this is populated using the Options
and PushActions contained within the chromosome Filter.

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::PushAction;

use strict;
use warnings;
use Digest::MD5;

use base qw(BioMart::Root);

use constant NAME                 => "name";
use constant REF                  => "ref";
use constant DATASETNAME          => "dataSetName";

use constant TITLES => [ 
               NAME,
               REF,
	       DATASETNAME,
			 ];

=head2 _new
  
  Usage      : no arguments
  Description: creates a new PushAction object which can contain a single
               Attribue object 
  Returntype : BioMart::Configuration::PushAction
  Exceptions : none
  Caller     : general

=cut

sub _new {
  my ($self, @param) = @_;
  $self->SUPER::_new(@param);
  $self->addParams(TITLES, @param);
  $self->attr('options',[]);
}


sub _init {
  my ($self, @param) = @_;
  $self->SUPER::_init(@param);
  my $proto = shift @param;
  $self->attr('options', $proto->getAllPushActions);
}


=head2 addOption

  Usage      : usage
  Description: Description
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub addOption {
  my ($self, $option) = @_;
  my $options = $self->get('options');
  push @{$options}, $option;
}


=head2 getAllOptions

  Usage      : usage
  Description: Description
  Returntype :
  Exceptions : none
  Caller     : caller

=cut

sub getAllOptions {
  my $self = shift;
  return $self->get('options');
}

=head2 name

  Usage      : my $optionName = $option->name; $option->name($optionName);
  Description: get/set for internal name
  Returntype : scalar $name
  Exceptions : none
  Caller     : general

=cut

sub name {
  # stores internal name
  my ($self, $value) = @_;
  if ($value){
      $self->setParam(NAME, $value);
  }
  return $self->getParam(NAME);
}


=head2 ref

  Usage      : my $ref = $option->ref; $option->ref($ref);
  Description: get/set for ref
  Returntype : scalar $ref
  Exceptions : none
  Caller     : general

=cut

sub ref {
  # stores ref
  my ($self, $value) = @_;
  if ($value){
      $self->setParam(REF, $value);
  }
  return $self->getParam(REF);
}

=head2 dataSetName

  Usage      : my $subName = $option->dataSetName; 
               $option->dataSetName->($newName);
  Description: get/set for the name of the dataSet which hosts this attribute.
  Returntype : scalar $name
  Exceptions : none
  Caller     : general

=cut

sub dataSetName {
  # stores dataset name?
  my ($self, $value) = @_;
  if ($value){
      $self->setParam(DATASETNAME, $value);
  }
  return $self->getParam(DATASETNAME);
}


sub _hashCode {
  my $self = shift;
  my $digest = Digest::MD5->new;
  $digest->add($self->SUPER::_hashCode);
  return $digest->hexdigest;
}

1;
