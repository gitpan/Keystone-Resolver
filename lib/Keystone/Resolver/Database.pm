# $Id: Database.pm,v 1.33 2008-04-10 00:15:25 mike Exp $

package Keystone::Resolver::Database;

use strict;
use warnings;
use DBI;
use Encode;			# To decode UTF-8 sequences from DB
use Carp;
use Scalar::Util;
use Keystone::Resolver::Utils qw(encode_hash decode_hash);

use Keystone::Resolver::DB::Genre;
use Keystone::Resolver::DB::ServiceType;
use Keystone::Resolver::DB::Service;
use Keystone::Resolver::DB::Serial;
use Keystone::Resolver::DB::Domain;
use Keystone::Resolver::DB::Site;
use Keystone::Resolver::DB::Session;
use Keystone::Resolver::DB::User;
use Keystone::Resolver::DB::MetadataFormat;
use Keystone::Resolver::DB::Provider;
use Keystone::Resolver::DB::ServiceTypeRule;
use Keystone::Resolver::DB::ServiceRule;
use Keystone::Resolver::DB::SerialAlias;
use Keystone::Resolver::DB::ServiceSerial;
use Keystone::Resolver::DB::GenreServiceType;


=head1 NAME

Keystone::Resolver::Database - Resource Database for an OpenURL v1.0 resolver

=head1 SYNOPSIS

 $db = new Keystone::Resolver::Database($resolver);
 $genre = $db->genre_by_mformat("info:ofi/fmt:kev:mtx:journal");
 print $genre->name();

=head1 DESCRIPTION

This object represents the Resource Database, or RDB, for an OpenURL
resolver.  In includes the physical connection information to the
underlying database together with application logic at the database
level.

=head1 METHODS

=cut


=head2 new()

 $db = new Keystone::Resolver::Database($resolver, $name);
 $rwdb = new Keystone::Resolver::Database($resolver, $name, 1);

Constructs a new Database for the specified resolver, using the
specified database name.  If an optional third argument is present and
true, then the database is opened in read-write mode rather than the
default read-only mode.

Read-only and read-write modes are achieved by connecting to the user
as one of two different users.
In read-only mode, the user named by the C<KRuser> environment
variable is used, together with the password specified by C<KRpw>.
In read-write mode, the user named by the C<KRrwuser> environment
variable is used, together with the password specified by C<KRrwpw>.
B<These environment variables must be set of the resolver will not run.>

The system administrator must ensure that the values provided for
read-write access do match a username (and password) that has
read-write access to the resolver database, and ideally that those
provided for readonly access do not.

The DBMS used (via the DBI framework) defaults to C<mysql>, but this
is overridden by the C<KRdbms> environment variable if set.

=cut

sub new {
    my $class = shift();
    my($resolver, $name, $rw) = @_;

    my($user, $pw);
    if ($rw) {
	$user = $ENV{KRrwuser} || die "no KRrwuser defined in environment";
	$pw = $ENV{KRrwpw}     || die "no KRrwpw defined in environment";
    } else {
	$user = $ENV{KRuser}   || die "no KRuser defined in environment";
	$pw = $ENV{KRpw}       || die "no KRpw defined in environment";
    }

    my $dbms = $ENV{KRdbms} || "mysql";
    my $dbh = DBI->connect_cached("dbi:$dbms:$name", $user, $pw,
				  { RaiseError => 1, AutoCommit => 1 });

    my $this = bless {
	resolver => $resolver,
	dbh => $dbh,
	cache => {},
    }, $class;

    # We don't want the back-reference to the parent object to prevent
    # its destruction.
    Scalar::Util::weaken($this->{resolver});

    $this->log(Keystone::Resolver::LogLevel::LIFECYCLE, "new DB $this with resolver=$resolver");
    return $this;
}


sub DESTROY {
    my $this = shift();
    Keystone::Resolver::static_log(Keystone::Resolver::LogLevel::LIFECYCLE,
				   "dead DB $this");
}


sub log {
    my $this = shift();
    my $resolver = $this->{resolver};
    if (defined $resolver) {
	return $resolver->log(@_);
    } else {
	warn "weakened {resolver} reference has become undefined: logging @_";
    }
}


