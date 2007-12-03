# $Id: Database.pm,v 1.15 2007-09-20 17:48:02 mike Exp $

package Keystone::Resolver::Database;

use strict;
use warnings;
use DBI;
use Encode;			# To decode UTF-8 sequences from DB
use Carp;
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

 $des = new Keystone::Resolver::Database($resolver, $name);

Constructs a new Database for the specified resolver, using the
specified name.

=cut

sub new {
    my $class = shift();
    my($resolver, $name, $rw) = @_;

    my %auth = (kr_read => "kr_read_3636");
    %auth = (kr_admin => "kr_adm_3636") if $rw;

    # We could use resolver options for username/password?
    my $dbh = DBI->connect("dbi:mysql:$name", %auth,
			   { RaiseError => 1, AutoCommit => 1 });

    return bless {
	resolver => $resolver,
	dbh => $dbh,
	cache => {},
    }, $class;
}


sub log { my $this = shift(); return $this->{resolver}->log(@_) }
sub loglookup { my $this = shift();
		return $this->log(Keystone::Resolver::LogLevel::DBLOOKUP, @_) }


sub genre_by_name {
    my $this = shift();
    my($name) = @_;

    my $obj = $this->_objectFromDB("Genre", 1, name => $name);
    return undef if !defined $obj;
    $this->loglookup("genre_by_name($name) -> ", $obj->render());
    return $obj;
}


sub genre_by_mformat {
    my $this = shift();
    my($mformat) = @_;

    ### No doubt this could be optimised
    my($id) = $this->_find1values("genre_id", "mformat", uri => $mformat);
    my $obj = $this->_objectFromDB("Genre", 0, id => $id);
    $this->loglookup("genre_by_mformat($mformat) -> ", $obj->render());

    return $obj;
}


sub servicetypes_by_genre {
    my $this = shift();
    my($genreId) = @_;

    ### No doubt this could be optimised
    my @idRefs = $this->_findvalues("service_type_id", "genre_service_type",
			      genre_id => $genreId);
    my @ids = map { $_->[0] } @idRefs;
    $this->loglookup("servicetypes_by_genre($genreId) -> " . join(", ", @ids));
    my @refs = ();
    foreach my $id (@ids) {
	# There should be no duplicates unless the database is broken
	push @refs, $this->_objectFromDB("ServiceType", 0, id => $id);
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
    my $stype = $this->_objectFromDB("ServiceType", 1, tag => $type);
    $obj = $this->_objectFromDB("Service", 1,
			 service_type_id => $stype->id(), tag => $tag)
	if defined $stype;
    $this->loglookup("service_by_type_and_tag($type, $tag) -> ",
		     defined $obj ? $obj->render() : "UNDEF",
		     !defined $stype ? " (unknown service-type)" : "");
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
	my $obj = $this->_objectFromDB("Serial", 1, issn => $issn);
	if (defined $obj) {
	    $this->loglookup("serial(issn=$issn) -> " . $obj->render());
	    return $obj;
	}
    }

    # No ISSN match: we need to search for the title instead
    # Normalise case and whitespace in serial title
    $title = lc($title);
    $title =~ s/^\s+//;
    $title =~ s/\s+$//;
    $title =~ s/\s+/ /g;
    my $obj = $this->_objectFromDB("Serial", 1, name => $title);
    if (defined $obj) {
	$this->loglookup("serial(title=$title) -> " . $obj->render());
	return $obj;
    }

    # No match on primary title: we need to search the aliases
    my @data = $this->_find1values("serial_id", "serial_alias", alias => $title);
    if (@data == 0) {
	$this->loglookup("serial(alias=$title) NO MATCH");
	return undef;
    }

    my $id = $data[0];
    $obj = $this->_objectFromDB("Serial", 0, id => $id);
    $this->loglookup("serial(alias=$title) -> " . $obj->render());
    return $obj;
}


sub service_has_serial {
    my $this = shift();
    my($service, $serial) = @_;

    my @data = $this->_find1values("service_id", "service_serial",
			     service_id => $service->id(),
			     serial_id => $serial->id());
    return @data != 0;
}


sub domain_by_name {
    my $this = shift();
    my($domain) = @_;

    my $obj = $this->_objectFromDB("Domain", 1, domain => $domain);
    $this->loglookup("domain_by_name($domain) -> ", $obj->render())
	if defined $obj;

    return $obj;
}


sub site_by_tag {
    my $this = shift();
    my($tag) = @_;

    my $obj = $this->_objectFromDB("Site", 1, tag => $tag);
    $this->loglookup("site_by_tag($tag) -> ", $obj->render())
	if defined $obj;

    return $obj;
}


### Do not use for new code -- use find1() instead
sub _objectFromDB {
    my $this = shift();
    my($type, $allowNoMatch, @conds) = @_;

    my $fields = join(",", "Keystone::Resolver::DB::$type"->physical_fields());
    my $table = "Keystone::Resolver::DB::$type"->table("dummy-type");
    my @data = $this->_find1values($fields, $table, @conds);
    if (@data == 0) {
	return undef if $allowNoMatch;
	die("_objectFromDB($type): no match for " . $this->condstr(@conds));
    }

    return "Keystone::Resolver::DB::$type"->new($this, @data);
}


### Do not use for new code -- use find1() instead
sub _find1values {
    my $this = shift();
    my($want, $table, @conds) = @_;

    my @refs = $this->_findvalues(@_);
    return ()
	if @refs == 0;

    if (@refs > 1) {
	### We should use OpenURL::warn(), but at this point in the
	#	code, we don't know what OpenURL we're trying to
	#	resolve.  Could be fixed by moving all this code into
	#	a per-OpenURL Database class, but the payoff is small.
	warn("multiple hits (" . scalar(@refs) . ") for $table." .
	     $this->_condstr(@conds) .  ": " .
	     join(", ", map { "[" . join(", ", @$_) . "]" } @refs));
    }

    return @{ $refs[0] };
}


