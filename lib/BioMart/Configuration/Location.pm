# $Id
#
# BioMart module for BioMart::Configuration::Location
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::Location

=head1 SYNOPSIS

Base Class for all BioMart location objects.

=head1 DESCRIPTION

Base Class for BioMart location objects defined within the registry XML
configguration

=head1 AUTHOR - Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::Location;

use strict;
use warnings;
use base qw(BioMart::Root);

use constant NAME         => "name";
use constant DISPLAYNAME          => "displayName";
use constant HOST         => "host";
use constant PORT         => "port";
use constant DEFAULT         => "default";
use constant VISIBLE         => "visible";
use constant INCLUDEDATASETS         => "includeDatasets";
use constant MARTUSER        => "martUser";
use constant SCHEMA         => "schema";
use constant DATABASETYPE  => "databaseType";
use constant DATABASE  => "database";
use constant USER     => "user";
use constant PASSWORD => "password";
use constant PROXY => "proxy";
use constant PATH =>"path";
use constant SERVERVIRTUALSCHEMA => "serverVirtualSchema";

use constant TITLES => [
               NAME,
	       DISPLAYNAME,
               HOST,
	       PORT,
	       DEFAULT,
               VISIBLE,
               INCLUDEDATASETS,
               MARTUSER,
               SCHEMA,
               DATABASETYPE,
               DATABASE,
               USER,
               PASSWORD,
	       PROXY,
               PATH,
	       SERVERVIRTUALSCHEMA
			 ];
=head2 _new

  Usage      : my $location_obj = 
                  BioMart::Configuration::Location_implementation->new();
  Description: create a new Location object
  Returntype : BioMart::Configuration::Location
  Exceptions : none
  Caller     : general

=cut

sub _new {

  my ($self, @param) = @_;
  $self->SUPER::_new(@param);
  $self->addParams(TITLES, @param);
  $self->attr('dsn', undef);
  $self->attr('datasets', { });
  $self->attr('datasetNumber', undef);
  $self->attr('visibleDatasetNames', []);
  $self->attr('visibleDatasetDisplayNames', []);
}

=head2 name

  Usage      : my $name = $location->name; $location->name($newName);
  Description: get/set for the name of the location
  Returntype : scalar $name
  Exceptions : none
  Caller     : caller

=cut

sub name {
  my ($self, $value) = @_;
  if ($value){
      $self->setParam(NAME, $value);
  }
  return $self->getParam(NAME);

}

=head2 displayName

  Usage      : my $displayName = $location->displayName; 
               $location->displayName($newName);
  Description: get/set for the displayName of the location
  Returntype : scalar $displayName
  Exceptions : none
  Caller     : caller

=cut

sub displayName {
  my ($self, $value) = @_;
  if ($value){
      $self->setParam(DISPLAYNAME, $value);
  }
  return $self->getParam(DISPLAYNAME);

}

=head2 host

  Usage      : my $host = $location->host; $location->host($newName);
  Description: get/set for the host of the location
  Returntype : scalar $host
  Exceptions : none
  Caller     : caller

=cut

sub host {
  my ($self, $value) = @_;
  if ($value){
      $self->setParam(HOST, $value);
  }
  return $self->getParam(HOST);

}

=head2 port

  Usage      : my $port = $location->port; $location->port($newName);
  Description: get/set for the port of the location
  Returntype : scalar $port
  Exceptions : none
  Caller     : caller

=cut

sub port {
  my ($self, $value) = @_;
  if ($value){
      $self->setParam(PORT, $value);
  }
  return $self->getParam(PORT);

}

=head2 martUser

  Usage      : my $martUser = $location->martUser; 
               $location->martUser($newName);
  Description: get/set for the martUser of the location
  Returntype : scalar $martUser
  Exceptions : none
  Caller     : caller

=cut

sub martUser {
  my ($self, $value) = @_;
  if ($value){
      $self->setParam(MARTUSER, $value);
  }
  return $self->getParam(MARTUSER);

}



=head2 includeDatasets

  Usage      : my $includeDatasets = $location->includeDatasets; 
               $location->includeDatasets($newName);
  Description: get/set for the includeDatasets of the location
  Returntype : scalar $includeDatasets
  Exceptions : none
  Caller     : caller

=cut

sub includeDatasets {
  my ($self, $value) = @_;
  if ($value){
      $self->setParam(INCLUDEDATASETS, $value);
  }
  return $self->getParam(INCLUDEDATASETS);

}

=head2 visible

  Usage      :  my $visible = $filt->visible; $location->visible($visible);
  Description:  get/set the visible flag associated with this location
  Returntype :  scalar $visible
  Exceptions :  none
  Caller     :  caller

=cut

