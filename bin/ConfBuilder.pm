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

package bin::ConfBuilder;

use strict;

use DBI;

sub getAssemblies
{
	my ($self, %OPTIONS) = @_;

	my $db = DBI->connect("DBI:mysql:ensembl_compara_$OPTIONS{ensversion}:$OPTIONS{dbhost}:$OPTIONS{dbport}", $OPTIONS{dbuser}, $OPTIONS{dbpassword})
		|| die ("Could not connect to compara database.");
	my $st = $db->prepare('SELECT name,assembly FROM ensembl_compara_'.$OPTIONS{ensversion}.'.genome_db');

	$st->execute();

	my %dataset2assembly;

	while (my @row = $st->fetchrow_array()) {

		my $species = $row[0];
		my $assembly = $row[1];

		my @speciesChops = split(' ', $species);
		my $speciesNoSpaces = $species;
		$speciesNoSpaces =~ s/ /_/g;

		$dataset2assembly{ substr(lc $species, 0, 1).(lc $speciesChops[1]) } = $speciesNoSpaces.'.'.$assembly;

	}

	$st->finish;
	$db->disconnect;

	return %dataset2assembly;
}

sub makehttpdConf
{
	my ($self, %OPTIONS) = @_;
	#$self->printOptions(%OPTIONS);
	$OPTIONS{conf} =~ m/(.*\/)[^\/]*/;	
	my $confdir = $1;
	my $httpdConfFile = $1."httpd.conf";

	open(STDHTTPD,">$httpdConfFile");
	print STDHTTPD qq/
	PidFile logs\/httpd.pid
	Timeout 300
	KeepAlive Off
	MaxKeepAliveRequests 100
	KeepAliveTimeout 15
	MinSpareServers 2
	MaxSpareServers 2
	StartServers 2
	MaxClients 30
	MaxRequestsPerChild 400
	Listen $OPTIONS{server_port}

	DirectoryIndex index.html

	TypesConfig conf\/mime.types
	DefaultType text\/plain
	AddType image\/gif .gif
	AddType image\/png .png
	AddType image\/jpeg .jpg .jpeg
	AddType text\/css .css
	AddType text\/html .html .htm
	AddType text\/xml .xml
	AddType text\/plain .asc .txt
	AddType application\/pdf .pdf
	AddType application\/x-gzip .gz .tgz
	AddType application\/vnd.ms-excel .xls
    
	ErrorLog logs\/error_log
	LogLevel warn
	LogFormat "%h %l %u %t \\"%r\\" %>s %b" combined
	CustomLog logs\/access_log combined
	/;

	if ($OPTIONS{httpd_modperl} && $OPTIONS{httpd_modperl} eq 'DSO')
	{
		print STDHTTPD qq/
		LoadModule perl_module $OPTIONS{httpd_modperl_dsopath}
		/;
		if ($OPTIONS{httpd_modperl_dsopath_modules})
		{
			foreach (@{$OPTIONS{httpd_modperl_dsopath_modules}})
			{
				print STDHTTPD qq/
				LoadModule $_ /;
				
			}
		}
	}
	
	## for mod_gzip Apache 1.3 only
	if ($OPTIONS{httpd_version} eq '1.3')
	{
		if ($OPTIONS{httpd_modperl_dsopath_modules})
		{
			foreach (@{$OPTIONS{httpd_modperl_dsopath_modules}})
			{
				print STDHTTPD qq/
				LoadModule $_ /;				
			}
		}
	}

	if ($OPTIONS{httpd_modperl} )
	{
		print STDHTTPD qq/
		<Perl>
		/;
		
		if($OPTIONS{libdirs})
		{
			foreach (@{$OPTIONS{libdirs}})
			{
				print STDHTTPD qq/
				use lib '$_'; /;
			}
		}
		foreach (@{$OPTIONS{modules_in_dist}})
		{
			print STDHTTPD qq/
			require "$_"; /;
		}
	
		print STDHTTPD qq/	
		#warn "MartView:: Initializing master Mart registry";
		eval { my \$init = BioMart::Initializer->new(registryFile => '$OPTIONS{conf}');
		\$main::BIOMART_REGISTRY = \$init->getRegistry() || die "Can't get registry from initializer";
		};
		<\/Perl>
		/;
		
	}
	

	## APACHE 1.3 compression
		if ($OPTIONS{httpd_version} eq '1.3')
		{
			print STDHTTPD qq/
			<IfModule mod_gzip.c>
                        mod_gzip_on Yes
                        mod_gzip_can_negotiate        Yes
                        mod_gzip_static_suffix        .gz
                        AddEncoding              gzip .gz
                        mod_gzip_update_static        No
                        mod_gzip_command_version      '\/mod_gzip_status'
                        mod_gzip_temp_dir \/tmp
                        mod_gzip_keep_workfiles No
                        mod_gzip_handle_methods        GET POST
                        mod_gzip_dechunk yes
                        mod_gzip_min_http 1000
                        mod_gzip_minimum_file_size  1000
                        mod_gzip_maximum_file_size  3000000
                        mod_gzip_maximum_inmem_size 60000

                        # which files are to be compressed?
                        #
                        # The order of processing during each of both phases is not important,
                        # but to trigger the compression of a request's content this request
                        # a) must match at least one include rule in each of both phases and
                        # b) must not match an exclude rule in any of both phases.
                        # These rules are not minimal, they are meant to serve as example only.
                        #
                        # phase 1: (reqheader, uri, file, handler)
                        # ========================================
                        # (see chapter about caching for problems when using 'reqheader' type
                        #  filter rules.)
                        # NO:   special broken browsers which request for gzipped content
                        #       but then aren't able to handle it correctly
                        mod_gzip_item_exclude         reqheader  "User-agent: Mozilla\/4.0[678]"
                        #
                        # JA:   HTML-Dokumente
                        mod_gzip_item_include         file       \\.html\$
                        mod_gzip_item_include         file       \\.biomart\$
                        mod_gzip_item_include           uri .

                        #
                        # NO:   include files \/ JavaScript & CSS (due to Netscape4 bugs)
                        mod_gzip_item_exclude         file       \\.js\$
                        mod_gzip_item_exclude         file       \\.css\$
                        mod_gzip_item_exclude         file       \\.gz\$
                        mod_gzip_item_exclude         file       \\.xls\$


                        #
                        # YES:  CGI scripts
                        mod_gzip_item_include         file       \\.pl\$
                        mod_gzip_item_include         handler    ^cgi-script\$
                        #
                        # phase 2: (mime, rspheader)
                        # ===========================
                        # YES:  normal HTML files, normal text files, Apache directory listings
                        #mod_gzip_item_include         mime       ^text\/html\$
                        #mod_gzip_item_include         mime       ^text\/plain\$
                        #mod_gzip_item_include         mime       ^httpd\/unix-directory\$

                        mod_gzip_item_include mime .

                        #mod_gzip_item_include mime ^application\/vnd.ms-excel

                        #
                        # NO:   images (GIF etc., will rarely ever save anything)
                        mod_gzip_item_exclude         mime       ^image\/

                        mod_gzip_send_vary Yes
                        <\/IfModule>
			/;
		}
		

	print STDHTTPD qq/	
	DocumentRoot "$OPTIONS{htdocs}"
	<Location \/>
    	Options Indexes FollowSymLinks MultiViews
    	AllowOverride None
    	Order allow,deny
    	Allow from all
	<\/Location>

	ScriptAlias \/$OPTIONS{cgiLocation}\/martview "$OPTIONS{cgibin}\/martview"
	<Location \/$OPTIONS{cgiLocation}\/martview>

	AllowOverride None
    	Options None
    	Order allow,deny
    	Allow from all
	/;

        if ($OPTIONS{httpd_version} eq '2.0' || $OPTIONS{httpd_version} eq '2.1+')
        {
                print STDHTTPD qq/
                <IfModule mod_deflate.c>
                        ## zip both input and output
                        SetOutputFilter DEFLATE
                        SetInputFilter DEFLATE
                        ## donot zip already zipped files 
                        SetEnvIfNoCase Request_URI \\.(?:exe|t?gz|zip|bz2|sit|rar)\$ no-gzip dont-vary
                <\/IfModule>
                /;
        }

	if ($OPTIONS{httpd_modperl})
	{
		print STDHTTPD qq/SetHandler perl-script
		/;
		if ($OPTIONS{httpd_version} eq '1.3')
		{
			print STDHTTPD qq/PerlHandler Apache::Registry/;
		}
		elsif($OPTIONS{httpd_version} eq '2.0' || $OPTIONS{httpd_version} eq '2.1+')
		{
			print STDHTTPD qq/PerlResponseHandler ModPerl::Registry/;
		}
	}
	
	print STDHTTPD qq/
    	Options +ExecCGI
	<\/Location>
	/;
	
	print STDHTTPD qq/
	ScriptAlias \/$OPTIONS{cgiLocation}\/martservice "$OPTIONS{cgibin}\/martservice"
	<Location \/$OPTIONS{cgiLocation}\/martservice>
    	AllowOverride None
    	Options None
    	Order allow,deny
    	Allow from all
	/;
	
	if ($OPTIONS{httpd_modperl})
	{
		print STDHTTPD qq/	SetHandler perl-script
		/;
		if ($OPTIONS{httpd_version} eq '1.3')
		{
			print STDHTTPD qq/PerlHandler     Apache::Registry/;
		}
		elsif($OPTIONS{httpd_version} eq '2.0' || $OPTIONS{httpd_version} eq '2.1+')
		{
			print STDHTTPD qq/PerlResponseHandler ModPerl::Registry/;
		}
	}
	print STDHTTPD qq/
    	Options +ExecCGI
	<\/Location>
	/;
	
	print STDHTTPD qq/
	ScriptAlias \/$OPTIONS{cgiLocation}\/martsoap "$OPTIONS{cgibin}\/martsoap"
	<Location \/$OPTIONS{cgiLocation}\/martsoap>
    	AllowOverride None
    	Options None
    	Order allow,deny
    	Allow from all
	/;
	
	if ($OPTIONS{httpd_modperl})
	{
		print STDHTTPD qq/	SetHandler perl-script
		/;
		if ($OPTIONS{httpd_version} eq '1.3')
		{
			print STDHTTPD qq/PerlHandler     Apache::Registry/;
		}
		elsif($OPTIONS{httpd_version} eq '2.0' || $OPTIONS{httpd_version} eq '2.1+')
		{
			print STDHTTPD qq/PerlResponseHandler ModPerl::Registry/;
		}
	}
	print STDHTTPD qq/
    	Options +ExecCGI
	PerlOptions +ParseHeaders
	<\/Location>
	/;
	
	
	print STDHTTPD qq/
	ScriptAlias \/$OPTIONS{cgiLocation}\/martwsdl "$OPTIONS{cgibin}\/martwsdl"
	<Location \/$OPTIONS{cgiLocation}\/martwsdl>
    	AllowOverride None
    	Options None
    	Order allow,deny
    	Allow from all
	<\/Location>
	/;
	
	print STDHTTPD qq/
	ScriptAlias \/$OPTIONS{cgiLocation}\/martxsd "$OPTIONS{cgibin}\/martxsd"
	<Location \/$OPTIONS{cgiLocation}\/martxsd>
    	AllowOverride None
    	Options None
    	Order allow,deny
    	Allow from all
	<\/Location>
	/;
	
	print STDHTTPD qq/
	ScriptAlias \/$OPTIONS{cgiLocation}\/martresults "$OPTIONS{cgibin}\/martresults"
	<Location \/$OPTIONS{cgiLocation}\/martresults>
    	AllowOverride None
    	Options None
    	Order allow,deny
    	Allow from all
	/;
	
	if ($OPTIONS{httpd_modperl})
	{
		print STDHTTPD qq/	SetHandler perl-script
		/;
		if ($OPTIONS{httpd_version} eq '1.3')
		{
			print STDHTTPD qq/PerlHandler     Apache::Registry/;
		}
		elsif($OPTIONS{httpd_version} eq '2.0' || $OPTIONS{httpd_version} eq '2.1+')
		{
			print STDHTTPD qq/PerlResponseHandler ModPerl::Registry/;
		}
	}
	print STDHTTPD qq/
    	Options +ExecCGI
	<\/Location>
	/;

	if ($OPTIONS{httpd_modperl})
	{
		print STDHTTPD qq/
		<Location \/$OPTIONS{cgiLocation}\/perl-status>/;

		print STDHTTPD qq/
			SetHandler perl-script
		/;
		if ($OPTIONS{httpd_version} eq '1.3')
		{
			print STDHTTPD qq/PerlHandler Apache::status/;
		}
		elsif($OPTIONS{httpd_version} eq '2.0' || $OPTIONS{httpd_version} eq '2.1+')
		{
			print STDHTTPD qq/PerlHandler Apache2::Status/;
		}
		
		print STDHTTPD qq/
		<\/Location>
		/;

	}

	close(STDHTTPD);	
}