sub loglookup {
    my $this = shift();
    return $this->log(Keystone::Resolver::LogLevel::DBLOOKUP,
		      map { !defined $_ ? "[undef]" :
				ref $_ ? $_->render() : $_ } @_);
}


sub genre_by_name {
    my $this = shift();
    my($name) = @_;

    my $obj = $this->find1("Genre", name => $name);
    return undef if !defined $obj;
    $this->loglookup("genre_by_name($name) -> ", $obj);
    return $obj;
}


sub genre_by_mformat {
    my $this = shift();
    my($mformat) = @_;

    # No doubt this could be optimised, but not using the object model
    my $mfobj = $this->find1("MetadataFormat", uri => $mformat);
    return undef if !$mfobj;
    my $obj = $this->find1("Genre", id => $mfobj->genre_id());
    $this->loglookup("genre_by_mformat($mformat) -> ", $obj);

    return $obj;
}


sub servicetypes_by_genre {
    my $this = shift();
    my($genreId) = @_;

    ### No doubt this could be optimised
    my @gst = $this->find("GenreServiceType", "service_type_id", genre_id => $genreId);
    my @ids = map { $_->service_type_id() } @gst;
    $this->loglookup("servicetypes_by_genre($genreId) -> " . join(", ", @ids));
    my @refs = ();
    foreach my $id (@ids) {
	# There should be no duplicates unless the database is broken
	my $stype = $this->find1("ServiceType", id => $id)
	    or die "no ServiceType $id";
	push @refs, $stype;
    }

    # Result is sorted lowest priority first
    return sort { $a->priority() <=> $b->priority() } @refs;
}


sub servicetypes_by_tags {
    my $this = shift();
    my(@tags) = @_;

    my @obj = $this->find("ServiceType", "priority", tag => \@tags);
    $this->loglookup("servicetypes_by_tag('@tags') -> " .
		     join(", ", map { $_->id() } @obj));
    return @obj;
}


sub services_by_type {
    my $this = shift();
    my($stID) = @_;

    my @obj = $this->find("Service", "priority", service_type_id => $stID);
    $this->loglookup("services_by_type($stID) -> " .
		     join(", ", map { $_->id() } @obj));
    return @obj;
}


sub services_by_tags {
    my $this = shift();
    my(@tags) = @_;

    my @obj = $this->find("Service", "priority", tag => \@tags);
    $this->loglookup("services_by_tag('@tags') -> " .
		     join(", ", map { $_->id() } @obj));
    return @obj;
}


sub service_by_type_and_tag {
    my $this = shift();
    my($type, $tag) = @_;

    my $obj = undef;
    my $stype = $this->find1("ServiceType", tag => $type);
    $obj = $this->find1("Service",
			 service_type_id => $stype->id(), tag => $tag)
	if defined $stype;
    $this->loglookup("service_by_type_and_tag($type, $tag) -> ",
		     $obj, !defined $stype ? " (unknown service-type)" : "");
    return $obj;
}


sub serial {
    my $this = shift();
    my($issn, $title) = @_;

    if (defined $issn) {
	# Match by ISSN if one is provided and detectable
	# Normalise spaces and hyphens in ISSN
	$issn =~ s/\s+//g;
	$issn =~ s/-//g;
	my $obj = $this->find1("Serial", issn => $issn);
	if (defined $obj) {
	    $this->loglookup("serial(issn=$issn) -> ", $obj);
	    return $obj;
	}
    }

    if (!defined $title) {
	$this->loglookup("serial(no title) NO MATCH");
	return undef;
    }

    # No ISSN match: we need to search for the title instead
    # Normalise case and whitespace in serial title
    $title = lc($title);
    $title =~ s/^\s+//;
    $title =~ s/\s+$//;
    $title =~ s/\s+/ /g;
    my $obj = $this->find1("Serial", name => $title);
    if (defined $obj) {
	$this->loglookup("serial(title=$title) -> ", $obj);
	return $obj;
    }

    # No match on primary title: we need to search the aliases
    my $alias = $this->find1("SerialAlias", alias => $title);
    if (defined $alias) {
	$obj = $this->find1("Serial", id => $alias->serial_id());
	$this->loglookup("serial(alias=$title) -> ", $obj);
	return $obj;
    }

    $this->loglookup("serial(alias=$title) NO MATCH");
    return undef;
}


