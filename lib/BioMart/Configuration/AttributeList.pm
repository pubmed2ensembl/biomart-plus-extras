# $Id: AttributeList.pm,v 1.4 2008-04-09 12:52:33 syed Exp $
#
# BioMart module for BioMart::Configuration::AttributeList
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::AttributeList

=head1 SYNOPSIS

Stores an array of attribute objects, in order.

=head1 DESCRIPTION

Stores an array of attribute objects. Used to handle the behaviour of
exportables in the system. When linking two Datasets together, the
BioMart::QueryRunner object will add the BioMart::AttributeList object
exported from the Exporting Dataset to the Query targeted to the
Exporting Dataset.

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Richard Holland, Darin London, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::AttributeList;

use strict;
use warnings;
use Digest::MD5;

use base qw(BioMart::Configuration::Attribute);

use constant LINKNAME        => "linkName";
use constant LINKVERSION     => "linkVersion";
use constant ATTRIBUTESTRING => "attribute_string";
use constant ORDERBYSTRING   => "orderby_string";
use constant TYPE   				=> "type";

use constant TITLES => [
               LINKNAME,
               LINKVERSION,
					ATTRIBUTESTRING,
               ORDERBYSTRING,
               TYPE
			 ];

=head2 _new

  Usage      : minimal:
               my $alist = BioMart::AttributeList->new();

               with name and dataSetName
               my $alist = BioMart::AttributeList->new(
                                'name' => $name,
                                'dataSetName' => $subName
                                                       );

               To be used as a Link Exportable (note orderby_string is 
						optional):
               my $alist = BioMart::AttributeList->new(
                                'name' => $name,
                                'dataSetName' => $subName,
                                'linkName'     => $linkName,
   				'attribute_string'   => $attribute_string,
                                'orderby_string' => $orderby_string
						       );


  Description: creates a new AttributeList object capable of storing an
               array of Attribute objects
  Returntype : BioMart::Configuration::AttributeList
  Exceptions : none
  Caller     : caller

=cut

sub _new {

  my ($self, @param) = @_;
  $self->SUPER::_new(@param);
  $self->addParams(TITLES, @param);
  $self->attr('attributes', []);
  $self->attr('orderby_attributes', []);
  $self->attr('default', 0);
}

=head2 linkName

  Usage        :  my $linkName = $alist->linkName; 
                  $alist->linkName($newLinkName);
  Description  :  get/set the linkName of this BioMart::AttributeList object.
  Returntype   :  scalar $linkName
  Exceptions   :  none
  Caller       :  caller

=cut

sub linkName {
  my ($self, $name) = @_;
  if ($name) {
    $self->setParam(LINKNAME, $name);
  }
  return $self->getParam(LINKNAME);
}

=head2 linkVersion

  Usage        :  my $linkVersion = $alist->linkVersion; 
                  $alist->linkVersion($newLinkVersion);
  Description  :  get/set the linkVersion of this BioMart::AttributeList 
                  object.
  Returntype   :  scalar $linkVersion
  Exceptions   :  none
  Caller       :  caller

=cut

sub linkVersion {
  my ($self, $name) = @_;
  if ($name) {
    $self->setParam(LINKVERSION, $name);
  }
  return $self->getParam(LINKVERSION);
}

=head2 attributeString

  Usage        :  my $attributeString = $alist->attributeString; 
                  $alist->attributeString($newAttString);
  Description  :  get/set the attributeString of this BioMart::AttributeList 
                  object.
  Returntype   :  scalar $attributeString
  Exceptions   :  none
  Caller       :  caller

=cut

sub attributeString {
  my ($self, $name) = @_;
  if ($name) {
    $self->setParam(ATTRIBUTESTRING, $name);
  }
  return $self->getParam(ATTRIBUTESTRING);
}

=head2 orderByString

  Usage        :  my $orderByString = $alist->orderByString; 
                  $alist->orderByString($newOrderByString);
  Description  :  get/set the orderByString of this BioMart::AttributeList 
                  object.
  Returntype   :  scalar $orderByString (a comma separated list of 
                  BioMart::Configuration::Attribute names)
  Exceptions   :  none
  Caller       :  caller

=cut

sub orderByString {
  my ($self, $name) = @_;
  if ($name) {
    $self->setParam(ORDERBYSTRING, $name);
  }
  return $self->getParam(ORDERBYSTRING);
}

