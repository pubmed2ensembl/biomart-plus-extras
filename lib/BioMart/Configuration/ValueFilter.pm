# $Id: ValueFilter.pm,v 1.3.2.2 2009-11-06 01:30:46 syed Exp $
#
# BioMart module for BioMart::Configuration::ValueFilter
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::ValueFilter

=head1 SYNOPSIS

A Filter which represents one or more 'x op value' clauses in a
where clause, eg x = y, chr > 3, etc.

=head1 DESCRIPTION

A BioMart::Filter implementation that links represents one or more
'name' 'operation' 'value' where clauses connected by OR, where
value is taken from a particular row in the Table.  The Table
for a ValueFilter should consist of only one column.

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Darin London, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::ValueFilter;

# inherits from FilterBase, implements _toSQL

use strict;
use warnings;
use Digest::MD5;

use base qw(BioMart::Configuration::BaseFilter);

=head2 _new

  Usage      : see Usage for BioMart::Configuration::BaseFilter.
  Description: creates a new ValueFilter object which becomes associated
               with a single Attribute and AttributeTable (or ResultTable) 
               object and an operation specifier.  The Table is assumed to 
               consist of only one column of data.
  Returntype : BioMart::Configuration::ValueFilter
  Exceptions : none
  Caller     : general

=cut

sub _new {
  my ($self, @param) = @_;
  $self->SUPER::_new(@param);

  $self->attr('attribute', undef);
  $self->attr('attribute_table', undef);
  $self->attr('operation', undef);
  $self->attr('otherFilters', undef);
  $self->attr('regexp', undef);
  $self->attr('defaultValue', undef);
  $self->attr('sql', undef);
}


sub _init {
  my ($self, @param) = @_;

  $self->SUPER::_init(@param);

  my $proto = shift @param;

  # if the prototype table is set, take its reference
  # as you will not want to change the underlying data
  # most of the time FilterList objects will be copied
  # before their tables are set
  $self->attr('attribute_table', $proto->getTable);
  $self->attr('attribute', $proto->attribute);
  $self->attr('operation', $proto->operation);
  $self->attr('otherFilters', $proto->otherFilters);
  $self->attr('regexp', $proto->regexp);
  $self->attr('defaultValue', $proto->defaultValue);
  $self->attr('sql', undef);
}


# interface implementation

sub _toSQL {
# goes through each row of the table, adds 'OR' in between
  my ($self,$oracle) = @_;
  my $sql = $self->get('sql');
  if ($sql){
      return $sql;
  }
  else{
      $sql = '';
  }

  my $or = '';
  my @values;
  my $attribute_table = $self->get('attribute_table');
  my $attribute = $self->get('attribute');
  my $operation = $self->get('operation');
  my $temp; # holds a copy of a value for apostrohe substitution

  # may need to replace with an IN list for large tables
  # but can only do if not part of a FilterList 

  # loop over rows rather than fetching by nextRow so querys can
  # potentiall be reexecuted
  my $rows = $attribute_table->getRows();
  foreach my $row (@{$rows}){
  #while (my $row = $attribute_table->nextRow()){
      next unless (defined($$row[0]));#avoid NULL entries
      
	 $temp = $$row[0];
	 $temp =~ s/'/''/g; # substitute a ' with '' so it works on all platforms PG, ORACLE, MYSQL

	 if ($operation eq '='){
	  #push @values, $$row[0];
	  push @values, $temp;
      }
      else{
	$sql .= $or.$attribute->toSQL.' '.$operation.' \''.$temp.'\'';
	$or = ' OR ';
      }
  }

  if (!$sql && @values > 0){#need to generate an IN list
       if (@values > 1){
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
  
	       $sql = $attribute->toSQL.join( "OR ".$attribute->toSQL, 
					      @in_lists );
	   }
	   else{
	       my %saw;
	       $sql = $attribute->toSQL." IN('";
	       $sql .= join("','", grep(!$saw{$_}++, @values)) if (@values > 0);
	       $sql .= "')";
	   }
       }
       else{
	   $sql .= $attribute->toSQL.' '.$operation.' \''.$values[0].'\'';
       }
  }

  $sql = '('.$sql.')' if ($sql);#needs incase contains ORs and followed 
                                # by an AND
  $self->set('sql',$sql);
  return $sql;
}


