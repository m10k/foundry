PHONY = install uninstall clean

ifeq ($(PREFIX), )
	PREFIX = /usr
endif

all:

install:
	mkdir --parents $(DESTDIR)$(PREFIX)/share/foundry/bots
	install --owner root --group root --mode 755 buildbot.sh $(DESTDIR)$(PREFIX)/share/foundry/bots/.
	install --owner root --group root --mode 755 distbot.sh  $(DESTDIR)$(PREFIX)/share/foundry/bots/.
	install --owner root --group root --mode 755 signbot.sh  $(DESTDIR)$(PREFIX)/share/foundry/bots/.
	install --owner root --group root --mode 755 slackbot.sh $(DESTDIR)$(PREFIX)/share/foundry/bots/.
	install --owner root --group root --mode 755 watchbot.sh $(DESTDIR)$(PREFIX)/share/foundry/bots/.
	mkdir --parents $(DESTDIR)$(PREFIX)/bin
	ln -sf $(PREFIX)/share/foundry/bots/buildbot.sh $(DESTDIR)$(PREFIX)/bin/buildbot
	ln -sf $(PREFIX)/share/foundry/bots/distbot.sh  $(DESTDIR)$(PREFIX)/bin/distbot
	ln -sf $(PREFIX)/share/foundry/bots/signbot.sh  $(DESTDIR)$(PREFIX)/bin/signbot
	ln -sf $(PREFIX)/share/foundry/bots/slackbot.sh $(DESTDIR)$(PREFIX)/bin/slackbot
	ln -sf $(PREFIX)/share/foundry/bots/watchbot.sh $(DESTDIR)$(PREFIX)/bin/watchbot

uninstall:
	rm -rf $(DESTDIR)$(PREFIX)/share/foundry/bots
	rm $(DESTDIR)$(PREFIX)/bin/buildbot
	rm $(DESTDIR)$(PREFIX)/bin/distbot
	rm $(DESTDIR)$(PREFIX)/bin/signbot
	rm $(DESTDIR)$(PREFIX)/bin/slackbot
	rm $(DESTDIR)$(PREFIX)/bin/watchbot

clean:

.PHONY: $(PHONY)
