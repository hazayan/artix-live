VERSION = 0.7

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

RUNIT_SVD = \
	data/runit/live

RUNIT_SV = \
	data/runit/pacman-init.run

GRUB_DEFAULT = \
	data/grub2-portable-efi

GRUB_D = \
	data/99_zzz-portable-efi

XDG = $(wildcard data/*.desktop)

XBIN = bin/desktop-items

all: $(BIN) $(RC) $(RUNIT_SV) $(XBIN) $(GRUB_D)

EDIT = sed -e "s|@datadir[@]|$(DATADIR)/$(TOOLS)|g" \
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

	install $(DMODE) $(DESTDIR)$(DATADIR)/$(TOOLS)
	install $(FMODE) $(SHARED) $(DESTDIR)$(DATADIR)/$(TOOLS)

install_rc:
	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/init.d
	install $(BMODE) $(RC) $(DESTDIR)$(SYSCONFDIR)/init.d

install_runit:
	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/rc/sysinit
	install $(DMODE) $(DESTDIR)$(LIBDIR)/rc/sv.d

	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/runit/sv/pacman-init
	install $(BMODE) $(RUNIT_SVD) $(DESTDIR)$(LIBDIR)/rc/sv.d
	ln -sf $(LIBDIR)/rc/sv.d/live $(DESTDIR)$(SYSCONFDIR)/rc/sysinit/98-live

	install $(BMODE) $(RUNIT_SV) $(DESTDIR)$(SYSCONFDIR)/runit/sv/pacman-init/run

install_portable_efi:
	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/default
	install $(BMODE) $(GRUB_DEFAULT) $(DESTDIR)$(SYSCONFDIR)/default

	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/grub.d
	install $(BMODE) $(GRUB_D) $(DESTDIR)$(SYSCONFDIR)/grub.d

install_xdg:
	install -dm0755 $(DESTDIR)$(PREFIX)/bin
	install -m0755 ${XBIN} $(DESTDIR)$(PREFIX)/bin

	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/skel/.config/autostart
	install -m0755 ${XDG} $(DESTDIR)$(SYSCONFDIR)/skel/.config/autostart

install: install_base install_rc install_portable_efi install_xdg

.PHONY: all clean install uninstall dist
