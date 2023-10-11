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

GENERATED_DIR = out
TEMPFILES = genkernel_conf \
	man_genkernel_8 \
	parse_cmdline \
	longusage \
	append_base_layout \
	create_initramfs \
	initramfs_append_func \
	determine_real_args

DEPS = genkernel.conf \
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


PREFIX = /usr/local
BINDIR = $(PREFIX)/bin
ifeq ($(PREFIX), /usr)
	SYSCONFDIR = /etc
else
	SYSCONFDIR = $(PREFIX)/etc
endif
MANDIR = $(PREFIX)/share/man


all: $(GENERATED_DIR)/genkernel man kconfig

debug:
	@echo "ARCH_KCONF=$(ARCH_KCONF)"
	@echo "GENERATED_KCONF=$(GENERATED_KCONF)"

kconfig: $(GENERATED_KCONF)
man: $(addprefix $(GENERATED_DIR)/,$(MANPAGE))

ChangeLog:
	git log >$@

clean:
	rm -f $(EXTRA_DIST)
	rm -rf $(GENERATED_DIR)

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

$(GENERATED_DIR)/%.8: doc/%.8.txt doc/asciidoc.conf Makefile $(GENERATED_DIR)/doc/genkernel.8.txt
	a2x --conf-file=doc/asciidoc.conf \
		 --format=manpage -D $(GENERATED_DIR) "$(GENERATED_DIR)/$<"

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

$(GENERATED_DIR)/:
	install -d $@

$(GENERATED_DIR)/%/:
	install -d $@

$(GENERATED_DIR)/temp/%: $(GENERATED_DIR)/temp/
	echo > $@

$(GENERATED_DIR)/build-config: $(addprefix $(GENERATED_DIR)/temp/,$(TEMPFILES))
ifdef GK_FEATURES
	awk -f compile_features.awk $(addprefix features/,${GK_FEATURES})
endif
	echo ${PREFIX} > $(GENERATED_DIR)/PREFIX
	echo ${BINDIR} > $(GENERATED_DIR)/BINDIR
	echo ${SYSCONFDIR} > $(GENERATED_DIR)/SYSCONFDIR
	echo ${MANDIR} > $(GENERATED_DIR)/MANDIR
	touch $(GENERATED_DIR)/build-config

$(GENERATED_DIR)/genkernel.conf: $(GENERATED_DIR)/build-config
	cat genkernel.conf | sed \
		-e '/#BEGIN FEATURES genkernel_conf/ r $(GENERATED_DIR)/temp/genkernel_conf' \
		> $(GENERATED_DIR)/genkernel.conf

$(GENERATED_DIR)/doc/genkernel.8.txt: $(GENERATED_DIR)/build-config $(GENERATED_DIR)/doc/
	cat doc/genkernel.8.txt | sed \
		-e '/\/\/ BEGIN FEATURES man_genkernel_8/ r $(GENERATED_DIR)/temp/man_genkernel_8' \
		> $(GENERATED_DIR)/doc/genkernel.8.txt

$(GENERATED_DIR)/gen_cmdline.sh: $(GENERATED_DIR)/build-config
	cat gen_cmdline.sh | sed \
		-e '/#BEGIN FEATURES parse_cmdline()/ r $(GENERATED_DIR)/temp/parse_cmdline' \
		-e '/#BEGIN FEATURES longusage()/ r $(GENERATED_DIR)/temp/longusage' \
		> $(GENERATED_DIR)/gen_cmdline.sh

$(GENERATED_DIR)/gen_initramfs.sh: $(GENERATED_DIR)/build-config
	cat gen_initramfs.sh | sed \
		-e '/#BEGIN FEATURES append_base_layout()/ r $(GENERATED_DIR)/temp/append_base_layout' \
		-e '/#BEGIN FEATURES create_initramfs()/ r $(GENERATED_DIR)/temp/create_initramfs' \
		-e '/#BEGIN FEATURES initramfs_append_func/ r $(GENERATED_DIR)/temp/initramfs_append_func' \
		> $(GENERATED_DIR)/gen_initramfs.sh

$(GENERATED_DIR)/gen_determineargs.sh: $(GENERATED_DIR)/build-config
	cat gen_determineargs.sh | sed \
		-e '/#BEGIN FEATURES determine_real_args()/ r $(GENERATED_DIR)/temp/determine_real_args' \
		> $(GENERATED_DIR)/gen_determineargs.sh

