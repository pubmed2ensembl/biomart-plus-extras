# $Id: CSV.pm,v 1.3 2007-01-09 17:16:00 rh4 Exp $
#
# BioMart module for BioMart::Formatter::CSV
#
# You may distribute this module under the same terms as perl
# itself.

# POD documentation - main docs before the code.

=head1 NAME

BioMart::Formatter::CSV

=head1 SYNOPSIS

The CSV Formatter returns comma separated tabular data
for a BioMart query's ResultTable

=head1 DESCRIPTION

When given a BioMart::ResultTable containing the results of 
a BioMart::Query the CSV Formatter will return tabular output
with one line for each row of data in the ResultTable and commas
separating the individual entries in each row. The getDisplayNames
and getFooterText can be used to return appropiately formatted
headers and footers respectively


=head1 AUTHORS 

=over

=item *
Damian Smedley

=back

=head1 CONTACT

This module is part of the BioMart project
http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut

package BioMart::Formatter::CSV;

use strict;
use warnings;
use Readonly;

# Extends BioMart::FormatterI
use base qw(BioMart::FormatterI);

# Constants
Readonly my $FIELD_DELIMITER  =>  q{,};
Readonly my $RECORD_DELIMITER => qq{\n};
Readonly my $FIELD_ENCLOSER   => qq{\"};

sub _new {
    my ($self) = @_;

    $self->SUPER::_new();
}

sub processQuery {
    my ($self, $query) = @_;

    $self->set('original_attributes',[@{$query->getAllAttributes()}]) 
	if ($query->getAllAttributes());
    $self->set('query',$query);
    return $query;
}

sub nextRow {
    my $self = shift;
    
    my $rtable = $self->get('result_table');
    my $row = $rtable->nextRow;
    if (!$row){
        return;
    }

    # Enclose non-numeric values in double quotes & escape the quotes already in them
    foreach(@{$row}) {
	$_ = q{} unless defined ($_);
	if($_ !~ /\A[\d\.]+\z/ && $_ =~ /$FIELD_DELIMITER/) {
	    $_ =~ s/$FIELD_ENCLOSER/\$FIELD_ENCLOSER/g;
  	    $_ = $FIELD_ENCLOSER . $_ . $FIELD_ENCLOSER;
 	}
    }
    
    # Create the final record-string
    return join($FIELD_DELIMITER, @{$row}) . $RECORD_DELIMITER;
}

sub getDisplayNames {
    my $self = shift;
    my @displayNames = $self->getTextDisplayNames();

    # Enclose non-numeric values in double quotes & escape the quotes already in them
    foreach(@displayNames) {
	if($_ !~ /\A[\d\.]+\z/ && $_ =~ /$FIELD_DELIMITER/) {
	    $_ =~ s/$FIELD_ENCLOSER/\$FIELD_ENCLOSER/g;
  	    $_ = $FIELD_ENCLOSER . $_ . $FIELD_ENCLOSER;
 	}
    }

    # Create the final header string
    return join($FIELD_DELIMITER, @displayNames) . $RECORD_DELIMITER;
}

1;