sub makeMartView
{
	my ($self, %OPTIONS) = @_;
	undef $/; ## whole file mode for read
	my $file = $OPTIONS{cgibin}."/martview.PLS";	
	open(STDMARTVIEW, "$file");	
	my $fileContents = <STDMARTVIEW> ;
	close(STDMARTVIEW);
	#print $fileContents;
	##---------------- replacing [TAG:lib]
	my $libPaths;
	if ($OPTIONS{libdirs})
	{
		foreach my $path(@{$OPTIONS{libdirs}})
		{	
			$libPaths .= qq/use lib "$path";\n/;
		}
	}
	$fileContents =~ s/\[TAG:lib\]/$libPaths/m;

	##---------------- replacing [TAG:conf]
	if ($OPTIONS{conf})
	{
		my $confFile = qq/\$CONF_FILE = '$OPTIONS{conf}';\n/; 
		$fileContents =~ s/\[TAG:conf\]/$confFile/m;
	}
	
	$file = $OPTIONS{cgibin}."/martview";	
	open(STDMARTVIEW, ">$file");	
	print STDMARTVIEW $fileContents;
	close(STDMARTVIEW);

	chmod 0755, $file;		
}
sub makeMartService
{
	my ($self, %OPTIONS) = @_;
	undef $/; ## whole file mode for read
	my $file = $OPTIONS{cgibin}."/martservice.PLS";	
	open(STDMARTSERVICE, "$file");	
	my $fileContents = <STDMARTSERVICE> ;
	close(STDMARTSERVICE);
	#print $fileContents;
	##---------------- replacing [TAG:lib]
	my $libPaths;
	if ($OPTIONS{libdirs})
	{
		foreach my $path(@{$OPTIONS{libdirs}})
		{	
			$libPaths .= qq/use lib "$path";\n/;
		}
	}
	$fileContents =~ s/\[TAG:lib\]/$libPaths/m;

	##---------------- replacing [TAG:conf]
	if ($OPTIONS{conf})
	{
		my $confFile = qq/\$CONF_FILE = '$OPTIONS{conf}';\n/; 
		$fileContents =~ s/\[TAG:conf\]/$confFile/m;
	}

	##---------------- replacing [TAG:server_host]
	if ($OPTIONS{server_host})
	{
		my $server_host = qq/\$server_host = '$OPTIONS{server_host}';\n/; 
		$fileContents =~ s/\[TAG:server_host\]/$server_host/m;
	}

	##---------------- replacing [TAG:cgiLocation]
	if ($OPTIONS{cgiLocation})
	{
		my $cgiLocation = qq/\$cgiLocation = '$OPTIONS{cgiLocation}';\n/; 
		$fileContents =~ s/\[TAG:cgiLocation\]/$cgiLocation/m;
	}

	##---------------- replacing [TAG:server_port]
	if ($OPTIONS{server_port})
	{
		my $server_port;
		if($OPTIONS{proxy}) 
		{
			$server_port = qq/\$server_port = '$OPTIONS{proxy}';\n/; 
		}
		else
		{
			$server_port = qq/\$server_port = '$OPTIONS{server_port}';\n/; 
		}
			
		$fileContents =~ s/\[TAG:server_port\]/$server_port/m;
			
	}
	
	##---------------- replacing [TAG:log_dir]
	my $logDir = qq/\$log_Dir = '$OPTIONS{logDir}';\n/;
	$fileContents =~ s/\[TAG:log_dir\]/$logDir/m;
	
	$file = $OPTIONS{cgibin}."/martservice";	
	open(STDMARTSERVICE, ">$file");	
	print STDMARTSERVICE $fileContents;
	close(STDMARTSERVICE);

	chmod 0755, $file;		
}

