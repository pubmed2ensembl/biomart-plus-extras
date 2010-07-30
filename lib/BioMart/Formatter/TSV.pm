# $Id: TSV.pm,v 1.3 2007-01-09 17:16:00 rh4 Exp $
#
# BioMart module for BioMart::Formatter::TSV
#
# You may distribute this module under the same terms as perl
# itself.

# POD documentation - main docs before the code.

=head1 NAME

BioMart::Formatter::TSV

=head1 SYNOPSIS

The TSV Formatter returns tab separated tabular data
for a BioMart query's ResultTable

=head1 DESCRIPTION

When given a BioMart::ResultTable containing the results of 
a BioMart::Query the TSV Formatter will return tabular output
with one line for each row of data in the ResultTable and tabs
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

package BioMart::Formatter::TSV;

use strict;
use warnings;

# Extends BioMart::FormatterI
use base qw(BioMart::FormatterI);
use Readonly;

# Constants
Readonly my $FIELD_DELIMITER  => qq{\t};
Readonly my $RECORD_DELIMITER => qq{\n};

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
    # Escape delimiters in value-strings
    foreach(@{$row}) {
	$_ = q{} unless defined ($_);
	$_ =~ s/$FIELD_DELIMITER/\$FIELD_DELIMITER/g;
    }
    
    # Create the final record-string
    return join($FIELD_DELIMITER, @{$row}) . $RECORD_DELIMITER;
}

sub getDisplayNames {
    my $self = shift;
    my @displayNames = $self->getTextDisplayNames();

    # Enclose non-numeric values in double quotes & escape the quotes already in them
    map { s/$FIELD_DELIMITER/\$FIELD_DELIMITER/g } @displayNames;
    
    # Create the final header string
    return join($FIELD_DELIMITER, @displayNames) . $RECORD_DELIMITER;
}

1;