# public methods

=head2 attribute

  Usage      :  my $att = $filt->attribute;  $filt->attribute($att);
  Description:  get/set method for the BioMart::Configuration::Attribute 
                object for this BooleanFilter
                This object represents the implementation specific location 
                of a data point on which to apply the filter.
  Returntype :  BioMart::Configuration::Attribute object
  Exceptions :  none
  Caller     :  caller

=cut

sub attribute {
# stores attribute
  my ($self, $attribute) = @_;
  if ($attribute){
    $self->set('attribute', $attribute);
    $self->set('sql',undef);
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

=head2 operation

  Usage      :  my $operation = $filt->operation; $filt->operation($op);
  Description:  get/set the operation to associate with the value filter
  Returntype :  scalar $op
  Exceptions :  none
  Caller     :  caller

=cut

sub operation {
  my ($self,$operation) = @_;

  if ($operation) {
    $self->set('operation',$operation);
    $self->set('sql',undef);
  }
  return $self->get('operation');
}

=head2 otherFilters

  Usage      :  my $otherFilters = $filt->otherFilters; 
                $filt->otherFilters($op);
  Description:  get/set the other filters to associate with the value filter
  Returntype :  scalar $otherFilters
  Exceptions :  none
  Caller     :  caller

=cut

sub otherFilters {
  my ($self,$otherFilters) = @_;

  if ($otherFilters) {
    $self->set('otherFilters',$otherFilters);
  }
  return $self->get('otherFilters');
}


=head2 regexp

  Usage      :  my $regexp = $filt->regexp; $filt->regexp($op);
  Description:  get/set the regexp to associate with the value filter
  Returntype :  scalar $regexp
  Exceptions :  none
  Caller     :  caller

=cut

sub regexp {
  my ($self,$regexp) = @_;

  if ($regexp) {
    $self->set('regexp',$regexp);
  }
  return $self->get('regexp');
}

=head2 defaultValue

  Usage      :  my $def = $filt->defaultValue; $filt->defaultValue($op);
  Description:  get/set the defaultValue to associate with the value filter
  Returntype :  scalar $defaultValue
  Exceptions :  none
  Caller     :  caller

=cut

sub defaultValue {
  my ($self,$defaultValue) = @_;

  if ($defaultValue) {
    $self->set('defaultValue',$defaultValue);
  }
  return $self->get('defaultValue');
}

=head2 setTable

  Usage      : set a BioMart::AttributeTable as the table
               $vfilt->setTable($attTable);

               set a BioMart::ResultTable as the table
               $vfilt->setTable($rTable);

  Description: stores a BioMart::AttributeTable or BioMart::ResultTable 
               object as the table to manipulate for toSQL.
  Returntype : none
  Exceptions : none
  Caller     : caller

=cut

sub setTable {
  my ($self,$attribute_table) = @_;
  
  $self->set('attribute_table',$attribute_table);
  $self->set('sql',undef);
}

=head2 getTable

  Usage        :  my $table = $vfilt->getTable;
  Description  :  get the BioMart::AttributeTable or BioMart::ResultTable 
                  object holding the data for this FilterList.
  Returntype   :  may be either a BioMart::AttributeTable, or a 
                  BioMart::ResultTable.
                  ResultTable objects can be manipulated as 
                  read-only AttributeTable objects.
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

  $digest->add($self->get('attribute')->hashCode) if ($self->get('attribute'));

  $digest->add($self->get('attribute_table')->hashCode) 
      if ($self->get('attribute_table'));

  $digest->add($self->get('operation')) if ($self->get('operation'));

  return $digest->hexdigest;
}

1;