sub makeMartResults
{
	my ($self, %OPTIONS) = @_;
	undef $/; ## whole file mode for read
	my $file = $OPTIONS{cgibin}."/martresults.PLS";	
	open(STDMARTRES, "$file");	
	my $fileContents = <STDMARTRES> ;
	close(STDMARTRES);
	#print $fileContents;
	##---------------- replacing [TAG:lib]
	my $libPaths;
	if ($OPTIONS{libdirs})
	{
		foreach my $path(@{$OPTIONS{libdirs}})
		{	
			$libPaths .= qq/use lib "$path";\n/;
		}
	}
	$fileContents =~ s/\[TAG:lib\]/$libPaths/m;

	$file = $OPTIONS{cgibin}."/martresults";	
	open(STDMARTRES, ">$file");	
	print STDMARTRES $fileContents;
	close(STDMARTRES);

	chmod 0755, $file;		
}

sub makeFeatures
{
	my ($self, %OPTIONS) = @_;
	undef $/; ## whole file mode for read
	my $file = $OPTIONS{cgibin}."/features.PLS";	
	open(STDFEATURES, "$file");	
	my $fileContents = <STDFEATURES> ;
	close(STDFEATURES);
	#print $fileContents;
	##---------------- replacing [TAG:lib]
	my $libPaths;
	if ($OPTIONS{libdirs})
	{
		foreach my $path(@{$OPTIONS{libdirs}})
		{	
			$libPaths .= qq/use lib "$path";\n/;
		}
	}
	$fileContents =~ s/\[TAG:lib\]/$libPaths/mg;

	##---------------- replacing [TAG:conf]
	if ($OPTIONS{conf})
	{
		my $confFile = qq/$OPTIONS{conf}/; 
		$fileContents =~ s/\[TAG:conf\]/$confFile/mg;
	}

	##---------------- replacing [TAG:server_host]
	if ($OPTIONS{server_host})
	{
		my $server_host = qq/$OPTIONS{server_host}/; 
		$fileContents =~ s/\[TAG:server_host\]/$server_host/mg;
	}

	##---------------- replacing [TAG:cgiLocation]
	if ($OPTIONS{cgiLocation})
	{
		my $cgiLocation = qq/$OPTIONS{cgiLocation}/; 
		$fileContents =~ s/\[TAG:cgiLocation\]/$cgiLocation/mg;			
	}

	##---------------- replacing [TAG:server_port]
	if ($OPTIONS{server_port})
	{
		my $server_port;
		if($OPTIONS{proxy}) 
		{
			$server_port = qq/$OPTIONS{proxy}/; 
		}
		else
		{
			$server_port = qq/$OPTIONS{server_port}/; 
		}
			
		$fileContents =~ s/\[TAG:server_port\]/$server_port/mg;
			
	}
	
	##---------------- replacing [TAG:log_dir]
	my $logDir = qq/$OPTIONS{logDir}/;
	$fileContents =~ s/\[TAG:log_dir\]/$logDir/m;
	
	$file = $OPTIONS{cgibin}."/features";	
	open(STDFEATURES, ">$file");	
	print STDFEATURES $fileContents;
	close(STDFEATURES);

	chmod 0755, $file;		
}

