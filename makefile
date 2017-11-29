all:

test:
	@(cd tests && ./test.sh)

PREFIX := /usr/local

install:
	@install -d $(DESTDIR)$(PREFIX)/bin
	@install src/*.sh $(DESTDIR)$(PREFIX)/bin
