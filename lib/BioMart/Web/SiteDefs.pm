# $Id: SiteDefs.pm,v 1.2 2008-04-09 12:52:34 syed Exp $
#
# BioMart module for BioMart::SiteDefs
#
# You may distribute this module under the same terms as perl
# itself.

# POD documentation - main docs before the code.

=head1 NAME

BioMart::Web::SiteDefs

=head1 SYNOPSIS

TODO: Synopsis here.

=head1 DESCRIPTION

Defines constants used throughout BioMart for things like URL prefixes.
Loads these from a file called settings.conf in the same location as
the registry XML file. If file not found, defaults are used.

=head1 AUTHOR - Syed Haider, Richard Holland

=head1 CONTACT

This module is part of the BioMart project
http://www.ebi.ac.uk/biomart

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut

package BioMart::Web::SiteDefs;

use strict;
use warnings;

my %settings = ();

sub getSettings {
	my ($self, $confDir) = @_;
	if($confDir) ## undefined expected from formatterI as it has no concept of conf dir
	{
		$self->configure($confDir);	
	}
	#return (exists $settings{$group}) ? %{$settings{$group}} : ();
	return \%settings;

}

sub configure {
	my ($self, $confDir) = @_;

	my $confFile = $confDir."/settings.conf";
	if (-e $confFile) {	
		open(FH, "<".$confFile) || return; # Ignore if can't read.
		my $currHash = undef;
		while (<FH>) {
			# Have to do split because of weird newline stuff.
			foreach (split("\n")) {
				s/^\s+//; # Strip leading whitespace
				s/\s+$//; # Strip trailing whitespace
				s/^#.*//; # Strip comments.
				m/^.+$/ or next; # Skip blank lines.
				m/^\[\s*(.*?)\s*\]$/ and $currHash = $1; # New section?
				$currHash and m/^(.*?)\s*=\s*(.*)$/ and $settings{$currHash}{$1}=$2; # Key=value
			}
		}
		close(FH);
	}
}

1;
