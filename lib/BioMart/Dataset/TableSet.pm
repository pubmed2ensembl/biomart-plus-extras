# $Id: TableSet.pm,v 1.8.2.2 2009-07-24 08:05:04 syed Exp $
#
# BioMart module for BioMart::Dataset::TableSet
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Dataset::TableSet

=head1 SYNOPSIS

Synopsis here

=head1 DESCRIPTION

Description here

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Darin London, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut
 

package BioMart::Dataset::TableSet;
# implements Dataset interface

use strict;
use warnings;
use Digest::MD5;
use IO::Handle;
use Log::Log4perl;

# temporary imports until XML configuration system is working

use BioMart::Configuration::ConfigurationTree;
use BioMart::Configuration::FilterTree;
use BioMart::Configuration::AttributeTree;
use BioMart::Configuration::FilterCollection;
use BioMart::Configuration::AttributeCollection;
use BioMart::Configuration::FilterGroup;
use BioMart::Configuration::AttributeGroup;
use BioMart::Configuration::BooleanFilter;
use BioMart::Configuration::ValueFilter;
use BioMart::Configuration::Attribute;

use base qw(BioMart::DatasetI);

use constant REPLACEBFILTER => '@@BATCHFILTER@@';
use constant REPLACELIMIT => '@@LIMITCLAUSE@@';


sub _new {

# called by configurator which passes itself in as a reference along with
#  the dataSet internal name and displayName

  my ($self, @param) = @_;
  $self->SUPER::_new(@param);

  $self->attr('mains',[]);
  $self->attr('keys',[]);
  $self->attr('batch_size', 0);
  $self->attr('batched_filterlist', undef);
  $self->attr('sql', undef);
  $self->attr('batch_filterSQL', undef);

  # for batching_filterlist queries, TableSet must
  # maintain its own batch_starts relative to
  # each list of items from the batching_filterlist
  $self->attr('batch_rows_processed', 0);



}

# private methods






sub __processNewQuery {
  my ($self, $query) = @_;

  #ignores query
  $self->set('batched_filterlist', undef);
  $self->set('sql', undef);
  $self->set('batch_filterSQL', undef);
  $self->set('batch_rows_processed', 0);
}


# Interface Implementations

sub _getConfigurationTree {
    my ($self,$interface,$dsCounter)=@_;

    return $self->getParam('configurator')->getConfigurationTree(
		     $self->virtualSchema, $self->name, $interface,$dsCounter);
}

sub _getResultTable {

  my ($self, @param) = @_;
  local($^W) = 0;  # prevent "odd number of elements" warning with -w.
  my(%param) = @param;
  my $table = $param{'table'};
  my $query = $param{'query'};
  my $batch_start = $param{'batch_start'} || 0;
  my $batch_size = $param{'batch_size'};
  
  my $rows_added = $self->_fillAttributeTableWith($query, $table, 
						  $batch_start,$batch_size);

  # System will run entire query in one call if they do not contain an 
  # importable, and are not explicitly called to batch with a batch_size 
  # parameter to getResultTable.
  $self->_setExhausted(1) unless ($self->get('explicit_batching') || 
				  $self->get('batched_filterlist'));

  if ($rows_added < 1) {
      if ($self->get('explicit_batching')) {
	  # if explicit_batching, this is a SQL batching query, which
	  # must set exhausted and return undef if a SQL query ever 
	  # results in no rows being added to the ResultTable.
	  $self->_setExhausted(1);
	  return undef;
      } 
     else {
	  #this will cause next call to get the next batch of ids
	  $self->set('batch_filterSQL', undef);
      }
  } 
  elsif ($self->get('batched_filterlist')) {
      my $batch_rows_processed = $self->get('batch_rows_processed');
      $batch_rows_processed += $rows_added;
      $self->set('batch_rows_processed', $batch_rows_processed);
  }

  return $table;
}

