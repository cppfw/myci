all:

test:
	@(cd tests && ./test.sh)

ifeq ($(PREFIX),) # PREFIX is environment variable, but if it is not set, then set default value
    PREFIX := /usr/local
endif

install:
	@install -d $(DESTDIR)$(PREFIX)/bin
	@install src/bash/*.sh $(DESTDIR)$(PREFIX)/bin
	@install -d $(DESTDIR)$(PREFIX)/lib/cmake/myci/modules
	@install src/cmake/*.cmake $(DESTDIR)$(PREFIX)/lib/cmake/myci
	@install src/cmake/modules/*.cmake $(DESTDIR)$(PREFIX)/lib/cmake/myci/modules
