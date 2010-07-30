# $Id: TemplateBuilder.pm,v 1.5 2008-04-09 12:52:34 syed Exp $

=head1 NAME

BioMart::Web::TemplateBuilder - class for building templates for a collection of BioMart  datasets


=head1 SYNOPSIS

    $tbuilder = BioMart::Web::TemplateBuilder->new({conf => $cwd.'/t/conf/martview.conf'});
    $tbuilder->build_templates() || print "Uh-oh, errors: ",$tbuilder->get_errstr();


=head1 DESCRIPTION

This module handles building secondary HTML-templates & Javascript for a MartView installation.

=head1 AUTHOR - Syed Haider, Damian Smedley, Gudmundur Arni Thorisson

=head2 Interaction with BioMart registry

All Mart-registry and related know-how is inherited from BioMart::Web, so this class only 
implements the extra functionality needed to pass the various Mart-config entities to 
templates.

=head2 Templates

The primary templates in conf/templates/default contain all logic for building filter and
attribute panels. This class is simplistic in the sense that it merely passes BioMart dataset
configuration items (filtertree, attributetrees) to the templates which then do the rest of
the work.

=head1 SUBROUTINES/METHODS 

=cut


package BioMart::Web::TemplateBuilder;

use strict;
use warnings;
use English;
use Readonly;
use Log::Log4perl;
use List::MoreUtils qw/apply/;
use File::Basename qw(dirname basename);
use File::Path;
use IO::File;
use Data::Dumper;
Readonly our $revision => substr(q$Revision: 1.5 $, 10);

#use Class::Std;
use base qw(BioMart::Web);
#{
    # variable name        |     init-value     | read accessor       | write accessor
    # my %mart_registry_of : ATTR(                  get=>'mart_registry', set=>'mart_registry' );

    # Private variables
    my $logger;                      # reference to master logger

=head2 new

  Usage      : my $tbuilder = BioMart::Web::TemplateBuilder->new({conf => $path_to_registryXMLfile});
  Purpose    : Construct a new instance of this class.
  Returns    : BioMart::Web::TemplateBuilder instance
  Arguments  : path to Mart registry XML-configfile
               reference to BioMart::Registry object (optional)
  Throws     : BioMart::Exception::Configuration on registry initialization errors.
  Status     : Public
  Comments   : If registry object is provided in constructor, it will be used instead of
               initialization a new registry from scratch.
  See Also   :

=cut

    # Constructor, sort of: Class::Std will call this method when it's constructing the object.
 sub _new {
     my ($self, @args_ref) = @_;
        
     $self->SUPER::_new(@args_ref);
     #my(%args_ref) = @args_ref;
	#print "\nTEMPLPATE BUILDER CONSTRUCTOR";
     # Initalize logging framework if not already done, and get reference to logger
     Log::Log4perl->init_once($self->get_config_dir().'/log4perl.conf');
     #print "\nTEMPLPATE BUILDER CONSTRUCTOR-AGAIN";
	$logger = Log::Log4perl->get_logger(__PACKAGE__);
     #$logger->debug("Running BUILD method for package ".__PACKAGE__.", objectID=$ident");

	# Create cached-template output dir if it does not exist already
     -d $self->get_cached_tt_dir() || mkpath($self->get_cached_tt_dir(),1,3775);
    	}
=head2 build_templates

  Usage      : $tbuild->build_templates()
  Purpose    : Create secondary HTML templates and Javascript code for a collection
               of BioMart datasets in the registry.
  Returns    : Undef if non-fatal errors/warnings occur.
  Arguments  : none
  Throws     : BioMart::Exception if fatal errors occur.
  Status     : Public
  Comments   : If return value is undef, get_errstr() can be used to retrieve an
               error message to help resolve config-problems.
  See Also   : Parent class BioMart::Web.

=cut

