#
# BioMart module for BioMart::AttributeTable
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::AttributeTable

=head1 SYNOPSIS

AttributeTables provide access to one or more rows of attribute values, each 
containing one or more columns.  They are used as placeholders for filters, 
and BioMart::ResultTable objects inherit their functionality, and extend them.

=head1 DESCRIPTION

An AttributeTable object contains a table of data in rows and columns (the 
minimal table being 1 X 1).  It can be used in a variety of contexts within 
the BioMart system.
It can be set as the value in a BioMart::Configuration::ValueFilter or
BioMart::Configuration::FilterList object to be used in a Query against a 
dataset. BioMart::ResultTable objects inherit all functionality from 
BioMart::AttributeTable, and extends it.
It basically presents a FIFO stack of array_ref objects.  Adding a row pushes 
this onto the stack, increasing its size by 1.  Getting a row shifts an 
array_ref from the stack, decreasing its size by 1.  Thus, it is possible for 
an AttributeTable to be exhausted, whereby the next call to getRow will return 
null. This can be avoided by prefacing each call to next_row with a call to 
hasMoreRows.

=head1 AUTHOR - Arek Kasprzyk, Syed Haider, Darin London, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::AttributeTable;

use strict;
use warnings;
use Digest::MD5;

use base qw(BioMart::Root);

=head2 _new

  Usage      : my $attTable = BioMart::AttributeTable->new();
  Description: creates a new AttributeTable object.
  Returntype : BioMart::Configuration::AttributeTable
  Exceptions : none
  Caller     : general

=cut

sub _new {
  my ($self, @param) = @_;

  $self->SUPER::_new(@param);
  $self->attr('columns', []);
  $self->attr('hashedResults', undef);
  #the hashCode for an AttributeTable is
  #the digest of its creation time.
  my $digest = Digest::MD5->new;
  $digest->add(scalar localtime);
  $self->attr('hc', $digest->hexdigest);
}


=head2 addRow

  Usage      : $attTable->addRow($row);
  Description: adds a row (array_ref) of data to the AttributeTable.
               Note, values from array_ref are harvested to avoid
               unintended reference operations.
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut


sub addRow {
  my ($self,$row) = @_;

  my $columns = $self->get('columns');
  push @{$columns}, [ @{ $row } ];
  $self->set('columns',$columns);#so hash code updated
}

sub getRows {

  my $self = shift;
  return $self->get('columns');
}

sub setRows {
  my ($self,$rows) = @_;

  $self->set('columns',$rows);
}

sub hashedResults {
    my ($self,$value) = @_;

    if ($value){
	$self->set('hashedResults',$value);
    }
    return $self->get('hashedResults');
}

sub addRows {
  my ($self,$rows) = @_;

  my $columns = $self->get('columns');
  push @{$columns}, @{ $rows };
  $self->set('columns',$columns);#so hash code updated
}


=head2 hasMoreRows

  Usage      : if ($table->hasMoreRows) { ... }
  Descripton : Determine if an AttributeTable has rows remaining to be 
               processed.
               Note that the return for this method is currently the number of
               rows remaining, but this may change in the future.
  Returntype : boolean, >1 (true) if there are more rows, 0 (false) otherwise
  Exceptions : none
  Caller     : caller

=cut

sub hasMoreRows {
  my $self = shift;

  my $columns = $self->get('columns');

  my $ret = @{$columns};
  return $ret;
}

=head2 nextRow
  
  Usage      : my $row = $attTable->nextRow;  foreach my $col (@{$row}) { ... }
  Description: returns a reference to the next row of data.
  Returntype : array_ref. This returns null if the table is exhausted
               Problems associated with this can be avoided by prefacing
               each call to nextRow with a test of hasMoreRows.
  Exceptions : none
  Caller     : caller

=cut


sub nextRow {
  my $self = shift;

  if ($self->hasMoreRows) {
    my $columns = $self->get('columns');
    my $rowref = shift @{$columns};
    $self->set('columns', $columns);
    return $rowref;
  }
  return undef;
}


#this is set at creation and never changed
sub _hashCode {
  my $self = shift;

  return $self->get('hc');
}

1;



