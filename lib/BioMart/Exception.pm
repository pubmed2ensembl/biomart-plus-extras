# $Id: Exception.pm,v 1.3 2008-04-09 12:52:33 syed Exp $

=head1 NAME

BioMart::Exception - Exceptions thrown by BioMart library modules

=head1 SYNOPSIS

   # In library code
   use BioMart::Exception;
   if('something goes horribly wrong in database-query') {
      BioMart::Exception::Database->throw('this query is busted');
   }

   # In calling code
   use BioMart::Exception;
   eval{ 'attempt to execute prepared Mart-query' };
   my $e;
   if($e = Exception::Class->caught('BioMart::Exception::Database')) {
      print "caught db-error";
      # do something about error, if possible
   }

=head1 DESCRIPTION

BioMart::Exception defines in a single module all exceptions thrown by the BioMart
modules. This is done in very few lines of code via the Exception::Class module
(see POD at http://search.cpan.org/~drolsky/Exception-Class/).
  Even though the 'automagic' framework is used, one can still do interesting things
like attach filehandles or db-statement handles to the exception before throwing it.
This may make it easier for the calling code to handle the exception.

=head1 AUTHOR -  Arek Kasprzyk, Syed Haider, Richard Holland, Damian Smedley, Gudmundur Arni Thorisson

=head1 EXCEPTION CLASSES

=head2 BioMart::Exception::Configuration

Error related to Mart configuration, such as attempts to retrieve a non-existing
filter from a dataset config-tree or adding an undefined filter to a query.

=head2 BioMart::Exception::Database

Error related to a Mart database connection, such as incorrect db-connection
parameters or bad SQL-statement.

=head2 BioMart::Exception::Template

Error related to MartView templating system, such as a syntax error in a template
or other problem relating to processing a template

=cut

package BioMart::Exception;

use Exception::Class (
  'BioMart::Exception',
   BioMart::Exception::Configuration => {
        isa         => 'BioMart::Exception',
        description => 'Error in BioMart configuration'
   },
   BioMart::Exception::Template => {
        isa         => 'BioMart::Exception',
        description => 'Error in MartView templating system'
   },
   BioMart::Exception::Database => {
        isa         => 'BioMart::Exception',
        description => 'Error in BioMart database connection or statement',
	fields      => ['dbh','sth'],
   },
   BioMart::Exception::Query => {
        isa         => 'BioMart::Exception',
        description => 'Error in building or executing Mart query',
	fields      =>['query'],
   },
   BioMart::Exception::Formatting => {
        isa        => 'BioMart::Exception',
        description => 'Error in output formatting'
   },
   BioMart::Exception::Session => {
        isa        => 'BioMart::Exception',
        description => 'Error in retrieving or storing a user session'
   },
   BioMart::Exception::Usage => {
        isa        => 'BioMart::Exception',
        description => 'Error in usage of API'
   },	
);

Exception::Class::Base->Trace(1);

1;

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.
Please report problems to BioMart development mailing list  (<mart-dev@ebi.ac.uk>)
Patches are welcome.

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 AUTHOR

Gudmundur A. Thorisson  <mummi@cshl.edu>

=head1 LICENCE AND COPYRIGHT

Copyright (c) <year> <copyright holder> (<contact address>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 

=cut