sub updatehttpdConf
{
	my ($self, %OPTIONS) = @_;
	
	$OPTIONS{conf} =~ m/(.*\/)[^\/]*/;	
	my $confdir = $1;
	my $httpdConfFile = $1."httpd.conf";

	open(STDHTTPD,">>$httpdConfFile");
	
	foreach my $datasetName (@{$OPTIONS{'dasDatasets'}})
	{
	#print "\n$datasetName";
	print STDHTTPD qq/
	ScriptAlias \/$OPTIONS{cgiLocation}\/das\/$datasetName\/features "$OPTIONS{cgibin}\/features"
	<Location \/$OPTIONS{cgiLocation}\/das\/$datasetName\/features>
	Options None
    	Order allow,deny
    	Allow from all
	/;
	
	if ($OPTIONS{httpd_modperl})
	{
		print STDHTTPD qq/	SetHandler perl-script
		/;
		if ($OPTIONS{httpd_version} eq '1.3')
		{
			print STDHTTPD qq/PerlHandler     Apache::Registry/;
		}
		elsif($OPTIONS{httpd_version} eq '2.0' || $OPTIONS{httpd_version} eq '2.1+')
		{
			print STDHTTPD qq/PerlResponseHandler ModPerl::Registry/;
		}
	}
	print STDHTTPD qq/
    	Options +ExecCGI
	<\/Location>
	/;
	
	} # end of foreach
	
	# Now adding location for server/location/das/dsn file
	print STDHTTPD qq/
	ScriptAlias \/$OPTIONS{cgiLocation}\/das\/dsn "$OPTIONS{cgibin}\/dsn"
	<Location \/$OPTIONS{cgiLocation}\/das\/dsn>
    	AllowOverride None
    	Options None
    	Order allow,deny
    	Allow from all
	/;
	
	if ($OPTIONS{httpd_modperl})
	{
		print STDHTTPD qq/	SetHandler perl-script
		/;
		if ($OPTIONS{httpd_version} eq '1.3')
		{
			print STDHTTPD qq/PerlHandler     Apache::Registry/;
		}
		elsif($OPTIONS{httpd_version} eq '2.0' || $OPTIONS{httpd_version} eq '2.1+')
		{
			print STDHTTPD qq/PerlResponseHandler ModPerl::Registry/;
		}
	}
	print STDHTTPD qq/
    	Options +ExecCGI
	<\/Location>
	/;
	
}

sub makeDSN
{
	my ($self, %OPTIONS) = @_;
	my $dsnFile = $OPTIONS{cgibin}."/dsn.PLS";
	undef $/; ## whole file mode for read
	open(STDDSN,"$dsnFile");
	my $fileContents = <STDDSN> ;
	close STDDSN;
	
	
	my $dasRegistry .= qq/<?xml version=\"1.0\" standalone=\"yes\"?>
	<!DOCTYPE DASDSN SYSTEM \"http:\/\/www.biodas.org\/dtd\/dasdsn.dtd\">
	<DASDSN>/;

	my %dataset2assembly = $self->getAssemblies(%OPTIONS);

	foreach my $datasetName (@{$OPTIONS{'dasDatasets'}})
	{
		# datasetName is something like default__tguttata_gene_ensembl__ensembl_das_gene
		my @datasetChops = split('_', $datasetName);
		my $autoconfDSN = $dataset2assembly{ $datasetChops[2] };

        	if ($datasetChops[8] eq 'chr') {
		        $autoconfDSN .= '.reference';
	        } elsif ($datasetChops[8] eq 'gene') {
	                $autoconfDSN .= '.transcript';
	        } else {
	                # Woops..
	        }       

		# <MAPMASTER>http:\/\/$OPTIONS{server_host}\/$OPTIONS{cgiLocation}\/das\/$autoconfDSN\/<\/MAPMASTER>
		if ($OPTIONS{server_port}) {
		$dasRegistry .= qq/<DSN href=\"http:\/\/pubmed2ensembl.smith.man.ac.uk\/biomart\/das\/dsn\">
		<SOURCE id=\"$datasetName\">$autoconfDSN<\/SOURCE>
		<MAPMASTER>http:\/\/sep2009.archive.ensembl.org\/das\/$autoconfDSN<\/MAPMASTER>
		<DESCRIPTION>BioMart dataset $datasetName<\/DESCRIPTION>
	<\/DSN>
	/;
		} else {
		$dasRegistry .= qq/<DSN href=\"http:\/\/pubmed2ensembl.smith.man.ac.uk\/biomart\/das\/dsn\">
		<SOURCE id=\"$datasetName\">$autoconfDSN<\/SOURCE>
		<MAPMASTER>http:\/\/sep2009.archive.ensembl.org\/das\/$autoconfDSN<\/MAPMASTER>
		<DESCRIPTION>BioMart dataset $datasetName<\/DESCRIPTION>
	<\/DSN>
	/;
		}
	
	}
	$dasRegistry .= qq /<\/DASDSN>/;

	$fileContents =~ s/\[TAG:dasSources\]/$dasRegistry/m;
	
	$dsnFile = $OPTIONS{cgibin}."/dsn";	
	open(STDDSN, ">$dsnFile");	
	print STDDSN $fileContents;
	close(STDDSN);
	chmod 0755, $dsnFile;
}

