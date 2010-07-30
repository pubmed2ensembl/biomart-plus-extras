#!/usr/bin/perl -w

#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR - Arek Kasprzyk, Syed Haider, Richard Holland, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut

use strict;
use bin::ExecuteConfigureBioMartBuilder;


#--------------------------------------------------------- for --help and --dependencies switch
for (my $index = 0; $index < scalar(@ARGV); $index++)
{
	if ($ARGV[$index] eq "--help")		
	{
		&displayHelpOptions();
		exit;
	}
	if ($ARGV[$index] eq "--dependencies")
	{
		&displayDependencies();
		exit;		
	}
	
}

# check if registry is present
my $found_reg;
for (my $i = 0; $i < scalar(@ARGV); $i++) {
if ($ARGV[$i] eq "-r"){$found_reg=1;}  
}

unless ($found_reg) {
print "\nSwitch -r followed by registryFileName is missing, Can't proceed.\n\n";
exit;
}


my @libModules;
my %reqList;

my $apiOnly = &promptUser("\nDo you want to install in API only mode [y/n] ", 'n');
if($apiOnly eq 'y')
{
	print "\n\t\tAPI configure only checks dependencies for using API\n\t\tAny additional switches supplied to this script will be ignored\n\n";
	&checkAPIDependencies();
}
elsif($apiOnly eq 'n')
{
	&configureMartView();
}
else
{
	print "\nInvalid instruction\n";
	exit;
}

#-----------------------------------------------------------------------------
sub displayDependencies
{
	my $path = "lib";
	my @webModules;
	my %modules_status;
	@webModules=&getLibModules($path);
	push @webModules, &getLibModules("bin");
	push @webModules, &getLibModules("t");
	%modules_status = &check_modules(@webModules);
	print qq/

	[== CPAN Modules Required For BioMart Web Interface : MARTVIEW ==]
	
	[--  BioMart has been tested with the latest versions of these --] 
	[--  modules available at the time of development. However the --] 
	[--  software is expected to  work with latest versions.       --]	
	[--  Some of the ones listed here comes  by default with PERL. --]
	[--  To find out which ones are already installed  with your   --] 
	[--  PERL  or  present through  PERL5LIB environment variable, --]
	[--  please follow the INSTALL instructions. Good Luck !.      --]
	
	/;
	foreach (keys %modules_status)
	{
		$_ =~ s/\//::/g;
		print "\n\t", $_;	
	}
	print "\n\n";	
}

