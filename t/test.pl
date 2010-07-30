#!/usr/bin/perl -w

# $Id: test.pl,v 1.1.1.1 2006-11-22 20:32:32 arek Exp $

use strict;
use FindBin qw($Bin);
use Test::Harness;

my @testfiles = ();
opendir(DIRHANDLE,"$Bin");
(/.*\.t/ and push @testfiles, "$Bin/$_") foreach (readdir(DIRHANDLE));
closedir(DIRHANDLE);

runtests(@testfiles);
