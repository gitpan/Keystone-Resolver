# $Id: regression.t,v 1.2 2007-12-11 16:59:57 mike Exp $

use strict;
use Test;
use vars qw(@tests);

BEGIN {
    @tests = qw(
		fail-jtitle
		feature-jtitle
		feature-single
		openly-01
		openly-02
		openly-03
		openly-03a
		openly-04
		openly-05
		openly-06
		openly-07
		openly-08
		openly-09
		openly-10
		openly-12
		openly-13
		openly-14
		standard-0.1-p4
		standard-0.1-p5b
		zetoc-sauroposeidon1
		zetoc-sauroposeidon2
		zetoc-suuwassea
		);
    plan tests => 1 + scalar(@tests);
};
use Keystone::Resolver::Test;
ok(1); # If we made it this far, we're ok.

$ENV{KRuser} = "kr_read";
$ENV{KRpw} = "kr_read_3636";

foreach my $test (@tests) {
    my $status = Keystone::Resolver::Test::run_test({ xml => 1, nowarn => 1 },
						    "t/regression/$test", 1);
    if ($status == 1) {
	ok($status, 0, "generated XML did not match expected");
    } elsif ($status == 2) {
	ok($status, 0, "fatal error in resolver");
    } elsif ($status == 3) {
	ok($status, 0, "malformed test-case");
    } elsif ($status == 4) {
	ok($status, 0, "system error: $!");
    } else {
	ok($status, 0, "failed with status=$status");
    }
}
