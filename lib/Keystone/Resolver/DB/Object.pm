# $Id: Object.pm,v 1.27 2007-12-13 17:12:03 mike Exp $

package Keystone::Resolver::DB::Object;

use strict;
use warnings;
use Carp;


sub new {
    my $class = shift();
    my($db) = shift();

    my @fields = $class->physical_fields();
    my %hash = (_db => $db);
    foreach my $i (1 .. @fields) {
	my $key = $fields[$i-1];
	my $value = $_[$i-1];
	$hash{$key} = $value;
    }

    return bless \%hash, $class;
}


sub class {
    my $this = shift();
    my $class = ref $this;
    $class =~ s/^Keystone::Resolver::DB:://;
    return $class;
}


# Accessors and delegations
sub db { shift()->{_db} }
sub log { shift()->{_db}->log(@_) }

# Default implementations of subclass-specific virtual functions
# fields() must be explicitly provided for searchable classes
# virtual_fields() must be explicitly provided for searchable classes
sub mandatory_fields { qw() }
# search_fields() must be explicitly provided for searchable classes
# display_fields() must be explicitly provided for searchable classes
sub fulldisplay_fields { shift()->display_fields(@_) }
sub field_map { {} }


# Returns a list of all the field specified by fields(), with types
# drawn from fulldisplay_fields() where available and using "t" when
# not.
#
# Fields which are used as the link-field in a virtual-field recipe
# not of the "dependent-link" type are omitted (e.g. service_type_id
# from the Service class, because it is the link-field in the
# service_type recipe).
#
# Virtual fields that are of not of the "dependent-link" type have a
# exclude-at-creation-time attribute prepended to their type, if they
# don't already have it.
#
sub editable_fields {
    my $class = shift();

    my @allfields = $class->fields();
    my %hash = @allfields;
    my(%linkFields, %virtualFields);
    foreach my $key (keys %hash) {
	my $value = $hash{$key};
	if (defined $value && ref $value && @$value > 3) {
	    $virtualFields{$key} = 1;
	    $linkFields{$value->[0]} = 1;
	}
    }

    my %fdfields = $class->fulldisplay_fields();
    my @res;

    while (@allfields) {
	my $name = shift @allfields;
	my $recipe = shift @allfields;
	if (defined $linkFields{$name}) {
	    warn "omitting '$name' from editable_field($class)\n";
	    next;
	}

	my $display = $fdfields{$name} || "t";
	if (defined $virtualFields{$name}) {
	    $display = "X$display" if $display !~ /X/;
	    warn "made '$name' readonly '$display' in editable_field($class)\n";
	}

	push @res, ($name, $display);
    }

    return @res;
}


sub physical_fields {
    my $class = shift();

    my @allfields = $class->fields();
    my @pfields;
    while (@allfields) {
	my $name = shift @allfields;
	my $recipe = shift @allfields;
	push @pfields, $name if !defined $recipe;
    }

    return @pfields;
}


sub virtual_fields {
    my $class = shift();

    my @allfields = $class->fields();
    my @vfields;
    while (@allfields) {
	my $name = shift @allfields;
	my $recipe = shift @allfields;
	push @vfields, $name, $recipe if defined $recipe;
    }

    return @vfields;
}