sub build_templates {
	my ($self) = @_;
	my %build_errors; # holds info on warnings collected in the templates

     # first clean out existing cached templates
     foreach my $f(glob($self->get_cached_tt_dir().'/*tt')) {
     	$logger->debug("Deleting old cached-template file ".basename($f));
          #unlink $f; ### dont delete them here, if exists they get overwritten. avoid deletion to get pre-cooked registries work
          		
	}
	# Determine up schema->dataset relationships, fetch the dataset objects themselves
     # from the registry and keep everything handy in a hash for later
     my $mart_registry = $self->get_mart_registry();
	my %js_pushactions_of_datasetmenu; # For holding pushaction-info for dataset-selection panel

     #  build filterpage and outputpage templates for each schema+dataset, as pulled from the Mart-config.
     my $schemas = $mart_registry->getAllVirtualSchemas();
	my @schemas;
	
	# Count things.
	my $totalDSCount = 0;
	my $currentDSCount = 0;
     foreach my $schema(@$schemas) {
     	my $schema_name = $schema->name();
		my $databases = $mart_registry->getAllDatabaseNames($schema_name, 1);
		foreach my $database_name(@$databases) {
	    		my $datasets = $mart_registry->getAllDataSetsByDatabaseName($schema_name, $database_name, 1);
		    	$totalDSCount += scalar(@$datasets);
		}
	}

	
		my @database_names;
		my @datasets;
		my $default_dataset;
		my %location_path = $self->getSettings('httpdSettings');
		my $TAG_path = $location_path{'location'};
     
     SCHEMA:
     foreach my $schema(@$schemas) {
 	    #if(!$schema->visible()) {
	    #$logger->info("Skipping schema ".$schema->name()." since it's flagged as not visible");
	    #next SCHEMA;
	    #}
		push(@schemas, $schema);
          my $schema_name = $schema->name();
	    	my $databases = $mart_registry->getAllDatabaseNames($schema_name, 1);
          DATABASE:
	    	foreach my $database_name(@$databases) {
			push @database_names, $database_name;
			# Add this database to pushaction-hash
			push(@{ $js_pushactions_of_datasetmenu{ 'schema' }->{ $schema_name }->{ 'databasemenu' } }, [$database_name, $database_name] );
			my $datasets = $mart_registry->getAllDataSetsByDatabaseName($schema_name, $database_name, 1);
			my $last_dataset;
		     DATASET:
			foreach my $dataset_name(sort @$datasets) {
				$currentDSCount++;
				printf STDERR "\r.... %d%%",(100*($currentDSCount/$totalDSCount));
			    	my $dataset = $mart_registry->getDatasetByName($schema_name, $dataset_name)
					|| BioMart::Exception::Configuration->throw("Couldn't get dataset $schema_name->$database_name->$dataset_name from registry");
				push @datasets, $dataset;
				my $conf_tree = $dataset->getConfigurationTree('default');
				# Add this dataset to pushaction-hash
				if ($conf_tree->defaultDataset()){
					unshift(@{ $js_pushactions_of_datasetmenu{ 'databasemenu' }->{ $database_name }->{ 'datasetmenu' } }, [$dataset->name, $dataset->displayName()]);
				}
		    		else{
					push(@{ $js_pushactions_of_datasetmenu{ 'databasemenu' }->{ $database_name }->{ 'datasetmenu' } }, [$dataset->name, $dataset->displayName()]);
		    		}
			    	#$default_schema ||= $schema_name if $schema->default();
			    	$default_dataset ||= $dataset; # if $dataset->defaultDataset();
			    	#my $conf_tree = $dataset->getConfigurationTree('default');
			    	$logger->debug("Building templates for dataset $schema_name->$database_name->$dataset_name: ".$dataset->displayName());
		    
				# Build filter templates first
		    		my %js_pushactions_of_filtermenu; # For holding pushaction-info collected from filter-configs
		    		my $filterpanel_tt = $self->process_template('filterpanel.tt',
								 {								 	
								     tbuilder    => $self,
								     dataset     => $dataset,
								     filtertrees => $conf_tree->getAllFilterTrees(),
								     build_errors=> \%build_errors,
								     js_pushactions_of_filtermenu => \%js_pushactions_of_filtermenu,
								     TAG_path => $TAG_path
								 });
		    		my $filterpanel_fh = IO::File->new(">".$self->get_cached_tt_dir()
						       . "/filterpanel_$schema_name\."
						       . $dataset->name.".tt") || die $!;
				
		    		$filterpanel_fh->print("[% TAGS star %]\n".$filterpanel_tt);
		    		$filterpanel_fh->close;
		    
		    		# Then attribute panel
		    		my $attributepanel_tt = $self->process_template('attributepanel.tt',
								    {
									tbuilder      => $self,
									dataset       => $dataset,
									build_errors=> \%build_errors,
									attributetrees => $conf_tree->getAllAttributeTrees(),
							     TAG_path => $TAG_path									
								    });
				my $attributepanel_fh = IO::File->new(">".$self->get_cached_tt_dir()
							  . "/attributepanel_$schema_name\."
							  . $dataset->name . ".tt") || die $!;
		    		$attributepanel_fh->print("[% TAGS star %]\n".$attributepanel_tt);
		    		$attributepanel_fh->close();

		    		my $filterTrees = $conf_tree->getAllFilterTrees();
				foreach my $filterTree (@{$filterTrees}){
					my $filterGroups = $filterTree->getAllFilterGroups();
					foreach my $filterGroup (@{$filterGroups}){
			    			my $filterCollections = $filterGroup->getAllCollections();
						foreach my $filterCollection (@{$filterCollections}){
							my $filters = $filterCollection->getAllFilters();
							foreach my $filter (@{$filters}){
								if ($filter->graph){
								# generate ontology file
								#warn("FILTER ".$filter->name." IS A GRAPH");
								generate_ontology_picker_tool($filter,$dataset_name);
					    			}
							}				
						}			    
					}
		    		}		
			} # foreach datasets closes
		} # foreach database closes
	} # foreach schema closes
	
	
        # build schema+dataset select-menus from the info collected above
	if(keys(%{ $js_pushactions_of_datasetmenu{ 'databasemenu' } }) == 0) {
     	$logger->warn("No datasets found in registry, so no templates were built. Returning 0");
          return 0;
	}
	$default_dataset ||= $datasets[0];
	print STDERR "\n"; # Last bit of progress bar.

	# make sure all cached tt files are precompiled for optimal site performance
     print STDERR "Compiling templates for visible datasets\n";
	my $currentTCount = 0;
	SCHEMA:
	foreach my $schema(@$schemas) {
		my $schema_name = $schema->name();
		my $databases = $mart_registry->getAllDatabaseNames($schema_name, 1);
		DATABASE:
	    	foreach my $database_name(@$databases) {
			push(@{ $js_pushactions_of_datasetmenu{ 'schema' }->{ $schema_name }->{ 'databasemenu' } }, [$database_name, $database_name] );
			my $datasets = $mart_registry->getAllDataSetsByDatabaseName($schema_name, $database_name, 1);
			DATASET:
			foreach my $dataset_name(sort @$datasets) {
				$currentTCount++;
				my $template_file = $self->get_cached_tt_dir()
							  . "/attributepanel_$schema_name\."
							  . $dataset_name . ".tt";
				print STDERR "[$currentTCount\/$totalDSCount] Attribute Panel of Dataset.. :$dataset_name\n";
				$self->process_template($template_file, { build_errors=> \%build_errors}) if (-e $template_file);
				$template_file = 	$self->get_cached_tt_dir()
							  . "/filterpanel_$schema_name\."
							  . $dataset_name . ".tt";
				print STDERR "[$currentTCount\/$totalDSCount] Filter Panel of Dataset..... :$dataset_name\n";
				$self->process_template($template_file, { build_errors=> \%build_errors}) if (-e $template_file);
				#$currentTCount++;
				#printf STDERR "\r.... %d%%",(100*($currentTCount/$totalDSCount));
			}
		}
	}
	
    	print STDERR "\n"; # Last bit of progress bar.
	
	# If any non-fatal errors occurred during template generation, get hash with info on them 
	# and set error message, then return undef to notify user
	if(%build_errors) {
	    my $errmsg = Dumper(\%build_errors);	    
	    $self->set_errstr($errmsg);
	    return undef;
	}
	
     return 1;
}



