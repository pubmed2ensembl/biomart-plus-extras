#
# BioMart module for BioMart::ResultTable
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::ResultTable

=head1 SYNOPSIS

Provides access to the Results of a BioMart Query.

=head1 DESCRIPTION

The BioMart::ResultTable object provides access to the results of a Query
against a BioMart::DatasetI implementation.  Its API is an extension of the
BioMart::AttributeTable object. In addition to the BioMart::AttributeTable 
methods, it provides methods to get access to individual columns in a row by 
its index (zero-based). This represents two usage paradigms:
  A.  while ($rtable->hasMoreRows) {
       my $row = $rtable->nextRow;
       map { print } @{$row};
     }

  B. while ($rtable->next) {
       print $rtable->getFieldByIndex(0);
     }

It also provides the QueryRunner with methods to set its batching behavior. 
Basically, batching involves splitting the results of a single query returning 
a large number of rows into several queries for the same data sliced into more 
managable resultSets.  This is managed transparently to the user of the
BioMart::ResultTable object (although users might notice a slight delay between
some calls to next or next_row which are not experienced in other calls, when 
the system has to call for another batch of data from the underlying Dataset).

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Darin London, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut

package BioMart::ResultTable;
use strict;
use warnings;
use Digest::MD5;

use base qw(BioMart::AttributeTable);

use constant STEPSIZE => 2; ##double the batchsize after each batch request

use constant QUERY               => 'query';
use constant TARGETDATASET     => 'target_dataset';
use constant INITIAL_BATCHSIZE => 'initial_batchsize';
use constant MAX_BATCHSIZE     => 'max_batchsize';

use constant TITLES => [
                         QUERY,
                         TARGETDATASET,
                         INITIAL_BATCHSIZE,
                         MAX_BATCHSIZE
                       ];

=head2 _new

  Usage      : non-batching ResultTable:
                 my $rtable = 
                      BioMart::ResultTable->new('query' => $query,
						'target_dataset' => $subsys,
						'initial_batchsize' => 100,
						'max_batchsize' => 100000
						);

               batching ResultTable:
                 my $rtable = 
                      BioMart::ResultTable->new('query' => $query,
						'target_dataset' => $subsys,
						'initial_batchsize' => 100,
						'max_batchsize' => 100000,
						'batchResults' => 1
						);

  Description: Creates a new BioMart::ResultTable object.  This requires a 
               query, and the target dataset for the query. It also requires an
               initial batchsize, and maximum batchsize for the batching 
               system. ResultTable objects are created by BioMart::DatasetI 
               implementing objects.  User code should never need to create 
               these, but should use BioMart::QueryRunner to get a ResultTable
               object for a particular Query instead.
  Returntype : BioMart::ResultTable
  Exceptions : Invalid or missing required Parameters.
  Caller     : BioMart::QueryRunner

=cut

sub _new {
  my ($self, @param) = @_;
  $self->SUPER::_new(@param);
  $self->addParams(TITLES, @param);

  $self->checkRequiredParams(TITLES);
  $self->_checkValidParams;

  $self->attr('nextCalled', 0); # set to 1 when next is called
  $self->attr('rows_processed', 0);
  $self->attr('batch_size', $self->getParam(INITIAL_BATCHSIZE)); # this will increase over successive calls for batches
  $self->attr('exhausted', 0);
  $self->attr('webOrigin', undef);
#  $self->attr('hashedResults', undef);

  my $fieldIndex = {};
  my $query = $self->getParam(QUERY);
  my $attList = $query->getAllAttributes();
  my $index = 0;
  foreach my $attribute (@{$attList}) {
    $$fieldIndex{$attribute->name} = $index;
    $index++;
  }

  my $alists = $query->getAllAttributeLists();
  foreach my $alist (@{$alists}) {
    my $atts = $alist->getAllAttributes;
    foreach my $attribute (@{$atts}) {
	if (! defined $attribute) {
	    BioMart::Exception::Query->throw("returning undef ... missing attributes for your exportable? ");
	} 
	unless (exists $fieldIndex->{$attribute->name}) {
	    #exportable may have an attribute that was also requested by the 
	    # user - dont duplicate
	    $fieldIndex->{$attribute->name} = $index;
	    $index++;
	}
    }
  }

  $self->attr('fieldIndex' , $fieldIndex);
  $self->attr('numFields', $index);
  $self->attr('current_row', undef); #used by next related methods

  # a particular ResultTable created for a particular targetDataset
  # at a particular time should equal another ResultTable created for
  # the same targetDataset at the same time
  # note, this calls set on 'hc' because it is already set for AttributeTable 
  # at this time
  my $digest = Digest::MD5->new;
  $digest->add($self->getParam(TARGETDATASET)->name);
  $digest->add(scalar localtime);
  $self->set('hc', $digest->hexdigest);
}