sub makeSOURCES
{       
        my ($self, %OPTIONS) = @_;
	my $sourcesFile = $OPTIONS{cgibin}."/sources.PLS";
        undef $/; ## whole file mode for read
        open(STDSOURCES,"$sourcesFile");
        my $fileContents = <STDSOURCES> ;
        close STDSOURCES;

        my %defaultCoordinates = (
                "acarolinensis", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS207" taxid="28377" source="Scaffold" authority="AnoCar" test_range="scaffold_3762:1,10342" version="1.0">AnoCar_1.0,Scaffold,Anolis carolinensis</COORDINATES>',
                "btaurus", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS161" taxid="9913" source="Chromosome" authority="Btau" test_range="Un.004.9443:1,2371" version="4.0">Btau_4.0,Chromosome,Bos taurus</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS162" taxid="9913" source="Contig" authority="Btau" test_range="AAFC03000737:1,1578" version="4.0">Btau_4.0,Contig,Bos taurus</COORDINATES>',
                "celegans", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS312" taxid="6239" source="Chromosome" authority="WS" test_range="MtDNA:1,13794" version="200">WS_200,Chromosome,Caenorhabditis elegans</COORDINATES>',
                "cjacchus", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS312" taxid="6239" source="Chromosome" authority="WS" test_range="MtDNA:1,13794" version="200">WS_200,Chromosome,Caenorhabditis elegans</COORDINATES>',
                "cfamiliaris", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS82" taxid="9615" source="Chromosome" authority="BROADD" test_range="33:3000001,3100000" version="2">BROADD_2,Chromosome,Canis familiaris</COORDINATES>',
                "cporcellus", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS183" taxid="10141" source="Scaffold" authority="cavPor" test_range="scaffold_0:1,100000" version="3">cavPor_3,Scaffold,Cavia porcellus</COORDINATES>',
                "choffmanni", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS209" taxid="9358" source="Scaffold" authority="choHof" test_range="scaffold_427506:1,951" version="1">choHof_1,Scaffold,Choloepus hoffmanni</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS208" taxid="9358" source="Gene Scaffold" authority="choHof" test_range="GeneScaffold_338:1,46652" version="1">choHof_1,Gene Scaffold,Choloepus hoffmanni</COORDINATES>',
                "cintestinalis", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS143" taxid="7719" source="Scaffold" authority="JGI" test_range="scaffold_26:1,100000" version="2">JGI_2,Scaffold,Ciona intestinalis</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS54" taxid="7719" source="Chromosome" authority="JGI" test_range="1p:1,100000" version="2">JGI_2,Chromosome,Ciona intestinalis</COORDINATES>',
                "csavignyi", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS182" taxid="51511" source="Reftig" authority="CSAV" test_range="reftig_0:1,100000" version="2.0">CSAV_2.0,Reftig,Ciona savignyi</COORDINATES>',
                "drerio", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS310" taxid="7955" source="Scaffold" authority="Zv" test_range="Zv8_NA10942:1,3000" version="8">Zv_8,Scaffold,Danio rerio</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS219" taxid="7955" source="Chromosome" authority="Zv" test_range="11:1,100000" version="8">Zv_8,Chromosome,Danio rerio</COORDINATES>',
                "dnovemcinctus", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS211" taxid="9361" source="Scaffold" authority="dasNov" test_range="scaffold_290450:1,794" version="2">dasNov_2,Scaffold,Dasypus novemcinctus</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS212" taxid="9361" source="Gene Scaffold" authority="dasNov" test_range="GeneScaffold_338:1,100000" version="2">dasNov_2,Gene Scaffold,Dasypus novemcinctus</COORDINATES>',
                "dordii", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS186" taxid="10020" source="Scaffold" authority="dipOrd" test_range="scaffold_209987:1,617" version="1">dipOrd_1,Scaffold,Dipodomys ordii</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS185" taxid="10020" source="Gene Scaffold" authority="dipOrd" test_range="GeneScaffold_338:1,100000" version="1">dipOrd_1,Gene Scaffold,Dipodomys ordii</COORDINATES>',
                "dmelanogaster", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS338" taxid="7227" source="Chromosome" authority="BDGP" test_range="dmel_mitochondrion_genome:1,19517" version="5.13">BDGP_5.13,Chromosome,Drosophila melanogaster</COORDINATES>',
                "etelfairi", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS146" taxid="9371" source="Scaffold" authority="TENREC" test_range="scaffold_290450:1,74978">TENREC,Scaffold,Echinops telfairi</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS172" taxid="9371" source="Gene Scaffold" authority="TENREC" test_range="GeneScaffold_1919:1,100000">TENREC,Gene Scaffold,Echinops telfairi</COORDINATES>',
                "ecaballus", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS120" taxid="9796" source="Chromosome" authority="EquCab" test_range="29:1,100000" version="2">EquCab_2,Chromosome,Equus caballus</COORDINATES>',
                "eeuropaeus", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS147" taxid="9365" source="Scaffold" authority="HEDGEHOG" test_range="scaffold_290450:1,8776">HEDGEHOG,Scaffold,Erinaceus europaeus</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS173" taxid="9365" source="Gene Scaffold" authority="HEDGEHOG" test_range="GeneScaffold_1919:1,100000">HEDGEHOG,Gene Scaffold,Erinaceus europaeus</COORDINATES>',
                "fcatus", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS148" taxid="9685" source="Scaffold" authority="CAT" test_range="scaffold_209987:1,550">CAT,Scaffold,Felis catus</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS174" taxid="9685" source="Gene Scaffold" authority="CAT" test_range="GeneScaffold_338:1,100000">CAT,Gene Scaffold,Felis catus</COORDINATES>',
                "ggallus", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS83" taxid="9031" source="Chromosome" authority="WASHUC" test_range="Un_random:1,100000" version="2">WASHUC_2,Chromosome,Gallus gallus</COORDINATES>',
                "gaculeatus", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS149" taxid="69293" source="Scaffold" authority="BROADS" test_range="scaffold_1446:1,4382" version="1">BROADS_1,Scaffold,Gasterosteus aculeatus</COORDINATES>',
                "ggorilla", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS188" taxid="9593" source="Scaffold" authority="gorGor" test_range="scaffold_427506:5,3516" version="1">gorGor_1,Scaffold,Gorilla gorilla</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS187" taxid="9593" source="Gene Scaffold" authority="gorGor" test_range="GeneScaffold_1919:1,98379" version="1">gorGor_1,Gene Scaffold,Gorilla gorilla</COORDINATES>',
                # 57: "Gorilla_gorilla", "11:31775481-32025480",
                "hsapiens", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS313" taxid="9606" source="Supercontig" authority="GRCh" test_range="GL000197.1:1,37175" version="37">GRCh_37,Supercontig,Homo sapiens</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS311" taxid="9606" source="Chromosome" authority="GRCh" test_range="11:60001,160000" version="37">GRCh_37,Chromosome,Homo sapiens</COORDINATES>',
                "lafricana", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS214" taxid="9785" source="Scaffold" authority="loxAfr" test_range="scaffold_217950:1,868" version="2">loxAfr_2,Scaffold,Loxodonta africana</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS215" taxid="9785" source="Gene Scaffold" authority="loxAfr" test_range="GeneScaffold_338:1,100000" version="2">loxAfr_2,Gene Scaffold,Loxodonta africana</COORDINATES>',
                # 57: "Loxodonta_africana", "scaffold_29:2758508-2782922",
                "mmulatta", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS164" taxid="9544" source="Scaffold" authority="MMUL" test_range="1099213956610:1,713" version="1">MMUL_1,Scaffold,Macaca mulatta</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS63" taxid="9544" source="Chromosome" authority="MMUL" test_range="10:1,100000" version="1">MMUL_1,Chromosome,Macaca mulatta</COORDINATES>',
                "meugenii", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS314" taxid="9315" source="Scaffold" authority="Meug" test_range="Scaffold276715:1,2656" version="1.0">Meug_1.0,Scaffold,Macropus eugenii</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS315" taxid="9315" source="Gene Scaffold" authority="Meug" test_range="GeneScaffold_1919:1,25429" version="1.0">Meug_1.0,Gene Scaffold,Macropus eugenii</COORDINATES>',
                "mmurinus", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS190" taxid="30608" source="Scaffold" authority="micMur" test_range="scaffold_88635:1,1998" version="1">micMur_1,Scaffold,Microcebus murinus</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS189" taxid="30608" source="Gene Scaffold" authority="micMur" test_range="GeneScaffold_338:1,100000" version="1">micMur_1,Gene Scaffold,Microcebus murinus</COORDINATES>',
                "mdomestica", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS101" taxid="13616" source="Chromosome" authority="BROADO" test_range="3:1,100000" version="5">BROADO_5,Chromosome,Monodelphis domestica</COORDINATES>',
                "mmusculus", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS139" taxid="10090" source="Supercontig" authority="NCBIM" test_range="NT_166405:1,100000" version="37">NCBIM_37,Supercontig,Mus musculus</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS108" taxid="10090" source="Chromosome" authority="NCBIM" test_range="11:3000001,3100000" version="37">NCBIM_37,Chromosome,Mus musculus</COORDINATES>',
                "mlucifugus", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS151" taxid="59463" source="Scaffold" authority="MICROBAT" test_range="scaffold_88635:1,1811" version="1">MICROBAT_1,Scaffold,Myotis lucifugus</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS176" taxid="59463" source="Gene Scaffold" authority="MICROBAT" test_range="GeneScaffold_338:1,100000" version="1">MICROBAT_1,Gene Scaffold,Myotis lucifugus</COORDINATES>',
                "oprinceps", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS192" taxid="9978" source="Scaffold" authority="pika" test_range="scaffold_88635:1,5435">pika,Scaffold,Ochotona princeps</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS191" taxid="9978" source="Gene Scaffold" authority="pika" test_range="GeneScaffold_338:1,100000">pika,Gene Scaffold,Ochotona princeps</COORDINATES>',
                "oanatinus", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS152" taxid="9258" source="Supercontig" authority="OANA" test_range="Contig288888:1,858" version="5">OANA_5,Supercontig,Ornithorhynchus anatinus</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS84" taxid="9258" source="Chromosome" authority="OANA" test_range="18:10001,110000" version="5">OANA_5,Chromosome,Ornithorhynchus anatinus</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS171" taxid="9258" source="Ultracontig" authority="OANA" test_range="Ultra81:1,100000" version="5">OANA_5,Ultracontig,Ornithorhynchus anatinus</COORDINATES>',
                "ocuniculus", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS153" taxid="9986" source="Scaffold" authority="RABBIT" test_range="scaffold_88635:1,4717">RABBIT,Scaffold,Oryctolagus cuniculus</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS177" taxid="9986" source="Gene Scaffold" authority="RABBIT" test_range="GeneScaffold_338:1,100000">RABBIT,Gene Scaffold,Oryctolagus cuniculus</COORDINATES>',
                # 57: "Oryctolagus_cuniculus", "scaffold_14:1-221924",
                "olatipes", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS170" taxid="8090" source="Scaffold" authority="MEDAKA" test_range="scaffold7467:1,2623" version="1">MEDAKA_1,Scaffold,Oryzias latipes</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS67" taxid="8090" source="Chromosome" authority="MEDAKA" test_range="11:105700,205699" version="1">MEDAKA_1,Chromosome,Oryzias latipes</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS169" taxid="8090" source="Ultracontig" authority="MEDAKA" test_range="ultracontig237:1,100000" version="1">MEDAKA_1,Ultracontig,Oryzias latipes</COORDINATES>',
                "ogarnettii", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS154" taxid="30611" source="Scaffold" authority="BUSHBABY" test_range="scaffold_44911:1,937" version="1">BUSHBABY_1,Scaffold,Otolemur garnettii</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS178" taxid="30611" source="Gene Scaffold" authority="BUSHBABY" test_range="GeneScaffold_338:1,100000" version="1">BUSHBABY_1,Gene Scaffold,Otolemur garnettii</COORDINATES>',
                "ptroglodytes", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS68" taxid="9598" source="Chromosome" authority="CHIMP" test_range="11:142549,242548" version="2.1">CHIMP_2.1,Chromosome,Pan troglodytes</COORDINATES>',
                "ppygmaeus", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS123" taxid="9600" source="Chromosome" authority="PPYG" test_range="18_random:1,100000" version="2">PPYG_2,Chromosome,Pongo pygmaeus</COORDINATES>',
                "pcapensis", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS194" taxid="9813" source="Scaffold" authority="proCap" test_range="scaffold_290450:1,1025" version="1">proCap_1,Scaffold,Procavia capensis</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS193" taxid="9813" source="Gene Scaffold" authority="proCap" test_range="GeneScaffold_338:1,100000" version="1">proCap_1,Gene Scaffold,Procavia capensis</COORDINATES>',
                "pvampyrus", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS196" taxid="132908" source="Scaffold" authority="pteVam" test_range="scaffold_44911:1,1975" version="1">pteVam_1,Scaffold,Pteropus vampyrus</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS195" taxid="132908" source="Gene Scaffold" authority="pteVam" test_range="GeneScaffold_338:1,100000" version="1">pteVam_1,Gene Scaffold,Pteropus vampyrus</COORDINATES>',
                "rnorvegicus", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS31" taxid="10116" source="Chromosome" authority="RGSC" test_range="7:1,100000" version="3.4">RGSC_3.4,Chromosome,Rattus norvegicus</COORDINATES>',
                "scerevisiae", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS85" taxid="4932" source="Chromosome" authority="SGD" test_range="I:1,100000" version="1.01">SGD_1.01,Chromosome,Saccharomyces cerevisiae</COORDINATES>',
                "saraneus", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS159" taxid="42254" source="Scaffold" authority="COMMON_SHREW" test_range="scaffold_217950:1,5395" version="1">COMMON_SHREW_1,Scaffold,Sorex araneus</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS179" taxid="42254" source="Gene Scaffold" authority="COMMON_SHREW" test_range="GeneScaffold_338:1,100000" version="1">COMMON_SHREW_1,Gene Scaffold,Sorex araneus</COORDINATES>',
                "stridecemlineatus", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS160" taxid="43179" source="Scaffold" authority="SQUIRREL" test_range="scaffold_88635:1,15987">SQUIRREL,Scaffold,Spermophilus tridecemlineatus</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS180" taxid="43179" source="Gene Scaffold" authority="SQUIRREL" test_range="GeneScaffold_338:1,100000">SQUIRREL,Gene Scaffold,Spermophilus tridecemlineatus</COORDINATES>',
                "sscrofa", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS341" taxid="9823" source="Chromosome" authority="Sscrofa" test_range="11:1,100000" version="9">Sscrofa_9,Chromosome,Sus scrofa</COORDINATES>',
                "tguttata", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS216" taxid="59729" source="Chromosome" authority="taeGut" test_range="23_random:1,100000" version="3.2.4">taeGut_3.2.4,Chromosome,Taeniopygia guttata</COORDINATES>',
                "trubripes", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS157" taxid="31033" source="Scaffold" authority="FUGU" test_range="scaffold_1:1,100000" version="4">FUGU_4,Scaffold,Takifugu rubripes</COORDINATES>',
                "tsyrichta", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS198" taxid="9478" source="Scaffold" authority="tarSyr" test_range="scaffold_427506:1,1274" version="1">tarSyr_1,Scaffold,Tarsius syrichta</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS197" taxid="9478" source="Gene Scaffold" authority="tarSyr" test_range="GeneScaffold_1919:1,13660" version="1">tarSyr_1,Gene Scaffold,Tarsius syrichta</COORDINATES>',
                "tnigroviridis", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS165" taxid="99883" source="Chromosome" authority="TETRAODON" test_range="11:500001,600000" version="8">TETRAODON_8,Chromosome,Tetraodon nigroviridis</COORDINATES>',
                "tbelangeri", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS166" taxid="37347" source="Scaffold" authority="TREESHREW" test_range="scaffold_88635:1,4424">TREESHREW,Scaffold,Tupaia belangeri</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS181" taxid="37347" source="Gene Scaffold" authority="TREESHREW" test_range="GeneScaffold_338:1,100000">TREESHREW,Gene Scaffold,Tupaia belangeri</COORDINATES>',
                "ttruncatus", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS200" taxid="9739" source="Scaffold" authority="turTru" test_range="scaffold_44911:1,1346" version="1">turTru_1,Scaffold,Tursiops truncatus</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS199" taxid="9739" source="Gene Scaffold" authority="turTru" test_range="GeneScaffold_338:1,100000" version="1">turTru_1,Gene Scaffold,Tursiops truncatus</COORDINATES>',
                "vpacos", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS184" taxid="30538" source="Scaffold" authority="vicPac" test_range="scaffold_290450:1,729" version="1">vicPac_1,Scaffold,Vicugna pacos</COORDINATES><COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS201" taxid="30538" source="Gene Scaffold" authority="vicPac" test_range="GeneScaffold_338:1,100000" version="1">vicPac_1,Gene Scaffold,Vicugna pacos</COORDINATES>',
                "xtropicalis", '<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS158" taxid="8364" source="Scaffold" authority="JGI" test_range="scaffold_1:1,100000" version="4.1">JGI_4.1,Scaffold,Xenopus tropicalis</COORDINATES>'
	);

        my $dasRegistry .= qq/<?xml version=\"1.0\" standalone=\"yes\"?>
        <SOURCES>/;

        my %dataset2assembly = $self->getAssemblies(%OPTIONS);

        foreach my $datasetName (@{$OPTIONS{'dasDatasets'}})
        {
                # datasetName is something like default__tguttata_gene_ensembl__ensembl_das_gene
                my @datasetChops = split('_', $datasetName);
                my $autoconfDSN = $dataset2assembly{ $datasetChops[2] };

                if ($datasetChops[8] eq 'chr') {
			$autoconfDSN .= '.reference';
                } elsif ($datasetChops[8] eq 'gene') {
                        # $autoconfDSN .= '.transcript';
			# We are not interesting in the gene view for now...
			next;
                } else {
                        # Woops..
		}

#<SOURCE uri="ENSEMBL_1_GRCh37" title="Homo_sapiens.GRCh37.reference" description="Homo_sapiens Reference server based on GRCh37 assembly. Contains 93 top level entries.">
#<MAINTAINER    email="helpdesk@ensembl.org" />
#<VERSION       uri="ENSEMBL_1_GRCh37" created="2010-02-25">
#<PROP name="label" value="ENSEMBL" />
#<COORDINATES uri="http://www.dasregistry.org/dasregistry/coordsys/CS_DS311" taxid="9606" source="Chromosome" authority="GRCh" test_range="11:60001,160000" version="37">GRCh_37,Chromosome,Homo sapiens</COORDINATES>
#<CAPABILITY  type="das1:features" query_uri="http://www.ensembl.org/das/Homo_sapiens.GRCh37.reference/features"     />
#</VERSION>
#</SOURCE> 

#		if ($OPTIONS{server_port}) {
		$dasRegistry .= qq/<SOURCE uri=\"$datasetName\" title=\"pubmed2ensembl\" description=\"www.pubmed2ensembl.org -- linking publications and genes\">
			<MAINTAINER email=\"joachim.baran\\\@manchester.ac.uk\" \/>
			<VERSION uri=\"$datasetName\" created=\"2010-05-03\">
				<PROP name=\"label\" value=\"pubmed2ensembl\" \/>
				$defaultCoordinates{ $datasetChops[2] }
				<CAPABILITY type=\"das1:features\" query_uri=\"http:\/\/pubmed2ensembl56.smith.man.ac.uk\/biomart\/das\/$datasetName\/features\" \/>
			<\/VERSION>
		<\/SOURCE>
		/;
		#               } else {
#	                $dasRegistry .= qq/<DSN>
#			<SOURCE id=\"$datasetName\" version=\"$OPTIONS{ensversion}\">$OPTIONS{enssourcename}<\/SOURCE>
#			<MAPMASTER>http:\/\/sep2009.archive.ensembl.org\/das\/$autoconfDSN<\/MAPMASTER>
#			<DESCRIPTION>BioMart dataset $datasetName<\/DESCRIPTION>
#		<\/DSN>
#		/;
#		}

	}
        $dasRegistry .= qq /<\/SOURCES>/;
		        
        $fileContents =~ s/\[TAG:dasSources\]/$dasRegistry/m;

        $sourcesFile = $OPTIONS{cgibin}."/sources";
        open(STDSOURCES, ">$sourcesFile");      
        print STDSOURCES $fileContents;
        close(STDSOURCES);
        chmod 0755, $sourcesFile;
}       