sub _fillAttributeTableWith {
  my ($self, $query, $table, $batch_start,$batch_size) = @_;

  # if this is a batched_filterlist, set batch_start to batch_rows_processed 
  # after sql_gen (which may reset this to zero at the beginning of each new 
  # batch)
  if ($self->get('batched_filterlist')) {
      $batch_start = $self->get('batch_rows_processed');
  }
  
  my $counter = 0;
  my $rows_added = 0;
 
  if ($self->serverType eq "web"){      
      # below is essential for linked dataset batching
      my $filters = $query->getAllFilters;
      foreach my $filter (@$filters){
	  # recover the tables
	  if ($filter->isa("BioMart::Configuration::FilterList")){
	      if ($filter->batching) {		  
		  $self->set('batch_rows_processed', 0);
		  $batch_start = $self->get('batch_rows_processed');
		  # when exhausted  is true, no more results remain
		  $self->_setExhausted($filter->exhausted);
		  # set batched_filterlist to keep up with changes to 
		  # underlying table
		  $self->set('batched_filterlist', $filter); 
	      }
	      else{
		  if (!$self->get('explicit_batching') && 
		      !$self->get('batched_filterlist')) {
		      $batch_start = 0;
		      $batch_size = 0;
		  }
              }	
	  }
      }

      if (!$self->get('explicit_batching') && 
	  !$self->get('batched_filterlist')) {
	  $batch_start = 0;
          $batch_size = 0;
      }      

      my $location = $self->getParam('configurator')->get('location');
      my $xml = $query->toXML($batch_start,$batch_size,0);    

     my $logger=Log::Log4perl->get_logger(__PACKAGE__);
     $logger->debug("QUERY XML:  $xml");


      foreach my $el($location->getResultSet("","POST",$xml)){	  
  	  if ($el =~ /^\s/) {next;}
	  $rows_added++;
	  # add false end to stop loss of trailing tab-sep empty strings
	  # vital for attribute merging
	  $el .= "\tend";
	  my @clean=split(/\t/,$el);
	  $table->addRow([@clean[0..scalar(@clean)-2]]);
      }
      return $rows_added;
            
  } 
  else {# "rdms" type rather than "web"
      my $oracle = 0;
      if ($self->getParam('configurator')->get('location')->
	  databaseType eq 'oracle'){
	  $oracle = 1;
      }
        
      my $sql= $self->_generateSQL($query, $batch_start, $batch_size,$oracle);
      	
      if ($oracle && $self->get('batched_filterlist')) {
	  $batch_start = $self->get('batch_rows_processed');
      }
    
      my $dbh = $self->_getDBH;
      my $batch;
      eval {
      	my $sth = $dbh->prepare($sql);
	      
      	$sth->execute;
      
      	$batch = $sth->fetchall_arrayref;
      	$sth->finish;
      };
      BioMart::Exception::Database->throw("Error during query execution: ".
      			$dbh->errstr."\n") if $@;
      			
      $dbh->disconnect;

      foreach my $row (@{$batch}){
	  $counter++;
	  if ($oracle){ 
	      if ( $counter > $batch_start  ) {
		  $table->addRow($row);
		  $rows_added++;
	      }
	  } else{
	      $table->addRow($row);
	      $rows_added++;
	  }   
      }
  }
  return $rows_added;
}


