package Bio::Das::ProServer::SourceAdaptor::biomart;

#   $Id: biomart.pm,v 1.1.1.1 2006-11-22 20:30:59 arek Exp $

use strict;
use warnings;

use base qw(Bio::Das::ProServer::SourceAdaptor);

use BioMart::Query;
use BioMart::QueryRunner;
use BioMart::Initializer;

use constant INIT_BATCHSIZE => 100;      # batch all with 100 initially
use constant MAX_BATCHSIZE  => 100000;

use constant DEFAULTVSCHEMA => "default";
use constant VIRTUALSCHEMA  => "virtualSchema";
use constant DATASET        => "dataset";
use constant MART           => "mart";
use constant LINKNAME       => "linkName";
use constant FEATUREKEYS    => "feature_keys";

use constant REQPARAMS =>
  [ DATASET, VIRTUALSCHEMA, MART, LINKNAME, FEATUREKEYS ];

use constant DEFAULTS => { 'start' => 0, 'end' => 0 };
use constant REQUIREDKEYS => [ "id", "type", "method" ];

sub init
{
    my ($self) = @_;
    $self->{'capabilities'}{'features'} = '1.0';

    # Place other initialization code here.  For BioMart I
    # would suggest that persistant data be stored beneath
    # $self->{'BioMart'}.
    my $biomart = $self->{'BioMart'};

    my $confPath = $self->config()->{'registryPath'}
      || die "BioMart DAS requires the path to a Configuration File "
      . "using the registryPath ini entry\n";

    # The configuration options from the ini-file may be
    # referenced through $self->config()->{'option'}, where
    # "option" is the key of the key-value pair in the ini-file.

    my $reqParams = REQPARAMS;
    foreach my $title ( @{$reqParams} ) {
        $biomart->{$title} = $self->config()->{$title};
    }

    die "BioMart DAS requires a mart and dataset in the ini file\n"
      unless ( defined( $biomart->{'mart'} )
        && defined( $biomart->{'dataset'} )
        && defined( $biomart->{'linkName'} )
        && defined( $biomart->{'feature_keys'} ) );

    unless ( defined( $biomart->{'virtualSchema'} ) ) {
        $biomart->{'virtualSchema'} = DEFAULTVSCHEMA;
    }

    # Remap the comma separated list in feature_keys to an actual
    # arrayref.
    $biomart->{'feature_keys'} =
      [ ( split /,/, $biomart->{'feature_keys'} ) ];

    my $initializer =
      BioMart::Initializer->new( 'registryFile'=>"$confPath", 
      	'init_batchsize'=>INIT_BATCHSIZE,
        'max_batchsize'=>MAX_BATCHSIZE,
        'action'=>"update")
      or die "Could not load Initializer $!\n";

    $biomart->{'registry'} = $initializer->getRegistry();

    # Now make sure the DatasetConfig has the required
    # Exportable/Importable.
    my $dataset =
      $biomart->{'registry'}
      ->getDatasetByName( $biomart->{'virtualSchema'},
        $biomart->{'dataset'} );

    my @importables = @{$dataset->getImportables( $biomart->{'linkName'} )};
    my @exportables = @{$dataset->getExportables( $biomart->{'linkName'} )};

    die "BioMart DAS Configuration must include an "
      . "Importable-Exportable pair named by "
      . $biomart->{'linkName'} . "\n"
      unless ( @importables && @exportables );

    # Make sure importable and exportable are compliant.
    print keys(%{$importables[0]})."\n";
    my $filts = $importables[0]->getAllFilters();

    die "BioMart DAS Compliant Importables "
      . "must contain at least one filter\n"
      unless ( scalar( @{$filts} ) >= 1 );

    foreach my $filt ( @${filts} ) {
        warn( "Recieved filt " . $filt->name . "\n" );
    }

    my $atts = $exportables[0]->getAllAttributes();

    die "BioMart DAS Compliant Exportables "
      . "must contain the same number of "
      . "attributes as keys in the feature_keys INI specification\n"
      unless (
        scalar( @{$atts} ) ==
        scalar( @{ $biomart->{'feature_keys'} } ) );

    # Determine the location of required keys.
    my $reqKeys = REQUIREDKEYS;
    my $i       = 0;
    foreach my $key ( @{ $biomart->{'feature_keys'} } ) {
        $biomart->{'required_keys'}{$key} = $i++
          if ( grep { ( $_ eq $key ) } @{$reqKeys} );
    }

    die "BioMart DAS Compliant feature_keys list "
      . "must contain at least "
      . join( ",", @{$reqKeys} ) . "\n"
      unless (
        scalar( keys %{ $biomart->{'required_keys'} } ) ==
        scalar( @{$reqKeys} ) );

    $biomart->{'attributes'} = $atts;
    $biomart->{'filters'}    = $filts;
    
    $self->{'BioMart'}=$biomart;
}

sub build_features
{
    my ( $self, $opts ) = @_;

    my $segment       = $opts->{'segment'} || return ();
    my $segment_start = $opts->{'start'};
    my $segment_end   = $opts->{'end'};

    # Use $segment and, if they are defined, $segment_start and
    # $segment_end, to fetch the appropriate data from the mart.

    my $biomart = $self->{'BioMart'};

    my $query = BioMart::Query->new(
        'registry'          => $biomart->{'registry'},
        'virtualSchemaName' => $biomart->{'virtualSchema'}
    );
    
    $query->setDataset($biomart->{'dataset'});

    my $atts = $biomart->{'attributes'};
    foreach my $att ( @{$atts} ) {
        $query->addAttribute($att->name());
    }

    $query->addFilter($biomart->{'filters'}[0]->name(), [$segment]);

    if ( $segment_start && $segment_end ) {
        $query->addFilter($biomart->{'filters'}[1]->name(), [$segment_start]);
        $query->addFilter($biomart->{'filters'}[2]->name(), [$segment_end]);
    }

    my $reqKeys  = REQUIREDKEYS;
    my $defaults = DEFAULTS;
    my @features = ();

    my $query_runner = BioMart::QueryRunner->new();
    $query->formatter('TSV');    # tab-separated results
    $query_runner->execute($query);

    my $result_buffer;

    open( my $RESULTS, '>', \$result_buffer );
    $query_runner->printResults($RESULTS);
    close($RESULTS);

    my @rows = split /\n/, $result_buffer;

  ROW: foreach my $rowLine (@rows) {
        my @row = split /\t/, $rowLine;

        my $feature = {};

        # Skip this feature unless all keys in REQUIREDKEYS are defined.
        my $good = 0;
      KEY: foreach my $reqKey ( @{$reqKeys} ) {
            my $pos = $biomart->{'required_keys'}{$reqKey};
            next KEY unless ( $row[$pos] );
            $good++;
        }
        next ROW unless ($good);

        my $i = 0;
        while ( $i < scalar(@row) ) {
            my $key = $biomart->{'feature_keys'}[$i];
            $feature->{$key} = $row[$i]
              || $defaults->{$key};   # May be either default, or undef.
            $i++;
        }

        push @features, $feature;
    }
    return @features;
}

1;