sub visible {
  my ($self,$visible) = @_;

  if ($visible) {
    $self->setParam(VISIBLE,$visible);
  }
  return $self->getParam(VISIBLE);
}

=head2 default

  Usage      : my $default = $location->default; $location->default($newName);
  Description: get/set for the default of the location
  Returntype : scalar $default
  Exceptions : none
  Caller     : caller

=cut

sub default {
  my ($self, $value) = @_;
  if ($value){
      $self->setParam(DEFAULT, $value);
  }
  return $self->getParam(DEFAULT);

}





=head2 schema

  Usage      : my $schema = $location->schema; $location->schema($newName);
  Description: get/set for the schema of the location
  Returntype : scalar $schema
  Exceptions : none
  Caller     : caller

=cut

sub schema {
  my ($self, $value) = @_;
  if ($value){
      $self->setParam(SCHEMA, $value);
  }
  return $self->getParam(SCHEMA);

}


=head2 databaseType

  Usage      : my $databaseType = $location->databaseType; 
               $location->name($databaseType);
  Description: get/set for the databaseType of the location
  Returntype : scalar $databaseType
  Exceptions : none
  Caller     : caller

=cut

sub databaseType {
  my ($self, $value) = @_;
  if ($value){
      $self->setParam(DATABASETYPE, $value);
  }
  return $self->getParam(DATABASETYPE);

}

=head2 database

  Usage      : my $database = $location->database; 
               $location->database($newName);
  Description: get/set for the database of the location
  Returntype : scalar $database
  Exceptions : none
  Caller     : caller

=cut

sub database {
  my ($self, $value) = @_;
  if ($value){
      $self->setParam(DATABASE, $value);
  }
  return $self->getParam(DATABASE);

}

=head2 user

  Usage      : my $user = $location->user; $location->user($newName);
  Description: get/set for the user of the location
  Returntype : scalar $user
  Exceptions : none
  Caller     : caller

=cut

sub user {
  my ($self, $value) = @_;
  if ($value){
      $self->setParam(USER, $value);
  }
  return $self->getParam(USER);

}

=head2 password

  Usage      : my $password = $location->password; 
               $location->password($newName);
  Description: get/set for the password of the location
  Returntype : scalar $password
  Exceptions : none
  Caller     : caller

=cut

sub password {
  my ($self, $value) = @_;
  if ($value){
      $self->setParam(PASSWORD, $value);
  }
  return $self->getParam(PASSWORD);

}

=head2 proxy

  Usage      : my $proxy = $location->proxy; $location->proxy($newName);
  Description: get/set for the proxy of the location
  Returntype : scalar $proxy
  Exceptions : none
  Caller     : caller

=cut

sub proxy {
  my ($self, $value) = @_;
  if ($value){
      $self->setParam(PROXY, $value);
  }
  return $self->getParam(PROXY);

}


=head2 path

  Usage      : my $path = $location->path; $location->path($newName);
  Description: get/set for the path of the location
  Returntype : scalar $path
  Exceptions : none
  Caller     : caller

=cut

sub path {
  my ($self, $value) = @_;
  if ($value){
      $self->setParam(PATH, $value);
  }
  return $self->getParam(PATH);

}




=head2 serverVirtualSchema

  Usage      : my $serverVirtualSchema = $location->serverVirtualSchema; 
               $location->serverVirtualSchema($newName);
  Description: get/set for the serverVirtualSchema of the location
  Returntype : scalar $serverVirtualSchema
  Exceptions : none
  Caller     : caller

=cut

sub serverVirtualSchema {
  my ($self, $value) = @_;
  if ($value){
      $self->setParam(SERVERVIRTUALSCHEMA, $value);
  }
  return $self->getParam(SERVERVIRTUALSCHEMA);

}

=head2 dsn

  Usage      : my $dsn = $location->dsn; $location->dsn($newName);
  Description: get/set for the dsn of the location
  Returntype : scalar $dsn
  Exceptions : none
  Caller     : caller

=cut

sub dsn {
  my ($self, $value) = @_;
  if ($value){
      $self->set('dsn', $value);
  }
  return $self->get('dsn');

}


=head2 datasetNumber

  Usage      : my $dsNo = $location->datasetNumber; $location->dsn($newNumber);
  Description: get/set for the datasetNumber of the location
  Returntype : scalar $datasetNumber
  Exceptions : none
  Caller     : caller

=cut

sub datasetNumber {
  my ($self, $value) = @_;
  if ($value){
      $self->set('datasetNumber', $value);
  }
  return $self->get('datasetNumber');

}