sub makeMartSoap
{
	my ($self, %OPTIONS) = @_;
	my $mart_registry = $OPTIONS{registryObj};
	undef $/; ## whole file mode for read
	my $file = $OPTIONS{cgibin}."/martsoap.PLS";	
	open(STDMARTSERVICE, "$file");	
	my $fileContents = <STDMARTSERVICE> ;
	close(STDMARTSERVICE);
	#print $fileContents;
	##---------------- replacing [TAG:lib]
	my $libPaths;
	if ($OPTIONS{libdirs})
	{
		foreach my $path(@{$OPTIONS{libdirs}})
		{	
			$libPaths .= qq/use lib "$path";\n/;
		}
	}
	$fileContents =~ s/\[TAG:lib\]/$libPaths/m;

	##---------------- replacing [TAG:conf]
	if ($OPTIONS{conf})
	{
		my $confFile = qq/\$CONF_FILE = '$OPTIONS{conf}';\n/; 
		$fileContents =~ s/\[TAG:conf\]/$confFile/m;
	}

	##---------------- replacing [TAG:server_host]
	if ($OPTIONS{server_host})
	{
		my $server_host = qq/\$server_host = '$OPTIONS{server_host}';\n/; 
		$fileContents =~ s/\[TAG:server_host\]/$server_host/m;
	}

	##---------------- replacing [TAG:cgiLocation]
	if ($OPTIONS{cgiLocation})
	{
		my $cgiLocation = qq/\$cgiLocation = '$OPTIONS{cgiLocation}';\n/; 
		$fileContents =~ s/\[TAG:cgiLocation\]/$cgiLocation/m;
	}

	##---------------- replacing [TAG:server_port]
	if ($OPTIONS{server_port})
	{
		my $server_port;
		if($OPTIONS{proxy}) 
		{
			$server_port = qq/\$server_port = '$OPTIONS{proxy}';\n/; 
		}
		else
		{
			$server_port = qq/\$server_port = '$OPTIONS{server_port}';\n/; 
		}
			
		$fileContents =~ s/\[TAG:server_port\]/$server_port/m;

	}
	
	##---------------- replacing [TAG:log_dir]
	my $logDir = qq/\$log_Dir = '$OPTIONS{logDir}';\n/;
	$fileContents =~ s/\[TAG:log_dir\]/$logDir/m;

	$fileContents =~ s/\[TAG:IF_ONTOLOGY_TERMS\]//m;

	$file = $OPTIONS{cgibin}."/martsoap";
	open(STDMARTSERVICE, ">$file");	
	print STDMARTSERVICE $fileContents;
	close(STDMARTSERVICE);

	chmod 0755, $file;		
}

