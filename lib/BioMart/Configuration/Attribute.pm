# $Id: Attribute.pm,v 1.4 2008-04-09 12:52:33 syed Exp $
#
# BioMart module for BioMart::Configuration::Attribute
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::Attribute

=head1 SYNOPSIS

Represents an attribute in a BioMart query

=head1 DESCRIPTION

Attribute objects model the concept of a BioMart attribute ie a column in a
mart ResultTable that can be requested as part of a mart query.

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Richard Holland, Darin London, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::Attribute;

use strict;
use warnings;
use Digest::MD5;
use Data::Dumper;

use base qw(BioMart::Root);

use constant NAME                   => "name";
use constant DISPLAYNAME            => "displayName";
use constant DESCRIPTION            => "description";
use constant IMAGEURL				   => "imageURL";
use constant TABLE                  => "table";
use constant RELATIONALATTRIBUTE    => "relational_attribute";
use constant DATASETNAME              => "dataSetName";
use constant INTERFACE              => "interface";
use constant KEY                    => "key";
use constant WIDTH                  => "width";
use constant LINK                    => "link";
use constant DATASETLINK             => "datasetLink";
use constant DEFAULT                 => "default";
use constant POINTEDFROMDATASET      => "pointedFromDataset";
use constant POINTEDFROMATTRIBUTE      => "pointedFromAttribute";
use constant POINTEDFROMINTERFACE    => "pointedFromInterface";
use constant DEPENDSON    => "dependsOn";
use constant DEPENDSONTYPE    => "dependsOnType";
use constant ATTRIBUTES    => "attributes";

use constant TITLES => [ 
               NAME,
               DISPLAYNAME,
               DESCRIPTION,
               IMAGEURL,
               TABLE,
               RELATIONALATTRIBUTE,
               DATASETNAME,
               INTERFACE,
               KEY,
               WIDTH,
               LINK,
	       DATASETLINK,
	       DEFAULT,
               POINTEDFROMDATASET,
               POINTEDFROMINTERFACE ,
               POINTEDFROMATTRIBUTE ,
               DEPENDSON,
               DEPENDSONTYPE,
               ATTRIBUTES
			 ];

=head2 _new

  Usage      : minimal (use setters for name, displayName, etc:
			   my $att = BioMart::Configuration::Attribute->new;

               fully configured:
               my $att = BioMart::Configuration::Attribute->new(
                       'name' => $name,
		       'displayName' => $dname,
                       'table' => $table,
                       'relational_attribute' => $rattribute,
                       'dataSetName' => $subname
								);
  Description: creates a new Attribute object.
  Returntype : BioMart::Configuration::Attribute
  Exceptions : insufficient arguments
  Caller     : general

=cut

sub _new {
  
  my ($self, @param) = @_;

  $self->SUPER::_new(@param);
  $self->addParams(TITLES, @param);
  $self->attr('dependency', []);
}

#non interface Methods

=head2 name

  Usage      : my $attName = $att->name; $att->name($newName);
  Description: get/set for internal name
  Returntype : scalar $name
  Exceptions : none
  Caller     : general

=cut

sub name {
  my ($self, $value) = @_;

  if ($value){
      $self->setParam(NAME, $value);
  }
  return $self->getParam(NAME);
}


=head2 imageURL

  Usage      : Arg [1] - (optional) string $imageURL
  Description: get/set for imageURL, a relative URL. 
  			   This is only used by MartView.
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub imageURL {
  # stores display name
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(IMAGEURL, $value);
  }
  return $self->getParam(IMAGEURL);
}


=head2 attributes

  Usage      : Arg [1] - (optional) string $attributes
  Description: get/set for attributes.
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub attributes {
  # stores display name
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(ATTRIBUTES, $value);
  }
  return $self->getParam(ATTRIBUTES);
}


