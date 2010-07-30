#!/usr/bin/perl -w

#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

CGI-script to handle BioMart background job retrievals.

This simple CGI checks to see if the file exists yet.
If it does, it looks up the mime type of that file, and
pipes it back to the user appropriately.
If it does not, it puts up a simple message saying so.

=head1 AUTHOR - Arek Kasprzyk, Syed Haider, Richard Holland, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


use strict;
use warnings;

#the TAG:lib below gets replaced by OPTIONS{lib}, from user's PERL5LIB
[TAG:lib]


use vars qw/ $VERSION $revision $CONF_FILE $LOGGER $WEBQUERY $BIOMART_REGISTRY/;

use CGI;
use BioMart::Web::SiteDefs;
use File::Path;
use File::Basename qw(dirname basename);


my $CGI = $ENV{MOD_PERL} ? CGI->new(shift @_) : CGI->new();

my $background_file = $CGI->param('file');

my $background_dir;
my $mart_registry = $main::BIOMART_REGISTRY;
my $hash = $mart_registry->settingsParams();
foreach(keys %$hash) {     	
     if($_ eq "background") {
     	foreach my $param (keys %{$hash->{$_}}) {
    			#print "\n\t\t\t$param \t", $hash->{$_}->{$param};
    			if($param eq "resultsDir1") {
    				$background_dir = $hash->{$_}->{$param};
    			}
    		}
    	}
}
$background_dir.='/';

if (-e $background_dir.$background_file) {	 
  
	open (MIME, '<'.$background_dir.$background_file.'.mime');
	my $mime_type = <MIME>;
	close (MIME);
	
	open (BINMODE, '<'.$background_dir.$background_file.'.binmode');
	my $binmode = <BINMODE>;
	close (BINMODE);
	
	print $CGI->header(-type=>$mime_type,
		-attachment=>$background_file);
		
	open (FH, '<'.$background_dir.$background_file);
	if ($binmode) {
		binmode STDOUT;
	}
	while (<FH>) { print STDOUT $_; }
	close (FH);
	
} else {

	print $CGI->header(-type=>'text/html');
	print qq{
		<html>
		<body>
		<p>The results file $background_file is not ready yet.</p>
		<p>You will be emailed when the results are ready.</p>
		</body>
		</html>
	};
	
}

exit 0;

### END OF MAIN PROGRAM ###
