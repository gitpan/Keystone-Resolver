# $Id: Makefile,v 1.3 2007-12-17 11:55:41 mike Exp $

# This way of running the tests is usually not needed, as the Perl
# packaging system's "make test" also works.  But this way is
# occasionally useful since it displays errors in more detail.

AUTH=env KRuser=kr_read KRpw=kr_read_3636

test: passed
	$(AUTH) perl -I../../lib ../../bin/kr-test nowarn=1 show_xml=1 `cat passed`

### Don't do this unless you really, really want to.
really-rewrite: passed
	$(AUTH) perl -I../../lib ../../bin/kr-test -w nowarn=1 show_xml=1 `cat passed`

passed: Register
	sed -n 's/^pass	//p' $? > $@

try: failed
	$(AUTH) perl -I../../lib ../../bin/kr-test `cat failed`

failed: Register
	sed -n 's/^	//p' $? > $@

# This is just a file of URLs, one per line, to paste into browsers
urls: passed Makefile
	cat $< | while read f; do sed -n '/^[a-z]/{p;q}' $$f; done | \
		sed 's/^/http:\/\/resolver.indexdata.com\/resolve?/' > $@

clean:
	rm -f passed failed urls