# Parses full-type strings such as those used on the RHS of
# display_fields() arrays, e.g. "c", "Lt", "Rn".  Returns an array of
# four elements:
#	0: whether the field is a link
#	1: whether the field is readonly
#	2: the field's core type
#	3: whether the field should be excluded at creation time.
# (It would make more sense if 2 and 3 were reversed, but existing
# code assumes the first three elements from before the fourth was
# added.)
#
sub analyse_type {
    my $_unused_this = shift();
    my($type, $field) = @_;

    return (undef, undef, $type) if ref $type;
    my $link = ($type =~ s/L//);
    my $readonly = ($type =~ s/R//);
    my $exclude = ($type =~ s/X//);
    # Special-case the fields that we know may never change
    $readonly = 1 if grep { $field eq $_ } qw(id tag);

    return ($link, $readonly, $type, $exclude);
}


# Returns name of CSS class to be used for displaying fields of the
# specified type.  ### Knows about what's in "style.css"
#
sub type2class {
    my $this = shift();
    my($type) = @_;

    return "enum" if ref($type) eq "ARRAY";
    return $type if grep { $type eq $_ } qw(t c n b);
    return "error";
}


sub create {
    my $class = shift();
    my($db, %maybe_data) = @_;

    my %data;
    foreach my $key (keys %maybe_data) {
	$data{$key} = $maybe_data{$key}
	    if $maybe_data{$key} ne "" &&
	    grep { $_ eq $key } $class->physical_fields();
    }

    my $sql = "INSERT INTO " . $class->table() .
	" (" . join(", ", sort keys %data) . ") VALUES" .
	" (" . join(", ", map { sql_quote($data{$_}) } sort keys %data) . ");";
    my $id = $db->do($sql, 1);
    return $db->find1($class, id => $id);
}


sub sql_quote {
    my($text) = @_;
    my $sq = "'";

    $text =~ s/$sq/''/g;
    return "'$text'";
}


# Returns a label to be used on-screen for the specified field
sub label {
    my $this = shift();
    my($field, $label) = @_;

    return $label if defined $label;
    my $map = $this->field_map();
    $label = $map->{$field};
    return $label if defined $label;

    # No explicit label passed, and none in config: use default rules
    $label = $field;
    $label =~ s/_/ /g;
    return ucfirst($label);
}


# Return the components needed to identify a linked-to object
sub link {
    my $this = shift();
    my($field) = @_;

    my %virtual = $this->virtual_fields();
    my $ref = $virtual{$field};
    return undef if !defined $ref;
    my($linkfield, $linkclass, $linkto) = @$ref;
    my $linkid = $this->field($linkfield);

    return ($linkclass, $linkto, $linkid, $linkfield);
}


# Returns the number of fields modified, dies on error
sub update {
    my $this = shift();
    my(%maybe_data) = @_;

    my %data;
    foreach my $key (keys %maybe_data) {
	$data{$key} = $maybe_data{$key}
	    if (!defined $this->field($key) ||
		$maybe_data{$key} ne $this->field($key));
    }

    return 0 if !%data;		# nothing to do
    my $sql = "UPDATE " . $this->table() . " SET " .
	join(", ", map { "$_ = " . sql_quote($data{$_}) } sort keys %data) .
	" WHERE id = " . $this->id() . ";";

    $this->db()->do($sql, 0);
    foreach my $key (keys %data) {
	$this->field($key, $data{$key});
    }

    return scalar keys %data;
}


sub field {
    my $this = shift();
    my($fieldname, $value) = @_;

    die "$this: request for system-function field '$fieldname'"
	if grep { $_ eq $fieldname } qw(table fields mandatory_fields
					physical_fields
					virtual_fields search_fields
					sort_fields display_fields
					fulldisplay_fields field_map
					field);

    if (grep { $_ eq $fieldname } $this->physical_fields()) {
	$this->{$fieldname} = $value if defined $value;
	return $this->{$fieldname};
    }

    my %virtual;
    eval { %virtual = $this->virtual_fields() };
    if (!defined $virtual{$fieldname}) {
	confess "$this: field `$fieldname' not defined";
    } elsif (defined $value) {
	die "can't set virtual field '$fieldname'='$value'";
    } else {
	return $this->virtual_field($fieldname);
    }
}


sub virtual_field {
    my $this = shift();
    my($fieldname) = @_;

    my %virtual = $this->virtual_fields();
    my $ref = $virtual{$fieldname};
    my($linkfield, $class, $linkto, $sortby, $valfield) = @$ref;

    my $value = $this->field($linkfield);
    return undef if !defined $value; # e.g. link-field in new record

    if (defined $sortby) {
	# Link is to multiple records
	my @obj = $this->db()->find($class, $sortby, $linkto, $value);
	#warn "$this->virtual_fields($fieldname) -> @obj";
	return [ @obj ];
    }

    # Link is to a single "parent" record
    my $obj = $this->db()->find1($class, $linkto, $value);
    if (!defined $obj) {
	# The link is broken!  The Dark Lord's reign begins!
	return "[$class:$linkto:$value]";
    }

    if (defined $valfield) {
	return $obj->field($valfield);
    } else {
	return $obj->render_name();
    }
}


sub AUTOLOAD {
    my $this = shift();

    my $class = ref $this || $this;
    use vars qw($AUTOLOAD);
    (my $fieldname = $AUTOLOAD) =~ s/.*:://;
    die "$class: request for field '$fieldname' on undefined object"
	if !defined $this;

    return $this->field($fieldname);
}


sub DESTROY {} # Avoid warning from AUTOLOAD()


sub render {
    my $this = shift();
    my $class = ref($this);

    my $name;
    eval {
	$name = $this->tag();
    }; if ($@ || !$name) {
	undef $@;		### should this really be necessary?
	eval {
	    $name = $this->name();
	}; if ($@ || !$name) {
	    undef $@;		### should this really be necessary?
	    $name = undef;
	}
    }

    my $text = "$class " . $this->id();
    $text .= " ($name)" if defined $name;
    return $text;
}


sub render_name {
    my $this = shift();

    my $res;
    eval { $res = $this->name() };
    if (!$@ && defined $res) {
	#warn "returning name()='$res'";
	return $res;
    }
    eval { $res = $this->tag() };
    if (!$@ && defined $res) {
	#warn "returning tag()='$res'";
	return $res;
    }

    my $id = $this->id();
    if (defined $id) {
	#warn "returning id '$id'";
	return ref($this) . " " . $id;
    }

    #warn "returning new";
    return "[NEW]";
}


1;
