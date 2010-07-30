# An example script demonstrating the use of BioMart API.

use strict;
use BioMart::Initializer;
use BioMart::Query;
use BioMart::QueryRunner;

my $confFile = (grep { m/biomart-perl\/lib+$/ } @INC)[0]."/../conf/projectRegistry.xml";
die ("Cant find configuration file $confFile\n") unless (-f $confFile);


#
# NB: change action to 'cached' if you want 
# to skip the configuraiton step on subsequent runs
# from the same registry
#

my $action='cached';
my $initializer = BioMart::Initializer->new('registryFile'=>$confFile, 'action'=>$action);
my $registry = $initializer->getRegistry;



# you can check for the available filters and attributes here
# you need to uncomment a print statement in the sub
# &check_available_datasets_filters_attributes($registry);

# or just run your favourite query
# &setup_and_run_query($registry);

# ex 1
#&example_1($registry);

#&example_2($registry);

#&example_3($registry);

&example_4($registry);

sub example_4
{
	my $registry = shift;
    
	my $query = BioMart::Query->new('registry'=>$registry,'virtualSchemaName'=>'default');

	$query->setDataset("hsapiens_gene_ensembl");
	$query->addAttribute("gene_stable_id");
	$query->addAttribute("str_chrom_name");
	$query->addAttribute("cdna");
	$query->addFilter("chromosome_name", ["c5_H2"]);
	$query->addFilter("upstream_flank", ["12"]);
	$query->addFilter("downstream_flank", ["12"]);
    # $query->formatter('HTML'); leave this blank for tab delimited

    my $query_runner = BioMart::QueryRunner->new();
    $query_runner->execute($query);
    $query_runner->printHeader();
    $query_runner->printResults();
    $query_runner->printFooter();

}

sub example_3
{
	my $registry = shift;
    
	my $query = BioMart::Query->new('registry'=>$registry,'virtualSchemaName'=>'default');

	$query->setDataset("hsapiens_gene_ensembl");
	$query->addAttribute("gene_stable_id");
	$query->addAttribute("str_chrom_name");
	$query->addAttribute("peptide");
	$query->addFilter("chromosome_name", ["c5_H2"]);
            
    # $query->formatter('HTML'); leave this blank for tab delimited

    my $query_runner = BioMart::QueryRunner->new();
    $query_runner->execute($query);
    $query_runner->printHeader();
    $query_runner->printResults();
    $query_runner->printFooter();

}


sub example_2
{
    my $registry = shift;
    
    my $query = BioMart::Query->new('registry'=>$registry,'virtualSchemaName'=>'default');
     
    $query->setDataset("msd");
    $query->addAttribute("pdb_id");
#    $query->addFilter("has_scop", ["Only"]);
    $query->addFilter("has_scop", ["Excluded"]);
    
    # $query->formatter('HTML'); leave this blank for tab delimited

    my $query_runner = BioMart::QueryRunner->new();
    $query_runner->execute($query);
    $query_runner->printHeader();
    $query_runner->printResults();
    $query_runner->printFooter();

}

sub example_1
{
    my $registry = shift;
    
    my $query = BioMart::Query->new('registry'=>$registry,'virtualSchemaName'=>'default');
     
    $query->setDataset("msd");
    $query->addAttribute("pdb_id");
    $query->addFilter("experiment_type", ["Electron diffraction","Electron microscopy","Electron tomography"]);
    
    # $query->formatter('HTML'); leave this blank for tab delimited

    my $query_runner = BioMart::QueryRunner->new();
    $query_runner->execute($query);
    $query_runner->printHeader();
    $query_runner->printResults();
    $query_runner->printFooter();

}
sub setup_and_run_query {
    
    my $registry = shift;
    
    my $query = BioMart::Query->new('registry'=>$registry,'virtualSchemaName'=>'default');
     
    $query->setDataset("hsapiens_gene_ensembl");
    $query->addAttribute("ensembl_transcript_id");
    $query->addAttribute("chromosome_name");
    $query->addFilter("chromosome_name", ["22"]);
    
    # $query->formatter('HTML'); leave this blank for tab delimited

    my $query_runner = BioMart::QueryRunner->new();
    $query_runner->execute($query);
    $query_runner->printHeader();
    $query_runner->printResults();
    $query_runner->printFooter();
    
}



sub check_available_datasets_filters_attributes {

    my $registry =shift;
    
    foreach my $schema (@{$registry->getAllVirtualSchemas()}){
	foreach my $mart (@{$schema->getAllMarts()}){
	    foreach my $dataset (@{$mart->getAllDatasets()}){
		foreach my $configurationTree (@{$dataset->getAllConfigurationTrees()}){                                       
		    foreach my $attributeTree (@{$configurationTree->getAllAttributeTrees()}){
			foreach my $group(@{$attributeTree->getAllAttributeGroups()}){
			    foreach my $collection (@{$group->getAllCollections()}){
				foreach my $attribute (@{$collection->getAllAttributes()}){
# 				    print "mart: ",$mart->name, 
# 				    "\tdataset: ",$dataset->name,
# 				    "\tattribute: ",$attribute->name,"\n";
				}
			    }
			}					       
		    }
		}    
	    }
	}
    }
    
}
