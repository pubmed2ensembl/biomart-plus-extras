# $Id: Links.pm,v 1.3 2008-04-09 12:52:33 syed Exp $
#
# BioMart module for BioMart::Links.
#
# You may distribute this module under the same terms as perl
# itself.

# POD documentation - main docs before the code.

=head1 NAME

BioMart::Links

=head1 SYNOPSIS

  Object representing a directional link between two BioMart datasets.

=head1 DESCRIPTION

The BioMart::Links class holds the links between two
BioMart::DatasetI objects.

Two BioMart::DatasetI objects are connected through
their exportable BioMart::Configuration::AttributeList ("the
exportable") and importable BioMart::Configuration::FilterList
("the importable") objects using named links.

To link two datasets, the exportable and the importable must
have the same name.

A BioMart::Links object stores the names of the exportable
and the importable and the names of the source and target
datasets (eg, it is directional). 

It also provides a method to override the default link
between the datasets (eg, use a different 
exportable<->importable name than that specified in the
XML for the two datasets as the default).

Finally, it holds a reference to the BioMart::Registry object 
that created it.

=head1 AUTHOR -  Arek Kasprzyk, Andreas Kahari, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project
http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut

#------------------------------------------------------------------------

package BioMart::Links;

use strict;
use warnings;

# Extends BioMart::Root
use base qw(BioMart::Root);

#------------------------------------------------------------------------

=head2 new

  Usage      :  my $links = BioMart::Links->new($registry);
  Description:  Creates a new BioMart::Links object.
  Return type:  A BioMart::Links object.
  Exceptions :  none
  Caller     :  BioMart::Registry

=cut

sub _new {
    my ($self, $registry, @params) = @_;

    $self->SUPER::_new(@params);

    # Links are a stored in a hash where the link name is the
    # hash key.  Each hash entry points to the name of the
    # exportable in the source dataset and the importable in
    # the target dataset (the names are the same for both).

    $self->attr('linkHash', { });

    $self->attr('sourceDatasetName', undef);
    $self->attr('targetDatasetName', undef);
    $self->attr('defaultLinkName', undef);
    $self->attr('registry', $registry);
    $self->attr('operation', 'join');# default to join til union is implemented
}

#------------------------------------------------------------------------

=head2 operation

  Usage      :  $links->operation($operation);
                $operation = $links->operation();

  Description:  Sets or gets the the operation between the source and target 
                dataset. Default is a join in which case a link is created 
                between the two datasets but can also be a union in which case 
                no link is required

  Return type:  A scalar (string).
  Exceptions :  none
  Caller     :

=cut

sub operation {
    my ($self, $operation) = @_;

    if (defined $operation) {
        $self->set('operation', $operation);
    }

    return $self->get('operation');
}


#------------------------------------------------------------------------

=head2 validateLink

  Usage      :  $links->validateLink($virtualSchema,$sourceInterface,
				     $targetInterface,$linkName);

  Description:  Tests whether appropiately named exportables and importables
                exist in the soucre and target datasets for the given 
                interfaces

  Return type:  1 or undef if link is not validated
  Exceptions :  none
  Caller     :

=cut

sub validateLink {
    my ($self, $virtualSchema, $sourceInterface, $targetInterface, 
	$linkName) = @_;
    
    my $registry = $self->get('registry');
    my $sourceDataset = $registry->getDatasetByName($virtualSchema, 
						    $self->sourceDataset);
    my $targetDataset = $registry->getDatasetByName($virtualSchema, 
						    $self->targetDataset);

    if ($targetDataset->getImportables($linkName,$targetInterface) && 
	$sourceDataset->getExportables($linkName,$sourceInterface)){
	return 1;
    }
    return undef;
}

#------------------------------------------------------------------------

=head2 sourceDataset

  Usage      :  $links->sourceDataset($dataSetName);
                $dataSetName = $links->sourceDataset();

  Description:  Sets or gets the the source dataset by name.
                Resetting the source dataset will invalidate
                (remove) all the already existing links within
                this BioMart::Links object.

  Return type:  A scalar (string).
  Exceptions :  none
  Caller     :

=cut

sub sourceDataset {
    my ($self, $dataSetName) = @_;

    if (defined $dataSetName || scalar(@_) > 1) {
        $self->set('sourceDatasetName', $dataSetName);
        $self->set('linkHash', { });
    }

    return $self->get('sourceDatasetName');
}

#------------------------------------------------------------------------

=head2 targetDataset

  Usage      :  $links->targetDataset($dataSetName);
                $dataSetName = $links->targetDataset();

  Description:  Sets or gets the target dataset by name.
                Resetting the target dataset will invalidate
                (remove) all the already existing links within
                this BioMart::Links object.

  Return type:  A scalar (string).
  Exceptions :  none
  Caller     :

=cut

sub targetDataset {
    my ($self, $dataSetName) = @_;

    if (defined $dataSetName || scalar(@_) > 1) {
        $self->set('targetDatasetName', $dataSetName);
        $self->set('linkHash', { });
    }

    return $self->get('targetDatasetName');
}

#------------------------------------------------------------------------

=head2 defaultLink

  Usage      :  $links->defaultLink($linkName);
                $linkName = $links->defaultLink();

  Description:  Sets or gets the name of the default link
                between the two datasets associated through
                this BioMart::Links object.

  Return type:  A scalar (string).
  Exceptions :  none
  Caller     :

=cut

sub defaultLink {
    my ($self, $linkName) = @_;
    if (defined $linkName || scalar(@_) > 1) {
        my $linkHash = $self->get('linkHash');
        if (!defined $linkName || defined $linkHash->{$linkName}) {
            $self->set('defaultLinkName', $linkName);
        } else {
            BioMart::Exception::Configuration->throw("Can not set default link to '$linkName', no such link");
        }
    }

    return $self->get('defaultLinkName');
}

#------------------------------------------------------------------------

=head2 addLink

  Usage      :  $links->addLink($linkName, $listName);
                $links->addLink($linkName);

  Description:  Adds a named link between one of the
                BioMart::Configuration::AttributeList objects
                (the exportable) of the source dataset to one 
                of the BioMart::Configuration::FilterList objects 
                (the importable) of the target dataset.

                The $listName parameter must be the name
                of a BioMart::Configuration::AttributeList
                object in the source dataset and of a
                BioMart::Configuration::FilterList object in the
                target dataset.

                If $listName is left undefined (the method is
                only called with one paramater, $linkName), then
                $linkName will be used instead.

                The newly added link will be the default link if
                no default link was previously specified.

  Return type:  none
  Exceptions :  none
  Caller     :

=cut

sub addLink {
    my ($self, $virtualSchema, $linkName, $listName) = @_;

    if (!defined $listName) {
        $listName = $linkName;
    }

    my $registry = $self->get('registry');
    my $linkHash = $self->get('linkHash');

    my $sourceDatasetName = $self->get('sourceDatasetName');
    if (!defined $sourceDatasetName) {
        BioMart::Exception::Configuration->throw("Can not add link '$linkName', no source dataset");
    }

    my $exportableFound = 0;

    my $sourceDataset = $registry->getDatasetByName($virtualSchema, 
						    $sourceDatasetName);
    my $attList;
    foreach my $attributeList (@{ $sourceDataset->getExportables() }) {
        if ($listName eq $attributeList->name()) {
            $exportableFound = 1;
	    $attList = $attributeList;
            last;
        }
    }

    if (!$exportableFound) {
        BioMart::Exception::Configuration->throw("Can not add link '$linkName', exportable '$listName' not found in source dataset:  $sourceDatasetName ");
    }

    my $targetDatasetName = $self->get('targetDatasetName');
    if (!defined $targetDatasetName) {
        BioMart::Exception::Configuration->throw("Can not add link '$linkName', no target dataset");
    }

    my $importableFound = 0;

    my $targetDataset = $registry->getDatasetByName($virtualSchema, 
						    $targetDatasetName);
    foreach my $filterList (@{ $targetDataset->getImportables() }) {
        if ($listName eq $filterList->name()) {
            $importableFound = 1;
            last;
        }
    }

    if (!$importableFound) {
        BioMart::Exception::Configuration->throw("Can not add link '$linkName', importable '$listName' not found in target dataset: $targetDatasetName source dataset: $sourceDatasetName");
    }

    $linkHash->{$linkName} = $listName;

    $self->set('linkHash', $linkHash);
 
    # make the first link the default or if AttList set as default
    # make this link the default
    if ((!defined $self->defaultLink()) || $attList->defaultList){
       $self->defaultLink($linkName);
    }
}

#------------------------------------------------------------------------

=head2 getAllLinks

  Usage      :  my @allLinks = $links->getAllLinks();
                my $allLinksref = $links->getAllLinks();

  Description:  Returns the names of all links associated with
                this BioMart::Links object, either as an
                array_ref (recommended), or as an array.

  Return type:  An array of strings in list context, or a
                reference to such an array in scalar context.

  Exceptions :  none
  Caller     :

=cut

sub getAllLinks {
    my ($self) = @_;

    my $linkHash = $self->get('linkHash');

    my @linkNames = keys %{ $linkHash };

    return (wantarray() ? @linkNames : \@linkNames);
}

1;

# vim: et
