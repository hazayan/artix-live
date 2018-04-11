VERSION = 0.5

PKG = live-services
TOOLS = artools

SYSCONFDIR = /etc
ifdef PREFIX
PREFIX = /usr/local
endif
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/lib
DATADIR = $(PREFIX)/share

FMODE = -m0644
DMODE = -dm0755
BMODE = -m0755
RM = rm -f
M4 = m4 -P
CHAW = chmod a-w
CHX = chmod +x

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

all: $(BIN) $(RC) $(RUNIT_SV) $(XBIN) $(GRUB_D)

EDIT = sed -e "s|@datadir[@]|$(DATADIR)$(TOOLS)|g" \
	-e "s|@sysconfdir[@]|$(SYSCONFDIR)/$(TOOLS)|g" \
	-e "s|@libdir[@]|$(LIBDIR)/$(TOOLS)|g"

%: %.in Makefile
	@echo "GEN $@"
	@$(RM) "$@"
	@$(M4) $@.in | $(EDIT) >$@
	@$(CHAW) "$@"
	@$(CHX) "$@"

clean:
	$(RM) $(BIN) $(RC) $(GRUB_D)

install_base:
	install $(DMODE) $(DESTDIR)$(BINDIR)
	install $(BMODE) $(BIN) $(DESTDIR)$(BINDIR)

	install $(DMODE) $(DESTDIR)$(LIBDIR)/$(TOOLS)
	install $(FMODE) $(LIBS) $(DESTDIR)$(LIBDIR)/$(TOOLS)

	install $(DMODE) $(DESTDIR)$(DATADIR)$(TOOLS)
	install $(FMODE) $(SHARED) $(DESTDIR)$(DATADIR)$(TOOLS)

install_rc:
	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/init.d
	install $(BMODE) $(RC) $(DESTDIR)$(SYSCONFDIR)/init.d

install_runit:
	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/runit/core-services
	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/sv/pacman-init
	install $(BMODE) $(RUNIT_CORE) $(DESTDIR)$(SYSCONFDIR)/runit/core-services
	install $(BMODE) $(RUNIT_SV) $(DESTDIR)$(SYSCONFDIR)/runit/sv/pacman-init/run

install_portable_efi:
	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/default
	install $(BMODE) $(GRUB_DEFAULT) $(DESTDIR)$(SYSCONFDIR)/default

	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/grub.d
	install $(BMODE) $(GRUB_D) $(DESTDIR)$(SYSCONFDIR)/grub.d

uninstall_base:
	for f in $(notdir $(BIN)); do $(RM) $(DESTDIR)$(PREFIX)/bin/$$f; done
	for f in $(notdir $(SHARED)); do $(RM) $(DESTDIR)$(DATADIR)$(TOOLS)/$$f; done
	for f in $(notdir $(LIBS)); do $(RM) $(DESTDIR)$(LIBDIR)/$(TOOLS)/$$f; done

uninstall_portable_efi:
	for f in $(notdir $(GRUB_DEFAULT)); do $(RM) $(DESTDIR)$(SYSCONFDIR)/default/$$f; done
	for f in $(notdir $(GRUB_D)); do $(RM) $(DESTDIR)$(SYSCONFDIR)/grub.d/$$f; done

uninstall_rc:
	for f in $(notdir $(RC)); do $(RM) $(DESTDIR)$(SYSCONFDIR)/init.d/$$f; done

uninstall_runit:
	for f in $(notdir $(RUNIT_SV)); do $(RM) $(DESTDIR)$(SYSCONFDIR)/runit/sv/$$f; done

install: install_base install_rc install_portable_efi

uninstall: uninstall_base uninstall_rc uninstall_runit uninstall_portable_efi

dist:
	git archive --format=tar --prefix=$(PKG)-$(VERSION)/ $(VERSION) | gzip -9 > $(PKG)-$(VERSION).tar.gz
	gpg --detach-sign --use-agent $(PKG)-$(VERSION).tar.gz

.PHONY: all clean install uninstall dist
