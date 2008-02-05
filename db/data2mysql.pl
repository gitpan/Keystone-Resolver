#!/usr/bin/perl -w

# $Id: data2mysql.pl,v 1.3 2008-02-05 02:19:32 mike Exp $
#
# Converts data from a simple, easy-to-edit format called d2m into SQL
# INSERT statements suitable for feeding to MySQL.  The d2m format is
# defined as follows:
#	Comments, from "#" to the end of the line, are discarded
#	Leading and trailing whitespace is discarded
#	Blank lines are ignored
#	Otherwise, lines are either Table or Row Directives:
#	Table Directives looks like this: *<name>=<col1>,<col2>,...
#		They indicate that following lines are row lines for
#		the table called <name>, and that they consist of
#		values for the specified values in the specified
#		order.
#	Row Directives look like this: <val1>,<val2>,...
#		The indicate that the specified values should be added
#		as a row to the table most recently indicated by a
#		Table Directive, with the values corresponding in
#		order to the columns nominated in that Directive.

use strict;
use warnings;

my $table = undef;
my @columns;

while (<>) {
    chomp();
    s/^#.*//;
    s/[^&0-9]#.*//;
    s/\s+$//;
    s/^\s+//;
    next if !$_;
    if (/^\*(.*)=(.*)/) {
	$table = $1;
	@columns = split /,/, $2;
	next;
    }

    die "$0: no Table Directive before first Row Directive"
	if !defined $table;

    my @data = split /,/, $_, -1;

    # Serial-specific hacks are neither necessary (as matching is
    # case-insensitive) nor desirable (since these are edited in the
    # Admin UI).
    if (0 && $table eq "serial") {
	foreach my $i (0 .. $#columns) {
	    if ($columns[$i] eq "name") {
		# Normalise case and whitespace in serial title
		my $title = lc($data[$i]);
		$title =~ s/^\s+//;
		$title =~ s/\s+$//;
		$title =~ s/\s+/ /g;
		$data[$i] = $title;
	    } elsif ($columns[$i] eq "issn") {
		# Normalise hyphens and whitespace in ISSN
		my $issn = $data[$i];
		$issn =~ s/\s+//g;
		$issn =~ s/-//g;
		$data[$i] = $issn;
	    }
	}
    }

    print("INSERT INTO $table (", join(", ", @columns), ") ",
	  "VALUES (", join(", ", map { s/[']/''/g; "'$_'" } @data), ");\n");
}