#private methods

sub _checkValidParams {
  my $self = shift;

  my $query = $self->getParam(QUERY);
  unless ($query->isa("BioMart::Query")){
      BioMart::Exception::Query->throw("BioMart::ResultTable did not recieve a valid BioMart::Query parameter\nReceived object ".$query."\n");
  }

  my $tdataset = $self->getParam(TARGETDATASET);
  unless ($tdataset->isa("BioMart::DatasetI")) {
      BioMart::Exception::Query->throw("BioMart::ResultTable did not recieve a valid BioMart::DatasetI parameter\nReceived object ".$tdataset."\n");
  }
}

sub _getBatch {
  my $self = shift;

  my $tdataset = $self->getParam(TARGETDATASET);

  my %qparams = ();
  $qparams{'query'} = $self->getParam(QUERY);

  # ResultTable always assumes batching. It will get undef from the underlying
  # Dataset if the Query is exhausted.
  
  # start 1 after the last processed row
  my $bstart = $self->get('rows_processed');
  my $bsize = $self->get('batch_size');
  $qparams{'batch_start'} = $bstart;
  $qparams{'batch_size'} = $bsize;

  $qparams{'table'} = $self;
  my $hasData = $tdataset->getResultTable(%qparams);

  # Dataset will return undef if it has exhausted its query, A Dataset may now 
  # return an empty ResultTable, but not be exhausted(Eg. Dataset now 
  # explicitly determines when it is exhausted, not ResultTable.
  $self->_setExhausted unless ($hasData);

  #increase step if this batch has data and more to come
  if($hasData && $self->SUPER::hasMoreRows) {
     $bsize *= STEPSIZE;
     $bsize = $self->getParam(MAX_BATCHSIZE) if $bsize > $self->getParam(MAX_BATCHSIZE);
  }

  $self->set('batch_size', $bsize);
}

sub _setExhausted {
    my $self = shift;

    $self->set('exhausted',1);
}


# BioMart::AttributeTable API methods

=head2 hasMoreRows

  Usage       :  if ($rtable->hasMoreRows) { .... }
  Description :  allows user to determine if a ResultTable has more rows to 
                 process.
  Returntype  :  boolean, 1 if there are more rows to process, 0 otherwise
  Exceptions  :  See Exceptions for the getResultTable method of
                 BioMart::DatasetI, and its implementations.
  Caller      :  caller

=cut

sub hasMoreRows {
  my $self = shift;

  my $tdataset = $self->getParam(TARGETDATASET);

  if ($self->get('exhausted')) {
      return 0;
  } 
  elsif ( $self->SUPER::hasMoreRows ) {
      return 1;
  } 
  elsif ($self->webOrigin){
      return 0;
  } 
  else {
      $self->_getBatch;
      return $self->hasMoreRows;
  }
}

#needs to increment its batch_size before returning the nextRow
sub nextRow {
  my $self = shift;

  my $ret = $self->SUPER::nextRow;

  if ($ret) {
      my $rows_processed = $self->get('rows_processed');
      $rows_processed++;
      $self->set('rows_processed', $rows_processed);
  }
  
  return $ret;
}

# extension methods

=head2 inCurrentBatch

  Usage        :  if ($rtable->inCurrentBatch()) { ... }  
                  while ($rtable->inCurrentBatch && 
			 $rtable->hasMoreRows) { ... }
  Description  :  determine if the ResultTable has rows available from the 
                  current batch as called from its underlying DataSet object.
  ReturnType   :  boolean, true if rows remain in the current batch, false if 
                  the next call to next or next_row would result in a call to 
                  the underlying Dataset for another batch.
  Exceptions   :  none
  Caller       :  BioMart::DatasetI implementations

