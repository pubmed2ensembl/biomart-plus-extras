# $Id: AttributeCollection.pm,v 1.4 2008-04-09 12:52:33 syed Exp $
#
# BioMart module for BioMart::Configuration::AttributeCollection
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::AttributeCollection

=head1 SYNOPSIS

Holds a List of BioMart::Attribute objects.

=head1 DESCRIPTION

Object to further define the Attributes available to the User Interface by
a Dataset.  Holds a list of one or more BioMart::Attribute objects.

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Richard Holland, Darin London, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::AttributeCollection;

use strict;
use warnings;
use base qw(BioMart::Root);

use constant NAMEKEY => "name";
use constant DISPLAYNAME => "displayName";
use constant DESCRIPTION => "description";
use constant MAXSELECT => "maxSelect";
use constant SELECTALL => "selectAll";

use constant TITLES => [ NAMEKEY,
                         DISPLAYNAME,
                         DESCRIPTION,
                         MAXSELECT,
                         SELECTALL];

sub _new {
  my ($self, @param) = @_;
  $self->SUPER::_new(@param);

  $self->addParams(TITLES, @param);
  $self->attr('attributes', []);
}


=head2 name

  Usage      : usage
  Description: Description
  Returntype : string name
  Exceptions : none
  Caller     : caller

=cut

sub name {
  my ($self, $newName) = @_;

  if ($newName) {
    $self->setParam(NAMEKEY, $newName);
  }
  return $self->getParam(NAMEKEY);
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

=head2 maxSelect

  Usage      : Arg [1] - (optional) string $max_select
  Description: get/set for max select
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub maxSelect {
  # stores max select
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(MAXSELECT, $value);
  }
  return $self->getParam(MAXSELECT);
}

=head2 selectAll

  Usage      : 
  Description: get/set for selectAll checkBox
  Returntype : true/false
  Exceptions : none
  Caller     : templateToolKit

=cut

sub selectAll {
  # stores max select
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(SELECTALL, $value);
  }
  return $self->getParam(SELECTALL);
}


=head2 addAttribute

  Usage      : usage
  Description: Description
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub addAttribute {
  my ($self, $attribute) = @_;

  my $attributes = $self->get('attributes');
  push @{$attributes}, $attribute;
}


=head2 getAllAttributes

  Usage      : usage
  Description: Description
  Returntype :
  Exceptions : none
  Caller     : caller

=cut

sub getAllAttributes {
  my $self = shift;

  return $self->get('attributes');
}

1;
