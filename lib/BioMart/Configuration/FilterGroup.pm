# $Id: FilterGroup.pm,v 1.3 2008-04-09 12:52:33 syed Exp $
#
# BioMart module for BioMart::Configuration::FilterGroup
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::FilterGroup

=head1 SYNOPSIS

Holds a List of BioMart::FilterCollection objects.

=head1 DESCRIPTION

Object to further define the Filters available to the User Interface by
a Dataset.  Holds a list of one or more BioMart::FilterCollection objects.

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Richard Holland, Darin London, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::FilterGroup;

use strict;
use warnings;
use base qw(BioMart::Root);

use constant NAMEKEY => "name";
use constant DISPLAYNAME => "displayName";
use constant DESCRIPTION => "description";
use constant TITLES => [ NAMEKEY,
                         DISPLAYNAME, DESCRIPTION ];

sub _new {
  my ($self, @param) = @_;
  $self->SUPER::_new(@param);

  $self->addParams(TITLES, @param);
  $self->attr('Cols', []);
}

=head2 name

  Usage      : my $name = $filt->name(); $filt->name($newname);
  Description: sets/gets the name of the FilterGroup
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


=head2 getFilterCollectionByName

  Usage      : my $ac = $ag->getFilterCollectionByName($name);
  Description: Returns a BioMart::FilterCollection object from this
               BioMart::FilterGroup object, named by the given name.
               If no object exists in this tree named by the given name,
               this method returns undef.
  Returntype : BioMart::FilterCollection or undef if none found 
               with given name.
  Exceptions : none
  Caller     : caller

=cut

sub getFilterCollectionByName {
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

sub getFilterByName {
  my ($self, $name) = @_;

  my $retFilt;

  my $filtTs = $self->get('Cols');
  foreach my $filtT (@{$filtTs}) {
    $retFilt = $filtT->getFilterByName($name);
    last if ($retFilt);
  }

  return $retFilt;
}


1;
