all:

test:

PREFIX := /usr/local

install:
	@install -d $(DESTDIR)$(PREFIX)/bin
	@install src/*.sh $(DESTDIR)$(PREFIX)/bin
