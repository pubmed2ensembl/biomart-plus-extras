# $Id: FilterCollection.pm,v 1.3 2008-04-09 12:52:33 syed Exp $
#
# BioMart module for BioMart::Configuration::FilterCollection
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::FilterCollection

=head1 SYNOPSIS

Holds a List of BioMart::BaseFilter implementing objects.

=head1 DESCRIPTION

Object to further define the Filters available to the User Interface by
a Dataset.  Holds a list of one or more BioMart::BaseFilter implementing 
objects.

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Richard Holland, Darin London, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::FilterCollection;


use strict;
use warnings;
use base qw(BioMart::Root);

use constant NAMEKEY => "name";
use constant DISPLAYNAME => "displayName";
use constant DESCRIPTION => "description";
use constant TITLES => [ NAMEKEY,
						DESCRIPTION,
                         DISPLAYNAME, ];

sub _new {
  my ($self, @param) = @_;
  $self->SUPER::_new(@param);

  $self->addParams(TITLES, @param);
  $self->attr('filters', []);
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

=head2 addFilter

  Usage      : usage
  Description: Description
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub addFilter {
  my ($self, $filter) = @_;

  $filter->filterCollection($self);
  my $filters = $self->get('filters');
  push @{$filters}, $filter;
}


=head2 getAllFilters

  Usage      : usage
  Description: Description
  Returntype :
  Exceptions : none
  Caller     : caller

=cut

sub getAllFilters {
  my $self = shift;

  return $self->get('filters');
}

sub getFilterByName {
  my ($self, $name) = @_;

  my $retFilt;

  my $filtTs = $self->get('filters');
  foreach my $filtT (@{$filtTs}) {
    $retFilt = $filtT if ($filtT->name eq $name);
    last if ($retFilt);
  }

  return $retFilt;
}


1;