=head2 addDataset

  Usage      : usage
  Description: Description
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub addDataset {
  my ($self, $dataset) = @_;

  my $dataSetName = $dataset->name();
  my $dataSetHash = $self->get('datasets');

  my $dataSetEntry = $dataSetHash->{$dataSetName};
  if (defined $dataSetEntry) {
      BioMart::Exception::Configuration->throw("Can not add dataset '$dataSetName', already added");
  }
  $dataSetHash->{$dataSetName} = $dataset;
  
  if ($dataset->visible == 1){
      my $datasetNames = $self->get('visibleDatasetNames');
      my $datasetDisplayNames = $self->get('visibleDatasetDisplayNames');
      push @$datasetNames,$dataSetName;
      push @$datasetDisplayNames, $dataset->displayName();
      $self->set('visibleDatasetNames', $datasetNames);
      $self->set('visibleDatasetDisplayNames', $datasetDisplayNames);
  }
  $self->set('datasets', $dataSetHash);

}


=head2 removeDataset

  Usage      : usage
  Description: Description
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub removeDataset {
  my ($self,$dataset) = @_;
  my $datasets = $self->getAllDatasets;
  my $i = 0;
  foreach my $dset (@$datasets){
      if ($dset->name eq $dataset->name){
	  splice @$datasets,$i,1;
	  last;
      }
      $i++;
  }
}


=head2 getAllVisibleDatasetNames

  Usage      : usage
  Description: Description
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub getAllVisibleDatasetNames {
  my $self = shift;
  return $self->get('visibleDatasetNames');

}

=head2 getAllVisibleDatasetDisplayNames

  Usage      : usage
  Description: Description
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub getAllVisibleDatasetDisplayNames {
  my $self = shift;
  return $self->get('visibleDatasetDisplayNames');

}

=head2 getAllDatasets

  Usage      : usage
  Description: Description
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub getAllDatasets {
  my ($self, $visible ) = @_;

  my $datasetHash =  $self->get('datasets');
  my @datasets = values %{$datasetHash};
	if(!$visible)
	{
		return \@datasets;
	}
	
	my $visibleDS;
	if ($visible == 1)
	{
		foreach my $vDS (@datasets)
		{
			if ($vDS->visible == 1)
			{
				push @{$visibleDS}, $vDS;
			}			
		}
		return $visibleDS;
	}
  #return $self->get('datasets');
}

=head2 getDatasetByName

  Usage      : usage
  Description: Description
  Returntype : 
  Exceptions : none
  Caller     : caller

=cut

sub getDatasetByName {
    my ($self,$dataSetName) = @_;
    my $dataSetHash = $self->get('datasets');
    my $dataSetEntry = $dataSetHash->{$dataSetName};
    return $dataSetEntry;
}

=head2 retrieveDatasetInfo

  Usage      : my $datasets_info = $location->retrieveDatasets;
  Description: Retrieves the dataset informations for a Location object.
  Returntype : SQL string
  Exceptions : none
  Caller     : caller

=cut

sub retrieveDatasetInfo {
  my ($self,@param) = @_;

  if ($self->can("_retrieveDatasetInfo")) {
    return $self->_retrieveDatasetInfo(@param);
  }
  $self->unimplemented_method;
}


sub configureMessage {
    my ($self,$virtualSchema,$dataSetName,$type,$dsCounter)=@_;

    my $counter;
    if (defined $dsCounter){
    my $datasets=$self->datasetNumber;
    if (length ($dsCounter)==1){$dsCounter="00".$dsCounter;}
    if (length ($dsCounter)==2){$dsCounter="0".$dsCounter;}
    if (length ($datasets)==1){$datasets="00".$datasets;}
    if (length ($datasets)==2){$datasets="0".$datasets;}

	$counter=  $dsCounter."/".$datasets;
    } else
    {
	$counter="";
    }
   
    my $displayName;
    if (defined $self->displayName){
	$displayName=$self->displayName;
    } else {
	$displayName="";
    }

    my $param0=10;
    my $param1=50;
    my $param2=25;
    my $param3=30;
    my $param4=10;    

    my $buffer0 = $self->_buffer($param0,$counter);
    my $buffer1 = $self->_buffer($param1,$virtualSchema." ".$dataSetName);
    
    
    my	$buffer2 = $self->_buffer($param2,$displayName);

    my $buffer3 = $self->_buffer($param3,$self->host.":".$self->port);
    my $buffer4 = $self->_buffer($param4,$virtualSchema);
    
    print STDERR $virtualSchema.$buffer4.$displayName.$buffer2.$counter.$buffer0.$dataSetName.
	$buffer1."(".$type.") ".$self->host.":".$self->port.$buffer3;
}

sub _buffer {
    my ($self,$param,$field)=@_;

    my $buffer=" ";
    if ($param>length($field)){
	for (my $i=0;$i<$param-length($field);$i++){
	    $buffer=$buffer.".";
	}
    } else {
	$buffer =" ... ";
    }
    
    $buffer=$buffer." ";
    return $buffer;
}




1;
