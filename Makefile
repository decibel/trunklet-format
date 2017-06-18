include pgxntool/base.mk

# TODO: Remove this after merging pgxntool 0.2.1+
testdeps: $(TEST_SQL_FILES) $(TEST_SOURCE_FILES)

testdeps: $(TESTDIR)/deps.sql $(TESTDIR)/load.sql

#
# Docs
#
ifeq (,$(ASCIIDOC))
ASCIIDOC = $(shell which asciidoc)
endif # ASCIIDOC
ifneq (,$(ASCIIDOC))
DOCS_built := $(DOCS:.asc=.html) $(DOCS:.adoc=.html)
DOCS += $(DOCS_built)

install: $(DOCS_built)
%.html: %.asc
	asciidoc $<
endif # ASCIIDOC

#
# OTHER DEPS
#
.PHONY: deps
install: deps
deps: trunklet extension_drop

.PHONY: trunklet
trunklet: $(DESTDIR)$(datadir)/extension/trunklet.control
$(DESTDIR)$(datadir)/extension/trunklet.control:
	pgxn install 'trunklet>=0.3.3' # 0.3.3 adds support for ignore_missing_functions

.PHONY: extension_drop
extension_drop: $(DESTDIR)$(datadir)/extension/extension_drop.control
# 0.1.1 fixes dependencies
$(DESTDIR)$(datadir)/extension/extension_drop.control:
	pgxn install --unstable 'extension_drop>=0.1.1'

