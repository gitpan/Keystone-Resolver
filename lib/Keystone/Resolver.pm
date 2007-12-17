# $Id: Resolver.pm,v 1.22 2007-12-17 11:46:17 mike Exp $

package Keystone::Resolver;

use 5.008;
use strict;
use warnings;
use Keystone::Resolver::Utils;
use Keystone::Resolver::LogLevel;
use Keystone::Resolver::OpenURL;
use Keystone::Resolver::ContextObject;
use Keystone::Resolver::Descriptor;
use Keystone::Resolver::Database;
use Keystone::Resolver::ResultSet;

our $VERSION = '1.11';


=head1 NAME

Keystone::Resolver - an OpenURL resolver

=head1 SYNOPSIS

 use Keystone::Resolver;
 $resolver = new Keystone::Resolver();
 $openURL = $resolver->openURL($args, $base, $referer);
 print $openURL->resolve();

=head1 DESCRIPTION

This is the top-level class of Index Data's Keystone Resolver.  It
delegates the process of resolving OpenURLs to a swarm of worker
classes.

=head1 METHODS

=cut

=head2 new()

 $resolver = new Keystone::Resolver();
 $resolver = new Keystone::Resolver(logprefix => "Keystone Resolver");
 $resolver = new Keystone::Resolver(logprefix => "Keystone Resolver",
                                    xsltdir => "/home/me/xslt");

Creates a new resolver that can be used to resolve OpenURLs.  If
arguments are provided, they are taken to be pairs that specify the
names and values of options.  See the documentation of the C<option()>
method below for information about specific options.

One option is special to this constructor: if C<_rw> is provided and
true, then the database is opened readwrite rather then readonly
(which is the default).

The resolver object accumulates some state as it goes along, so it
is generally more efficient to keep using a single resolver than to
make new one every time you need to resolve an OpenURL.

=cut

sub new {
    my $class = shift();
    my(%options) = @_;

    my $rw = delete $options{_rw};
    my $xsltdir = $ENV{KRxsltdir} || "../etc/xslt";
    my $this = bless {
	parser => undef,	# set when needed in parser()
	xslt => undef,		# set when needed in xslt()
	ua => undef,		# set when needed in ua()
	stylesheets => {},	# cache, populated by stylesheet()
	db => {},		# cache, populated by db()
	rw => $rw,
	options => {
	    # Options can be overridden by creation-time arguments.
	    # They should probably take default values from the Config
	    # table of the RDB instead of hard-wired values.
	    logprefix => $0,
	    loglevel => 0,
	    xsltdir => $xsltdir,
	},
    }, $class;

    foreach my $key (keys %options) {
	my $val = $options{$key};
	# Special case for "loglevel" to allow hex and octal bitmasks
	$val = oct($val) if $key eq "loglevel" && $val =~ /^0/;
	$this->{options}->{$key} = $val;
    }

    $this->log(Keystone::Resolver::LogLevel::CHITCHAT, "new resolver $this");
    return $this;
}


=head2 option()

 $level = $resolver->option("loglevel");
 $oldpath = $resolver->option(xsltdir => "/home/me/xslt");

Gets and sets options in a C<Keystone::Resolver> object.  When called with a
single argument, returns the value the resolver has for that key.
When called with two arguments, a key and a value, sets the specified
new value for that key and returns the old value anyway.

Supported options include:

=over 4

=item logprefix

The initial string emitted at the beginning of each line of debugging
output generated by the C<log()> method.  The default value is the
name of the running program.

=item loglevel

A bit mask indicating the categories of message that should be logged
by calls to the C<log()> method.  Should be set to the bitwise AND of
zero or more of the symbolic constants defined in
C<Keystone::Resolver::LogLevel>.  See the documentation of that module for a
description of the recognised categories.

=item xsltdir

The directory where the resolver looks for XSLT files.

=back

=cut

sub option {
    my $this = shift();
    my($key, $value) = @_;

    my $old = $this->{options}->{$key};
    $this->{options}->{$key} = $value
	if defined $value;

    return $old;
}


=head2 log()

 $resolver->log(Keystone::Resolver::LogLevel::CHITCHAT, "starting up");

Logs a message to thye standard error stream if the log-level of the
resolver includes the level specified as the first argument in its
bitmask.  If so, the message consists of the logging prefix (by
default the name of the program), the label of the specified level in
parentheses, and all other arguments concatenated, finishing with a
newline.

=cut

sub log {
    my $this = shift();
    my($level, @args) = @_;

    if ($this->option("loglevel") & $level) {
	### could check another option for whether to include PID
	my $prefix = $this->option("logprefix");
	my $label = Keystone::Resolver::LogLevel::label($level);
	print STDERR "$prefix ($label): ", @args, "\n";
    }
}


=head2 openURL()

 $openURL = $resolver->openURL($args, $base, $referer);

