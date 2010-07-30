#
# BioMart module for BioMart::Dataset::GenomicRegion::DNAAdaptor
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Dataset::GenomicSequence::DNAAdaptor.pm

=head1 SYNOPSIS

=head1 DESCRIPTION


=head1 AUTHOR Darin London, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut

package BioMart::Dataset::GenomicSequence::DNAAdaptor;

use strict;
use warnings;
use DBI;
use base qw(BioMart::Root);
use Log::Log4perl;
my $logger=Log::Log4perl->get_logger(__PACKAGE__);

use constant SEQNAME => "seq_name";
use constant SEQTABLENAME => "dna_tablename";
use constant SEQFIELDNAME => "seq_fieldname";
use constant CHUNKNAMEFIELD => "chunk_name_fieldname";
use constant CHUNKSTARTFIELD => "chunk_start_fieldname";
use constant CONF => "configurator";
use constant CHUNKSIZE => "chunk_size";

use constant TITLES => [
                        SEQNAME,
                        SEQTABLENAME,
                        SEQFIELDNAME,
                        CHUNKNAMEFIELD,
                        CHUNKSTARTFIELD,
                        CONF,
                        CHUNKSIZE
                      ];

use constant SQLFULL => "select %s from %s where %s = ? and %s = ?";

use constant SQLSUB  => "select substring(%s, ?, ?) from %s where %s = ? and %s = ?";
use constant SQLSUBORACLE  => "select substr(%s, ?, ?) from %s where %s = ? and %s = ?";

=head2 _new

  Usage        :  my $dna = BioMart::Dataset::GenomicSequence::DNAAdaptor->
                        new("seq_name" => $name,
                            "dna_tablename" => $dnatablename,
                            "seq_fieldname" => $seqfieldname,
                            "chunk_name_fieldname" => $chunkfieldname,
                            "chunk_start_fieldname" => $chunk_start_fieldname,
                            "configurator" => $conf,
                            "chunk_size" => 10
                            );

  Description  :  creates a DNAAdaptor, for retrieving dna sequence. Requires 
                  a name, which maps to a mart sequence database, the name of 
                  the dna table within the database(eg, dna_chunks in ensembl)
                  , and the names of that tables sequence, chunkname, and 
                  chunk_start fields (eg, sequence, chr_name, chr_start in 
                  ensmbl),  a BioMart::Configurator object, and the dna chunk 
                  size.
  Returntype   :  BioMart::Dataset::GenomicSequence::DNAAdaptor object. Meant 
                  for use by the BioMart::Dataset::GenomicSequence object.
  Exceptions   :  Missing or invalid params
  Caller       :  BioMart::Dataset::GenomicSequence

=cut

sub _new {
    my ($self, @param) = @_;

    $self->SUPER::_new(@param);
    
    $self->addParams(TITLES, @param);
    $self->checkRequiredParams(TITLES);
    
    $self->attr('fullSth', undef);
    $self->attr('subSth', undef);
    $self->attr('dbh', undef);
    
    $self->_initialize;
}

#private methods

sub _initialize {
    my $self = shift;
    
    #connect to the sequence mart
    my $dbname = $self->getParam(SEQNAME);

    my $location=$self->getParam(CONF)->get('location');
    $location->openConnection();

    my $dbh = $location->dbh();
  
    if ($self->getParam('configurator')->get('location')->databaseType 
        eq 'oracle'){
        $dbh->{LongReadLen} = 2**25;
    }

    $self->throw("Could not connect to sequence db $dbname ".DBI::errstr."!\n")
        unless ($dbh);
  
    my $fullSQL = sprintf(SQLFULL, 
                          $self->getParam(SEQFIELDNAME), 
                          $self->getParam(SEQTABLENAME), 
                          $self->getParam(CHUNKSTARTFIELD), 
                          $self->getParam(CHUNKNAMEFIELD));
    my $subSQL;
    if ($self->getParam('configurator')->get('location')->databaseType 
        eq 'oracle'){
        $subSQL = sprintf(SQLSUBORACLE, 
                          $self->getParam(SEQFIELDNAME), 
                          $self->getParam(SEQTABLENAME), 
                          $self->getParam(CHUNKSTARTFIELD), 
                          $self->getParam(CHUNKNAMEFIELD));
    }
    else{
        $subSQL = sprintf(SQLSUB, 
                          $self->getParam(SEQFIELDNAME), 
                          $self->getParam(SEQTABLENAME), 
                          $self->getParam(CHUNKSTARTFIELD), 
                          $self->getParam(CHUNKNAMEFIELD));
    }
  
    my $fullSth = $dbh->prepare($fullSQL) or 
        $self->throw("Couldnt prepare fullSQL ".$dbh->errstr."!\n");
    my $subSth = $dbh->prepare($subSQL) or 
        $self->throw("Couldnt prepare subSQL ".$dbh->errstr."!\n");

    #my $logger=Log::Log4perl->get_logger(__PACKAGE__);
    #$logger->info("QUERY FULL SQL:  $fullSQL");
    #$logger->info("QUERY SUB SQL:  $subSQL");

    $self->set('fullSth', $fullSth);
    $self->set('subSth', $subSth);
    $self->set('dbh', $dbh);
}

