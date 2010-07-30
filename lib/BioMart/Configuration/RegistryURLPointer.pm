# $Id: 
#
# BioMart module for BioMart::Configuration::RegistryURLPointer
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::RegistryURLPointer

=head1 SYNOPSIS

A Location that represents the configuration for a mart database accessed
via a mart server

=head1 DESCRIPTION



=head1 AUTHOR - Arek Kasprzyk, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::RegistryURLPointer;

use strict;
use warnings;

use base qw(BioMart::Configuration::URLLocation);



=head2 _new

  Usage      : see Usage for BioMart::Configuration::Location.
  Description: creates a new MartURLLocation object which ...
  Returntype : BioMart::Configuration::MartURLLocation
  Exceptions : none
  Caller     : general

=cut

sub _new {
  my ($self, @param) = @_;

  $self->SUPER::_new(@param);  
}


sub getRegistryXML {
    my $self = shift;
       
    my $qualifier="type=registry";   
    my $xml = join "",$self->getResultSet($qualifier,"GET"); 
    return $xml;
}





1;
