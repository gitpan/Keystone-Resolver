# $Id: Utils.pm,v 1.3 2007-06-26 16:09:40 mike Exp $

package Keystone::Resolver::Utils;

use strict;
use warnings;
use URI::Escape qw(uri_unescape uri_escape_utf8);
use Encode;

use Exporter 'import';
our @EXPORT_OK = qw(encode_hash decode_hash utf8param);

=head1 NAME

Keystone::Resolver::Utils - Simple utility functions for Keystone Resolver

=head1 SYNOPSIS

 use Keystone::Resolver::Utils qw(encode_hash decode_hash);
 $string = encode_hash(%foo);
 %bar = decode_hash($string);

=head1 DESCRIPTION

This module consists of standalone functions -- yes, that's right,
functions: not classes, not methods, functions.  These are provided
for the use of Keystone Resolver.

=head1 FUNCTIONS

=head2 encode_hash(), decode_hash()

 $string = encode_hash(%foo);
 %bar = decode_hash($string);

C<encode_hash()> encodes a hash into a single scalar string, which may
then be stored in a database, specified as a URL parameters, etc.
C<decode_hash()> decodes a string created by C<encode_hash()> back
into a hash identical to the original.

These two functions constitute a tiny subset of the functionality of
the C<Storable> module, but have the pleasant property that the
encoded form is human-readable and therefore useful in logging.  In
theory, the encoding is secret, but I may as well admit that the hash
is encoded as a URL query.

=cut

sub encode_hash {
    my(%hash) = @_;

    return join("&", map {
	uri_escape_utf8($_) . "=" . uri_escape_utf8($hash{$_})
    } sort keys %hash);
}

sub decode_hash {
    my($string) = @_;

    return (map { decode_utf8(uri_unescape($_)) }
	    map { (split /=/, $_, -1) } split(/&/, $string, -1));
}


=head2 utf8param()

 $unicodeString = utf8param($r, $key)

Returns the value associated with the parameter named C<$key> in the
Apache Request (or similar object) C<$r>, on the assumption that the
encoded value was a sequence of UTF-8 octets.  These octets are
decoded into Unicode characters, and it is a string of these that is
returned.

=cut

sub utf8param {
    my($r, $key, $value) = @_;
    die "utf8param() called with value '$value'" if defined $value;

    my $raw = $r->param($key);
    return undef if !defined $raw;

    my $cooked = decode_utf8($raw);
    warn "converted '$raw' to '", $cooked, "'\n" if $cooked ne $raw;
    return $cooked;
}


1;
