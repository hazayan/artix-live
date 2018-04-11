VERSION=0.1

PKG = live-services
PREFIX = /usr/local
SYSCONFDIR = /etc

FMODE = -m0644
DMODE = -dm0755
BMODE = -m0755
RM = rm -f

BIN = \
	bin/artix-live

LIBS = $(wildcard lib/*.sh)

SHARED = \
	$(wildcard data/*.map) \
	data/live.conf

RC = \
	data/rc/gnupg-mount \
	data/rc/pacman-init \
	data/rc/artix-live

RUNIT_CORE = \
	data/runit/89-artix-live.sh

RUNIT_SV = \
	data/runit/pacman-init.run

GRUB_DEFAULT = \
	data/grub2-portable-efi

GRUB_D = \
	data/99_zzz-portable-efi

all: $(BIN) $(RC) $(RUNIT_SV) $(XBIN) ${GRUB_D}

EDIT = sed -e "s|@datadir[@]|$(DESTDIR)$(PREFIX)/share/artools|g" \
	-e "s|@sysconfdir[@]|$(DESTDIR)$(SYSCONFDIR)/artools|g" \
	-e "s|@libdir[@]|$(DESTDIR)$(PREFIX)/lib/artools|g"

%: %.in Makefile
	@echo "GEN $@"
	@$(RM) "$@"
	@m4 -P $@.in | $(EDIT) >$@
	@chmod a-w "$@"
	@chmod +x "$@"

clean:
	$(RM) $(BIN) $(RC) ${GRUB_D}

install_base:
	install $(DMODE) $(DESTDIR)$(PREFIX)/bin
	install $(BMODE) ${BIN} $(DESTDIR)$(PREFIX)/bin

	install $(DMODE) $(DESTDIR)$(PREFIX)/lib/artools
	install $(FMODE) ${LIBS} $(DESTDIR)$(PREFIX)/lib/artools

	install $(DMODE) $(DESTDIR)$(PREFIX)/share/artools
	install $(FMODE) ${SHARED} $(DESTDIR)$(PREFIX)/share/artools

install_rc:
	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/init.d
	install $(BMODE) ${RC} $(DESTDIR)$(SYSCONFDIR)/init.d

install_runit:
	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/runit/core-services
	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/sv/pacman-init
	install $(BMODE) ${RUNIT_CORE} $(DESTDIR)$(SYSCONFDIR)/runit/core-services
	install $(BMODE) ${RUNIT_SV} $(DESTDIR)$(SYSCONFDIR)/runit/sv/pacman-init/run

install_portable_efi:
	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/default
	install $(BMODE) $(GRUB_DEFAULT) $(DESTDIR)$(SYSCONFDIR)/default

	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/grub.d
	install $(BMODE) $(GRUB_D) $(DESTDIR)$(SYSCONFDIR)/grub.d

uninstall_base:
	for f in $(notdir ${BIN}); do $(RM) $(DESTDIR)$(PREFIX)/bin/$$f; done
	for f in $(notdir ${SHARED}); do $(RM) $(DESTDIR)$(PREFIX)/share/artools/$$f; done
	for f in $(notdir ${LIBS}); do $(RM) $(DESTDIR)$(PREFIX)/lib/artools/$$f; done

uninstall_portable_efi:
	for f in $(notdir ${GRUB_DEFAULT}); do $(RM) $(DESTDIR)$(SYSCONFDIR)/default/$$f; done
	for f in $(notdir ${GRUB_D}); do $(RM) $(DESTDIR)$(SYSCONFDIR)/grub.d/$$f; done

uninstall_rc:
	for f in $(notdir ${RC}); do $(RM) $(DESTDIR)$(SYSCONFDIR)/init.d/$$f; done

uninstall_runit:
	for f in $(notdir ${RUNIT_SV}); do $(RM) $(DESTDIR)$(SYSCONFDIR)/runit/sv/$$f; done

install: install_base install_rc install_portable_efi

uninstall: uninstall_base uninstall_rc uninstall_runit uninstall_portable_efi

dist:
	git archive --format=tar --prefix=$(PKG)-$(VERSION)/ $(VERSION) | gzip -9 > $(PKG)-$(VERSION).tar.gz
	gpg --detach-sign --use-agent $(PKG)-$(VERSION).tar.gz

.PHONY: all clean install uninstall dist
