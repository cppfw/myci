all:

test:
	@(cd tests && ./test.sh)

ifeq ($(PREFIX),) #PREFIX is environment variable, but if it is not set, then set default value
    PREFIX := /usr/local
endif

install:
	@install -d $(DESTDIR)$(PREFIX)/bin
	@install src/*.sh $(DESTDIR)$(PREFIX)/bin
	@install -d $(DESTDIR)$(PREFIX)/include
	@install src/*.mk $(DESTDIR)$(PREFIX)/include
