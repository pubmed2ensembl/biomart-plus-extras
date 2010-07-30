# $Id: 
#
# BioMart module for BioMart::Configuration::URLLocation
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

BioMart::Configuration::URLLocation

=head1 SYNOPSIS

A Location that represents the configuration for a mart database accessed
via a mart server

=head1 DESCRIPTION



=head1 AUTHOR - Arek Kasprzyk, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


package BioMart::Configuration::URLLocation;

use strict;
use warnings;
use LWP::UserAgent;
use Log::Log4perl;

use base qw(BioMart::Configuration::Location);


=head2 _new

  Usage      : see Usage for BioMart::Configuration::Location.
  Description: creates a new MartURLLocation object which ...
  Returntype : BioMart::Configuration::MartURLLocation
  Exceptions : none
  Caller     : general

=cut

sub _new {
  my ($self, @param) = @_;
  $self->SUPER::_new(@param);
 
  $self->dsn("http://".$self->host.":".$self->port.$self->path."?");
    
}


sub getResultSet {

    my ($self, $qualifier,$type,$xml)=@_;
    
    if (!defined $xml){$xml=""}  # no uninitilized warning


    my $logger=Log::Log4perl->get_logger(__PACKAGE__);
    my $request;
    if ($type eq "POST"){

     $logger->warn("POST: ", $self->dsn," query=$xml");
   
     $request = HTTP::Request->new($type,$self->dsn,
				      HTTP::Headers->new(),'query='.$xml."\n");
    } elsif ($type eq "GET") {

         $qualifier=$qualifier."&requestid=biomart-client";
         $logger->warn("GET: ", $self->dsn," $qualifier");

	$request = HTTP::Request->new($type,$self->dsn.$qualifier);
    } else {
	BioMart::Exception::Query->throw("need a valid request type: GET or POST");    
    }

	my $ua = LWP::UserAgent->new;
	$ua->timeout(20); # default is 180 seconds
    $ua->proxy( ['http', 'https'], $self->proxy ) if defined $self->proxy;
    my $response = $ua->request($request);
    
    my @results;
    
    if ($response->is_success) {
	my @arr=split(/\n/,$response->content); # much neater to use 'content' instead of 'as_string', we don't need to explicitly ignore header part of the http response any more.
	foreach my $el(@arr){         
	    $logger->warn("RESPONSE:  $el");
	    push (@results,$el);
	}
	
    }  else {
	warn ("\n\nProblems with the web server: ".
	      $response->status_line."\n\n");
    }

    return @results;   
}


1;
