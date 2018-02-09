Version=0.1

PREFIX = /usr/local
SYSCONFDIR = /etc

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

RUNIT_SV = $(wildcard data/runit/*.sh)

GRUB_DEFAULT = \
	data/grub2-portable-efi

GRUB_D = \
	data/99_zzz-portable-efi

all: $(BIN) $(RC) $(RUNIT_SV) $(XBIN) ${GRUB_D}

edit = sed -e "s|@datadir[@]|$(DESTDIR)$(PREFIX)/share/artools|g" \
	-e "s|@sysconfdir[@]|$(DESTDIR)$(SYSCONFDIR)/artools|g" \
	-e "s|@libdir[@]|$(DESTDIR)$(PREFIX)/lib/artools|g"

%: %.in Makefile
	@echo "GEN $@"
	@$(RM) "$@"
	@m4 -P $@.in | $(edit) >$@
	@chmod a-w "$@"
	@chmod +x "$@"

clean:
	rm -f $(BIN) $(RC) ${GRUB_D}

install_base:
	install -dm0755 $(DESTDIR)$(PREFIX)/bin
	install -m0755 ${BIN} $(DESTDIR)$(PREFIX)/bin

	install -dm0755 $(DESTDIR)$(PREFIX)/lib/artools
	install -m0644 ${LIBS} $(DESTDIR)$(PREFIX)/lib/artools

	install -dm0755 $(DESTDIR)$(PREFIX)/share/artools
	install -m0644 ${SHARED} $(DESTDIR)$(PREFIX)/share/artools

install_rc:
	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/init.d
	install -m0755 ${RC} $(DESTDIR)$(SYSCONFDIR)/init.d

install_runit:
	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/runit/core-services
	install -m0755 ${RUNIT_SV} $(DESTDIR)$(SYSCONFDIR)/runit/core-services

install_portable_efi:
	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/default
	install -m0755 $(GRUB_DEFAULT) $(DESTDIR)$(SYSCONFDIR)/default

	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/grub.d
	install -m0755 $(GRUB_D) $(DESTDIR)$(SYSCONFDIR)/grub.d

uninstall_base:
	for f in ${BIN}; do rm -f $(DESTDIR)$(PREFIX)/bin/$$f; done
	for f in ${SHARED}; do rm -f $(DESTDIR)$(PREFIX)/share/artools/$$f; done
	for f in ${LIBS}; do rm -f $(DESTDIR)$(PREFIX)/lib/artools/$$f; done

uninstall_portable_efi:
	for f in ${GRUB_DEFAULT}; do rm -f $(DESTDIR)$(SYSCONFDIR)/default/$$f; done
	for f in ${GRUB_D}; do rm -f $(DESTDIR)$(SYSCONFDIR)/grub.d/$$f; done

uninstall_rc:
	for f in ${RC}; do rm -f $(DESTDIR)$(SYSCONFDIR)/init.d/$$f; done

uninstall_runit:
	for f in ${RUNIT_SV}; do rm -f $(DESTDIR)$(SYSCONFDIR)/runit/sv/$$f; done

install: install_base install_rc install_portable_efi

uninstall: uninstall_base uninstall_rc uninstall_runit uninstall_portable_efi

dist:
	git archive --format=tar --prefix=live-services-$(Version)/ $(Version) | gzip -9 > live-services-$(Version).tar.gz
	gpg --detach-sign --use-agent live-services-$(Version).tar.gz

.PHONY: all clean install uninstall dist
