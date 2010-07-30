#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR - Arek Kasprzyk, Syed Haider

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut

package bin::ExecuteConfigureBioMartBuilder;

use strict;
use Cwd;
use English;

sub executeSystemCommand
{
#	print "\nFINAL COMMAND: $ARG[1]\n";
	my $command = Cwd::cwd.'/bin/'.$ARG[1];
#	print "\nFINAL COMMAND: $command\n";
	system("perl $command");	
}

1;