#-----------------------------------------------------------------------------
sub checkAPIDependencies
{
	my $path = "lib";

	my @api_modules;
	foreach my $mod (&getLibModules($path))
	{
	    if($mod !~ m/Web/) {
		push (@api_modules,$mod);
	    }
	}
	push @api_modules, &getLibModules("t");

	#&check_modules(@api_modules);
	

	my %modules_status = &check_modules(@api_modules);
	
	my $counter=1;

	print "\nChecking prerequisites ...";
        my @missing;
	foreach my $moduleName (keys %modules_status) {
		if ($modules_status{$moduleName} ne '[OK]') {
		    # so it can be copied and pasted directly for 'cpan -i'           
		    my $printModule =$moduleName;
		    $printModule=~s/\//::/g;

		    $counter++;	    
#		    print $counter++, "\tMODULE: ", $printModule,"\t\t", $modules_status{$moduleName} , "\n";		
		    push @missing, $printModule;
		}	
	}
	
	if($counter > 1) {
	    print " please install the following modules:\n\n";
	    foreach my $module (@missing){
		print "$module\n";

	    }
	    print "\n"; 
	    exit;
	}
	
	print "\nLooks good.... you are done.\n\n";	
}
#-----------------------------------------------------------------------------
sub configureMartView
{
	my $path = "lib";

	my @webModules=&getLibModules($path);
	push @webModules, &getLibModules("bin");
	push @webModules, &getLibModules("t");

	my %modules_status = &check_modules(@webModules);

	#------------------------- IF EVERYTHING IS FINE, RUN configureBioMart.pl	
	my $counter=1;
	my $allOK = 'true';

	print "\nChecking prerequisites ...";
        my @missing;
	foreach my $moduleName (keys %modules_status)
	{
		if ($modules_status{$moduleName} ne '[OK]')
		{
			# so it can be copied and pasted directly for 'cpan -i'           
			my $printModule =$moduleName;
			$printModule=~s/\//::/g;

$counter++;	    
#		    print $counter++, "\tMODULE: ", $printModule,"\t\t", $modules_status{$moduleName} , "\n";		
		push @missing, $printModule;
		}	
	}
	
	if($counter > 1)
	{

     	print " please install the following modules:\n\n";

       foreach my $module (@missing){

print "$module\n";

}

print "\n"; 
          exit;
	}


		print "[Looks good] \n";	
		my $mode = undef;
		my $action = undef;
		my $registryFile = undef;
		my $recompile = undef;

		if (@ARGV)
		{
			for (my $i = 0; $i < scalar(@ARGV); $i++)	
			{
				if ($ARGV[$i] eq "--recompile")	
				{
					$recompile = $ARGV[$i];
				}
				if ($ARGV[$i] eq "--cached")
				{
					$action = $ARGV[$i];
				}
				if ($ARGV[$i] eq "--clean")
				{
						$action = $ARGV[$i];
				}
				if ($ARGV[$i] eq "--update")
				{
					$action = $ARGV[$i];
				}
				if ($ARGV[$i] eq "--backup")
				{
					$action = $ARGV[$i];
				}

				if ($ARGV[$i] eq "--memory" || $ARGV[$i] eq "--m")
				{
					$mode = $ARGV[$i];
				}
				if ($ARGV[$i] eq "--lazyload" || $ARGV[$i] eq "--l")
				{
					$mode = $ARGV[$i];
				}
				if ($ARGV[$i] eq "-r" || $ARGV[$i] eq "-registryFile")
				{
					if($ARGV[$i+1])
					{	
						$registryFile = "-r ".$ARGV[$i+1];
					}
				}
			
			}
			#print scalar (@ARGV);
			#print "\n\tACTION: $action";
			#print "\n\tMODE: $mode";
			#print "\n\tREGISTRY: $registryFile";
		}
		my $run_configureBioMart = "configureBioMart.pl";
		if ($action)
		{
			$run_configureBioMart .= " $action";
		}
		if ($mode)
		{
			$run_configureBioMart .= " $mode";
		}
		if ($registryFile)
		{
			$run_configureBioMart .= " $registryFile";
		}
		if ($recompile)
		{
			$run_configureBioMart .= " $recompile";
		}
		bin::ExecuteConfigureBioMartBuilder->executeSystemCommand($run_configureBioMart);			
	}	

#-----------------------------------------------------------------------------
sub getLibModules
{
	my @dirnames = [];
        while (my $dirname = shift) {
                push @dirnames, $dirname;
        }

        foreach my $dirname (@dirnames) {
        next if (ref($dirname) eq 'ARRAY');
        opendir (DIR, $dirname);
        my @entries = readdir (DIR);
        closedir (DIR);

 
   	foreach my $entry (@entries)
   	{
	  	next if $entry eq ".";
		next if $entry eq "..";
		my $temp_name = "$dirname/$entry";
		if (-d $temp_name) {
	    	&getLibModules($temp_name);
		} elsif ((-f $temp_name) && ($temp_name =~ /\.(t|p[ml])\Z/)) {
			push @libModules, $temp_name;
	}
   	}
	}

	return @libModules;
}

#-----------------------------------------------------------------------------

