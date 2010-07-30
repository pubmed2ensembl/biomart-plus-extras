# $Id: FilterList_List.pm,v 1.3.2.3 2009-11-06 01:30:46 syed Exp $
#
# BioMart module for BioMart::Configuration::FilterList_List
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::FilterList_List

=head1 SYNOPSIS

Stores an array of filter objects and a table to be manipulated in those 
filter objects.

=head1 DESCRIPTION

Stores an array of filter objects, and an BioMart::AttributeTable 
(or BioMart::ResultTable) with data to represent these filters. The default 
way to handle this mapping of datai n the tree to filters in the filter list 
is represented by the toSQL method, but this can be overridden by any given 
Dataset.  FilterList objects are used as Importables which can link the 
ResultTable from an Exporting Dataset with a particular Importing Dataset 
based on the link name.  The name of the Link representing the 
exportable<->importable relationship between the two datasets can be 
retrieved from a FilterList using its linkName.

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::FilterList_List;

# inherits from FilterBase, implements toSQL

use strict;
use warnings;
use Digest::MD5;
use Carp;
use Data::Dumper;

use base qw(BioMart::Configuration::BaseFilter);

use constant LINKNAME => "linkName";
use constant LINKVERSION => "linkVersion";
use constant FILTERSTRING => "filter_string";


use constant TITLES => [ LINKNAME,
                         LINKVERSION,
                         FILTERSTRING,
                         ];


=head2 _new

  Usage      : minimal (use the setter methods to set the name, dataSetName,
               and linkName):
               my $flist = BioMart::Configuration::FilterList_List->new();

               with name, and dataSetName:
               my $flist = BioMart::Configuration::FilterList_List->new(
                                   'name' => $name,
                                   'dataSetName' => $subName
								   );
               to be used as a Link Importable:
               my $flist = BioMart::Configuration::FilterList_List->new(
                                    'name' => $name,
                                    'dataSetName' => $subName,
                                    'linkName'  => $linkName
								   );

  Description: creates a new FilterList_List object capable of storing an
               array of Filter objects, and a Table to hold the data 
               to apply to these Filter objects.
  Returntype : BioMart::Configuration::FilterList_List
  Exceptions : none
  Caller     : general

=cut

sub _new {
  my ($self, @param) = @_;
  $self->SUPER::_new(@param);

  $self->addParams(TITLES, @param);
  $self->attr('filters', []);
  $self->attr('attribute_table', undef);
  $self->attr('exhausted', undef);
  $self->attr('batching', undef);
}

# interface implementation

sub _init {
  my ($self, @param) = @_;

  $self->SUPER::_init(@param);
  

  my $proto = shift @param;

  #until we implement _init in all objects this wont work.
  my $protoFilters = $proto->getAllFilters;
  my $newFilters = [];
  foreach my $filt (@{$protoFilters}) {
    push @{$newFilters}, $filt->new;
  }
  $self->attr('filters', $newFilters);

  # if the prototype table is set, take its reference
  # as you will not want to change the underlying data
  # most of the time FilterList objects will be copied
  # before their tables are set
  $self->attr('attribute_table', $proto->getTable);

  $self->attr('batching', $proto->batching);
  $self->attr('exhausted', $proto->exhausted);
  $self->attr('sql', undef);
}