sub _generateSQL {
    my ($self, $query, $batch_start, $batch_size, $oracle) = @_;
    my $sql = $self->get('sql');
    unless ($sql) {
	my ($select, $from, $where, $orderby, $comma, $and) = ('')x6;
	my %tables;
	my %joinTables;
	my $schema;    

	# attributes = > SELECT clause generation

	my $attributes = $query->getAllAttributes;
	foreach my $attribute (@$attributes){
	    # postgres does not like mixing schemas and aliases
	    if($attribute->table ne "main"){
		$schema=$self->schema.".";
	    }
	    else{
		$schema="";
	    }

	    $select .= $comma.$schema.$attribute->toSQL;
	    my $table = $attribute->table;
	    $tables{$table} = 1;
	
	
	    if ($table eq 'main'){
		my $keys = $self->get('keys');
		foreach my $key (reverse @$keys){
		    last if (uc($joinTables{'main'}) eq uc($key));
		    if (uc($attribute->key) eq uc($key)){
			$joinTables{'main'} = $key;
			last;
		    }
		}
	    }
	    else{ # dm table
		     $joinTables{$self->schema.".".$table} = $attribute->key;
	    }
	    $comma = ', ';
	}
    
	# filters (and filterlists) => WHERE clause generation

	my $filters = $query->getAllFilters;
	foreach my $filter (@$filters){
	    if ($filter->isa("BioMart::Configuration::FilterList")
	    	|| $filter->isa("BioMart::Configuration::FilterList_List") ){
		if ($filter->batching) {
		    $self->set('batched_filterlist', $filter);
		    #REPLACEBFILTER replaced later with actual SQL
		    $where .= $and.REPLACEBFILTER;
		} 
		else {
		    $where .= $and.$filter->toSQL($oracle);
		}
	
		my $list_filters = $filter->getAllFilters;
		foreach my $list_filter (@$list_filters){
		    my $table = $list_filter->table;
		    $tables{$table} = 1;

		    if ($table eq 'main'){
			my $keys = $self->get('keys');
			foreach my $key (reverse @$keys){
			    last if (uc($joinTables{'main'}) eq uc($key));
			    if (uc($list_filter->attribute->key) eq uc($key)){
				$joinTables{'main'} = $key;
				last;
			    }
			}
		    }
		    else{ # dm table
			$joinTables{$table} = $list_filter->attribute->key;
		    }
		}
	    }
	    else{# non FilterList filter
		$where .= $and.$filter->toSQL($oracle);
		my $table = $filter->table;
		$tables{$table} = 1;

		if ($table eq 'main'){
		    my $keys = $self->get('keys');
		    foreach my $key (reverse @$keys){
			last if (uc($joinTables{'main'}) eq uc($key));
			if (uc($filter->attribute->key) eq uc($key)){
			    $joinTables{'main'} = $key;
			    last;
			}
		    }
		}
		else{# dm table
			 $joinTables{$table} = $filter->attribute->key;
		}
		
	    }
      
	    $and = ' AND ';
	}# end of filters => WHERE clause generation

        my ($main,$i);
    
	# identify the lowest key and set main accordingly
	if (%joinTables){
	    my $keys = $self->get('keys');
	    $i = scalar @$keys - 1;
	  OUTER:foreach my $key (reverse @$keys){
	      foreach my $join_table (keys %joinTables){
		  if (uc($joinTables{$join_table}) eq uc($key)){
		      last OUTER;
		  }
	      }
	      $i--;
	    }
	}
	else{
	    $i = 0;# for when no join tables 
	} 

	my $mains = $self->get('mains');
	$main = $$mains[$i];

	# AttributeList(s) = > SELECT clause additional generation
	# has to be done last as the choice of correct attribute can depend on 
	# the key chosen above - "dynamic linking"
    
	my $ct = $self->getConfigurationTree($query->
			      getInterfaceForDataset($self->name));
	$comma = '';
	my $subselect;

	my $attribute_lists = $query->getAllAttributeLists;
	foreach my $attribute_list (reverse @$attribute_lists){
            # reverse makes sure the attlists used for attribute merging are 
	    # put at the beginning
	    $subselect = '';
	    my $attributeString = $attribute_list->attributeString;
	    my @attributeNames = split(/,/,$attributeString);
	    foreach my $attributeName (@attributeNames){
		# dynamically recover correct attribute to use based on the 
		# cardinality of the current query
		my $keys = $self->get('keys');
		my $attribute;
		my $j = $i;#current key from above
		while ($j > -1){
		    my $key = $$keys[$j];
		    $attribute = $ct->getAttributeByNameKey($attributeName,
							    $key);
		    last if ($attribute);
		    $j--;
		}

		if (!$attribute){
		    $j = $i + 1;
		    my $keys = $self->get('keys');
		    while ($j <= (scalar (@$keys - 1))){
			my $key = $$keys[$j];
			$attribute = $ct->getAttributeByNameKey($attributeName,
								$key);
			if ($attribute){
			    $main = $$mains[$j];
			    last;
			}
			$j++;
		    }
		}

		if (!$attribute){
		    $attribute = $ct->getAttributeByName($attributeName);
		}

		if (!$attribute){
		    # recover from the actual AttributeList
		    $attribute = $attribute_list->
			getAttributeByName($attributeName);
		}

		$subselect .= $comma.$attribute->toSQL;

		my $table = $attribute->table;
		$tables{$table} = 1;

		if ($table eq 'main'){
		    my $keys = $self->get('keys');
		    my $k = scalar @$keys - 1;
		    foreach my $key (reverse @$keys){
			last if (uc($joinTables{'main'}) eq uc($key));
			if (uc($attribute->key) eq uc($key)){
			    $joinTables{'main'} = $key;
			    # set main table to this lower one
			    $main = $$mains[$k];
			    last;
			}
			$k--;
		    }
		}
		else{ # dm table
		    $joinTables{$table} = $attribute->key;
		}
		$comma = ', ';
	    }# end of attribute name loop
      
	    # add the attribute list generated SQL to the query
	    if ($select){#some attributes already added
		$select = $subselect.$comma.$select;
	    }
	    else{
		$select = $subselect;
	    }
      
	    # order by code
	    $comma = '';
	    my $orderByString = $attribute_list->orderByString;
	    my @orderByAttNames;
	    @orderByAttNames = split( /\,/, $orderByString) 
		if ($orderByString);
	    foreach my $attributeName (@orderByAttNames){
		# dynamically recover correct attribute to use based on the 
		# cardinality of the current query
		my $keys = $self->get('keys');
		my $attribute;
		my $j = $i;#current key from above
		while ($j > -1){
		    my $key = $$keys[$j];
		    $attribute = $ct->getAttributeByNameKey($attributeName,
							    $key);
		    last if ($attribute);
		    $j--;
		}
		if (!$attribute){
		    $j = $i + 1;
		    my $keys = $self->get('keys');
		    while ($j <= (scalar (@$keys - 1))){
			my $key = $$keys[$j];
			$attribute = $ct->getAttributeByNameKey($attributeName,
								$key);
			last if ($attribute);
			$j++;
		    }
		}

		$orderby .= $comma.$attribute->toSQL;
		$comma = ', ';
	    } # end of orderBy loop
	    
	    $comma = '';
	} # end of AttributeList(s) = > SELECT clause additional generation


	if ($query->orderBy()) {
	    # Exportable orderBy instructions over ride Query->orderBy 
	    unless ($orderby) {
		my @orderByNames = map { $_->name } @{$query->orderBy()};

		foreach my $attributeName (@orderByNames){
		    # dynamically recover correct attribute to use based on
		    # the cardinality of the current query
		    my $keys = $self->get('keys');
		    my $attribute;
		    my $j = $i;#current key from above
		    while ($j > -1){
			my $key = $$keys[$j];
			$attribute = $ct->getAttributeByNameKey($attributeName,
								$key);
			last if ($attribute);
			$j--;
		    }
		    if (!$attribute){
			$j = $i + 1;
			my $keys = $self->get('keys');
			while ($j <= (scalar (@$keys - 1))){
			    my $key = $$keys[$j];
			    $attribute = $ct->getAttributeByNameKey(
						$attributeName,$key);
			    last if ($attribute);
			    $j++;
			}
		    }

		    $orderby .= $comma.$attribute->toSQL;
		    $comma = ', ';
		}
	    }
	}

	# redo main table choice incase attlist has changed it
	if (%joinTables){
	    my $keys = $self->get('keys');
	    $i = scalar @$keys - 1;
	  OUTER:foreach my $key (reverse @$keys){
	      foreach my $join_table (keys %joinTables){
		  if (uc($joinTables{$join_table}) eq uc($key)){
		      last OUTER;
		  }
	      }
	      $i--;
	  }
	}
	else{
	    $i = 0;# for when no join tables
	} 
	$mains = $self->get('mains');
	$main = $$mains[$i];

	
	# generate FROM clause

	foreach my $table (keys %tables){
	    if ($table ne "main"){
		$from .= $self->schema.".".$table.', ';
	    }
	}  
	$from .= $self->schema.".".$main.' main';

	# add table joins to WHERE clause

	foreach my $join_table (keys %joinTables){
	    next if $join_table eq "main";
	    $where .= $and."main.".$joinTables{$join_table}."=".$join_table
		.".".$joinTables{$join_table};
	    $and = ' AND ';
	} 

	# generate the whole SQL statement

	$sql = 'SELECT '.$select.' FROM '.$from;
	if ($where){
	    $sql .= ' WHERE '.$where;
	}

	# restricted primary key access
	my $restricted_pk = $self->getConfigurationTree($query->
	       getInterfaceForDataset($self->name))->primaryKeyRestriction;
	if ($restricted_pk){
	    my $or = '';
	    my $key = ${$self->get('keys')}[0];
	    my $restrictedSQL = '(';
	    my @restrictions = split(/,/,$restricted_pk);
	    foreach(@restrictions){
		my ($start_restriction,$end_restiction) = split(/\-/,$_);
		$restrictedSQL .= $or.'main.'.$key.' BETWEEN '.
		    $start_restriction.' AND '.$end_restiction;
		$or = ' OR ';
	    }
	    $restrictedSQL .= ')';
	    if ($where){
		$sql .= ' AND '.$restrictedSQL;
	    }
	    else{
		$sql .= ' WHERE '.$restrictedSQL;
		$where = $restrictedSQL;
	    }
        }# end of resticted pk

	# add batching specific limits

	if ($self->get('explicit_batching') || 
	    $self->get('batched_filterlist')) {
	    #SQL batches both batching filter and explicit batched queries
	    if ($oracle){
		if ($orderby) {
		    $sql .= ' ORDER BY '.$orderby;

		    # Oracle rownum is calculated before the order by
		    # in order to get around this create a subselect from
		    # original ORDERED query and then get rownum based on that
		    
		    my @origfields = split ", ",$select;

		    # remove duplicates in the select list
		    #   duplicates in the select list cause problems with
		    #   the outer select in the subselect construct below
		    
		    my %saw;
         
                    # try without uniquifying

		    my @unique_qualified_fields = 
			grep (!$saw{$_}++, @origfields  );
	 
                    # try without uniquifying
         
		    my $uniqueselect = join ", ", @unique_qualified_fields;
		    $sql =~ s/$select/$uniqueselect/g;

		    # Outer select cannot have table alias names in it
		    #  i.e. 'table_name.field_name' will become 'field_name'
		    
		    my @unqualified_fields = 
			map { $_ =~ s/[^\.]+\.//g;$_; } @origfields;
		    my $unqualified_select = join ", ", @unqualified_fields;

		    # now create that new sql query
		    $sql = "SELECT $unqualified_select FROM ($sql) WHERE ".
			REPLACELIMIT;
	  
		}
		elsif ($where){  
		    $sql .= ' AND '.REPLACELIMIT;
		}
		else{
		    $sql .= ' WHERE '.REPLACELIMIT;
		}
	    }# end of ORACLE batching
	    else{ # non ORACLE batching
		#order goes before limit in MYSQL
		if ($orderby) {
		    $sql .= ' ORDER BY '.$orderby;
		}
		$sql .= REPLACELIMIT;
	    }
	}# end of batching limit generation

	$self->set('sql', $sql);
  
    }# end of unless ($sql)

    # put in the correct current limits into the batching

    my $batched_filterlist = $self->get('batched_filterlist');
    if ($batched_filterlist) {
	my $sub = $self->get('batch_filterSQL');
	unless ($sub) {
	    $sub = $batched_filterlist->toSQL($oracle);
	    $self->set('batch_filterSQL', $sub);
	    $self->set('batch_rows_processed', 0);
	}
	$batch_start = $self->get('batch_rows_processed');
	my $replace = REPLACEBFILTER;
	$sql =~ s/$replace/$sub/;
	#when this is true, no more results remain
	$self->_setExhausted($batched_filterlist->exhausted); 
        #keep up with changes to underlying table
	$self->set('batched_filterlist', $batched_filterlist);    
    }

    # set limits from batch_start and batch_size 
    # if explicit_batching or batch_filter
  
    if ($self->get('explicit_batching') || $batched_filterlist) {
	my $limit;
	if ($oracle) {
	    my $rownum_limit = $batch_size + $batch_start + 1;
	    $limit = ' rowNum < '.$rownum_limit; 
	} 
	elsif ($self->getParam('configurator')->get('location')->databaseType 
	       eq 'postgres'){
	    $limit = ' LIMIT ';
	    if ($batch_start){
		$limit .= $batch_size.' OFFSET ';
		$limit .= $batch_start;
	    } 
	    else {
		$limit .= $batch_size;
	    }
	} 
	elsif ($self->getParam('configurator')->get('location')->databaseType 
	       eq 'mysql'){
	    $limit = ' LIMIT ';
	    if ($batch_start){
		$limit .= $batch_start.',';
	    }
	    $limit .= $batch_size;
	} 
	else {
	    BioMart::Exception::Query->throw("Unsupported RDBMS type: ".$self->getParam('configurator')->get('location')->databaseType ."Currently supported: mysql, oracle and postgres");	
	}
	my $replace = REPLACELIMIT;
	$sql =~ s/$replace/$limit/;
    }

my $logger=Log::Log4perl->get_logger(__PACKAGE__);
 $logger->info("QUERY SQL:  $sql");

	return $sql;
}

sub _getCount {

    my ($self, @param) = @_;
    my $ret;
    my $batching;

    local($^W) = 0;  # prevent "odd number of elements" warning with -w.
    my(%param) = @param;

    my $query = $param{'query'};
  
    $self->_processNewQuery($query); #always act as if a new query for count.
    
    if ($self->serverType eq "web"){          
	my $location = $self->getParam('configurator')->get('location');
	my $xml = $query->toXML(0,0,1);

        my $logger=Log::Log4perl->get_logger(__PACKAGE__);
        $logger->info("COUNT XML:  $xml");

      
	my @results = $location->getResultSet("","POST",$xml);
	return $results[0];   
    }
  
    # rbdms
    my ($sql, $select, $from, $where, $limit, $comma, $and) = ('')x7;
    my %tables;
    my %joinTables;
    my $oracle = 0;

    if ($self->getParam('configurator')->get('location')->databaseType eq 
	'oracle'){
	$oracle = 1;
    }

    $select = 'COUNT(*)';
	my $filtList_List_flag = 0;
    # recover where clause from filters (and filterlists)
    my $filters = $query->getAllFilters;
  FILTERS: foreach my $filter (@$filters){
      
      # call with 'ORACLE' flag if appropiate to allow IN list switching
      $where .= $and.$filter->toSQL($oracle);
      # recover the tables
      if ($filter->isa("BioMart::Configuration::FilterList")
      	|| $filter->isa("BioMart::Configuration::FilterList_List")){
        if ($filter->isa("BioMart::Configuration::FilterList_List")){
		$filtList_List_flag = 1;
	}
	if ($filter->batching) {
	    $ret = 1; 
	    $batching = 1;
	    last FILTERS;
	}

	my $list_filters = $filter->getAllFilters;
	foreach my $list_filter (@$list_filters){
            my $table = $list_filter->table;
	    $tables{$table} = 1;
	    if ($table eq 'main'){
		my $keys = $self->get('keys');
		foreach my $key (reverse @$keys){
		    last if (uc($joinTables{'main'}) eq uc($key));
		    if (uc($list_filter->attribute->key) eq uc($key)){
			$joinTables{'main'} = $key;
			last;
		    }
		}
	    }
	    else{ # dm table
		$joinTables{$table} = $list_filter->attribute->key;
	    }
	}
      }
      else{
	  my $table = $filter->table;
	  $tables{$table} = 1;
	  if ($table eq 'main'){
	      my $keys = $self->get('keys');
	      foreach my $key (reverse @$keys){
	  	last if (uc($joinTables{'main'}) eq uc($key));
	  	if (uc($filter->attribute->key) eq uc($key)){
	  	    $joinTables{'main'} = $key;
	  	    last;
	  	}
	      }
	  }
	  else{# dm table
	  	 $joinTables{$table} = $filter->attribute->key;
	  }
      }
      $and = ' AND ';
    }

    #this will be true if there is a batching filter
    if ($batching) {
	return [ $ret ];
    }
 
    my ($main,$i);

    # identify the lowest key and set main accordingly
    my $keys = $self->get('keys');

    if (%joinTables){
	
	$i = scalar @$keys - 1;
      OUTER:foreach my $key (reverse @$keys){
	  foreach my $join_table (keys %joinTables){
	      if (uc($joinTables{$join_table}) eq uc($key)){
		  last OUTER;
	      }
	  }
	  $i--;
      }
    }
    else{
      $i = 0;# for when no join tables
    } 


    my $mains = $self->get('mains');
    $main = $$mains[$i];

    if ($i != 0 || $filtList_List_flag){
	$select = 'COUNT(DISTINCT main.'.$$keys[0].')';
    }

    foreach my $table (keys %tables){
	if ($table !~ /main$/){
	    $from .= $self->schema.".".$table.', ';
	}
    }  
    $from .= $self->schema.".".$main.' main';

    foreach my $join_table (keys %joinTables){
	next if $join_table eq "main";
	$where .= $and."main.".$joinTables{$join_table}."=".$join_table.".".
	    $joinTables{$join_table};
	$and = ' AND ';
    } 

    $sql = 'SELECT '.$select.' FROM '.$from;
    if ($where){
	$sql .= ' WHERE '.$where;
    }
    if ($limit){
	$sql .= ' LIMIT '.$limit;
    }

    # restricted primary key access
    my $restricted_pk = $self->getConfigurationTree($query->
	    getInterfaceForDataset($self->name))->primaryKeyRestriction;
    if ($restricted_pk){
	my $or = '';
	my $key = ${$self->get('keys')}[0];
	my $restrictedSQL = '(';
	my @restrictions = split(/,/,$restricted_pk);
	foreach(@restrictions){
	    my ($start_restriction,$end_restiction) = split(/\-/,$_);
	    $restrictedSQL .= $or.'main.'.$key.' BETWEEN '.$start_restriction.
		' AND '.$end_restiction;
	    $or = ' OR ';
	}
	$restrictedSQL .= ')';
	if ($where){
	  $sql .= ' AND '.$restrictedSQL;
	}
	else{
	  $sql .= ' WHERE '.$restrictedSQL;
	  $where = $restrictedSQL;
        }
   }


my $logger=Log::Log4perl->get_logger(__PACKAGE__);
 $logger->info("COUNT SQL:  $sql");


   my $dbh = $self->_getDBH;
   my $sth = $dbh->prepare($sql);
   unless ($sth) {
       BioMart::Exception::Database->throw("Couldnt connect to Database: ".
					   $dbh->errstr."\n");
   }
   $sth->{RaiseError} = 0;
   $sth->execute || warn($sth->errstr);
   $ret = ${$sth->fetchrow_arrayref}[0];
   $sth->finish;
   $dbh->disconnect;

   return $ret;
}

1;
