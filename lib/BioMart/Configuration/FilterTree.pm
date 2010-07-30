# $Id: FilterTree.pm,v 1.3 2008-04-09 12:52:33 syed Exp $
#
# BioMart module for BioMart::Configuration::FilterTree
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::FilterTree

=head1 SYNOPSIS

Holds a List of BioMart::FilterGroup objects.


=head1 DESCRIPTION

Object to further define the Filters available to the User Interface by
a Dataset.  Holds a list of one or more BioMart::FilterGroup objects.

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Richard Holland, Darin London, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::FilterTree;


use strict;
use warnings;
use base qw(BioMart::Root);

use constant NAMEKEY => "name";
use constant DISPLAYNAME => "displayName";
use constant DESCRIPTION => "description";
use constant HIDEDISPLAY => "hideDisplay";
use constant TITLES => [ NAMEKEY,
                         DISPLAYNAME,
                         DESCRIPTION,
			 HIDEDISPLAY];

sub _new {
  my ($self, @param) = @_;
  $self->SUPER::_new(@param);

  $self->addParams(TITLES, @param);
  $self->attr('filtGs', []);
}

=head2 name

  Usage      : my $name = $filt->name(); $filt->name($newname);
  Description: sets/gets the name of the FilterTree
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

=head2 hideDisplay

  Usage      : Arg [1] - (optional) string $hideDisplay
  Description: get/set for hideDisplay toggle
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub hideDisplay {
  # stores display name
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(HIDEDISPLAY, $value);
  }
  return $self->getParam(HIDEDISPLAY);
}



=head2 addFilterGroup

  Usage      : $filt->addFilterGroup($fg);
  Description: adds a FilterGroup to this FilterTree. The
               order of addition of each FilterGroup is maintained.
  Returntype : na
  Exceptions : none
  Caller     : caller

=cut

sub addFilterGroup {
  my ($self, $filtGroup) = @_;

  my $filtGs = $self->get('filtGs');
  push @{$filtGs}, $filtGroup;
}

=head2 getFilterGroupByName

  Usage      : my $fg = $filt->getFilterGroupByName($name);
  Description: Returns a BioMart::FilterGroup object from this
               BioMart::FilterTree object, named by the given name.
               If no object exists in this tree named by the given name,
               this method returns undef.
  Returntype : BioMart::FilterGroup or undef if none found with given name.
  Exceptions : none
  Caller     : caller

=cut

sub getFilterGroupByName {
  my ($self, $name) = @_;

  my $retGroup;

  my $filtGs = $self->get('filtGs');

  foreach my $filtG (@{$filtGs}) {
    if ($filtG->name() eq $name) {
      $retGroup = $filtG;
      last;
	}
  }

  return $retGroup;
}

=head2 getAllFilterGroups

  Usage        :  my $groups = $filt->getAllFilterGroups; 
                  foreach my $group (@{$groups}) { ... }
  Description  :  Returns a list_ref of all FilterGroups held in this 
                  FilterTree.
  Returntype   :  list_ref of BioMart::FilterGroup objects
  Exceptions   :  none
  Caller       :  caller

=cut

sub getAllFilterGroups {
  my $self = shift;

  return $self->get('filtGs');
}

=head2 getFilterByName

  Usage        :  my $filt = $filt->getFilterByName($name);
  Description  :  Get a specific BioMart::Filter object named by $name.
                  May return undef if no object is contained within 
                  this FilterTree with the given name.
  Returntype   :  BioMart::Filter or undef if none found with given name
  Exceptions   :  none
  Caller       :  caller

=cut

sub getFilterByName {
  my ($self, $name) = @_;

  my $retFilt;

  my $filtGs = $self->get('filtGs');
  GROUP: foreach my $filtG (@{$filtGs}) {
    my $filtColls = $filtG->getAllCollections;

    foreach my $filtCol (@{$filtColls}) {
      my $filts = $filtCol->getAllFilters;

      foreach my $filt (@{$filts}) {
        if ($filt->name eq $name) {
          $retFilt = $filt;
          last GROUP;
		}
	  }
	}
  }

  return $retFilt;
}


=head2 getOptionByName

  Usage        :  my $option = $filtT->getOptionByName($name);
  Description  :  Get a specific BioMart::Option object named by $name.
                  May return undef if no object is contained within 
                  this FilterTree with the given name.
  Returntype   :  BioMart::Option or undef if none found with given name
  Exceptions   :  none
  Caller       :  caller

=cut

sub getOptionByName {
  my ($self, $name) = @_;

  my $retOption;

  my $filtGs = $self->get('filtGs');
  GROUP: foreach my $filtG (@{$filtGs}) {
    my $filtColls = $filtG->getAllCollections;

    foreach my $filtCol (@{$filtColls}) {
      my $filts = $filtCol->getAllFilters;

      foreach my $filt (@{$filts}) {
	  my $ops = $filt->getAllOptions;

	  foreach my $op (@{$ops}) {
	      if ($op->name eq $name) {
		  $retOption = $op;
		  last GROUP;
	      }
	  }
      }
  }
  }
  
  return $retOption;
}

1;
