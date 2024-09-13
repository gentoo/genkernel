#PACKAGE_VERSION = $(shell /bin/grep -F -- GK_V= genkernel | sed "s/.*GK_V='\([^']\+\)'/\1/")
PACKAGE_VERSION = $(file <VERSION)
ifeq ("$(PACKAGE_VERSION)", "")
PACKAGE_VERSION = $(shell git describe --tags |sed 's,^v,,g')
endif
distdir = genkernel-$(PACKAGE_VERSION)
MANPAGE = genkernel.8
# Add off-Git/generated files here that need to be shipped with releases
EXTRA_DIST = ChangeLog $(KCONF)

default: all

# First argument in the override file
# Second argument is the base file
BASE_KCONF = defaults/kernel-generic-config
ARCH_KCONF = $(wildcard arch/*/arch-config)
GENERATED_KCONF = $(subst arch-,generated-,$(ARCH_KCONF))
KCONF = $(GENERATED_KCONF)

BUILD_DIR = build

FINAL_DEPS = genkernel.conf \
	gen_arch.sh \
	gen_bootloader.sh \
	gen_cmdline.sh \
	gen_compile.sh \
	gen_configkernel.sh \
	gen_determineargs.sh \
	gen_funcs.sh \
	gen_initramfs.sh \
	gen_moddeps.sh \
	gen_package.sh \
	gen_worker.sh \
	path_expander.py

SOFTWARE = BCACHE_TOOLS \
	BOOST \
	BTRFS_PROGS \
	BUSYBOX \
	COREUTILS \
	CRYPTSETUP \
	DMRAID \
	DROPBEAR \
	EUDEV \
	EXPAT \
	E2FSPROGS \
	FUSE \
	GPG \
	HWIDS \
	ISCSI \
	JSON_C \
	KMOD \
	LIBAIO \
	LIBGCRYPT \
	LIBGPGERROR \
	LIBXCRYPT \
	LVM \
	LZO \
	MDADM \
	MULTIPATH_TOOLS \
	POPT \
	SEDUTIL \
	STRACE \
	THIN_PROVISIONING_TOOLS \
	UNIONFS_FUSE \
	USERSPACE_RCU \
	UTIL_LINUX \
	XFSPROGS \
	XZ \
	ZLIB \
	ZSTD

SOFTWARE_VERSION = $(foreach entry, $(SOFTWARE), "VERSION_$(entry)=${VERSION_$(entry)}\n")

PREFIX = /usr/local
BINDIR = $(PREFIX)/bin
ifeq ($(PREFIX), /usr)
	SYSCONFDIR = /etc
else
	SYSCONFDIR = $(PREFIX)/etc
endif
MANDIR = $(PREFIX)/share/man

all: $(BUILD_DIR)/genkernel $(BUILD_DIR)/build-config man kconfig

debug:
	@echo "ARCH_KCONF=$(ARCH_KCONF)"
	@echo "GENERATED_KCONF=$(GENERATED_KCONF)"
	@echo "PACKAGE_VERSION=$(PACKAGE_VERSION)"

kconfig: $(GENERATED_KCONF)
man: $(addprefix $(BUILD_DIR)/,$(MANPAGE))

ChangeLog:
	git log >$@

clean:
	rm -f $(EXTRA_DIST)
	rm -rf $(BUILD_DIR)

check-git-repository:
ifneq ($(UNCLEAN),1)
	git diff --quiet || { echo 'STOP, you have uncommitted changes in the working directory' ; false ; }
	git diff --cached --quiet || { echo 'STOP, you have uncommitted changes in the index' ; false ; }
else
	@true
endif

dist: verify-shellscripts-initramfs verify-doc check-git-repository distclean $(EXTRA_DIST)
	mkdir "$(distdir)"
	echo $(PACKAGE_VERSION) > $(distdir)/VERSION
	git ls-files -z | xargs -0 cp --no-dereference --parents --target-directory="$(distdir)" \
		$(EXTRA_DIST)
	tar cf "$(distdir)".tar "$(distdir)"
	xz -v "$(distdir)".tar
	rm -Rf "$(distdir)"

distclean: clean
	rm -Rf "$(distdir)" "$(distdir)".tar "$(distdir)".tar.xz

.PHONY: clean check-git-repository dist distclean kconfig verify-doc install

# Generic rules
%/generated-config: %/arch-config $(BASE_KCONF) merge.pl Makefile
	if grep -sq THIS_CONFIG_IS_BROKEN $< ; then \
		cat $< >$@ ; \
	else \
		perl merge.pl $< $(BASE_KCONF) | sort > $@ ; \
	fi ;

$(BUILD_DIR)/%.8: doc/%.8.txt doc/asciidoc.conf Makefile $(BUILD_DIR)/doc/genkernel.8.txt
	a2x --conf-file=doc/asciidoc.conf \
		--format=manpage -D $(BUILD_DIR) --attribute="genkernelversion=$(PACKAGE_VERSION)" \
		"$(BUILD_DIR)/$<"

verify-doc: doc/genkernel.8.txt
	@rm -f faildoc ; \
	GK_SHARE=. ./genkernel --help | \
		sed 's,-->, ,g' | \
		fmt -1 | \
		grep -e '--' | \
		tr -s '[:space:].,' ' ' | \
		sed -r \
			-e 's,=<[^>]+>,,g' | \
		tr -s ' ' '\n' | \
		sed -r \
			-e 's,[[:space:]]*--(no-)?,,g' \
			-e '/boot-font/s,=\(current\|<file>\|none\),,g' \
			-e '/bootloader/s,=\(grub\|grub2\),,g' \
			-e '/microcode/s,=\(all\|amd\|intel\),,g' \
			-e '/ssh-host-keys/s,=\(create\|create-from-host\|runtime\),,g' | \
		while read opt ; do \
			regex="^*--(...no-...)?$$opt" ; \
			if ! grep -Ee "$$regex" $< -sq ; then \
				touch faildoc ; \
				echo "Undocumented option: $$opt" ; \
			fi ; \
		done ; \
	if test -e faildoc ; then \
		echo "Refusing to build!" ; \
		rm -f faildoc ; \
		exit 1 ; \
	fi ; \
	rm -f faildoc

verify-shellscripts-initramfs:
# we need to check every file because a fatal error in
# an included file (SC1094) is just a warning at the moment
	shellcheck \
		--external-sources \
		--source-path SCRIPTDIR \
		--severity error \
		defaults/linuxrc \
		defaults/initrd.scripts

$(BUILD_DIR)/build-config:
# $(addprefix $(BUILD_DIR)/temp/,$(TEMPFILES))
	install -d $(BUILD_DIR)
	echo $(PREFIX) > $(BUILD_DIR)/PREFIX
	echo $(BINDIR) > $(BUILD_DIR)/BINDIR
	echo $(SYSCONFDIR) > $(BUILD_DIR)/SYSCONFDIR
	echo $(MANDIR) > $(BUILD_DIR)/MANDIR
	touch $(BUILD_DIR)/build-config

$(BUILD_DIR)/software.sh:
	install -d $(BUILD_DIR)/temp/
	echo -e $(SOFTWARE_VERSION) > $(BUILD_DIR)/temp/versions
	cat $(BUILD_DIR)/temp/versions defaults/software.sh > $(BUILD_DIR)/software.sh

$(BUILD_DIR)/doc/genkernel.8.txt:
	install -D doc/genkernel.8.txt $(BUILD_DIR)/doc/genkernel.8.txt

$(BUILD_DIR)/%: %
	install -D $< $@

$(BUILD_DIR)/genkernel: $(addprefix $(BUILD_DIR)/,$(FINAL_DEPS)) $(BUILD_DIR)/software.sh
	install genkernel $(BUILD_DIR)/genkernel

SHARE_DIRS = arch defaults gkbuilds modules netboot patches worker_modules

install: all
	$(eval PREFIX := $(file <$(BUILD_DIR)/PREFIX))
	$(eval BINDIR := $(file <$(BUILD_DIR)/BINDIR))
	$(eval SYSCONFDIR := $(file <$(BUILD_DIR)/SYSCONFDIR))
	$(eval MANDIR := $(file <$(BUILD_DIR)/MANDIR))
	install -d $(DESTDIR)/$(SYSCONFDIR)
	install -m 644 $(BUILD_DIR)/genkernel.conf $(DESTDIR)/$(SYSCONFDIR)/

	install -d $(DESTDIR)/$(BINDIR)
	install -m 755 $(BUILD_DIR)/genkernel $(DESTDIR)/$(BINDIR)/

	install -d $(DESTDIR)/$(PREFIX)/share/genkernel

	cp -ra $(SHARE_DIRS) $(DESTDIR)/$(PREFIX)/share/genkernel/

	install -m 755 -t $(DESTDIR)/$(PREFIX)/share/genkernel $(addprefix $(BUILD_DIR)/,$(FINAL_DEPS))

	install $(BUILD_DIR)/software.sh $(DESTDIR)/$(PREFIX)/share/genkernel/defaults

	install -d $(DESTDIR)/$(MANDIR)/man8
	install $(BUILD_DIR)/genkernel.8 $(DESTDIR)/$(MANDIR)/man8

# No trailing blank lines please.
# vim:ft=make:
