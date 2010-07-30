# $Id: AttributeGroup.pm,v 1.3 2008-04-09 12:52:33 syed Exp $
#
# BioMart module for BioMart::Configuration::AttributeGroup
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::AttributeGroup

=head1 SYNOPSIS

Holds a List of BioMart::AttributeCollection objects.

=head1 DESCRIPTION

Object to further define the Attributes available to the User Interface by
a Dataset.  Holds a list of one or more BioMart::AttributeCollection objects.

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Richard Holland, Darin London, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::AttributeGroup;

use strict;
use warnings;
use base qw(BioMart::Root);

use constant NAMEKEY => "name";
use constant DISPLAYNAME => "displayName";
use constant DESCRIPTION => "desription";
use constant MAXSELECT => "maxSelect";

use constant TITLES => [ NAMEKEY,
                         DISPLAYNAME,
                         DESCRIPTION,
			 MAXSELECT];

sub _new {
  my ($self, @param) = @_;
  $self->SUPER::_new(@param);

  $self->addParams(TITLES, @param);
  $self->attr('Cols', []);
}

=head2 name

  Usage      : my $name = $att->name(); $att->name($newname);
  Description: sets/gets the name of the AttributeGroup
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


=head2 addCollection

  Usage      : usage
  Description: Description
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub addCollection {
  my ($self, $col) = @_;

  my $cols = $self->get('Cols');
  push @{$cols}, $col;
}



=head2 getAttributeCollectionByName

  Usage      : my $ac = $ag->getAttributeCollectionByName($name);
  Description: Returns a BioMart::AttributeCollection object from this
               BioMart::AttributeGroup object, named by the given name.
               If no object exists in this tree named by the given name,
               this method returns undef.
  Returntype : BioMart::AttributeCollection or undef if none found with 
               given name.
  Exceptions : none
  Caller     : caller

=cut

sub getAttributeCollectionByName {
  my ($self, $name) = @_;

  my $retCollection;

  my $attCs = $self->get('Cols');

  foreach my $attC (@{$attCs}) {
    if ($attC->name() eq $name) {
      $retCollection = $attC;
      last;
	}
  }

  return $retCollection;
}




=head2 getAllCollections

  Usage      : usage
  Description: Description
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub getAllCollections {
  my $self = shift;
  return $self->get('Cols');
}



1;
