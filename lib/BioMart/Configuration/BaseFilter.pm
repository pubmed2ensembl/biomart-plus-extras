# $Id: BaseFilter.pm,v 1.5.2.1 2008-07-04 16:12:59 syed Exp $
#
# BioMart module for BioMart::Configuration::BaseFilter
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::BaseFilter

=head1 SYNOPSIS

Base Interface for all BioMart filters.

=head1 DESCRIPTION

Base Interface for BioMart filters

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Richard Holland, Darin London, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::BaseFilter;

use strict;
use warnings;
use Digest::MD5;
use base qw(BioMart::Root);

use constant NAME                 => "name";
use constant DISPLAYNAME          => "displayName";
use constant DESCRIPTION		  => "description";
use constant DATASETNAME          => "dataSetName";
use constant IMAGEURL			  => "imageURL";
use constant INTERFACE            => "interface";
use constant BUTTONURL            => "buttonURL";
use constant SETATTRIBUTEPAGE     => "setAttributePage";
use constant DEFAULTON            => "defaultOn";
use constant SETATTRIBUTE         => "setAttribute";
use constant DISPLAYTYPE          => "displayType";
use constant MULTIPLEVALUES       => "multipleValues";
use constant STYLE                => "style";
use constant GRAPH                => "graph";
use constant AUTOCOMPLETION       => "autoCompletion";
use constant TYPE                 => "type";
use constant FILTERCOLLECTION     => "filterCollection";
use constant POINTEDFROMDATASET   => "pointedFromDataset";
use constant POINTEDFROMINTERFACE => "pointedFromInterface";
use constant DEPENDSON            => "dependsOn";
use constant DEPENDSONTYPE        => "dependsOnType";
use constant HIDEDISPLAY        => "hideDisplay";
use constant LEGAL_QUALIFIERS        => "legalQualifiers";



use constant TITLES => [
               NAME,
               DISPLAYNAME,
               DESCRIPTION,
               DATASETNAME,
               IMAGEURL,
	       INTERFACE,		
	       BUTTONURL,
               SETATTRIBUTEPAGE,
	       DEFAULTON,
               TYPE,
	       SETATTRIBUTE,
               DISPLAYTYPE,
               MULTIPLEVALUES,
               STYLE,
               GRAPH,
               AUTOCOMPLETION,
               POINTEDFROMDATASET,
               POINTEDFROMINTERFACE,
               DEPENDSON,
               DEPENDSONTYPE,
               HIDEDISPLAY,
               LEGAL_QUALIFIERS
			 ];
=head2 _new

  Usage      : minimal (users should next set the name and dataSetName with the
               appropriate setter methods):
               my $filt = 
                    BioMart::Configuration::BaseFilter_implementation->new();

               with name, and dataSetName
               my $filt = 
                  BioMart::Configuration::BaseFilter_implementation->new(
		     'name' => $name,
		     'dataSetName' => $subName);

  Description: create a new BaseFilter object
  Returntype : BioMart::Configuration::BaseFilter
  Exceptions : none
  Caller     : general

=cut

sub _new {

  my ($self, @param) = @_;
  $self->SUPER::_new(@param);
  $self->addParams(TITLES, @param);
  $self->attr('options', []);
	$self->attr('dependency',[]);
}