Creates a new C<Keystone::Resolver::OpenURL> object using this
C<Keystone::Resolver> and the specified arguments and referer.  This
is a shortcut for

 new Keystone::Resolver::OpenURL($resolver, $args, $base, $referer)

=cut

sub openURL {
    my $this = shift();

    #use Carp qw(cluck); cluck("$$: creating new OpenURL(" . join(", ", map { defined $_ ? "'$_'" : "undef" } @_) . ")");
    return new Keystone::Resolver::OpenURL($this, @_);
}


=head2 parser()

 $parser = $resolver->parser();

Returns the XML parser associated with this resolver.  If it does not
yet have a parser, then one is created for it, cached for next time,
and returned.  The parser is an C<XML::LibXML> object: see the
documentation of that class for how to use it.

=cut

sub parser {
    my $this = shift();

    if (!defined $this->{parser}) {
	$this->{parser} = new XML::LibXML();
    }

    return $this->{parser};
}


=head2 xslt()

 $xslt = $resolver->xslt();

Returns the XSLT processor associated with this resolver.  If it does
not yet have a XSLT processor, then one is created for it, cached for
next time, and returned.  The XSLT processor is an C<XML::LibXSLT>
object: see the documentation of that class for how to use it.

=cut

sub xslt {
    my $this = shift();

    if (!defined $this->{xslt}) {
	$this->{xslt} = new XML::LibXSLT();
    }

    return $this->{xslt};
}


=head2 ua()

 $ua = $resolver->ua();

Returns the LWP User Agent associated with this resolver.  If it does
not yet have a User Agent, then one is created for it, cached for next
time, and returned.

=cut

sub ua {
    my $this = shift();

    if (!defined $this->{ua}) {
	$this->{ua} = new LWP::UserAgent();
    }

    return $this->{ua};
}


=head2 stylesheet()

 $stylesheet1 = $resolver->stylesheet();
 $stylesheet2 = $resolver->stylesheet("foo");

Returns a stylesheet object for the XSLT stylesheet named in the
argument, or for the default stylesheet if no argument is supplied.
The returned object is an <XML::LibXSLT::Stylesheet>: see the
documentation of that class for how to use it.

=cut

# $this->{stylesheets} is used only in this function.  It's a cache
# mapping a full stylesheet pathname to a duple consisting of that
# file's last modification time and the compiled stylesheet described
# by it.  The file is compiled if we're asked for it for the first
# time or if it's changed since the last compilation.
#
sub stylesheet {
    my $this = shift();
    my($name) = @_;

    $name ||= "default";
    my $cache = $this->{stylesheets};
    my $filename = $this->option("xsltdir") . "/$name.xsl";
    my(@stat) = stat($filename)
	or die "can't stat XSLT file '$filename': $!";
    my $mtime = $stat[9];
    $this->log(Keystone::Resolver::LogLevel::CACHECHECK,
	       "checking cache for XSLT file '$name', age $mtime");

    if (!defined $cache->{$name} ||
	$mtime > $cache->{$name}->[0]) {
	my $style_doc = $this->parser()->parse_file($filename);
	my $stylesheet = $this->xslt()->parse_stylesheet($style_doc);
	$cache->{$name} = [ $mtime, $stylesheet ];
	$this->log(Keystone::Resolver::LogLevel::PARSEXSLT,
		   "parsed XSLT file '$name', age $mtime");
    }

    return $cache->{$name}->[1];
}


=head2 db()

 $db = $resolver->db();
 $db = $resolver->db("kr-backup");

Returns the database object associated with this specified name for
this resolver.  if no name is provided, the default name "kr" (for
Keystone Resolver) is used.  If the resolver does not yet have a
database handle associated with this name, then one is created for it,
cached for next time, and returned.  The handle is a
C<Keystone::Resolver::Database> object: see the documentation for how
to use it.

=cut

sub db {
    my $this = shift();
    my($name) = @_;

    $name ||= "kr";

#    ### This is a hack.  We can do better
#    if (!defined $name) {
#	my $sn = $ENV{SCRIPT_NAME} || "/resolve";
#	if ($sn =~ s@.*/resolve@@) {
#	    $name = "kr$sn";
#	} else {
#	    $name = "kr";
#	}
#    }

    my $cache = $this->{db};
    if (!defined $cache->{$name}) {
	$cache->{$name} =
	    new Keystone::Resolver::Database($this, $name, $this->{rw});
    }

    return $cache->{$name};
}


=head1 AUTHOR

Mike Taylor E<lt>mike@indexdata.comE<gt>

First version Tuesday 9th March 2004.

=head1 SEE ALSO

C<Keystone::Resolver::OpenURL>,
C<Keystone::Resolver::Result>,
C<Keystone::Resolver::LogLevel>,
C<Keystone::Resolver::ContextObject>,
C<Keystone::Resolver::Database>,
C<Keystone::Resolver::Descriptor>,
C<Keystone::Resolver::Test>.

=cut


1;
