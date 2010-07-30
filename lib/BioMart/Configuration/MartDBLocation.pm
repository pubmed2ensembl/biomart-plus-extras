# $Id: 
#
# BioMart module for BioMart::Configuration::MartDBLocation
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::MartDBLocation

=head1 SYNOPSIS

A Location that represents the configuration for a mart database accessed
directly from the DB server

=head1 DESCRIPTION



=head1 AUTHOR - Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::MartDBLocation;

use base qw(BioMart::Configuration::DBLocation);
use strict;
use warnings;
use Digest::MD5;



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


#------------------------------------------------------------------------

=head2 getDatasetConfigXML

  Usage      :  my $xml = $configurator->getXML($dataset);

  Description:  Gets XML directly from the db server

  Return type:  xml hash

  Exceptions :
  Caller     :

=cut

sub getDatasetConfigXML{

    my ($self,$virtualSchema,$dataSetName,$interfaceType,$dsCounter,$noMessage)=@_;

	if(!$noMessage)
	{
	    	$self->configureMessage($virtualSchema,$dataSetName,"RDBMS",$dsCounter);
	}

	my $dbh=$self->dbh();
	if (!$dbh)
	{	$self->openConnection(); 
     	$dbh=$self->dbh();
	}
	
    # stops AE XML too long bug
    $dbh->{'LongTruncOk'} = 0;
    $dbh->{'LongReadLen'} = 5000000;
    
    my $upperName = uc($dataSetName);

    my $interface_count_sql="SELECT count(*) FROM ".
	$self->schema.".meta_conf__interface__dm";
    my $sth1= $dbh->prepare($interface_count_sql);
    my $executed1 = $sth1->execute;
    my $interface_count = 0;
    if( $executed1 ){
      while  ( my $tt=$sth1->fetchrow_arrayref){
	$interface_count=$tt->[0];
      }
    }



my $user=$self->martUser;
    if ($user eq ""){
        $user="default";
    }

    my $sql;
    if ($interface_count > 0){
        $sql = "SELECT compressed_xml FROM ".$self->schema."."."meta_conf__xml__dm mc, ".$self->schema."."."meta_conf__user__dm mu, ".$self->schema.".meta_conf__interface__dm mi, ".$self->schema.".meta_conf__dataset__main main WHERE (dataset = \'".$dataSetName."\' OR dataset = \'$upperName\') AND mu.mart_user=\'".$user."\' AND mu.dataset_id_key=main.dataset_id_key AND interface = \'".$interfaceType."\' AND main.dataset_id_key=mc.dataset_id_key AND mc.dataset_id_key=mi.dataset_id_key";
    }
    else{
        $sql = "SELECT compressed_xml FROM ".$self->schema."."."meta_conf__xml__dm mc, ".$self->schema."."."meta_conf__user__dm mu, ".$self->schema.".meta_conf__dataset__main main WHERE (dataset = \'".$dataSetName."\' OR dataset = \'$upperName\') AND mu.mart_user=\'".$user."\' AND mu.dataset_id_key=main.dataset_id_key AND  main.dataset_id_key=mc.dataset_id_key";
    }

	my $sth = $dbh->prepare($sql) || die $dbh->errstr;
	
	eval{
		$sth->execute;		
	};
	
	if($@ || !$sth) {
     	BioMart::Exception::Configuration->throw("Could not retrieve valid data from Meta Tables. SCHEMA ".$self->schema." DATASET ".$dataSetName.": ".$@); 
  	}	
	
	
	my $row = $sth->fetchrow_arrayref;
	my $xml = Compress::Zlib::memGunzip($$row[0]) ;

	if (!$xml)
	{ BioMart::Exception::Configuration->throw("Could not retrieve valid XML for SCHEMA: ".$self->schema."\tDATASET: $dataSetName");
	}

	$sth->finish();
	$sth1->finish();
	$self->dbhDC();    

	return $xml;

}

sub versionCheck() {
    
    my ($self,$version)=@_;
    #my $dbh=$self->dbh();
    #unless (defined $dbh) {$self->openConnection(); $dbh=$self->dbh();}
    $self->openConnection(); 
    my $dbh=$self->dbh();


    my $schema = $self->schema;
    my $sql="SELECT count(*) FROM ".$schema.".meta_version__version__main WHERE version = \'$version\'";
    my $sth= $dbh->prepare($sql);
    my $executed = $sth->execute;
    my $tt=$sth->fetchrow_arrayref;
    my $count=$tt->[0];
	
	$sth->finish;
	$self->dbhDC();
    
    return $count;
}


