PREFIX ?= /usr
ALPMDIR = $(PREFIX)/share/libalpm
SCRIPTSDIR = $(ALPMDIR)/scripts
HOOKSDIR = $(ALPMDIR)/hooks

OPENRCSCRIPTS = $(wildcard openrc/scripts/*)
OPENRCHOOKS = $(wildcard openrc/hooks/*)

OPENRCCRONIEHOOKS = $(wildcard openrc/cronie-hooks/*)
OPENRCDBUSHOOKS = $(wildcard openrc/dbus-hooks/*)

RUNITSCRIPTS = $(wildcard runit/scripts/*)
RUNITHOOKS = $(wildcard runit/hooks/*)

S6SCRIPTS = $(wildcard s6/scripts/*)
S6HOOKS = $(wildcard s6/hooks/*)

S6EXTRA = s6/s6-rc-bundle-update

S6CRONIEHOOKS = $(wildcard s6/cronie-hooks/*)
S6DBUSHOOKS = $(wildcard s6/dbus-hooks/*)

SUITE66SCRIPTS = $(wildcard suite66/scripts/*)
SUITE66HOOKS = $(wildcard suite66/hooks/*)

SUITE66CRONIEHOOKS = $(wildcard suite66/cronie-hooks/*)
SUITE66DBUSHOOKS = $(wildcard suite66/dbus-hooks/*)

UDEVSCRIPTS = $(wildcard udev/scripts/*)
UDEVHOOKS = $(wildcard udev/hooks/*)

BASESCRIPTS = $(wildcard base/scripts/*)
BASEHOOKS = $(wildcard base/hooks/*)

TMPFILESHOOKS = $(wildcard tmpfiles/hooks/*)

SYSUSERSHOOKS = $(wildcard sysusers/hooks/*)

DMODE = -dm0755
MODE = -m0644
EMODE = -m0755

install_common:
	install $(DMODE) $(DESTDIR)$(SCRIPTSDIR)
	install $(DMODE) $(DESTDIR)$(HOOKSDIR)

install_s6_extra:
	install $(DMODE) $(DESTDIR)$(PREFIX)/bin
	install $(EMODE) $(S6EXTRA) $(DESTDIR)$(PREFIX)/bin

install_base: install_common
	install $(EMODE) $(BASESCRIPTS) $(DESTDIR)$(SCRIPTSDIR)
	install $(MODE) $(BASEHOOKS) $(DESTDIR)$(HOOKSDIR)

install_udev: install_common
	install $(EMODE) $(UDEVSCRIPTS) $(DESTDIR)$(SCRIPTSDIR)
	install $(MODE) $(UDEVHOOKS) $(DESTDIR)$(HOOKSDIR)

install_tmpfiles: install_common
	install $(MODE) $(TMPFILESHOOKS) $(DESTDIR)$(HOOKSDIR)

install_sysusers: install_common
	install $(MODE) $(SYSUSERSHOOKS) $(DESTDIR)$(HOOKSDIR)

install_openrc: install_common
	install $(EMODE) $(OPENRCSCRIPTS) $(DESTDIR)$(SCRIPTSDIR)
	install $(MODE) $(OPENRCHOOKS) $(DESTDIR)$(HOOKSDIR)

install_runit: install_common
	install $(EMODE) $(RUNITSCRIPTS) $(DESTDIR)$(SCRIPTSDIR)
	install $(MODE) $(RUNITHOOKS) $(DESTDIR)$(HOOKSDIR)

install_s6: install_common install_s6_extra
	install $(EMODE) $(S6SCRIPTS) $(DESTDIR)$(SCRIPTSDIR)
	install $(MODE) $(S6HOOKS) $(DESTDIR)$(HOOKSDIR)

install_suite66: install_common
	install $(EMODE) $(SUITE66SCRIPTS) $(DESTDIR)$(SCRIPTSDIR)
	install $(MODE) $(SUITE66HOOKS) $(DESTDIR)$(HOOKSDIR)

install_openrc_cronie: install_common
	install $(MODE) $(OPENRCCRONIEHOOKS) $(DESTDIR)$(HOOKSDIR)

install_openrc_dbus: install_common
	install $(MODE) $(OPENRCDBUSHOOKS) $(DESTDIR)$(HOOKSDIR)

install_s6_cronie: install_common
	install $(MODE) $(S6CRONIEHOOKS) $(DESTDIR)$(HOOKSDIR)

install_s6_dbus: install_common
	install $(MODE) $(S6DBUSHOOKS) $(DESTDIR)$(HOOKSDIR)

install_suite66_cronie: install_common
	install $(MODE) $(SUITE66CRONIEHOOKS) $(DESTDIR)$(HOOKSDIR)

install_suite66_dbus: install_common
	install $(MODE) $(SUITE66DBUSHOOKS) $(DESTDIR)$(HOOKSDIR)
