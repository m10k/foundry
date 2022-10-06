PHONY = install uninstall clean

ifeq ($(PREFIX), )
	PREFIX = /usr
endif

all:

install:
	mkdir --parents $(DESTDIR)$(PREFIX)/share/foundry/utils
	install --owner root --group root --mode 755 foundry-ctxtap.sh    $(DESTDIR)$(PREFIX)/share/foundry/utils/.
	install --owner root --group root --mode 755 foundry-ctxinject.sh $(DESTDIR)$(PREFIX)/share/foundry/utils/.
	mkdir --parents $(DESTDIR)$(PREFIX)/bin
	ln -sf $(PREFIX)/share/foundry/utils/foundry-ctxtap.sh    $(DESTDIR)$(PREFIX)/bin/foundry-ctxtap
	ln -sf $(PREFIX)/share/foundry/utils/foundry-ctxinject.sh $(DESTDIR)$(PREFIX)/bin/foundry-ctxinject

uninstall:
	rm -rf $(DESTDIR)$(PREFIX)/share/foundry/utils
	rm $(DESTDIR)$(PREFIX)/bin/foundry-ctxtap
	rm $(DESTDIR)$(PREFIX)/bin/foundry-ctxinject

clean:

.PHONY: $(PHONY)