sub _toSQL {

  my ($self,$oracle) = @_;

  my ($sql, $subsql, $and, $or, @values);
  my $filts = $self->get('filters');
  my @filters = @$filts;
  my $attribute_table = $self->get('attribute_table');

  my $i = 0;
  $or = '';

  my $rows_avail = $attribute_table->hasMoreRows();
  while ($rows_avail && $self->_inBatch($attribute_table)){
      my $row = $attribute_table->nextRow();
      $i = 0;
      $subsql = '';
      $and = '';

			my @cols = split (/\:/, $row->[0]);
			# my $logger=Log::Log4perl->get_logger(__PACKAGE__);
 			# $logger->warn("\ncols: @cols");
      
      foreach my $col (@cols){
	  		if ((scalar(@cols) == 1) && ($filters[$i]->operation eq '=')){
	  		#    	push @values,$col;
       				for (my $h=0; $h < scalar(@filters); $h++) {
					my $subatt_table = BioMart::AttributeTable->new();
                        		my $aref = [$col];
                			$subatt_table->addRow($aref);
            				if (!defined $filters[$i]){
                                       	BioMart::Exception::Configuration->throw ("returning undef ... missing filters from your importable?");
                			}
            				$filters[$i]->setTable($subatt_table);
                			$subsql .= $and.$filters[$i]->toSQL;
                			$and = ' OR ';
                			$i++;
				}

			}
	  		else{

	     	 	my $subatt_table = BioMart::AttributeTable->new();
	     	 	my $aref = [$col];
	      	$subatt_table->addRow($aref);
            if (!defined $filters[$i]){
		  			BioMart::Exception::Configuration->throw ("returning undef ... missing filters from your importable?");
	      	}              
            $filters[$i]->setTable($subatt_table);
	      	$subsql .= $and.$filters[$i]->toSQL;
	      	$and = ' AND ';
	      	$i++;
	  		}
      }

      next unless ($subsql);#avoids NULL value warnings
      $sql .= $or.'('.$subsql.')';
      $or = ' OR ';
  }

  $self->set('exhausted', 1) unless ($rows_avail);

  if (!$sql){#need to generate an IN list
      foreach (@values) {
	  $_ =~ s/'/''/g if ($_); # subsitituting single ' with two '' to overcome SQL issues on ORACLE, mySQL, PG
      }
      if ($oracle){
          #will hold stringified sublists
          my @in_lists;

          #remove duplicates from @values for performance reasons
          my %saw;
          my @values = grep (!$saw{$_}++, @values);

          #quote each value
          @values = map{ "'".$_."'" } @values;
    
          #create sublists of 1000 or less elements using 'splice'
          while (@values) {
              my @sublist = grep{ $_ } splice (@values, 0, 999);
              push @in_lists, join(",",@sublist);             
          }

          #now, create multiple IN clauses and join them together
          @in_lists = map { " IN(".$_.")\n" } @in_lists;
	  if (@in_lists > 0){
	      $sql = $filters[$i]->attribute->toSQL.join( "OR ".
			$filters[$i]->attribute->toSQL, @in_lists );
	  }
	  else{
	      $sql = $filters[$i]->attribute->toSQL." IN('')";
	  }
      }

      else{
	  my %saw;
	  $sql = $filters[$i]->attribute->toSQL." IN('";
	  $sql .= join("','", grep(!$saw{$_}++, @values)) if (@values > 0);
	  $sql .= "')";
      }
  }
  
  return '('.$sql.')';
}

sub _inBatch {
  my ($self, $attribute_table) = @_;

  #always true if underlying table is an AttributeTable and it has rows
  my $inBatch = ($attribute_table->isa("BioMart::ResultTable")) 
                 ? $attribute_table->inCurrentBatch() 
                 : $attribute_table->hasMoreRows;
  return $inBatch;
}


# public methods

=head2 batching

  Usage        :  $filt->batching(1);  if ($filt->batching) { }
  Description  :  Determine if this is a batching filter, or instruct it 
                  that it is a batching filter.
  Returntype   :  boolean, true if this is a batching filter, false otherwise
  Exceptions   :  na
  Caller       :  BioMart::DatasetI implementations.


=cut

sub batching {
  my ($self, $batching) = @_;

  if ($batching) {
    $self->set('batching', $batching);
  }

  return $self->get('batching');
}


=head2 exhausted

  Usage        :  unless ($filter->exhausted) { .. }
  Description  :  determine if this FilterList is exhausted (eg, 
                  its underlying table is exhausted).
  Returntype   :  boolean, true if a table has been set on the FilterList, 
                  and it is exhausted, false otherwise
  Exceptions   :  none
  Caller       :  BioMart::DatasetI

=cut

sub exhausted {
  my $self = shift;
  return $self->get('exhausted');
}

=head2 linkName

Usage        :  my $linkName = $flist->linkName; $flist->linkName($newName);
Description  :  set/get the linkName for this FilterList, if it is used
                as an Importable.  This method is intended for use only by
                the BioMart::QueryRunner, or a BioMart::DatasetI implementing 
                object.
Returntype   :  scalar $linkName
Exceptions   :  none
Caller       :  BioMart::QueryRunner, or a BioMart::DatasetI implementing 
                object.

