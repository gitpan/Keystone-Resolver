# $Id: Serial.pm,v 1.6 2007-06-09 00:11:57 mike Exp $

package Keystone::Resolver::DB::Serial;

use strict;
use warnings;
use Keystone::Resolver::DB::Object;

use vars qw(@ISA);
@ISA = qw(Keystone::Resolver::DB::Object);


sub table { "serial" }

sub fields { (id => undef,
	      name => undef,
	      issn => undef,
	      ) }

sub search_fields { (name => "t25",
		     issn => "t12",
		     ) }

sub sort_fields { ("name") }

sub display_fields { (name => "Lt",
		      issn => "t",
		      ) }

sub field_map { {
    issn => "ISSN",
} }

1;