sub makeMartWSDL
{
	my ($self, %OPTIONS) = @_;
	undef $/; ## whole file mode for read
	my $file = $OPTIONS{cgibin}."/martwsdl.PLS";	
	open(STDMARTRES, "$file");	
	my $fileContents = <STDMARTRES> ;
	close(STDMARTRES);
	#print $fileContents;
	
	##---------------- replacing [TAG:server_host]
	if ($OPTIONS{server_host})	{		
		$fileContents =~ s/\[TAG:server_host\]/$OPTIONS{server_host}/mg;
	}

	##---------------- replacing [TAG:cgiLocation]
	if ($OPTIONS{cgiLocation})	{
		$fileContents =~ s/\[TAG:cgiLocation\]/$OPTIONS{cgiLocation}/mg;
	}

	##---------------- replacing [TAG:server_port]
	if ($OPTIONS{server_port})
	{
		my $server_port;
		if($OPTIONS{proxy}) {
			$fileContents =~ s/\[TAG:server_port\]/$OPTIONS{proxy}/mg;
		}
		else {
			$fileContents =~ s/\[TAG:server_port\]/$OPTIONS{server_port}/mg;
		}
	}

	##---------------- replacing [TAG:xx]
	$fileContents =~ s/\[TAG:IF_ONTOLOGY_TERMS_OPERATION\]//mg;
	$fileContents =~ s/\[TAG:IF_ONTOLOGY_TERMS_PORTTYPE\]//mg;
	$fileContents =~ s/\[TAG:IF_ONTOLOGY_TERMS_MESSAGE\]//mg;
	
	$file = $OPTIONS{cgibin}."/martwsdl";	
	open(STDMARTRES, ">$file");	
	print STDMARTRES $fileContents;
	close(STDMARTRES);

	chmod 0755, $file;
}

