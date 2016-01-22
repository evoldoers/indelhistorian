.SECONDARY:

# try to figure out where GSL is
# autoconf would be better but we just need a quick hack for now :)
# Thanks to Torsten Seemann for gsl-config and pkg-config formulae
GSLPREFIX = $(shell gsl-config --prefix)
ifeq (,$(wildcard $(GSLPREFIX)/include/gsl/gsl_sf.h))
GSLPREFIX = /usr
ifeq (,$(wildcard $(GSLPREFIX)/include/gsl/gsl_sf.h))
GSLPREFIX = /usr/local
endif
endif

GSLFLAGS = $(shell pkg-config --cflags gsl)
ifeq (, $(GSLFLAGS))
GSLFLAGS = -I$(GSLPREFIX)/include
endif

GSLLIBS = $(shell pkg-config --libs gsl)
ifeq (, $(GSLLIBS))
GSLLIBS = -L$(GSLPREFIX)/lib -lgsl -lgslcblas -lm
endif

# figure out whether to use Boost
# Boost is optional -- it's only needed for regexes with gcc
# NB pkg-config support for Boost is lacking; see https://svn.boost.org/trac/boost/ticket/1094
BOOSTPREFIX = /usr
ifeq (,$(wildcard $(BOOSTPREFIX)/include/boost/regex.h))
BOOSTPREFIX = /usr/local
ifeq (,$(wildcard $(BOOSTPREFIX)/include/boost/regex.h))
BOOSTPREFIX =
endif
endif

BOOSTFLAGS =
BOOSTLIBS =
ifneq (,$(BOOSTPREFIX))
BOOSTFLAGS := -DUSE_BOOST -I$(BOOSTPREFIX)/include
BOOSTLIBS := -L$(BOOSTPREFIX)/lib -lboost_regex
endif

# install dir
PREFIX = /usr/local

# other flags
CPPFLAGS = -DUSE_VECTOR_GUARDS -std=c++11 -g $(GSLFLAGS) $(BOOSTFLAGS)
LIBFLAGS = -lstdc++ -lz $(GSLLIBS) $(BOOSTLIBS)

CPPFILES = $(wildcard src/*.cpp)

# try clang++, fall back to g++
CPP = clang++
ifeq (, $(shell which $(CPP)))
CPP = g++
endif

# pwd
PWD = $(shell pwd)

# /bin/sh
SH = /bin/sh

# Targets

MAIN = idhist

all: $(MAIN)

$(MAIN): bin/$(MAIN)

install: bin/$(MAIN)
	cp $< $(PREFIX)/bin
	chmod a+x $(PREFIX)/bin/$(MAIN)

uninstall:
	rm $(PREFIX)/bin/$(MAIN)

clean:
	rm -rf bin/*

# Main build rule
bin/%: $(CPPFILES) t/%.cpp
	test -e bin || mkdir bin
	$(CPP) $(CPPFLAGS) $(LIBFLAGS) -o $@ t/$*.cpp $(CPPFILES)

# Tests

test: testlogsumexp testrateio testmatexp testmerge

testlogsumexp: bin/testlogsumexp
	bin/testlogsumexp -slow >data/logsumexp.txt
	perl/testexpect.pl bin/testlogsumexp -fast data/logsumexp.txt

testmatexp: bin/testmatexp
	perl/testexpect.pl bin/testmatexp data/testrates.json 1 data/testrates.probs.json

testrateio: bin/testrateio
	perl/testexpect.pl bin/testrateio data/testrates.json data/testrates.out.json

testmerge: bin/testmerge
	perl/testexpect.pl bin/testmerge data/testmerge1.xy.fa data/testmerge1.xz.fa data/testmerge1.xyz.fa
	perl/testexpect.pl bin/testmerge data/testmerge1.xy.fa data/testmerge1.ayz.fa data/testmerge1.xyaz.fa
	perl/testexpect.pl bin/testmerge data/testmerge1.xz.fa data/testmerge1.ayz.fa data/testmerge1.xzay.fa
	perl/testexpect.pl bin/testmerge data/testmerge1.axyz.fa data/testmerge1.xz.fa data/testmerge1.axyz.fa
	echo "\nThe next test is expected to throw an exception - do not be alarmed:\n"
	perl/testexpect.pl bin/testmerge data/testmerge1.xy.fa data/testmerge1.xz.fa data/testmerge1-fail.ayz.fa data/empty

# Rules for building files in the repository
# For updating README.md
README.md: bin/$(MAIN)
	PATH=bin:$(PATH); $(MAIN) help | perl -pe 's/</&lt;/g;s/>/&gt;/g;' | perl -e 'open FILE,"<README.md";while(<FILE>){last if/<pre>/;print}close FILE;print"<pre><code>\n";while(<>){print};print"</code></pre>\n"' >temp.md
	mv temp.md $@
