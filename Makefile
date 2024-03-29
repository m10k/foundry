DEPS = bots utils
PHONY = $(DEPS) install uninstall test

ifeq ($(PREFIX), )
	PREFIX = /usr
endif

all: $(DEPS)

clean: $(DEPS)

install: $(DEPS)
	mkdir -p $(DESTDIR)$(PREFIX)/share/toolbox/include
	mkdir -p $(DESTDIR)$(PREFIX)/share/foundry
	mkdir -p $(DESTDIR)/var/lib/foundry/contexts
	install --owner root --group root --mode 755 foundry.sh $(DESTDIR)$(PREFIX)/share/foundry/.
	ln -s $(PREFIX)/share/foundry/foundry.sh $(DESTDIR)$(PREFIX)/bin/foundry
	mkdir -p $(DESTDIR)/etc
	install --owner root --group root --mode 644 foundry.conf $(DESTDIR)/etc/.
	cp -r include $(DESTDIR)$(PREFIX)/share/foundry/.
	chown root.root $(DESTDIR)$(PREFIX)/share/foundry
	chown -R root.root $(DESTDIR)$(PREFIX)/share/foundry/include
	find $(DESTDIR)$(PREFIX)/share/foundry/include -type d -exec chmod 755 {} \;
	find $(DESTDIR)$(PREFIX)/share/foundry/include -type f -exec chmod 644 {} \;
	ln -s $(PREFIX)/share/foundry/include/foundry $(DESTDIR)$(PREFIX)/share/toolbox/include/foundry

uninstall: $(DEPS)
	rm $(DESTDIR)$(PREFIX)/share/toolbox/include/foundry
	rmdir $(DESTDIR)/var/lib/foundry/contexts
	rm -rf $(DESTDIR)$(PREFIX)/share/foundry

$(DEPS):
	$(MAKE) -C $@ $(MAKECMDGOALS)

.PHONY: $(PHONY)