### Do not use for new code -- use find() instead
sub _findvalues {
    my $this = shift();
    my($want, $table, @conds) = @_;

    my(@keys, @values);
    for (my $i = 0; $i < @conds/2; $i++) {
	push @values, $conds[2*$i+1];
	push @keys, $conds[2*$i];
    }

    my $cmd = ("select $want from $table where " .
	       join(" and ", map { "$_ = ?" } @keys));
    $this->log(Keystone::Resolver::LogLevel::SQL,
	       "_findvalues(): $cmd [", join(", ", @values), "]");
    my $sth = $this->{dbh}->prepare($cmd);
    $sth->execute(@values);

    my $refref = $sth->fetchall_arrayref();
    return map { [ map { decode_utf8($_) } @$_ ] } @{ $refref };
}


# Wrappers for finding a single object of a specific type
sub session1 { shift()->find1("Keystone::Resolver::DB::Session", @_) }
sub user1 { return shift()->find1("Keystone::Resolver::DB::User", @_) }


# Returns a SCALAR of the first (hopefully only) matching object
sub find1 {
    my $this = shift();
    my $class = shift();
    my @conds = @_;

    return $this->_findraw($class, 1, undef, @conds);

# There is a cache in $this of loaded objects, indexed by the
# $class/@conds combination.  But in general we can't use this since
# we need a way of invalidating the cache when the relevant part of
# the database is modified.  But since the invalidation bit would have
# to be shared between all Apache processes, it would itself need to
# be stored in the database, so that a database search would necessary
# to determine whether a cached object is invalid.  In which case, why
# not just blindly do the search afresh each time the linked object is
# needed?
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
}


# Returns an ARRAY of objects matching the conditions
sub find {
    my $this = shift();
    my($class, $sortby, @conds) = @_;

    return $this->_findraw($class, 0, $sortby, @conds);
}


# @conds is a set of (key, value) pairs, with an implicit equality
# relation, and all the pairs are ANDed together.  $sortby is the
# order in which to sort the discovered records: if it is undefined,
# this means to expect a single matching record and return just that
# record rather than an array.
#
sub _findraw {
    my $this = shift();
    my $class = shift();
    my $single = shift();
    my $sortby = shift();
    my @conds = @_;

    $class = "Keystone::Resolver::DB::$class" if $class !~ /::/;
    my $table = $class->table();
    my @fields = $class->physical_fields();
    my $want = join(", ", @fields);

    my(@keys, @values);
    my $rendered = "";		# used only for error-messages
    for (my $i = 0; $i < @conds/2; $i++) {
	my $key = $conds[2*$i];
	my $value = $conds[2*$i+1];
	croak "key with value '$value' undefined" if !defined $key;
	croak "value for key '$key' undefined" if !defined $value;

	$rendered .= ", " if $i > 0;
	if (ref $value) {
	    $rendered .= "$key=(" . join(" or ", @$value) . ")";
	    push @keys, [ $key, scalar(@$value) ];
	    push @values, @$value;
	} else {
	    $rendered .= "$key=$value";
	    push @keys, $key;
	    push @values, $value;
	}
    }

    my $cmd = "select $want from $table";
    if (@keys) {
	$cmd .= " where " . join(" and ", map {
	    my $res;
	    if (ref $_) {
		my($key, $n) = @$_;
		$res = "(" . join(" or ", map { "$key = ?" } (1..$n)) . ")";
	    } else {
		$res = "$_ = ?";
	    }
	    $res;
	} @keys);
    }

    $cmd .= " order by $sortby" if defined $sortby;
    $this->log(Keystone::Resolver::LogLevel::SQL,
	       "_findraw(): $cmd [", join(", ", @values), "]");
    my $sth = $this->{dbh}->prepare($cmd);
    $sth->execute(@values);

    my $refref = $sth->fetchall_arrayref();
    if ($single) {
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


### There are far too many near-identical functions here
sub _findcond {
    my $this = shift();
    my($class, $cond, $sort) = @_;

    my $dbh = $this->{dbh};
    my $table = $class->table();
    my @fields = $class->physical_fields();
    my $want = join(", ", @fields);

    # First, count how many rows we're going to find
    my $sql = "select count(*) from $table where $cond";
    my $countref = $dbh->selectall_arrayref($sql);
    my $count = $countref->[0]->[0];

    $sql = "select $want from $table where $cond";
    $sql .= " order by $sort" if defined $sort;
    $this->log(Keystone::Resolver::LogLevel::SQL, "_findcond(): $sql");
    my($sth, $errmsg) = $this->do($sql, 0);
    return (undef, undef, $errmsg) if !defined $sth;
    return($sth, $count);
}


sub do {
    my $this = shift();
    my($sql, $return_id) = @_;

    my $sth = $this->{dbh}->prepare($sql);
    $this->log(Keystone::Resolver::LogLevel::SQL, "doing: $sql");
    $sth->execute();
    return $sth if !$return_id;

    # last_insert_id() doesn't work for DBD::mysql, but there is a
    # MySQL-specific hack that we can use instead.
    #my $id = $this->{dbh}->last_insert_id();
    my $id = $this->{dbh}->{mysql_insertid};
    die "can't get new record's ID" if !defined $id;

    return $id;
}


sub _condstr {
    my $this = shift();
    my(@conds) = @_;

    my $s;
    for (my $i = 0; $i < @conds/2; $i++) {
	my $key = $conds[2*$i];
	my $value = $conds[2*$i+1];
	$s .= ", " if $i > 0;
	$s .= "$key=$value";
    }

    return $s;
}


1;
