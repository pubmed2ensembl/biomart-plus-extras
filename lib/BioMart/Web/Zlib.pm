# BioMart::Zlib.pm
#
# Copyright (c) 1998-2004 Tom Hughes <tom@compton.nu>.
# All rights reserved. This program is free software; you can redistribute
# it and/or modify it under the same terms as Perl itself.
# Seriously modified by Richard Holland.

package BioMart::Web::Zlib;

$VERSION = "1.04";

require 5.004;

use strict;
use vars qw($VERSION $AUTOLOAD @ISA);

use Carp;
use Fcntl qw(SEEK_SET);
use Compress::Zlib;
use Compress::Raw::Zlib;
use IO::Compress::Gzip;

use Symbol;
use Tie::Handle;

@ISA = qw(Tie::Handle);

sub TIEHANDLE
{
    my $class = shift;
    my @args = @_;

    my $self = bless {}, $class;

    return @args ? $self->OPEN(@args) : $self;
}

sub DESTROY
{
}

sub OPEN
{
    my $self = shift;
    my $fileh = shift;

    $self->{'fileh'} = $fileh;
    $self->{'gz'} = new Compress::Raw::Zlib::Deflate(
                      -AppendOutput  => 1,
                      -CRC32         => 1,
                      -ADLER32       => 0,
                      -Level         => Z_BEST_COMPRESSION(),
                      -WindowBits    => - MAX_WBITS(),
                     )
	or croak "$self: Cannot create deflation streami\n";
    binmode $fileh;
    print $fileh IO::Compress::Gzip::GZIP_MINIMUM_HEADER ;

    return defined($self->{'gz'}) ? $self : undef;
}

sub CLOSE
{
    my $self = shift;

    return undef unless defined($self->{'gz'});

    my $output = '';
    my $status = $self->{'gz'}->flush(\$output);
    my $fileh = $self->{'fileh'};
    print $fileh $output.pack("V V", $self->{'gz'}->crc32(), $self->{'gz'}->total_in());

    delete $self->{'gz'};
    delete $self->{'fileh'};

    return ($status == Compress::Zlib::Z_OK) ? 1 : undef;
}

sub READ
{
}

sub READLINE
{
}

sub WRITE
{
    my $self = shift;
    my $buf = shift;
    my $length = shift;
    my $offset = shift;

    $self->OPEN unless $self->{'gz'};

    croak "BioMart::Zlib::WRITE: too long LENGTH" unless $length <= length($buf);
    croak "BioMart::Zlib::WRITE: OFFSET not supported" if defined($offset) && $offset != 0;

    my $data = substr($buf,0,$length);
    my $output = '';
    my $status = $self->{'gz'}->deflate($data,\$output);
    my $fileh = $self->{'fileh'};
    print $fileh $output;
    return ($status==Compress::Zlib::Z_OK) ? $length : undef;
}

sub EOF
{
}

sub new
{
    my $class = shift;
    my @args = @_;

    my $self = gensym();

    tie *{$self}, $class, @args;

    return tied(${$self}) ? bless $self, $class : undef;
}

sub AUTOLOAD
{
    my $self = shift;

    $AUTOLOAD =~ s/.*:://;
    $AUTOLOAD =~ tr/a-z/A-Z/;

    return tied(*{$self})->$AUTOLOAD(@_);
}

1;
