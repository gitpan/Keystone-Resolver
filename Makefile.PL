# $Id: Makefile.PL,v 1.15 2007-12-01 23:59:11 mike Exp $

use 5.008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Keystone::Resolver',
    VERSION_FROM      => 'lib/Keystone/Resolver.pm', # finds $VERSION
    PREREQ_PM         => {
	# The versions specified for these prerequsite modules are
	# those that I happen to have on the staging box (Debian 3.1),
	# and which are therefore the oldest versions that I _know_
	# work.  There is every chance that older versions will work
	# just fine, though.
	CGI => 3.04,
	DBI => 1.46,
	LWP => 5.803,
	XML::LibXSLT => 1.57,
	Text::Iconv => 1.2,
	Digest::MD5 => 2.33,
	HTML::Entities => 1.32,
	Apache => 1.27,
    },
    EXE_FILES    => [ 'bin/kr-recipe', 'bin/kr-test' ],
    clean => { FILES => "build-stamp install-stamp t/regression/passed " .
			"debian/files " .
			"debian/keystone-resolver " .
			"debian/keystone-resolver-webui " .
			"debian/keystone-resolver-db " .
			"debian/keystone-resolver-db.substvars " .
			"debian/libkeystone-resolver-perl " .
			"debian/libkeystone-resolver-perl.substvars " .
			"debian/output" },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Keystone/Resolver.pm', # retrieve abstract from module
       AUTHOR         => 'Mike Taylor <mike@indexdata,com>') : ()),
);


sub MY::postamble { q[debian: debian/output

debian/output:
	dpkg-buildpackage -rfakeroot
	rm -rf debian/output
	mkdir debian/output
	mv ../*.deb ../*.dsc ../*.tar.gz ../*.changes debian/output
#	(cd debian/output; for i in *.deb; do name=`echo $$i | sed 's/\.deb$$//'`; dpkg-deb -c $$i > $$name.list; done)

debinstall: debian/output
	sudo dpkg -i debian/output/*.deb

debuninstall:
	sudo dpkg -r keystone-resolver keystone-resolver-webui libkeystone-resolver-perl keystone-resolver-db
];
}


# Do I need this?
#
## This nasty hack overrides the standard PERL_DL_NONLAZY=1 thing,
## which setting makes it impossible to load DBD::mysql on Red Hat 9
## systems.
##
## Doing this requires far too much knowledge of MakeMaker's Dirty
## Laundry.  Basically, by providing these packages in the MY package,
## we are overriding what's provided in MM_Unix, which is what's used
## on Red Hat 9.  By inspection of that package, we can see that its
## parent is MM_Any, so that's what we delegate to here.
##
#sub MY::test_via_harness {
#    my($self, $perl, $tests) = @_;
#    return $self->ExtUtils::MM_Any::test_via_harness($perl, $tests);
#}
#sub MY::test_via_script {
#    my($self, $perl, $tests) = @_;
#    return $self->ExtUtils::MM_Any::test_via_script($perl, $tests);
#}
