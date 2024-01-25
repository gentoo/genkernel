#PACKAGE_VERSION = $(shell /bin/grep -F -- GK_V= genkernel | sed "s/.*GK_V='\([^']\+\)'/\1/")
PACKAGE_VERSION = $(shell git describe --tags |sed 's,^v,,g')
distdir = genkernel-$(PACKAGE_VERSION)
MANPAGE := genkernel.8
# Add off-Git/generated files here that need to be shipped with releases
EXTRA_DIST = $(MANPAGE) ChangeLog $(KCONF)

# First argument in the override file
# Second argument is the base file
BASE_KCONF = defaults/kernel-generic-config
ARCH_KCONF = $(wildcard arch/*/arch-config)
GENERATED_KCONF = $(subst arch-,generated-,$(ARCH_KCONF))
KCONF = $(GENERATED_KCONF)

BUILD_DIR = build
TEMPFILES = genkernel_conf \
	man_genkernel_8 \
	parse_cmdline \
	longusage \
	append_base_layout \
	create_initramfs \
	initramfs_append_func \
	determine_real_args

FINAL_DEPS = genkernel.conf \
	gen_cmdline.sh \
	gen_initramfs.sh \
	gen_determineargs.sh \
	gen_arch.sh \
	gen_bootloader.sh \
	gen_compile.sh \
	gen_configkernel.sh \
	gen_funcs.sh \
	gen_moddeps.sh \
	gen_package.sh \
	gen_worker.sh \
	path_expander.py

SOFTWARE = BCACHE_TOOLS BOOST BTRFS_PROGS BUSYBOX COREUTILS CRYPTSETUP \
	DMRAID DROPBEAR EUDEV EXPAT E2FSPROGS FUSE GPG \
	HWIDS ISCSI JSON_C KMOD LIBAIO LIBGCRYPT LIBGPGERROR LIBXCRYPT LVM \
	LZO MDADM MULTIPATH_TOOLS POPT STRACE THIN_PROVISIONING_TOOLS UNIONFS_FUSE \
	USERSPACE_RCU UTIL_LINUX XFSPROGS XZ ZLIB ZSTD

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
	git ls-files -z | xargs -0 cp --no-dereference --parents --target-directory="$(distdir)" \
		$(EXTRA_DIST)
	tar cf "$(distdir)".tar "$(distdir)"
	xz -v "$(distdir)".tar
	rm -Rf "$(distdir)"

distclean: clean
	rm -Rf "$(distdir)" "$(distdir)".tar "$(distdir)".tar.xz

.PHONY: clean check-git-repository dist distclean kconfig verify-doc

# Generic rules
%/generated-config: %/arch-config $(BASE_KCONF) merge.pl Makefile
	if grep -sq THIS_CONFIG_IS_BROKEN $< ; then \
		cat $< >$@ ; \
	else \
		perl merge.pl $< $(BASE_KCONF) | sort > $@ ; \
	fi ;

$(BUILD_DIR)/%.8: doc/%.8.txt doc/asciidoc.conf Makefile $(BUILD_DIR)/doc/genkernel.8.txt
	a2x --conf-file=doc/asciidoc.conf \
		 --format=manpage -D $(BUILD_DIR) "$(BUILD_DIR)/$<"

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

# $(BUILD_DIR)/:
# 	install -d $@
#
# $(BUILD_DIR)/%/:
# 	install -d $@

$(BUILD_DIR)/temp/%:
	install -d $(@D)
	echo > $@
ifdef GK_FEATURES
	cat $(addsuffix /$(@F) <(echo), $(addprefix features/,${GK_FEATURES})) > $@
endif

$(BUILD_DIR)/build-config: $(addprefix $(BUILD_DIR)/temp/,$(TEMPFILES))
	echo ${PREFIX} > $(BUILD_DIR)/PREFIX
	echo ${BINDIR} > $(BUILD_DIR)/BINDIR
	echo ${SYSCONFDIR} > $(BUILD_DIR)/SYSCONFDIR
	echo ${MANDIR} > $(BUILD_DIR)/MANDIR
	touch $(BUILD_DIR)/build-config

$(BUILD_DIR)/genkernel.conf: $(BUILD_DIR)/temp/genkernel_conf
	cat genkernel.conf | sed \
		-e '/#BEGIN FEATURES genkernel_conf/ r $(BUILD_DIR)/temp/genkernel_conf' \
		> $(BUILD_DIR)/genkernel.conf

$(BUILD_DIR)/doc/genkernel.8.txt: $(BUILD_DIR)/temp/man_genkernel_8
	install -d $(BUILD_DIR)/doc/
	cat doc/genkernel.8.txt | sed \
		-e '/\/\/ BEGIN FEATURES man_genkernel_8/ r $(BUILD_DIR)/temp/man_genkernel_8' \
		> $(BUILD_DIR)/doc/genkernel.8.txt

$(BUILD_DIR)/gen_cmdline.sh: $(BUILD_DIR)/temp/parse_cmdline $(BUILD_DIR)/temp/longusage
	cat gen_cmdline.sh | sed \
		-e '/#BEGIN FEATURES parse_cmdline()/ r $(BUILD_DIR)/temp/parse_cmdline' \
		-e '/#BEGIN FEATURES longusage()/ r $(BUILD_DIR)/temp/longusage' \
		> $(BUILD_DIR)/gen_cmdline.sh

$(BUILD_DIR)/gen_initramfs.sh: $(BUILD_DIR)/temp/append_base_layout $(BUILD_DIR)/temp/create_initramfs \
	$(BUILD_DIR)/temp/initramfs_append_func
	cat gen_initramfs.sh | sed \
		-e '/#BEGIN FEATURES append_base_layout()/ r $(BUILD_DIR)/temp/append_base_layout' \
		-e '/#BEGIN FEATURES create_initramfs()/ r $(BUILD_DIR)/temp/create_initramfs' \
		-e '/#BEGIN FEATURES initramfs_append_func/ r $(BUILD_DIR)/temp/initramfs_append_func' \
		> $(BUILD_DIR)/gen_initramfs.sh

$(BUILD_DIR)/gen_determineargs.sh: $(BUILD_DIR)/temp/determine_real_args
	cat gen_determineargs.sh | sed \
		-e '/#BEGIN FEATURES determine_real_args()/ r $(BUILD_DIR)/temp/determine_real_args' \
		> $(BUILD_DIR)/gen_determineargs.sh

$(BUILD_DIR)/software.sh:
	install -d $(BUILD_DIR)/temp/
	echo -e $(SOFTWARE_VERSION) > $(BUILD_DIR)/temp/versions
	cat $(BUILD_DIR)/temp/versions defaults/software.sh > $(BUILD_DIR)/software.sh

$(BUILD_DIR)/%: %
	install -d $(BUILD_DIR)/
	cp $< $@

$(BUILD_DIR)/genkernel: $(addprefix $(BUILD_DIR)/,$(FINAL_DEPS)) $(BUILD_DIR)/software.sh
	cp genkernel $(BUILD_DIR)/genkernel

install: PREFIX := $(file <$(BUILD_DIR)/PREFIX)
install: BINDIR := $(file <$(BUILD_DIR)/BINDIR)
install: SYSCONFDIR := $(file <$(BUILD_DIR)/SYSCONFDIR)
install: MANDIR := $(file <$(BUILD_DIR)/MANDIR)
install: all
	install -d $(DESTDIR)/$(SYSCONFDIR)
	install -m 644 $(BUILD_DIR)/genkernel.conf $(DESTDIR)/$(SYSCONFDIR)/

	install -d $(DESTDIR)/$(BINDIR)
	install -m 755 $(BUILD_DIR)/genkernel $(DESTDIR)/$(BINDIR)/

	install -d $(DESTDIR)/$(PREFIX)/share/genkernel

	cp -rp arch $(DESTDIR)/$(PREFIX)/share/genkernel/
	cp -rp defaults $(DESTDIR)/$(PREFIX)/share/genkernel/
	cp -rp gkbuilds $(DESTDIR)/$(PREFIX)/share/genkernel/
	cp -rp modules $(DESTDIR)/$(PREFIX)/share/genkernel/
	cp -rp netboot $(DESTDIR)/$(PREFIX)/share/genkernel/
	cp -rp patches $(DESTDIR)/$(PREFIX)/share/genkernel/
	cp -rp worker_modules $(DESTDIR)/$(PREFIX)/share/genkernel/

	install -m 755 -t $(DESTDIR)/$(PREFIX)/share/genkernel $(addprefix $(BUILD_DIR)/,$(FINAL_DEPS))
	
	install $(BUILD_DIR)/software.sh $(DESTDIR)/$(PREFIX)/share/genkernel/defaults

	install -d $(DESTDIR)/$(MANDIR)
	install $(BUILD_DIR)/genkernel.8 $(DESTDIR)/$(MANDIR)/man8

	# install -d $(DESTDIR)/var/lib/genkernel/src
	# install -m 644 tarballs/* $(DESTDIR)/var/lib/genkernel/src/