sub makeMartXSD
{
	my ($self, %OPTIONS) = @_;
	undef $/; ## whole file mode for read
	my $file = $OPTIONS{cgibin}."/martxsd.PLS";	
	open(STDMARTRES, "$file");	
	my $fileContents = <STDMARTRES> ;
	close(STDMARTRES);
	#print $fileContents;
	##---------------- replacing [TAG:server_host]
	if ($OPTIONS{server_host})	{		
		$fileContents =~ s/\[TAG:server_host\]/$OPTIONS{server_host}/mg;
	}

	##---------------- replacing [TAG:cgiLocation]
	if ($OPTIONS{cgiLocation})	{
		$fileContents =~ s/\[TAG:cgiLocation\]/$OPTIONS{cgiLocation}/mg;
	}

	##---------------- replacing [TAG:server_port]
	if ($OPTIONS{server_port})
	{
		my $server_port;
		if($OPTIONS{proxy}) {
			$fileContents =~ s/\[TAG:server_port\]/$OPTIONS{proxy}/mg;
		}
		else {
			$fileContents =~ s/\[TAG:server_port\]/$OPTIONS{server_port}/mg;
		}
	}

	##---------------- replacing [TAG:xx]
	$fileContents =~ s/\[TAG:IF_ONTOLOGY_TERMS\]//mg;
	
	$file = $OPTIONS{cgibin}."/martxsd";	
	open(STDMARTRES, ">$file");	
	print STDMARTRES $fileContents;
	close(STDMARTRES);

	chmod 0755, $file;
}

sub makeCopyDirectories
{
	my ($self, %OPTIONS) = @_;
	
	my $path = $OPTIONS{htdocs}.'/'.$OPTIONS{cgiLocation}.'/mview/';
	
	system("mkdir -p $path");
		
	my $source = $OPTIONS{htdocs}.'/martview/*';
	my $destination = $path;
	system("cp -r $source $destination");
	
#	print "\nPATH:  ",$path, "\n";
#	print "\nSOURCE:  ",$source, "\n";
	
}

sub printOptions
{
	my ($self, %OPTIONS) = @_;	
	foreach my $key (keys %OPTIONS)
	{
		if($key eq 'modules_in_dist' || $key eq 'libdirs')
		{
			print "\n", $key, " \t\t>>>> ", @{$OPTIONS{$key}}, "\n";
		}
		else
		{
			print "\n", $key, " \t\t>>>> ", $OPTIONS{$key}, "\n";
		}
	}

}

1;