sub service_has_serial {
    my $this = shift();
    my($service, $serial) = @_;

    my $ss = $this->find1("ServiceSerial", service_id => $service->id(),
					   serial_id => $serial->id());
    my $b = defined $ss ? 1 : 0;
    $this->loglookup("service_has_serial(", $service, ", ", "$serial) -> $b");
    return $b;
}


sub domain_by_name {
    my $this = shift();
    my($domain) = @_;

    my $obj = $this->find1("Domain", domain => $domain);
    $this->loglookup("domain_by_name($domain) -> ", $obj)
	if defined $obj;

    return $obj;
}


sub site_by_tag {
    my $this = shift();
    my($tag) = @_;

    my $obj = $this->find1("Site", tag => $tag);
    $this->loglookup("site_by_tag($tag) -> ", $obj)
	if defined $obj;

    return $obj;
}


# Wrappers for finding a single object of a specific type
sub session1 { shift()->find1("Keystone::Resolver::DB::Session", @_) }
sub user1 { return shift()->find1("Keystone::Resolver::DB::User", @_) }


# There is a cache in $this of loaded objects, indexed by the
# $class/@conds combination.  But in general we can't use this since
# we need a way of invalidating the cache when the relevant part of
# the database is modified.  But since the invalidation bit would have
# to be shared between all Apache processes, it would itself need to
# be stored in the database, so that a database search would necessary
# to determine whether a cached object is invalid.  In which case, why
# not just blindly do the search afresh each time the linked object is
# needed?  So the following code does _not_ appear in find1()
#
#    my $index = "$class:" . encode_hash(@conds);
#    my $obj = $this->{cache}->{$index};
#    if (defined $obj) {
#	$this->log(Keystone::Resolver::LogLevel::CACHECHECK,
#		   "reusing cached object $obj");
#    } else {
#	$obj = $this->_findraw($class, 1, undef, @conds);
#	$this->{cache}->{$index} = $obj;
#	$this->log(Keystone::Resolver::LogLevel::CACHECHECK,
#		   "fetched and cached object $obj");
#    }
#
#    return $obj;


# Returns a SCALAR of the first (hopefully only) matching object
sub find1 {
    my $this = shift();
    my($class, @conds) = @_;

    return $this->_findraw($class, 1, undef, @conds);
}


# Returns an ARRAY of objects matching the conditions
sub find {
    my $this = shift();
    my($class, $sortby, @conds) = @_;

    return $this->_findraw($class, 0, $sortby, @conds);
}


# @conds is a set of (key, value) pairs, with an implicit equality
# relation, and all the pairs are ANDed together.  $sortby, if
# defined, is the order in which to sort the discovered records.  If
# $single is true, this means to expect a single matching record and
# return just that record rather than an array.
#
sub _findraw {
    my $this = shift();
    my($class, $single, $sortby, @conds) = @_;
    $class = "Keystone::Resolver::DB::$class" if $class !~ /::/;

    my($cond, $rendered, @values) = _make_cond(@conds);
    my($sth, undef, $errmsg) = $this->_findcond($class, $cond, $sortby, 1, @values);
    die "_findraw(): $errmsg" if !defined $sth;

    my $refref = $sth->fetchall_arrayref();
    if ($single) {
	my $table = $class->table();
	if (@$refref == 0) {
	    $this->log(1, "no $table satisfying $rendered");
	    return undef;
	} elsif (@$refref > 1) {
	    $this->log(1, scalar(@$refref), " ${table}s satisfying $rendered");
	}
	my $ref = $refref->[0];
	return $class->new($this, map { decode_utf8($_) } @$ref);
    }

    return map { $class->new($this, map { decode_utf8($_) } @$_) } @$refref;
}


