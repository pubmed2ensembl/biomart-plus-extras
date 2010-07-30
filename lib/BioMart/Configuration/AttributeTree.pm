# $Id: AttributeTree.pm,v 1.4 2008-04-09 12:52:33 syed Exp $
#
# BioMart module for BioMart::Configuration::AttributeTree
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::AttributeTree

=head1 SYNOPSIS

Holds a List of BioMart::AttributeGroup objects.

=head1 DESCRIPTION

Object to further define the Attributes available to the User Interface by
a Dataset.  Holds a list of one or more BioMart::AttributeGroup objects.

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Richard Holland, Darin London, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::AttributeTree;

use strict;
use warnings;
use base qw(BioMart::Root);

use constant NAMEKEY => "name";
use constant DISPLAYNAME => "displayName";
use constant DESCRIPTION => "description";
use constant HIDEDISPLAY => "hideDisplay";
use constant OUTFORMATS => "outFormats";
use constant MAXSELECT => "maxSelect";


use constant TITLES => [ NAMEKEY ,
                         DISPLAYNAME,
                         DESCRIPTION,
			 HIDEDISPLAY,
			 OUTFORMATS,
			 MAXSELECT ];

sub _new {
  my ($self, @param) = @_;
  $self->SUPER::_new(@param);

  $self->addParams(TITLES, @param);
  $self->attr('attGs', []);
}

=head2 name

  Usage      : my $name = $att->name(); $att->name($newname);
  Description: sets/gets the name of the AttributeTree
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

  Usage      : Arg [1] - stores maximum number of groups
  Description: get/set for maxSelect
  Returntype : number
  Exceptions : none
  Caller     : general

=cut

sub maxSelect {
  
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(MAXSELECT, $value);
  }
  return $self->getParam(MAXSELECT);
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

=head2 outFormats

  Usage      : Arg [1] - (optional) string $outFormats
  Description: get/set for outFormats toggle
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub outFormats {
  # stores display name
  my ($self, $value) = @_;
  if ($value){
    $self->setParam(OUTFORMATS, $value);
  }
  return $self->getParam(OUTFORMATS);
}

=head2 addAttributeGroup

  Usage      : $at->addAttributeGroup($ag);
  Description: adds an AttributeGroup to this AttributeTree. The
               order of addition of each AttributeGroup is maintained.
  Returntype : na
  Exceptions : none
  Caller     : caller

=cut

sub addAttributeGroup {
  my ($self, $attGroup) = @_;

  my $attGs = $self->get('attGs');
  push @{$attGs}, $attGroup;
}

=head2 getAttributeGroupByName

  Usage      : my $ag = $at->getAttributeGroupByName($name);
  Description: Returns a BioMart::AttributeGroup object from this
               BioMart::AttributeTree object, named by the given name.
               If no object exists in this tree named by the given name,
               this method returns undef.
  Returntype : BioMart::AttributeGroup or undef if none found with given name.
  Exceptions : none
  Caller     : caller

=cut

sub getAttributeGroupByName {
  my ($self, $name) = @_;

  my $retGroup;

  my $attGs = $self->get('attGs');

  foreach my $attG (@{$attGs}) {
    if ($attG->name() eq $name) {
      $retGroup = $attG;
      last;
	}
  }

  return $retGroup;
}

=head2 getAllAttributeGroups

  Usage        :  my $groups = $at->getAllAttributeGroups; 
                  foreach my $group (@{$groups}) { ... }
  Description  :  Returns a list_ref of all AttributeGroups held in 
                  this AttributeTree.
  Returntype   :  list_ref of BioMart::AttributeGroup objects
  Exceptions   :  none
  Caller       :  caller

=cut

sub getAllAttributeGroups {
  my $self = shift;

  return $self->get('attGs');
}


=head2 getFilterByName

  Usage        :  my $filt = $filt->getFilterByName($name);
  Description  :  Get a specific BioMart::Filter object named by $name.
                  May return undef if no object is contained within 
                  this AttributerTree with the given name.
  Returntype   :  BioMart::Filter or undef if none found with given name
  Exceptions   :  none
  Caller       :  caller

=cut

sub getFilterByName {
  my ($self, $name) = @_;

  my $retFilt;

  my $attGs = $self->get('attGs');
  GROUP: foreach my $attG (@{$attGs}) {
    my $attColls = $attG->getAllCollections;

    foreach my $attCol (@{$attColls}) {
      my $filts = $attCol->getAllAttributes;# attributeFilters are just added
	                                    # as attributes on start-up

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


=head2 getAttributeByName

  Usage        :  my $att = $at->getAttributeByName($name);
  Description  :  Get a specific BioMart::Attribute object named by $name.
                  May return undef if no object is contained within 
                  this AttributeTree with the given name.
  Returntype   :  BioMart::Attribute or undef if none found with given name
  Exceptions   :  none
  Caller       :  caller

=cut

sub getAttributeByName {
  my ($self, $name) = @_;

  my $retAtt;

  my $attGs = $self->get('attGs');
  GROUP: foreach my $attG (@{$attGs}) {
    my $attColls = $attG->getAllCollections;

    foreach my $attCol (@{$attColls}) {
      my $atts = $attCol->getAllAttributes;

      foreach my $att (@{$atts}) {
	next if (!defined($att));
        if ($att->name eq $name) {
          $retAtt = $att;
          last GROUP;
		}
	  }
	}
  }

  return $retAtt;
}

=head2 getAttributeByNameKey

  Usage        :  my $att = $at->getAttributeByNameKey($name,$key);
  Description  :  Get a specific BioMart::Attribute object named 
                  by $name, $key.
                  May return undef if no object is contained within 
                  this AttributeTree with the given name and key.
  Returntype   :  BioMart::Attribute or undef if none found with given name
  Exceptions   :  none
  Caller       :  caller

=cut

sub getAttributeByNameKey {
  my ($self, $name, $key) = @_;
  my $retAtt;

  my $attGs = $self->get('attGs');
  GROUP: foreach my $attG (@{$attGs}) {
    my $attColls = $attG->getAllCollections;

    foreach my $attCol (@{$attColls}) {
      my $atts = $attCol->getAllAttributes;

      foreach my $att (@{$atts}) {
	next if (!defined($att));
        if ($att->name eq $name) {
	  if ($att->key){ 
	      $retAtt = $att if ($att->key eq $key);
	  }
	  else{
	      $retAtt = $att;
	  }
          last GROUP;
		}
	  }
	}
  }
  return $retAtt;
}



1;