#----------------------------------------------------------------------
# Generates the ontology picker tool
my( $COUNT, $TMPL, $ONT_TMP_DIR );

sub generate_ontology_picker_tool{
    my $filter = shift;
    my $dataset_name = shift;

    my $configurationFile = shift;

    #my $fh = IO::File->new($configurationFile, "<");

    $TMPL    = "TE.A(%u,%u,'%s');\n";
    $ONT_TMP_DIR = "./htdocs/tmp/_ontology";
    if (!(-e $ONT_TMP_DIR)) {
	if (!(-e "./htdocs/tmp")) {
	    mkdir("./htdocs/tmp") or die( "Could not mkdir ./htdocs/tmp");
	}
	mkdir( $ONT_TMP_DIR ) or die( "Could not mkdir $ONT_TMP_DIR: $!" );
    }
    
    my $ontology = $filter->name;
    $ontology =~ tr/ /_/;
		   
    # Get the filehandle
    
    my $fh1 = start_ontology_file($ontology, $dataset_name);
    # Kick off the file-build
    $COUNT = 0;
    
    recurse_ontology( $fh1, $COUNT, $filter );
		   
    # Clean up
    end_ontology_file( $fh1 );
		  
    return 1;
}


# Recursive function for descending eVoc heirarchy
sub recurse_ontology{

    my $fh      = shift; # Filehandle to write to
    my $p_id    = shift; # ID of parent node
    my $configuration_object = shift; # Filter/Option
    my $options = $configuration_object->getAllOptions;
    foreach my $option( @$options ){
	my $text = $option->displayName;
	my $t_id = ++ $COUNT;
	$text =~ s/'/\\'/g;
	printf $fh ( $TMPL,  $t_id, $p_id, $text );
	recurse_ontology( $fh, $t_id, $option );
    }
}


