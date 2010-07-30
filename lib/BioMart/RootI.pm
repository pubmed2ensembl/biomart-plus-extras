#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR - Arek Kasprzyk, Syed Haider, Damian Smedley

=head1 CONTACT

This module is part of the BioMart project http://www.biomart.org

Questions can be posted to the mart-dev mailing list:
mart-dev@ebi.ac.uk

=head1 METHODS

=cut

package BioMart::RootI;

use strict;
use warnings;
use Time::localtime;
use Carp;

# Interface methods

=head2 new

  Usage        :  my $object = BioMart::RootI_ImplementingObject->new(%params);
                  my $copy = $object->new;
                  my $copy2 = BioMart::RootI_ImplementingObject->new($object);
  Description  :  All RootI implementing objects can take a hash of parameters,
                  check the existence and validity of these parameters, and
                  return a new instance.  Also acts as a Copy Constructor for 
                  implementations which support this functionality (see init 
		  below).
  Returntype   :  $object reference
  Exceptions   :  Missing or invalid required parameters.  Implementation 
                  specific Exceptions.
  Caller       :  caller

=cut

sub new { # interface
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self = {
	'_hashCode'	=> undef,
	'_hashDirty'	=> 1,
    };
    bless $self, $class;

    if (ref $proto) {
	$self->init($proto);
    } else {
	if ($self->can('_new')) {
	    $self->_new(@_);
	} else {
	    $self->unimplemented_method();
	}
    }

    return $self;
}

=head2 init

  Usage        :  my $obj = $oldObj->new;  
                  my $obj = BioMart::RootImp->new($oldObj);
  Description  :  RootI Implementations with an _init method can return 
                  newly instantiated copies of themselves.
                  See perlpod for new above.
  Returntype   :  newly instantiated copy of an existing object.
  Exceptions   :  implentation specific
  Caller       :  caller

=cut

sub init { # Interface
    my $self = shift;

    if ($self->can('_init')) {
	return $self->_init(@_);
    }
    $self->unimplemented_method();
}

sub equals { # Interface
    my $self = shift;

    if ($self->can('_equals')) {
	return $self->_equals(@_);
    }
    $self->unimplemented_method();
}

sub hashCode { # Interface
    my $self = shift;

    if (defined $self->{'_hashCode'} && $self->{'_hashDirty'} == 0) {
	return $self->{'_hashCode'};
    }

    my $hashCode;
    if ($self->can('_hashCode')) {
	$hashCode = $self->_hashCode(@_);
    } else {
	$self->unimplemented_method();
    }

    $self->{'_hashCode'} = $hashCode;
    $self->{'_hashDirty'} = 0;

    return $hashCode;
}

sub toString { # Interface
    my $self = shift;

    if ($self->can('_toString')) {
	return $self->_toString(@_);
    }
    $self->unimplemented_method();
}

# utility methods available to all implementations

sub unimplemented_method {
    my $self = shift;

    my $subroutine = [ caller 1 ]->[3];
    $subroutine =~ s/^.*:://;

    BioMart::Exception->throw(sprintf("Unimplemented method '%s::%s'",
	ref $self || $self, $subroutine));
}

1;