sub check_modules
{
    my @modules =@_;

	foreach my $file (@modules)
	{
		undef $/;	
		open(STDPATHS, "<$file");
		my $contents = <STDPATHS>;
		my @reqs = $contents =~ m/^\s*use\s+.*?;/mg; ## catching all use statements here
		close(STDPATHS);
		#--- only hardcoded dependency, from Exception.pm and Template::Plugin::Number::format is just like Number::Format
		#--- and both are used as use Number::Format
		push @reqs, "use Exception::Class;";
		push @reqs, "use Template::Plugin::Number::Format;";
		push @reqs, "use OLE::Storage_Lite;";
		#---
		foreach my $req (@reqs)
		{
			if($req !~ m/lib|BioMart|constant|vars|local|strict|English|warnings|SiteDefs/) ## ignoring usual built in perl mods
			{
				#------------ removing qw(freeze thaw) type of arguments which comes after the name
				#------------ e.g Number::Format qw(:subs)
				#------------ e.g Time::HiRes qw/time/
				$req =~ m/\s*use\s+([^(\s|;)]*)/;
				$req = $1;	
	
				#------------ substitution of :: by forward slash /
				$req =~ s/::/\//g;
				$reqList{$req} = '[NOT OK], CANT FIND THIS MODULE IN @INC';
			}
		}		

	}

	#----------------------------------------------------------------------------
	#------------------------------ finding the required module in @INC
	foreach my $incPath(@INC)
	{
		foreach my $moduleName (keys %reqList)
		{
			my $target = $incPath."/".$moduleName.".pm";
		
			if(-e $target)
			{
				$reqList{$moduleName} = '[OK]';
			}
		}
	
	}
	return %reqList;
}

#-----------------------------------------------------------------------------
sub promptUser {

   my ($promptString,$defaultValue) = @_;
   if ($defaultValue) {
      print $promptString, "[", $defaultValue, "]: ";
   } else {
      print $promptString, ": ";
   }

   $| = 1;               # force a flush after our print
   $_ = <STDIN>;         # get the input from STDIN (presumably the keyboard)
   chomp;

   if ("$defaultValue") {
      return $_ ? $_ : $defaultValue;    # return $_ if it has a value
   } else {
      return $_;
   }
}

#-----------------------------------------------------------------------------
sub displayHelpOptions()
{
	print qq/
	[============ WELCOME TO BIOMART HELP SECTION ============]
	
	[-----------------  TO START INSTALLATION ----------------] 

[your biomart-web directory]\$ perl bin\/configure.pl [ACTION optional] [MODE optional] [REGISTRYFILE]

REGISTRYFILE: -r registryFile.xml
-r 	path\/name of registry file. should live in conf directory. if no registry is specified,
	conf\/defaultMartRegistry.xml will be used

ACTION: --clean, --cached, --update
--clean
	Removes all existing xmls from the local disk being used, and fetch 
	all of them again from target MartLocations as per martRegistryFile.xml
--cached (default)
	Checks if there is already a pre-configured registry object associated
	with this registry file. If there exists one pre-configured registry, 
	simply retruns that, and doesnt redo all the configuration 	process. 
	The process is simply based on the name of registry file. Incase you 
	have chaged the contents of registry file, try either  --clean or 
	--update, which ever suits you.
--update
	Updates the registry object, incase the xml files representing your
	datasets have been updated. Can also be used to switch between MODES
	[--memory and --lazyload]
--recompile
	Recompiles templates for all visible datasets and default templates.
	This switch is related to inhouse development only. If you fancy changing 
	master templates knowing what you are doing in order to fiddle with cosmetics
	of Martview - most welcome.

MODE: --memory, --lazyload
--memory (default)
	Recommended for user with healthy amount of memory available.
--lazyload
	If you want your installation\/configuration process and Apache to utilise 
	minimum possible memory, try this option. Keeps all the information on disk and 
	brings only the required amount of information to memory as and when needed.

OPTIONAL:
--help
	lists all of the above switches on user\'s terminal.
--dependencies
	lists all CPAN Modules required for BioMart.
[for details and examples, see INSTALL file on the root of your biomart install directory]
	
	[== for further assistance, write to mart-admin\@ebi.ac.uk ==]
	[== or visit our documentation section on www.biomart.org ==]
	
/;

}