=head2 type

  Usage        :  $exp->type();
                  
  Description  :  get/set for the exportable type 
                  object.
  Returntype   :  string                  
  Exceptions   :  none
  Caller       :  caller

=cut

sub type {
  my ($self, $name) = @_;
  if ($name) {
    $self->setParam(TYPE, $name);
  }
  return $self->getParam(TYPE);
}


=head2 addAttribute

  Usage      : $alist->addAttribute($att);
  Description: adds a BioMart::Attribute object to the AttributeList, 
               maintaining the order of addition.
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut

sub addAttribute {
  my ($self, $attribute) = @_;

  my $attributes = $self->get('attributes');
  push @{$attributes}, $attribute;
  $self->set('attributes', $attributes);

}

=head2 getAllAttributes

  Usage        :  my $atts = $alist->getAllAttributes;
  Description  :  get all Attributes added to this AttributeList.
                  Primarily used by BioMart::ResultTable to
                  support getFieldByName and getIndexByName, but
                  may also be used by DatasetI objects which
                  override or ignore the default toSQL method.
  Returntype   :  array_ref of BioMart::Attribute objects
  Exceptions   :  none
  Caller       :  BioMart::ResultTable, and BioMart::DatasetI implementatiions.

=cut

sub getAllAttributes {
  my $self = shift;
  return $self->get('attributes');
}

sub getAttributeByName {
  my ($self,$name) = @_;
  my $attribute;
  my $attributes = $self->get('attributes');
  foreach (@$attributes){
      if ($_->name eq $name){
	  $attribute = $_;
	  last;
      }
  }
  return $attribute;
}



=head2 addOrderByAttribute

  Usage      : $alist->addSortByAttribute($att);
  Description: adds a BioMart::Attribute object to the AttributeList
               sortBy list, maintaining the order of addition.
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut

sub addOrderByAttribute {
  my ($self, $attribute) = @_;

  my $attributes = $self->get('orderby_attributes');
  push @{$attributes}, $attribute;
  $self->set('orderby_attributes', $attributes);
}

=head2 toSQL

  Usage      : my $sql = $alist->toSQL;
  Description: returns a SQL stub for all the attributes stored in the
               AttributeList
  Returntype : string
  Exceptions : none
  Caller     : caller

=cut

sub toSQL {
  # gets each attribute, inserts ',' in between
  my $self = shift;
  my $sql;
  my $attributes = $self->get('attributes');
  foreach my $attribute (@$attributes){
    $sql .= ' '.$attribute->toSQL().',';
  }
  chop $sql;
  return $sql;
}

=head2 toOrderBySQL

  Usage      : my $sql = $alist->toOrderBySQL;
  Description: returns a SQL stub for all the attributes stored in the
               AttributeList sortBy list.
  Returntype : string
  Exceptions : none
  Caller     : caller

=cut

sub toOrderBySQL {
  # gets each attribute, inserts ',' in between
  my $self = shift;
  my $sql;
  my $attributes = $self->get('orderby_attributes');
  foreach my $attribute (@$attributes){
    $sql .= ' '.$attribute->toSQL().',';
  }
  chop $sql;
  return $sql;
}

=head2 setDefault

  Usage      : $alist->setDefault;
  Description: sets this AttributeList as the default
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut

sub setDefault {
  my $self = shift;
  $self->set('default',1);
}

=head2 unSetDefault

  Usage      : $alist->unSetDefault;
  Description: this BioMart::AttributeList will no longer be the default.
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut

sub unSetDefault {
  my $self = shift;
  $self->set('default',0);
}

=head2 defaultList

  Usage      : no arguments
  Description: returns 1 if this AttributeList is the default, otherwise 0
  Returntype : 0,1
  Exceptions : none
  Caller     : caller

=cut

sub defaultList {
  my $self = shift;
  return $self->get('default');
}

sub _hashCode {
  my $self = shift;

  my $digest = Digest::MD5->new;

  $digest->add($self->name) if ($self->name);
  $digest->add($self->linkName) if ($self->linkName);
  $digest->add($self->dataSetName) if ($self->dataSetName);

  my $atts = $self->get('attributes');
  foreach my $att (@{$atts}) {
    $digest->add($att->hashCode);
  }

  $digest->add($self->defaultList);

  return $digest->hexdigest;
}

1;
