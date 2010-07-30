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

package BioMart::Root;

use strict;
use warnings;
use Data::Dumper;
use Log::Log4perl qw(get_logger :levels);	

# Implements BioMart::RootI
use base qw(BioMart::RootI);

# BioMart::RootI

sub _new {
    my $self = shift;

    # Subclasses should all do this before doing anything else.
    #	$self->SUPER::_new(@_);

    $self->attr('params', {});
    
   	 Log::Log4perl->init(\ qq{
log4perl.logger                               	  = FATAL, Screen
log4perl.appender.Screen                          = Log::Log4perl::Appender::Screen
log4perl.appender.Screen.layout                   = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Screen.layout.ConversionPattern = %c:%L:%p> %m%n
log4perl.appender.Screen.stderr  = 1
     }) unless Log::Log4perl->initialized();
}

sub _init {
  my ($self, $proto) = @_;

  # Subclasses should all do this before doing anything else
  #    $self->SUPER::_init(@_);

  my $paramCopy = {};
  my $protoParams = $proto->_getParams;
  foreach my $key (keys %{$protoParams}) {
     #TODO:  some params are objects.  Really need to instantiate new copies 
     # here, but for now just take the references, as _init is not implemented 
     # in many objects yet
     $paramCopy->{$key} = $protoParams->{$key};
  }

  $self->attr('params', $paramCopy );
}


sub _getParams {
  my $self = shift;
  return $self->get('params');
}

sub _equals {
    my $self = shift;
    my $object = shift;

    return (($object == $self) ||
		(ref $object && $object->isa(ref $self) &&
		 $object->hashCode() eq $self->hashCode()))
}

sub _hashCode {
    my $self = shift;
    return "$self";
}

sub _toString {
    my $self = shift;
    return Dumper($self);
}

# Non-interface

sub addParams {
  my ($self, $titleRef, @param) = @_;

  local($^W) = 0;  # prevent "odd number of elements" warning with -w.
  my(%param) = @param;

  foreach my $title (@{$titleRef}) {
    $self->setParam($title, $param{$title});
  }
}

sub setParam {
  my $self = shift;
  my $key = shift;
  my $value = shift;

  my $params = $self->get('params');
  $params->{$key} = $value;
  $self->set('params', $params);
}

sub getParam {
  my ($self, $key) = @_;

  #may return an undefined value
  return $self->get('params')->{$key};
}

sub checkRequiredParams {
  my ($self, $paramref) = @_;
  foreach my $reqParam (@{$paramref}) {
    # removed apparently nonsensical == 0 check 
    unless (defined $self->getParam($reqParam)){
      BioMart::Exception->throw("Missing Required Parameter ${reqParam}\n");
    }
  }
}

sub attr {
    my $self = shift;
    my $attr = shift;
    my $value = shift;

    if (exists $self->{$attr}) {
	BioMart::Exception->throw(sprintf("Attribute '%s' already exists", $attr));
    }

    $self->{$attr} = $value;
    $self->{'_hashDirty'} = 1;
}

sub get {
    my $self = shift;
    my $attr = shift;

    my $class = ref $self;

    if (!exists $self->{$attr}) {
	  BioMart::Exception->throw(sprintf("Attribute '%s' does not exist", $attr));
    }

    return $self->{$attr};
}

sub set {
    my $self = shift;
    my $attr = shift;
    my $value = shift;

    if (!exists $self->{$attr}) {
	  BioMart::Exception->throw(sprintf("Attribute '%s' does not exist", $attr));
    }

    $self->{$attr} = $value;
    $self->{'_hashDirty'} = 1;
}

=head2 loadModule

  Usage        :  $self->loadModule($module); my $obj = "$module"->new(@param);
  Description  :  Sets up $module (eg BioMart::X::Y::Z) from @INC in the 
                  perl symbol table.
                  Caller can then construct an object of type $module.
  Returntype   :  none
  Exceptions   :  Problems finding module in @INC
  Caller       :  caller

=cut

sub loadModule {
  my ($self, $moduleName) = @_;

  eval "require $moduleName" or BioMart::Exception->throw("could not load module $moduleName: $@");

  return;
}

1;
