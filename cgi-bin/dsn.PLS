#!/usr/bin/perl -w

#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR - Syed Haider

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut


use strict;
use warnings;
use Log::Log4perl;
use Data::Dumper;
use CGI;
use BioMart::Exception;




my $CGI = $ENV{MOD_PERL} ? CGI->new(shift @_) : CGI->new();

# this gets replaced with the list of possible DAS resources
my $dasSources = qq([TAG:dasSources]);


print $CGI->header(	-'type' =>'text/xml',
								-'X-DAS-Version' => 'DAS/1.5',
								-'X-DAS-Status'  => '200',
								-'X-DAS-Capabilities' => 'dsn/1.0; features/1.0;');
print $dasSources;