sub _Npad{
    my ($self, $num)= @_;

    my $ret = '';
    my $i = 0;
    while ($i < $num) {
      $ret .= 'N';
      $i++;
    }
 
    return $ret;
}

sub _fetchSequence {
    my ($self, $chr, $start, $len) = @_;
    
    my $chunkSize = $self->getParam(CHUNKSIZE);
    my $chunkStart = $start - ( ( $start - 1 ) % $chunkSize );

    if ($start == $chunkStart && $len == $chunkSize) {
        return $self->_fetchFullChunk($chr, $chunkStart);
    }
    return $self->_fetchChunkSubstring($chr, $start, $chunkStart, $len);
}

sub _fetchFullChunk {
    my ($self, $chr, $chunkStart) = @_;
    
    my $sth = $self->get('fullSth');
    my $sql_statement = $sth->{Statement};
    $sql_statement =~ s/\?/$_/ foreach ("\"$chunkStart\"", "\"$chr\"");
    $logger->info("QUERY FULL SQL: $sql_statement\;");
    $sth->execute($chunkStart, $chr);
 
    my $ret = $sth->fetchrow;
    
    $sth->finish;
    $self->set('fullSth', $sth);
    return $ret;
}

sub _fetchChunkSubstring {
    my ($self, $chr, $start, $chunkStart, $len) = @_;
    
    my $coord = $start - $chunkStart + 1;
    my $sth = $self->get('subSth');
    my $sql_statement = $sth->{Statement};
    $sql_statement =~ s/\?/$_/ foreach ("\"$coord\"", "\"$len\"", "\"$chunkStart\"", "\"$chr\"");
    $logger->info("QUERY SUBSTRING SQL: $sql_statement\;");
    $sth->execute($coord, $len, $chunkStart, $chr);
    
    my $ret = $sth->fetchrow;
    $sth->finish;
    $self->set('subSth', $sth);
    return $ret;
}

sub _fetchResidualSequence {
    my ($self, $chr, $start, $len, $initialSeq) = @_;

    my $currentLength = length(${$initialSeq});
    my $currentStart = $start + $currentLength;

    while ($currentLength < $len) {
        my $residual = $len - $currentLength;
        my $curr = $self->_fetchSequence($chr, $currentStart, $residual);

        my $currLength = length($curr);
        last if ($currLength < 1);

        ${$initialSeq} .= $curr;
        $currentLength += $currLength;
        $currentStart = $start + $currentLength;
    }
}

# interface methods

#override Root::throw to close before throw
sub throw {
    my ($self, $message) = @_;
    $self->close;
    
    $self->SUPER::throw($message);
}

#public methods

=head2 getSequence

  Usage        :  my $seq = $dna->getSequence($chunk_name, $start, $end);
  Description  :  gets the dna sequence at a particular genomic location
                  chunk_name corresponds to the value that would occur in the
                  chunk_name_fieldname field passed to the constructor for 
                  DNAAdaptor (eg. the value of chr_name in ensembl). 
                  start corresonds to the value in the chunk_start_fieldname 
                  field passed to the constructor (eg. the value of 
                  chr_start in ensembl). 
  Returntype   :  scalar $seq
  Exceptions   :  none
  Caller       :  BioMart::SubSequence::GenomicSequence

=cut

sub getSequence {
    my ($self, $chr, $start, $end) = @_;

    my $len = ($end - $start) + 1;

    my $ret = $self->_fetchSequence($chr, $start, $len);

    my $seqLen = 0;
    
    if ($ret) {
        $seqLen = length($ret);
    }

    unless ($seqLen) {
    $logger->info("Padding with Ns");
        return $self->_Npad($len);
    }

    if ($seqLen < $len) {
        #in place modification of reference $ret
	$self->_fetchResidualSequence($chr, $start, $len, \$ret);
    }

    return $ret;
}

=head2 close

    Usage        :  $dna->close;
    Description  :  closes all DBI resources involved with fetching sequences.
                    To be called by the sequence parser when it has exhausted 
                    its resultSet for the given query.
    Returntype   :  none
    Exceptions   :  none
    Caller       :  sequence parser module

=cut

sub close {
    my $self = shift;

    my $dbh = $self->get('dbh');

    if ($dbh) {
        my $fullSth = $self->get('fullSth');
        my $subSth = $self->get('subSth');

        if ($fullSth) {
            $fullSth->finish;
        }

        if ($subSth) {
            $subSth->finish;
        }
        $dbh->disconnect;
    }
}

sub DESTROY {
        my $self = shift;
        $self->close;
}

1;