sub _make_cond {
    my(@conds) = @_;

    return (undef, "")
	if !@conds;

    my(@keys, @values);
    my $rendered = "";		# used only for error-messages
    for (my $i = 0; $i < @conds/2; $i++) {
	my $key = $conds[2*$i];
	my $value = $conds[2*$i+1];
	croak "key with value '$value' undefined" if !defined $key;
	croak "value for key '$key' undefined" if !defined $value;

	$rendered .= ", " if $i > 0;
	if (!ref $value) {
	    $rendered .= "$key=$value";
	    push @keys, $key;
	    push @values, $value;
	} else {
	    $rendered .= "$key=(" . join(" or ", @$value) . ")";
	    push @keys, [ $key, scalar(@$value) ];
	    push @values, @$value;
	}
    }

    my $cond = join(" AND ", map {
	my $res;
	if (ref $_) {
	    my($key, $n) = @$_;
	    $res = "(" . join(" OR ", map { "$key = ?" } (1..$n)) . ")";
	} else {
	    $res = "$_ = ?";
	}
	$res;
    } @keys);

    return ($cond, $rendered, @values);
}


# This is used directly by the Admin UI, but not by the resolver
# proper, which instead uses the higher-level methods find1() and
# find(), which call this through _findraw().
#
sub _findcond {
    my $this = shift();
    my($class, $cond, $sortby, $nocount, @values) = @_;

    my $table = $class->table();
    my @fields = $class->physical_fields();
    my $want = join(", ", @fields);

    my $sql = "SELECT $want FROM $table";
    $sql .= " WHERE $cond" if defined $cond;
    $sql .= " ORDER BY $sortby" if defined $sortby;
    my($sth, $errmsg) = $this->do($sql, 0, @values);
    return (undef, undef, $errmsg) if !defined $sth;

    my $count;
    $count = $this->_count($sth, $table, $cond) if !$nocount;

    return($sth, $count);
}


# Here we attempt to discover the number of records satisfying the
# query in as efficient a way as possible.  There's no reliable
# standard way to do this, so we have to pox about with
# driver-specific code: some support rows(), some do not.
#
sub _count {
    my $this = shift();
    my($sth, $table, $cond) = @_;
    my $dbh = $this->{dbh};

    #warn "driver name is '" . $dbh->{Driver}->{Name} . "'\n";

    # Exploit especially capable drivers that can count their own rows
    if ($dbh->{Driver}->{Name} eq "xmysql") {
	return $sth->rows();
    }

    # Some really brain-dead back-ends -- notably the Nearly Wonderful
    # DBD::CSV -- don't support SELECT COUNT(); so we just do the
    # actual query twice and damned well count the records.  Obviously
    # very inefficient.  So it goes: it'll never happen on a Real
    # Database.
    if ($dbh->{Driver}->{Name} ne "CSV") {
	my $sql = "SELECT id FROM $table";
	$sql .= " WHERE $cond" if defined $cond;
	my($sth, $errmsg) = $this->do($sql);
	die "can't count rows by hand: $errmsg" if !defined $sth;
	my $count = 0;
	while ($sth->fetchrow_array()) {
	    $count++;
	}
	return $count;
    }

    # Default implemetation
    my $sql = "SELECT COUNT(*) FROM $table";
    $sql .= " WHERE $cond" if defined $cond;
    my $countref = $dbh->selectall_arrayref($sql);
    die "can't count rows with '$sql': " . $dbh->errstr()
	if !defined $countref;

    return $countref->[0]->[0];
}


# Used by findcond() and _count(), and for INSERT, UPDATE and DELETE
# in DB/Object.pm.  The intention is that ALL SQL statements executed
# by the resolver and its admin UI come through here.
#
sub do {
    my $this = shift();
    my($sql, $return_id, @values) = @_;
    my $dbh = $this->{dbh};

    my $sth = $dbh->prepare($sql);
    return (undef, $dbh->errstr()) if !$sth;
    $this->log(Keystone::Resolver::LogLevel::SQL, "do(): $sql [", join(", ", @values), "]");
    $sth->execute(@values) or return (undef, $dbh->errstr());
    return $sth if !$return_id;

    # last_insert_id() doesn't work for DBD::mysql, but there is a
    # MySQL-specific hack that we can use instead.
    #my $id = $dbh->last_insert_id();
    my $id = $dbh->{mysql_insertid};
    die "can't get new record's ID" if !defined $id;

    return $id;
}


1;