sub version() {
    my $self = shift;
    $self->openConnection();
    my $dbh=$self->dbh();


    my $schema = $self->schema;
    my $sql="SELECT version FROM ".$schema.".meta_version__version__main";
    my $sth= $dbh->prepare($sql);
    my $executed = $sth->execute;
    my $tt=$sth->fetchrow_arrayref;
    my $version=$tt->[0];

	$sth->finish;
	$self->dbhDC();

    return $version;
}





sub _retrieveDatasetInfo() {

    my ($self,$vSchemaName, $virtualSchemaDefault)=@_;
	
	my $dbh=$self->dbh();
	if (!$dbh)
	{	$self->openConnection(); 
     	$dbh=$self->dbh();
	}
	
    my $schema = $self->schema;

    my $user_count_sql="SELECT count(*) FROM ".$schema.".meta_conf__user__dm";
    my $sth1= $dbh->prepare($user_count_sql);
    my $executed1 = $sth1->execute;
    my $users = 0;
    if( $executed1 ){
      while  ( my $tt=$sth1->fetchrow_arrayref){
	$users=$tt->[0];
      }
    }     

    my $sql;
    
    my $user=$self->martUser;
    if ($user eq ""){
	$user="default";
    }

    # inlcude datasets
    my $include_string; 
    my @include_datasets=split(/\,/,$self->includeDatasets);
    if (scalar (@include_datasets)>0){ 	
	my $quoted = join ("\','",@include_datasets);
	$quoted ="'".$quoted."'";	
	$include_string = " AND dataset IN (".$quoted.")";
    } else {
	$include_string="";
    }
   
    if ($users >0){

		
	$sql = "SELECT type, dataset, display_name, visible, version, interface, modified 
                  FROM ".$schema.".meta_conf__dataset__main   conf,"
                  .$schema."."."meta_conf__user__dm  muser,"
                  .$schema."."."meta_conf__interface__dm  minterface  
                  WHERE type IS NOT NULL 
                  AND conf.dataset_id_key=muser.dataset_id_key 
                  AND conf.dataset_id_key=minterface.dataset_id_key 
                  AND muser.mart_user= \'$user\'";

	
    }
    else{
	$sql = "SELECT type, dataset, display_name, visible, version, interface, modified
                  FROM ".$schema.".meta_conf__dataset__main  conf,"
		  .$schema."."."meta_conf__interface__dm  minterface 
                  WHERE type IS NOT NULL
                  AND conf.dataset_id_key=minterface.dataset_id_key";    
    }


    $sql=$sql.$include_string;
    $sql .= " ORDER BY conf.dataset_id_key";
    my $sth = $dbh->prepare($sql);
    unless($sth) {
        my $err = $dbh->errstr;
        $dbh->disconnect;
        warn("\n\nWARNING: Could not fetch Configuration XML for ".
	     $self->displayName.": $err\nSKIPPING\n\n");
		BioMart::Exception::Database->throw("Could not fetch Configuration XML for : ".$self->displayName."  $err");  
	#return; 
    }
    
    my $executed = $sth->execute;
    
      unless ($executed) {
	  my $err = $dbh->errstr;
	  $sth->finish;
	  $dbh->disconnect;
	  warn("\n\nWARNING: Could not fetch Configuration XML for :".
	       $self->displayName." $err\nSKIPPING\n\n");
		BioMart::Exception::Database->throw("Could not fetch Configuration XML for : ".$self->displayName."  $err");  
		#return;
      }
        
    my @datasets;
    my $counter;
    my ($type,$dataset,$displayName,$visible,$version,
	$interfaces,$comma,$modified);
    
    while (my $tt=$sth->fetchrow_arrayref) {
	if (!$dataset || $tt->[1] ne $dataset){
	    if ($dataset){
		my %data = ('type'        => $type,
		    'dataset'     => $dataset,
		    'displayName' => $displayName,
		    'visible'     => $visible,
		    'version'     => $version,
		    'interfaces'   => $interfaces,
		    'modified'  => $modified);
		push (@datasets, \%data);
	    }
	    $type        = $tt->[0];
	    $dataset     = $tt->[1];
	    $displayName = $tt->[2],
	    $visible     = $tt->[3],
	    $version     = $tt->[4],
	    $interfaces  = $tt->[5];
	    $modified    = $tt->[6];
	    $comma = ',';
	}
	else{
	    $interfaces = $interfaces.$comma.$tt->[5];
	}
    }

    my %data = ('type'        => $type,
		    'dataset'     => $dataset,
		    'displayName' => $displayName,
		    'visible'     => $visible,
		    'version'     => $version,
		    'interfaces'   => $interfaces,
		    'modified'  => $modified);
    push (@datasets, \%data);  

    	
    $self->datasetNumber(scalar @datasets);

	$sth->finish;
	$sth1->finish;
	$self->dbhDC();    

    return @datasets;
}





1;
