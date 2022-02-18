PHONY = install uninstall test

ifeq ($(PREFIX), )
	PREFIX = /usr
endif

all:

clean:

install:
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	mkdir -p $(DESTDIR)$(PREFIX)/share/toolbox/include
	mkdir -p $(DESTDIR)$(PREFIX)/share/foundry
	mkdir -p $(DESTDIR)/var/lib/foundry/contexts
	cp -r include $(DESTDIR)$(PREFIX)/share/foundry/.
	cp -r src $(DESTDIR)$(PREFIX)/share/foundry/bots
	chown -R root.root $(DESTDIR)$(PREFIX)/share/foundry
	find $(DESTDIR)$(PREFIX)/share/foundry -type d -exec chmod 755 {} \;
	find $(DESTDIR)$(PREFIX)/share/foundry -type f -exec chmod 644 {} \;
	find $(DESTDIR)$(PREFIX)/share/foundry/bots -type f -exec chmod 755 {} \;
	ln -s $(PREFIX)/share/foundry/bots/buildbot.sh $(DESTDIR)$(PREFIX)/bin/buildbot
	ln -s $(PREFIX)/share/foundry/bots/distbot.sh  $(DESTDIR)$(PREFIX)/bin/distbot
	ln -s $(PREFIX)/share/foundry/bots/signbot.sh  $(DESTDIR)$(PREFIX)/bin/signbot
	ln -s $(PREFIX)/share/foundry/bots/slackbot.sh $(DESTDIR)$(PREFIX)/bin/slackbot
	ln -s $(PREFIX)/share/foundry/bots/watchbot.sh $(DESTDIR)$(PREFIX)/bin/watchbot
	ln -s $(PREFIX)/share/foundry/include/foundry  $(DESTDIR)$(PREFIX)/share/toolbox/include/foundry

uninstall:
	rm $(DESTDIR)$(PREFIX)/bin/buildbot
	rm $(DESTDIR)$(PREFIX)/bin/distbot
	rm $(DESTDIR)$(PREFIX)/bin/signbot
	rm $(DESTDIR)$(PREFIX)/bin/slackbot
	rm $(DESTDIR)$(PREFIX)/bin/watchbot
	rm $(DESTDIR)$(PREFIX)/share/toolbox/include/foundry
	rm -rf $(DESTDIR)$(PREFIX)/share/foundry

.PHONY: $(PHONY)
