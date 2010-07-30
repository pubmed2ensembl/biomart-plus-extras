# $Id: 
#
# BioMart module for BioMart::Configuration::RegistryDBPointer
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::RegistryDBPointer

=head1 SYNOPSIS

A Location that represents the configuration for a mart database accessed
directly from the DB server

=head1 DESCRIPTION



=head1 AUTHOR - Arek Kasprzyk, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::RegistryDBPointer;

use base qw(BioMart::Configuration::DBLocation);
use strict;
use warnings;




=head2 _new

  Usage      : see Usage for BioMart::Configuration::Location.
  Description: creates a new MartDBLocation object which ...
  Returntype : BioMart::Configuration::MartDBLocation
  Exceptions : none
  Caller     : general

=cut

sub _new {
    my ($self, @param) = @_;
  
    $self->SUPER::_new(@param);
}


sub getRegistryXML {

    my $self=shift;

    my $dbh=$self->dbh();
    my $dsn=$self->dsn();

    unless ($dbh) {
	warn("\n\nWARNING: Could not load Registry from database $dsn, SKIPPING\n\n");
	return undef;
    }

    # stops XML too long bug
    $dbh->{'LongTruncOk'} = 1;
    $dbh->{'LongReadLen'} = 20000;

    my $sql = "SELECT compressed_xml FROM ".$self->schema.".meta_registry";
    
    my $sth = $dbh->prepare($sql); 
    unless ($sth) {
	my $err = $dbh->errstr;
	$dbh->disconnect;
	BioMart::Exception::Database->throw("Could not prepare statement handle for registry fetch for db $dsn: $err");
    }

    my $executed = $sth->execute;
    
    unless ($executed) {
	my $err = $dbh->errstr;
	$sth->finish;
	$dbh->disconnect;
	BioMart::Exception::Database->throw("Could not execute sql for $dsn: $err");
    }

    my $row = $sth->fetchrow_arrayref;
    my $xml = Compress::Zlib::memGunzip($row->[0]) ;

    $sth->finish;
    $dbh->disconnect;
    
    return $xml;
}







1;
