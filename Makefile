VERSION = 0.11.2

PKG = live-services
TOOLS = artools

SYSCONFDIR = /etc
PREFIX ?= /usr
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/lib
DATADIR = $(PREFIX)/share
SYSUSERSDIR = $(PREFIX)/lib/sysusers.d
LIVEUSER ?= artix

FMODE = -m0644
DMODE = -dm0755
BMODE = -m0755

BIN = \
	bin/artix-live

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

S6_LIVE = \
	data/s6/artix-live/up \
	data/s6/artix-live/type

S6_PI = \
	data/s6/pacman-init/type \
	data/s6/pacman-init/up \
	data/s6/pacman-init/down

S6_BUNDLE = \
	data/s6/live/type \
	data/s6/live/contents

66_LIVE = \
	data/66/artix-live

66_PI = \
	data/66/pacman-init

XDG = $(wildcard data/*.desktop)

XBIN = bin/desktop-items

SYSUSERS = \
	data/sysusers

RM = rm -f
M4 = m4 -P
CHMODAW = chmod a-w
CHMODX = chmod +x

all: $(BIN) $(SYSUSERS) $(XBIN) $(RC) $(RUNIT_SVD) $(S6_PI) $(S6_LIVE)

EDIT = sed -e "s|@datadir[@]|$(DATADIR)|g" \
	-e "s|@sysconfdir[@]|$(SYSCONFDIR)|g" \
	-e "s|@bindir[@]|$(BINDIR)|g" \
	-e "s|@libdir[@]|$(LIBDIR)|g" \
	-e "s|@live[@]|$(LIVEUSER)|g"

%: %.in Makefile lib/util-live.sh
	@echo "GEN $@"
	@$(RM) "$@"
	@{ echo -n 'm4_changequote([[[,]]])'; cat $@.in; } | $(M4) | $(EDIT) >$@
	@$(CHMODAW) "$@"
	@$(CHMODX) "$@"
	@bash -O extglob -n "$@"

clean:
	$(RM) $(BIN) $(SYSUSERS) $(XBIN) $(RC) $(RUNIT_SVD) $(S6_PI) $(S6_LIVE)

install_base:
	install $(DMODE) $(DESTDIR)$(BINDIR)
	install $(BMODE) $(BIN) $(DESTDIR)$(BINDIR)

	install $(DMODE) $(DESTDIR)$(SYSUSERSDIR)
	install $(FMODE) $(SYSUSERS) $(DESTDIR)$(SYSUSERSDIR)/live-artix.conf

	install $(DMODE) $(DESTDIR)$(DATADIR)/$(TOOLS)
	install $(FMODE) $(SHARED) $(DESTDIR)$(DATADIR)/$(TOOLS)

install_rc:
	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/init.d
	install $(BMODE) $(RC) $(DESTDIR)$(SYSCONFDIR)/init.d

install_runit:
	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/rc/sysinit
	install $(DMODE) $(DESTDIR)$(LIBDIR)/rc/sv.d

	install $(BMODE) $(RUNIT_SVD) $(DESTDIR)$(LIBDIR)/rc/sv.d
	ln -sf $(LIBDIR)/rc/sv.d/live $(DESTDIR)$(SYSCONFDIR)/rc/sysinit/98-live

	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/runit/sv/pacman-init
	install $(BMODE) $(RUNIT_SV) $(DESTDIR)$(SYSCONFDIR)/runit/sv/pacman-init/run

install_s6:
	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/s6/sv

	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/s6/sv/pacman-init
	install $(BMODE) $(S6_PI) $(DESTDIR)$(SYSCONFDIR)/s6/sv/pacman-init/

	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/s6/sv/artix-live
	install $(BMODE) $(S6_LIVE) $(DESTDIR)$(SYSCONFDIR)/s6/sv/artix-live/

	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/s6/sv/live
	install $(BMODE) $(S6_BUNDLE) $(DESTDIR)$(SYSCONFDIR)/s6/sv/live/

install_66:
	install $(DMODE) $(DESTDIR)$(SYSCONFDIR)/66/service

	install $(FMODE) $(66_LIVE) $(DESTDIR)$(SYSCONFDIR)/66/service/artix-live
	install $(FMODE) $(66_PI) $(DESTDIR)$(SYSCONFDIR)/66/service/pacman-init

install_xdg:
	install -dm0755 $(DESTDIR)$(PREFIX)/bin
	install -m0755 ${XBIN} $(DESTDIR)$(PREFIX)/bin

	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/skel/.config/autostart
	install -m0755 ${XDG} $(DESTDIR)$(SYSCONFDIR)/skel/.config/autostart

install: install_base install_rc install_runit install_s6 install_xdg

.PHONY: install
