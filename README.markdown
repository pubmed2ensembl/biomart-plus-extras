BioMart Plus Extras
===================

**BioMart Plus Extras** is based on BioMart release 0.7  [www.biomart.org](http://www.biomart.org),
which is a data query system for large databases, for which we have
added several extras in order to power our web-site [www.pubmed2ensembl.org](http://www.pubmed2ensembl.org).

Additional features of **BioMart Plus Extras** are:

* interactive full-text search queries via NCBI's Entrez Utilities
* support of the DAS 'sources' request
* annotation of database query results that show on 'mouseover'
* 'list like' view that shows individual URL link-outs for comma separated data
* highlighting of alternating rows, depending on the first column's value in a result set

Installation
------------

**BioMart Plus Extras** extends `biomart-perl`, and as such, the CVS checkout
as described under Section 2.2 in the Biomart 0.7 documentation has to be replaced
by the git command:

    git clone git@github.com:pubmed2ensembl/biomart-plus-extras.git

After cloning, the installation can be carried out as described in the BioMart 0.7
documentation. However, some hardcoded references exist in our version of BioMart
that may need manual adjustments. The references in the source are tailored to
work with the _Ensembl Mart 56_.

In particular, the following files will need manual changes:

* `conf/settings.conf`
  * configuration settings depending on the local installation environment
* `conf/templates/default/header.tt`
  * fixing of URL link-outs
* `bin/ConfBuilder.pm`
  * correction of MAPMASTER link-out
  * adjustments in `sub makeSOURCES`
* `lib/BioMart/Registry.pm`
  * adjustments in `sub getDefaultCoordinate`
* and rather specific changes need to be made in the following files that
  depend on the data sources that have been integrated into the mart, but try
  to look for "Entrez" and "EMBL" to get an understanding of what needs
  to be changed
  * `conf/template/default/menupanel.tt`
  * `cgi-bin/features.PLS`
  * `lib/BioMart/Configurator.pm`

Supporting Software
-------------------

For the pop-ups that occur on 'mouseover' events, we needed to include Walter Zorn's
[wz_tooltip](http://swik.net/wz_tooltip) library. The library is released under LGPL.

License
-------

BioMart 0.7 is released under the LGPL, and we are continuing to adopt this 
license for BioMart Plus Extras 0.7.1 (see LICENSE).