=cut

sub inCurrentBatch {
  my $self = shift;

  return $self->SUPER::hasMoreRows;
}


=head2 useExportableFieldIndex


 Description  :  instructs the resultTable to reset its index
                 values to reflect that it is being used as an Importable.
                 After this is set, only fields that were exported by the 
                 target_subsytem of this ResultTable object are reflected in 
                 the field indexing system.  Needed by any Dataset 
                 implementation needing to merge data.

=cut

 sub useExportableFieldIndex {
   my $self = shift;

   my $fieldIndex = {};
   my $query = $self->getParam(QUERY);
   my $tdataset = $self->getParam(TARGETDATASET);
   my $tdatasetname = $tdataset->name;
   my $attList = $query->getAllAttributes($tdatasetname);
   my $index = 0;
   foreach my $attribute (@{$attList}) {
     $$fieldIndex{$attribute->name} = $index;
     $index++;
   }

   my $alists = $query->getAllAttributeLists($tdatasetname);
   foreach my $alist (@{$alists}) {
     my $atts = $alist->getAllAttributes;
     foreach my $attribute (@{$atts}) {
       unless (exists $fieldIndex->{$attribute->name}) {
         # exportable may have an attribute that was also requested by the user
         # dont duplicate
         $fieldIndex->{$attribute->name} = $index;
         $index++;
       }
       }
   }
   $self->set('fieldIndex' , $fieldIndex);
   $self->set('numFields', $index);
 }

=head2 next

  Usage       :  $rtable->next;
                 while ($rtable->next) { ... }
  Description :  increments the row of the ResultSet.  If the ResultSet is 
                 exhausted, this will return 0, and calls to getFieldByXXX will
                 return undef.
                 Users can avoid problems associated with this by using next 
                 in a while loop.
  Returntype  :  boolean, 0 if resultSet is exhausted, 1 otherwise
  Exceptions  :  See Exceptions for the getResultTable method of
                 BioMart::DatasetI, and its implementations.
  Caller      :  caller

=cut

sub next {
  my $self = shift;
  $self->set('nextCalled', 1);
  if ($self->hasMoreRows) {
    $self->set('current_row', $self->nextRow);
    return 1;
  }
  $self->set('current_row', undef);
  return 0;
}

=head2 getFieldByIndex

  Usage       :  my $field = $rtable->getFieldByIndex($index);
  Description :  Returns the field at index $index (zero-based) in the current
                 row of the ResultTable.  If this ResultTable is exhausted, 
                 this will return undef.
  Returntype  :  scalar $field.  May be undef if the ResultTable is exhausted.
  Exceptions  :  Throws an Exception if this method is called without a 
                 previous call to next.  Also, see Exceptions for the 
                 getResultTable method of BioMart::DatasetI, and its 
                 implementations.
  Caller      :  caller

=cut

sub getFieldByIndex {
  my ($self, $index) = @_;

  unless ($self->get('nextCalled')) {
    BioMart::Exception::Query->throw("ResultTable getFieldByXXX methods must be prefaced with a call to ResultTable next\n");
  }

  my $curRow = $self->get('current_row');
  if ($curRow) {
    return $curRow->[$index];
  }
  return undef;
}

sub getNumFields {
    my $self = shift;

    return $self->get('numFields');
}

sub webOrigin {
    my ($self,$value) = @_;
 
   if ($value){
	$self->set('webOrigin',$value);
    }
    return $self->get('webOrigin');
}

#sub hashedResults {
#    my ($self,$value) = @_;
#
#    if ($value){
#	$self->set('hashedResults',$value);
#    }
#    return $self->get('hashedResults');
#}

sub _hashCode {
  my $self = shift;
 
  return $self->get('hc');
}

#sub DESTROY {
#  my $self = shift;
#
#  my $tdataset = $self->getParam(TARGETDATASET);
#  if ($tdataset) {
#      #warn("for dataset ".$tdataset->name."\n");
#  } else {
#      #warn("for undefined dataset\n");
#  }
#}

1;
