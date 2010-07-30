# $Id: 
#
# BioMart module for BioMart::Configuration::Option
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::Option

=head1 SYNOPSIS

Object responsible for Options

=head1 DESCRIPTION

Object responsible for Options contained within a BioMart::BaseFilter 
implementing object. These Options can represent just simple distinct values
for a filter so a drop-down/radio button can be generated. They can also
contain a BioMart::BaseFilter implementing object themselves, in which case
the root Filter object is an empty container for a drop down list of
Filters

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Richard Holland, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::Option;

use strict;
use warnings;
use Digest::MD5;

use base qw(BioMart::Root);

use constant NAME                   => "name";
use constant DESCRIPTION            => "description";
use constant DISPLAYNAME            => "displayName";
use constant DATASETNAME            => "dataSetName";
use constant VALUE                  => "value";

use constant TITLES => [ 
               NAME,
               DISPLAYNAME,
	       DATASETNAME,
               VALUE,
               	DESCRIPTION
			 ];

=head2 _new
  
  Usage      : no arguments
  Description: creates a new Option object which can contain a single
               Attribue object 
  Returntype : BioMart::Configuration::Option
  Exceptions : none
  Caller     : general

=cut

sub _new {
  my ($self, @param) = @_;
  $self->SUPER::_new(@param);
  $self->addParams(TITLES, @param);
  $self->attr('filter',undef);
  $self->attr('options',[]);
  $self->attr('pushActions',[]);
  $self->attr('operation','');
}


sub _init {
  my ($self, @param) = @_;
  $self->SUPER::_init(@param);
  my $proto = shift @param;
  $self->attr('filter', $proto->filter);
  $self->attr('options', $proto->getAllOptions);
  $self->attr('pushActions', $proto->getAllPushActions);
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

=head2 addPushAction

  Usage      : usage
  Description: Description
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub addPushAction {
  my ($self, $pa) = @_;
  my $pas = $self->get('pushActions');
  push @{$pas}, $pa;
}


=head2 getAllPushActions

  Usage      : usage
  Description: Description
  Returntype :
  Exceptions : none
  Caller     : caller

=cut

sub getAllPushActions {
  my $self = shift;
  return $self->get('pushActions');
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


=head2 displayName

  Usage      : Arg [1] - (optional) string $display_name
  Description: get/set for display name
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub displayName {
  # stores display name
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(DISPLAYNAME, $value);
  }
  return $self->getParam(DISPLAYNAME);
}


=head2 description

  Usage      : Arg [1] - (optional) string $description
  Description: get/set for description
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub description {
  # stores description
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(DESCRIPTION, $value);
  }
  return $self->getParam(DESCRIPTION);
}

=head2 value

  Usage      : Arg [1] - (optional) string $display_name
  Description: get/set for value
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub value {
  # stores display name
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(VALUE, $value);
  }
  return $self->getParam(VALUE);
}

=head2 dataSetName

  Usage      : my $subName = $option->dataSetName; 
               $option->dataSetName->($newName);
  Description: get/set for the name of the dataSet which hosts this attribute.
  Returntype : scalar $name
  Exceptions : none
  Caller     : general

=cut

sub operation {
  my ($self,$operation) = @_;
  if ($operation) {
    $self->set('operation',$operation);
  }
  return $self->get('operation');
}

sub dataSetName {
  # stores dataset name?
  my ($self, $value) = @_;
  if ($value){
      $self->setParam(DATASETNAME, $value);
  }
  return $self->getParam(DATASETNAME);
}


=head2 filter

  Usage      : Arg[1] - (optional) BioMart::Configuration::BooleanFilter
               or ValueFilter object
  Description: get/set method for the Filter object for this Option
  Returntype : BioMart::Configuration::BooleanFilter or ValueFilter object
  Exceptions : none
  Caller     : caller

=cut

sub filter {
# stores filter
  my ($self, $filter) = @_;
  if ($filter){
    $self->set('filter', $filter);
  }
  return $self->get('filter');
}

sub _toSQL {
  my $self = shift;
  my $filter = $self->filter();
  return $filter->toSQL();
}

sub _hashCode {
  my $self = shift;
  my $digest = Digest::MD5->new;
  $digest->add($self->SUPER::_hashCode);
  $digest->add($self->filter()->hashCode);
  return $digest->hexdigest;
}

1;
