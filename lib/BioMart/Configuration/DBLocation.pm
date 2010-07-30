# $Id: 
#
# BioMart module for BioMart::Configuration::DBLocation
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::DBLocation

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


package BioMart::Configuration::DBLocation;

use base qw(BioMart::Configuration::Location);
use strict;
use warnings;
use BioMart::Exception;
use DBI;

use constant ORACLEDSNTEMPLATE => q(dbi:Oracle:host=%s;sid=%s;port=%s);
use constant MYSQLDNSTEMPLATE => q(dbi:mysql:database=%s;host=%s;port=%s);
use constant POSTGRESTEMPLATE => q(dbi:Pg:dbname=%s;host=%s;port=%s);
use constant ODBCDNSTEMPLATE => q(dbi:odbc:%s);

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
  $self->attr('dbh', undef);
 

  $self->openConnection();


}

sub openConnection {
  my $self = shift; 

  unless (defined($self->host ) && defined ($self->databaseType)  
	    && defined($self->database) && defined($self->user)) { 
	BioMart::Exception::Database->throw("Database Specifications must contain at least the database type (".$self->databaseType.") host (".$self->host."), database (".$self->database."), and user (".$self->user.")"); 
  }
  
  my $dsn;
  if ($self->databaseType eq 'oracle'){
      $dsn=sprintf(ORACLEDSNTEMPLATE, $self->host, $self->database,
      	   $self->port);
  } elsif ($self->databaseType eq 'mysql') {
      $dsn=sprintf(MYSQLDNSTEMPLATE, $self->database, $self->host, 
		   $self->port);
  } elsif ($self->databaseType eq 'postgres') {
      $dsn=sprintf(POSTGRESTEMPLATE, $self->database, $self->host, 
		   $self->port);
   } elsif ($self->databaseType eq 'odbc') {
      $dsn=sprintf(ODBCDNSTEMPLATE, $self->database);
  } else {
      warn("unsupported RDBMS type:  \"$self->databaseType\" - please use the correct name or supported RDBMS ...... skipping connection");
  }

  $self->dsn($dsn); 
 
  my $dbh;
      
  eval {
      $dbh = DBI->connect(
			  $dsn,
			  $self->user,
			  $self->password,
			  {InactiveDestroy => 1, RaiseError => 1, PrintError => 1}
			  );
  };
  if($@ || !$dbh) {
      BioMart::Exception::Database->throw("Could not connect to ".$self->databaseType." database ".$self->database.": ".$@);
  }
      
  $self->dbh($dbh);    
}


sub dbh {
  my ($self, $dbh) = @_;

  if ($dbh) {
     $self->set('dbh',$dbh);
  }

  return $self->get('dbh');
}

sub dbhDC
{
	my ($self, $dbh) = @_;	
	$dbh = $self->get('dbh');
	$dbh->disconnect();##->disconnect; assuming all statement handles have already called respective ->finish()
     $self->set('dbh',undef);
}



1;