# Creates an appropriate ontology file and returns an open file handle
sub start_ontology_file{

    my $ontology = shift || die( "Need an ontology identifier" );
    my $dataset = shift;
    my $filename = "${ONT_TMP_DIR}/_${ontology}.html";

	my $fh = IO::File->new( "> $filename" )
	     or die( "Could not open $filename for write: $!" );

    #warn( "[MARTCONF][INFO] Writing ontology picker $filename" );

    my $jscript1 = '/martview/js/hdropd.js';

  $fh->print( qq|
<!--#set var="decor" value="none"-->
<html>
<head>
  <title>$ontology</title>
  <script type="text/javascript" src="$jscript1"></script>
<head>
<body onMouseDown="Reset()">
<form>
<table width="100%" cellspacing="0" cellpadding="0" border="1">
 <tr width="100%">
  <td width="100%" align="right"><input type="button" value="Close" onclick="javascript:window.close()" /></td>
 </tr>
</table>
</form>
<script type="text/javascript">
<!--
              function MenuBuild(){
pForm = " |
    .$dataset."__filter.".qq |${ontology}"; //Form in parent window to update with sel value - new for martp website compatible
    is = new BrowserCheck();  //Checking browser version
    TE = new TreeItem(0,0,""); \n | );

	      return $fh;
	  }


# Adds closing text and closes the ontology filehandle
sub end_ontology_file{
    my $fh = shift || die( "Need a file handle" );

    print $fh qq|
	TE.WriteCSS();
    TE.WriteDiv();
    TE.Reset();
}
MenuBuild();
MenuInit();
//-->
    </script> \n|;

$fh->close();

return 1;
}

#}
1;

=head1 SEE ALSO

L<BioMart::Web>, L<BioMart::Registry>, L<BioMart::Query>, L<BioMart::Web::QueryRunner>

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.
Please report problems to BioMart development mailing list  (<mart-dev@ebi.ac.uk>)
Patches are welcome.

=head1 CONTACT

This module is part of the BioMart project http://www.ebi.ac.uk/biomart

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 AUTHOR

The BioMart team <mart-dev@ebi.ac.uk>

=head1 LICENCE AND COPYRIGHT

Copyright (c) <year> <copyright holder> (<contact address>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 

=cut