=cut

sub linkName {
  my ($self, $name) = @_;
  if ($name) {
    $self->setParam(LINKNAME, $name);
  }
  return $self->getParam(LINKNAME);
}

=head2 linkVersion

Usage        :  my $linkVersion = $flist->linkVersion; 
                $flist->linkVersion($newName);
Description  :  set/get the linkVersion for this FilterList, if it is used
                as an Importable.  This method is intended for use only by
                the BioMart::QueryRunner, or a BioMart::DatasetI implementing 
                object.
Returntype   :  scalar $linkVersion
Exceptions   :  none
Caller       :  BioMart::QueryRunner, or a BioMart::DatasetI implementing 
                object.

=cut

sub linkVersion {
  my ($self, $name) = @_;
  if ($name) {
    $self->setParam(LINKVERSION, $name);
  }
  return $self->getParam(LINKVERSION);
}



=head2 addFilter

  Usage      : $flist->addFilter($filter);
  Description: adds a BioMart::BaseFilter implementing object to the 
               FilterList, maintaining the order of addition.
  Returntype : none
  Exceptions : none
  Caller     : caller
=cut

sub addFilter {

# add Filter to an array of filters
  my ($self, $filter) = @_;

  my $filters = $self->get('filters');
  push @{$filters}, $filter;
  $self->set('filters',$filters);
}

=head2 getAllFilters

Usage        :  my $filts = $flist->getAllFilters; 
                foreach my $filt (@{$filts}) { ... }
Description  :  returns an array_ref containing all 
                BioMart::Configuration::BaseFilter implementing objects added
                to this FilterList using the addFilter method.  Intended
                for use by BioMart::DatasetI implementations to override 
                the base toSQL functionality.
Returntype   :  array_ref of BioMart::Configuration::BaseFilter implementing 
                objects.
Exceptions   :  none
Caller       :  BioMart::DatasetI implementing objects.

=cut

sub getAllFilters {
  my $self = shift;
  return $self->get('filters');
}

=head2 filterString

  Usage        :  my $filterString = $flist->fitlerString; 
                  $flist->filterString($newFiltString);
  Description  :  get/set the filterString of this BioMart::FilterList 
                  object.
  Returntype   :  scalar $filterString
  Exceptions   :  none
  Caller       :  caller

=cut

sub filterString {
  my ($self, $name) = @_;
  if ($name) {
    $self->setParam(FILTERSTRING, $name);
  }
  return $self->getParam(FILTERSTRING);
}


=head2 setTable

  Usage      : set a BioMart::AttributeTable as the table
               $flist->setTable($attTable);

               set a BioMart::ResultTable as the table
               $flist->setTable($rTable);

  Description: stores a BioMart::AttributeTable or BioMart::ResultTable 
               object as the table to manipulate for toSQL.
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut

sub setTable {
  my ($self,$attribute_table) = @_;

  if ($attribute_table && $attribute_table->isa("BioMart::ResultTable")) {
    #instructs the ResultTable to use its exportable indices
    #instead of the global query indices.
    $attribute_table->useExportableFieldIndex;
  }

  $self->set('attribute_table',$attribute_table);
}


=head2 getTable

  Usage        :  my $table = $flist->getTable;
  Description  :  get the BioMart::AttributeTable or BioMart::ResultTable 
                  object holding the data for this FilterList.
  Returntype   :  may be either a BioMart::AttributeTable, or a 
                  BioMart::ResultTable.
                  ResultTable objects can be manipulated as read-only 
                  AttributeTable objects.
                  This is intended to be used by a BioMart::DatasetI 
                  implementation to override the default toSQL method.
  Exceptions   :  none
  Caller       :  caller

=cut

sub getTable {
  my $self = shift;
  return $self->get('attribute_table');
}


sub _hashCode {
  my $self = shift;

  my $digest = Digest::MD5->new;
  $digest->add($self->SUPER::_hashCode);
  $digest->add($self->linkName) if ($self->linkName);

  my $fils =   $self->get('filters');
  foreach my $filt (@{$fils}) {
    $digest->add($filt->hashCode);
  }

  $digest->add($self->get('attribute_table')->hashCode)
      if ($self->get('attribute_table'));

  return $digest->hexdigest;
}

1;