=head2 displayName

  Usage      : Arg [1] - (optional) string $display_name
  Description: get/set for display name
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub displayName {
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

=head2 dataSetName

  Usage      : my $subName = $att->dataSetName; $att->dataSetName->($newName);
  Description: get/set for the name of the dataSet which hosts this attribute.
  Returntype : scalar $name
  Exceptions : none
  Caller     : general

=cut

sub dataSetName {
  my ($self, $value) = @_;
  
  if ($value){
      $self->setParam(DATASETNAME, $value);
  }
  return $self->getParam(DATASETNAME);
}

=head2 interface

  Usage      : my $interface = $att->interface; $att->interface->($newName);
  Description: get/set for the name of the interface which 
               hosts this attribute.
  Returntype : scalar $name
  Exceptions : none
  Caller     : general

=cut

sub interface {
  my ($self, $value) = @_;

  if ($value){
      $self->setParam(INTERFACE, $value);
  }
  return $self->getParam(INTERFACE);
}


=head2 table

  Usage      : Arg [1] - (optional) string $table
  Description: get/set for table
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub table {
  my ($self, $value) = @_;
  
  if ($value){
      $self->setParam(TABLE, $value);
  }
  return $self->getParam(TABLE);
}


=head2 relationalAttribute

  Usage      : Arg [1] - (optional) string $relational_attribute
  Description: get/set for relational attribute
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub relationalAttribute {
  my ($self, $value) = @_;

  if ($value){
    $self->setParam(RELATIONALATTRIBUTE, $value);
  }
  return $self->getParam(RELATIONALATTRIBUTE);
}

=head2 key

  Usage      : Arg [1] - (optional) string $key for table joining
  Description: get/set for key
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub key {
  my ($self, $value) = @_;
  
  if ($value){
    $self->setParam(KEY, $value);
  }
  return $self->getParam(KEY);
}

=head2 width

  Usage      : Arg [1] - (optional) string $width for table joining
  Description: get/set for width
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub width {
  my ($self, $value) = @_;

  if ($value){
    $self->setParam(WIDTH, $value);
  }
  return $self->getParam(WIDTH);
}

=head2 link

  Usage      : Arg [1] - (optional) string $link for URL display
  Description: get/set for linkURL
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub link {
  my ($self, $value) = @_;
 
  if ($value){
    $self->setParam(LINK, $value);
  }
  return $self->getParam(LINK);
}


=head2 datasetLink

  Usage      : Arg [1] - (optional) string $datasetLink
  Description: get/set for datasetLink
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub datasetLink {
  my ($self, $value) = @_;
  
  if ($value){
    $self->setParam(DATASETLINK, $value);
  }
  return $self->getParam(DATASETLINK);
}

=head2 default

  Usage      : Arg [1] - (optional) string $default
  Description: get/set for default atribute(s) for a dataset
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub default {
  my ($self, $value) = @_;
  
  if ($value){
    $self->setParam(DEFAULT, $value);
  }
  return $self->getParam(DEFAULT);
}

=head2 pointedFromAttribute

  Usage      : Arg [1] - (optional) string $pointedFromDataset
  Description: get/set for pointedFromDataset atribute(s) for a dataset
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub pointedFromAttribute {
  my ($self, $value) = @_;
  
  if ($value){
    $self->setParam(POINTEDFROMATTRIBUTE, $value);
  }
  return $self->getParam(POINTEDFROMATTRIBUTE);
}

=head2 pointedFromDataset

  Usage      : Arg [1] - (optional) string $pointedFromDataset
  Description: get/set for pointedFromDataset atribute(s) for a dataset
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub pointedFromDataset {
  my ($self, $value) = @_;
  
  if ($value){
    $self->setParam(POINTEDFROMDATASET, $value);
  }
  return $self->getParam(POINTEDFROMDATASET);
}

=head2 pointedFromInterface

  Usage      : Arg [1] - (optional) string $pointedFromInterface
  Description: get/set for pointedFromInterface atribute(s) for a dataset
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub pointedFromInterface {
  my ($self, $value) = @_;
  
  if ($value){
    $self->setParam(POINTEDFROMINTERFACE, $value);
  }
  return $self->getParam(POINTEDFROMINTERFACE);
}

=head2 dependsOn

  Usage      : Arg [1] - (optional) string $dependsOn delimited by commas
  Description: get/set for dependsOn atribute(s) for a dataset
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub dependsOn {
  my ($self, $value) = @_;
  
  if ($value){
    $self->setParam(DEPENDSON, $value);    
  }
  return $self->getParam(DEPENDSON);
}

=head2 dependsOnType

  Usage      : Arg [1] - (optional) string $dependsOnType
  Description: get/set for dependsOnType - all or any are acceptable.
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub dependsOnType {
  my ($self, $value) = @_;
  
  if ($value){
    $self->setParam(DEPENDSONTYPE, $value);
  }
  return $self->getParam(DEPENDSONTYPE);
}

=head2 addDependency

  Usage      : usage
  Description: Description
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub addDependency {
  my ($self, $resolvedDependency) = @_;

  push @{$self->get('dependency')}, $resolvedDependency;
}


=head2 dependencies

  Usage      : usage
  Description: Description
  Returntype :
  Exceptions : none
  Caller     : caller

=cut

sub dependencies {
  my $self = shift;

  return $self->get('dependency');
}

=head2 toSQL

  Usage      : no arguments
  Description: returns the SQL stub for the attribute (ie)
               table.column
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub toSQL {
  my $self = shift;
  
  return $self->getParam(TABLE).'.'.$self->getParam(RELATIONALATTRIBUTE);
}


sub _hashCode {
  my $self = shift;

  my $digest = Digest::MD5->new;
  
  # Get uninitialized value in subroutine entry warnings whenever one of 
  # the below params has been set from an XML::Simple hash ie dataSetName 
  # is always OK
  # investigate keyAttrs setting in XMLIn
  $digest->add($self->name) if ($self->name);
  $digest->add($self->displayName) if ($self->displayName);
  $digest->add($self->dataSetName) if ($self->dataSetName);
  $digest->add($self->table) if ($self->table);
  $digest->add($self->relationalAttribute) if ($self->relationalAttribute);
  $digest->add($self->key) if ($self->key);

  return $digest->hexdigest;
}

1;