sub _init {
  my ($self, @param) = @_;
  $self->SUPER::_init(@param);
  my $proto = shift @param;
  $self->attr('options', $proto->getAllOptions);
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

=head2 addOptions

  Usage      : usage
  Description: Description
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub addOptions {
  my ($self, $new_options) = @_;
  my $options = $self->get('options');
  push @{$options}, @{$new_options};
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

  Usage      : my $name = $filt->name; $filt->name($newName);
  Description: get/set for the name of the filter
  Returntype : scalar $name
  Exceptions : none
  Caller     : caller

=cut

sub name {
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



=head2 table

  Usage      :
  Description: returns the table name associated with this filter;
  Returntype : String table name
  Exceptions : none
  Caller     : caller

=cut

sub table {

  #my $self = shift;
  #my $attribute = $self->get('attribute');
  #return $attribute->table;
return "";


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


=head2 buttonURL

  Usage      : Arg [1] - (optional) string $buttonURL
  Description: get/set for display name
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub buttonURL {
  # stores display name
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(BUTTONURL, $value);
  }
  return $self->getParam(BUTTONURL);
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



=head2 setAttributePage

  Usage      : Arg [1] - (optional) string $setAttributePage
  Description: get/set for display name
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub setAttributePage {
  # stores display name
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(SETATTRIBUTEPAGE, $value);
  }
  return $self->getParam(SETATTRIBUTEPAGE);
}

=head2 dataSetName

  Usage        :  my $subName = $filt->dataSetName;  
                  $filt->dataSetName($newName);
  Description  :  get/set the name of the dataSet providing this Filter 
                  to the user.
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

=head2 interface

  Usage      : my $interface = $att->interface; $att->interface->($newName);
  Description: get/set for the name of the interface which hosts this 
               filter.
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

=head2 defaultOn

  Usage      : Arg [1] - (optional) string $defaultOn
  Description: get/set for default on
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub defaultOn {
  # stores display name
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(DEFAULTON, $value);
  }
  return $self->getParam(DEFAULTON);
}

=head2 type

  Usage      : $type = $filter->type();
  Description: get filter type
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub type {
  my ($self) = @_;
  return $self->getParam(TYPE);
}

=head2 filterCollection

  Usage      : $type = $filter->filterCollection();
  Description: get filter collection filter belongs to
  Returntype : reference to filter collection parent
  Exceptions : none
  Caller     : general

=cut

sub filterCollection {
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(FILTERCOLLECTION, $value);
  }

  return $self->getParam(FILTERCOLLECTION);
}

=head2 setAttribute

  Usage      : Arg [1] - (optional) string $setAttribute
  Description: get/set for set attribute
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub setAttribute {
  # stores display name
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(SETATTRIBUTE, $value);
  }
  return $self->getParam(SETATTRIBUTE);
}

=head2 displayType

  Usage      : Arg [1] - (optional) string $displayType
  Description: get/set for displayType
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub displayType {
  # stores display name
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(DISPLAYTYPE, $value);
  }
  return $self->getParam(DISPLAYTYPE);
}

=head2 multipleValues

  Usage      : Arg [1] - (optional) string $multipleValues
  Description: get/set for multipleValues
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub multipleValues {
  # stores display name
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(MULTIPLEVALUES, $value);
  }
  return $self->getParam(MULTIPLEVALUES);
}

=head2 graph

  Usage      : Arg [1] - (optional) string $graph
  Description: get/set for graph
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub graph {
  # stores display name
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(GRAPH, $value);
  }
  return $self->getParam(GRAPH);
}

=head2 style

  Usage      : Arg [1] - (optional) string $style
  Description: get/set for style
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub style {
  # stores display name
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(STYLE, $value);
  }
  return $self->getParam(STYLE);
}

=head2 hideDisplay

  Usage      : Arg [1] - (optional) string $display
  Description: get/set for style
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub hideDisplay {
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(HIDEDISPLAY, $value);
  }
  return $self->getParam(HIDEDISPLAY);
}

=head2 legalQualifiers

  Usage      : Arg [1] - (optional) string $qualifiers
  Description: get/set for legal_qualifiers
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub legalQualifiers {
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(LEGAL_QUALIFIERS, $value);
  }
  return $self->getParam(LEGAL_QUALIFIERS);
}


=head2 autoCompletion

  Usage      : Arg [1] - (optional) string $autoCompletion
  Description: get/set for autoCompletion
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub autoCompletion {
  # stores display name
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(AUTOCOMPLETION, $value);
  }
  return $self->getParam(AUTOCOMPLETION);
}

=head2 toSQL

  Usage      : my $sql = $filt->toSQL;
  Description: Returns the SQL where clause reprensentation for a 
               particular BaseFilter implementation.
  Returntype : SQL string
  Exceptions : none
  Caller     : caller

=cut

sub toSQL {
  my ($self,$oracle) = @_;

  if ($self->can("_toSQL")) {
    return $self->_toSQL($oracle);
  }
  $self->unimplemented_method;
}

sub _hashCode {
  my $self = shift;

  my $digest = Digest::MD5->new;
  $digest->add($self->name) if ($self->name);
  $digest->add($self->displayName) if ($self->displayName);
  $digest->add($self->dataSetName) if ($self->dataSetName);
  return $digest->hexdigest;
}

1;
