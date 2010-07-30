# $Id: BooleanFilter.pm,v 1.3 2008-04-09 12:52:33 syed Exp $
#
# BioMart module for BioMart::Configuration::BooleanFilter
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::BooleanFilter

=head1 SYNOPSIS

Object responsible for boolean included/excluded filters

=head1 DESCRIPTION

Object responsible for boolean included/excluded filters

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::BooleanFilter;
# inherits from FilterBase, overrides toSQL

use strict;
use warnings;
use Digest::MD5;

use base qw(BioMart::Configuration::BaseFilter);

=head2 _new
  
  Usage      : no arguments
  Description: creates a new BooleanFilter object which can contain a single
               Attribue object and a flag for excluded vs included
  Returntype : BioMart::Configuration::BooleanFilter
  Exceptions : none
  Caller     : general

=cut

sub _new {
  my ($self, @param) = @_;
  $self->SUPER::_new(@param);
  $self->attr('attribute',undef);
  $self->attr('excluded',0);
  $self->attr('number_flag',0);
}


sub _init {
  my ($self, @param) = @_;

  $self->SUPER::_init(@param);

  my $proto = shift @param;

  $self->attr('attribute', $proto->attribute);
  $self->attr('excluded', 0);
  $self->attr('number_flag',0);
}

=head2 attribute

  Usage      : Arg[1] - (optional) BioMart::Configuration::Attribute object
  Description: get/set method for the Attribute object for this BooleanFilter
  Returntype : BioMart::Configuration::Attribute object
  Exceptions : none
  Caller     : caller

=cut

sub attribute {

# stores attribute
  my ($self, $attribute) = @_;
  if ($attribute){
    $self->set('attribute', $attribute);
  }
  return $self->get('attribute');
}

=head2 table

  Usage      : 
  Description: returns the table name associated with this filter; 
  Returntype : String table name
  Exceptions : none
  Caller     : caller

=cut

sub table {
  my $self = shift;
  my $attribute = $self->get('attribute');
  return $attribute->table;
}

=head2 setExcluded

  Usage      : no arguments
  Description: sets this BooleanFilter as an exclude rather than include filter			
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut

sub setExcluded {
  my ($self, $val) = @_;
	if (defined($val))
	{
		$self->set('excluded',$val);
	}
	else
	{
	  $self->set('excluded',1);
	}
}

=head2 getExcluded

  Usage      : no arguments
  Description: gets this BooleanFilter as an exclude rather than include filter
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut

sub getExcluded {
  my $self = shift;
  return $self->get('excluded');
}

=head2 setIncluded

  Usage      : no arguments
  Description: sets this BooleanFilter as an include rather than exclude filter
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut

sub setIncluded {
  my $self = shift;
  $self->set('excluded',0);
}


=head2 setNumberFlag

  Usage      :  $filt->setNumberFlag;
  Description:  set the number flag for 1,0, null type filters
  Returntype :  none
  Exceptions :  none
  Caller     :  caller

=cut

sub setNumberFlag {
  my $self = shift;
    $self->set('number_flag',1);
}

=head2 getNumberFlag

  Usage      :  $filt->getNumberFlag;
  Description:  geet the number flag for 1,0, null type filters
  Returntype :  none
  Exceptions :  none
  Caller     :  caller

=cut

sub getNumberFlag {
  my $self = shift;
  return $self->get('number_flag');
}

sub _toSQL {
  my $self = shift;
  my $attribute = $self->attribute();
  my $condition = $self->get('number_flag') ? ' > 0' : ' IS NOT NULL';
  if ($self->get('excluded')){
      $condition = $self->get('number_flag') ? ' = 0' : ' IS NULL';
  }
  return $attribute->toSQL().$condition; 

}

sub _hashCode {
  my $self = shift;

  my $digest = Digest::MD5->new;

  $digest->add($self->SUPER::_hashCode);
  $digest->add($self->table) if ($self->table);
  $digest->add($self->get('excluded'));
  $digest->add($self->attribute()->hashCode);
  return $digest->hexdigest;
}

1;
