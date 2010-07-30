#!/usr/bin/perl -w

#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

CGI-script to handle BioMart requests. Scripts does initialization
of essential objects, checks if some things already initialized &
persistent in memory (ModPerl) and then passes the request to the
main BioMart::Web class which does all the work.

=head1 AUTHOR - Syed Haider, Gudmundur Arni Thorisson

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


#the TAG:lib below gets replaced by OPTIONS{lib}, from user's PERL5LIB
[TAG:lib]

use strict;
use warnings;
use Config;
use Log::Log4perl;
use File::Basename qw(&basename &dirname);
use Data::Dumper;
use CGI;
use BioMart::Web;
use BioMart::Exception;

use vars qw/ $VERSION $revision $CONF_FILE $LOGGER $WEBQUERY $BIOMART_REGISTRY/;

#the TAG:conf below gets replaced by OPTIONS{conf}, path to registry file
[TAG:conf]

# Initialize master logger for this wrapper script, but only if it's not defined
# already. Other components of system will use the same logger-setup but with 
# different configurations.
if(!defined($LOGGER)) {
    Log::Log4perl->init(dirname($CONF_FILE) . '/log4perl.conf');
    my $script = basename($0);
    $LOGGER = Log::Log4perl->get_logger($script);
    $LOGGER->debug("initialized logger for $script");
}
else {
    $LOGGER->debug("Using existing logger $LOGGER");
}

my $CGI = $ENV{MOD_PERL} ? CGI->new(shift @_) : CGI->new();

# removing hacking attempts using script tags
$CGI->param($_,map{/<script/?q():$_}$CGI->param($_))for $CGI->param;

  
# Initialize BioMart::Web if not already present via mod_perl persistance. Use global,
# persistent Mart registry if that's available from the parent process.

my $registry;
if (!$main::BIOMART_REGISTRY){
	my $ex = Exception::Class->caught('BioMart::Exception');
	if(!$ex) {
	$ex = BioMart::Exception->new('non-BioMart die(): '.'please run configure.pl following the instructions from file INSTALL');
    }
} 
else {
	$registry = $main::BIOMART_REGISTRY;
}

if(!$WEBQUERY)
{
	$WEBQUERY = BioMart::Web->new(conf     => $CONF_FILE,
							   registry => $registry);
}
else 
{
    $LOGGER->debug("Using existing BioMart::Web object");
}


# Pass request object to the main method of webquery-class

eval {
    $WEBQUERY->handle_request($CGI);
};

if($@) {
    my $ex = Exception::Class->caught('BioMart::Exception');
    if(!$ex) {
	$ex = BioMart::Exception->new('non-BioMart die(): '.$@);
    }
    my $errmsg = "ERROR: caught ".ref($ex) . ": " . $ex->error();
    my $tracestring = '';
 
    # Only build a trace message if this is not a user-exception
    if(ref($ex) ne 'BioMart::Exception::Usage') {
	$tracestring = "Stacktrace:\n";
	my $trace = $ex->trace();
	while (my $frame = $trace->next_frame())
	{
	    $tracestring .= '  ' . $frame->subroutine() 
	                  . '  ' . $frame->filename()  
			  . ':'  . $frame->line() . "\n";
	}
    }
    $LOGGER->error_warn($errmsg."\n".$tracestring);
    $errmsg      =~ s/\n/<br \/>/g;
    $tracestring =~ s/\n/<br \/>/g;
    print $CGI->header();
    print $WEBQUERY->process_template("error.tt",
				      {errmsg      => $errmsg,
				       tracestring => $tracestring
				       });
}

exit 0;

### END OF MAIN PROGRAM ###