$(GENERATED_DIR)/software.sh:
	cat defaults/software.sh | sed \
		-e "s:VERSION_BCACHE_TOOLS:${VERSION_BCACHE_TOOLS}:"\
		-e "s:VERSION_BOOST:${VERSION_BOOST}:"\
		-e "s:VERSION_BTRFS_PROGS:${VERSION_BTRFS_PROGS}:"\
		-e "s:VERSION_BUSYBOX:${VERSION_BUSYBOX}:"\
		-e "s:VERSION_COREUTILS:${VERSION_COREUTILS}:"\
		-e "s:VERSION_CRYPTSETUP:${VERSION_CRYPTSETUP}:"\
		-e "s:VERSION_DMRAID:${VERSION_DMRAID}:"\
		-e "s:VERSION_DROPBEAR:${VERSION_DROPBEAR}:"\
		-e "s:VERSION_EUDEV:${VERSION_EUDEV}:"\
		-e "s:VERSION_EXPAT:${VERSION_EXPAT}:"\
		-e "s:VERSION_E2FSPROGS:${VERSION_E2FSPROGS}:"\
		-e "s:VERSION_FUSE:${VERSION_FUSE}:"\
		-e "s:VERSION_GPG:${VERSION_GPG}:"\
		-e "s:VERSION_HWIDS:${VERSION_HWIDS}:"\
		-e "s:VERSION_ISCSI:${VERSION_ISCSI}:"\
		-e "s:VERSION_JSON_C:${VERSION_JSON_C}:"\
		-e "s:VERSION_KMOD:${VERSION_KMOD}:"\
		-e "s:VERSION_LIBAIO:${VERSION_LIBAIO}:"\
		-e "s:VERSION_LIBGCRYPT:${VERSION_LIBGCRYPT}:"\
		-e "s:VERSION_LIBGPGERROR:${VERSION_LIBGPGERROR}:"\
		-e "s:VERSION_LIBXCRYPT:${VERSION_LIBXCRYPT}:"\
		-e "s:VERSION_LVM:${VERSION_LVM}:"\
		-e "s:VERSION_LZO:${VERSION_LZO}:"\
		-e "s:VERSION_MDADM:${VERSION_MDADM}:"\
		-e "s:VERSION_MULTIPATH_TOOLS:${VERSION_MULTIPATH_TOOLS}:"\
		-e "s:VERSION_POPT:${VERSION_POPT}:"\
		-e "s:VERSION_STRACE:${VERSION_STRACE}:"\
		-e "s:VERSION_THIN_PROVISIONING_TOOLS:${VERSION_THIN_PROVISIONING_TOOLS}:"\
		-e "s:VERSION_UNIONFS_FUSE:${VERSION_UNIONFS_FUSE}:"\
		-e "s:VERSION_USERSPACE_RCU:${VERSION_USERSPACE_RCU}:"\
		-e "s:VERSION_UTIL_LINUX:${VERSION_UTIL_LINUX}:"\
		-e "s:VERSION_XFSPROGS:${VERSION_XFSPROGS}:"\
		-e "s:VERSION_XZ:${VERSION_XZ}:"\
		-e "s:VERSION_ZLIB:${VERSION_ZLIB}:"\
		-e "s:VERSION_ZSTD:${VERSION_ZSTD}:"\
		> $(GENERATED_DIR)/software.sh

$(GENERATED_DIR)/%: % $(GENERATED_DIR)/
	cp $< $@

$(GENERATED_DIR)/genkernel: $(addprefix $(GENERATED_DIR)/,$(DEPS)) $(GENERATED_DIR)/software.sh
	cp genkernel $(GENERATED_DIR)/genkernel

install: PREFIX := $(file <$(GENERATED_DIR)/PREFIX)
install: BINDIR := $(file <$(GENERATED_DIR)/BINDIR)
install: SYSCONFDIR := $(file <$(GENERATED_DIR)/SYSCONFDIR)
install: MANDIR := $(file <$(GENERATED_DIR)/MANDIR)
install: all
	install -d $(DESTDIR)/$(SYSCONFDIR)
	install -m 644 $(GENERATED_DIR)/genkernel.conf $(DESTDIR)/$(SYSCONFDIR)/

	install -d $(DESTDIR)/$(BINDIR)
	install -m 755 $(GENERATED_DIR)/genkernel $(DESTDIR)/$(BINDIR)/

	install -d $(DESTDIR)/$(PREFIX)/share/genkernel

	cp -rp arch $(DESTDIR)/$(PREFIX)/share/genkernel/
	cp -rp defaults $(DESTDIR)/$(PREFIX)/share/genkernel/
	cp -rp modules $(DESTDIR)/$(PREFIX)/share/genkernel/
	cp -rp netboot $(DESTDIR)/$(PREFIX)/share/genkernel/
	cp -rp patches $(DESTDIR)/$(PREFIX)/share/genkernel/

	install -m 755 -t $(DESTDIR)/$(PREFIX)/share/genkernel $(addprefix $(GENERATED_DIR)/,$(DEPS))
	
	install $(GENERATED_DIR)/software.sh $(DESTDIR)/$(PREFIX)/share/genkernel/defaults

	install -d $(DESTDIR)/$(MANDIR)
	install $(GENERATED_DIR)/genkernel.8 $(DESTDIR)/$(MANDIR)/man8

	# install -d $(DESTDIR)/var/lib/genkernel/src
	# install -m 644 tarballs/* $(DESTDIR)/var/lib/genkernel/src/
