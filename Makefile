include pgxntool/base.mk

# TODO: Remove this after merging pgxntool 0.2.1+
testdeps: $(TEST_SQL_FILES) $(TEST_SOURCE_FILES)

testdeps: $(TESTDIR)/deps.sql $(TESTDIR)/load.sql

#
# OTHER DEPS
#
.PHONY: deps
deps: trunklet

.PHONY: trunklet
trunklet: $(DESTDIR)$(datadir)/extension/trunklet.control

$(DESTDIR)$(datadir)/extension/trunklet.control:
	pgxn install --unstable trunklet >= 0.2.0
