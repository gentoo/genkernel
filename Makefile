#PACKAGE_VERSION = $(shell /bin/grep -F -- GK_V= genkernel | sed "s/.*GK_V='\([^']\+\)'/\1/")
PACKAGE_VERSION = $(shell git describe --tags |sed 's,^v,,g')
distdir = genkernel-$(PACKAGE_VERSION)
MANPAGE = genkernel.8
# Add off-Git/generated files here that need to be shipped with releases
EXTRA_DIST = $(MANPAGE) ChangeLog $(KCONF)

default: kconfig man

# First argument in the override file
# Second argument is the base file
BASE_KCONF = defaults/kernel-generic-config
ARCH_KCONF = $(wildcard arch/*/arch-config)
GENERATED_KCONF = $(subst arch-,generated-,$(ARCH_KCONF))
KCONF = $(GENERATED_KCONF)

debug:
	@echo "ARCH_KCONF=$(ARCH_KCONF)"
	@echo "GENERATED_KCONF=$(GENERATED_KCONF)"

kconfig: $(GENERATED_KCONF)
man: $(MANPAGE)

ChangeLog:
	git log >$@

clean:
	rm -f $(EXTRA_DIST)
	rm -r out

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

%.8: doc/%.8.txt doc/asciidoc.conf Makefile genkernel out
	a2x --conf-file=doc/asciidoc.conf --attribute="genkernelversion=$(PACKAGE_VERSION)" \
		 --format=manpage -D out "$<"

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

out:
	mkdir out
	mkdir out/share

src: out

	cp genkernel.conf out/

	cat gen_cmdline.sh | sed \
		-e '/#BEGIN FEATURES parse_cmdline()/ r temp/parse_cmdline' \
		-e '/#BEGIN FEATURES longusage()/ r temp/longusage' \
		> out/gen_cmdline.sh
	cat gen_initramfs.sh | sed \
		-e '/#BEGIN FEATURES append_base_layout()/ r temp/append_base_layout' \
		-e '/#BEGIN FEATURES create_initramfs()/ r temp/create_initramfs' \
		-e '/#BEGIN FEATURES initramfs_append/ r temp/initramfs_append' \
		> out/gen_initramfs.sh
	cat gen_determineargs.sh | sed \
		-e '/#BEGIN FEATURES determine_real_args()/ r temp/determine_real_args' \
		> out/gen_determineargs.sh

	cp gen_arch.sh out/
	cp gen_bootloader.sh out/
	cp gen_compile.sh out/
	cp gen_configkernel.sh out/
	cp gen_funcs.sh out/
	cp gen_moddeps.sh out/
	cp gen_package.sh out/

	cp genkernel out/

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
		> out/software.sh


install: default src

	install -d $(DESTDIR)/$(SYSCONFDIR)
	install -m 644 out/genkernel.conf $(DESTDIR)/$(SYSCONFDIR)/

	install -d $(DESTDIR)/$(BINDIR)
	install -m 755 out/genkernel $(DESTDIR)/$(BINDIR)/

	install -d $(DESTDIR)/$(PREFIX)/share/genkernel

	cp -rp arch $(DESTDIR)/$(PREFIX)/share/genkernel/
	cp -rp defaults $(DESTDIR)/$(PREFIX)/share/genkernel/
	cp -rp modules $(DESTDIR)/$(PREFIX)/share/genkernel/
	cp -rp netboot $(DESTDIR)/$(PREFIX)/share/genkernel/
	cp -rp patches $(DESTDIR)/$(PREFIX)/share/genkernel/

	install -m 755 out/gen_arch.sh $(DESTDIR)/$(PREFIX)/share/genkernel
	install -m 755 out/gen_bootloader.sh $(DESTDIR)/$(PREFIX)/share/genkernel
	install -m 755 out/gen_cmdline.sh $(DESTDIR)/$(PREFIX)/share/genkernel
	install -m 755 out/gen_compile.sh $(DESTDIR)/$(PREFIX)/share/genkernel
	install -m 755 out/gen_configkernel.sh $(DESTDIR)/$(PREFIX)/share/genkernel
	install -m 755 out/gen_determineargs.sh $(DESTDIR)/$(PREFIX)/share/genkernel
	install -m 755 out/gen_funcs.sh $(DESTDIR)/$(PREFIX)/share/genkernel
	install -m 755 out/gen_initramfs.sh $(DESTDIR)/$(PREFIX)/share/genkernel
	install -m 755 out/gen_moddeps.sh $(DESTDIR)/$(PREFIX)/share/genkernel
	install -m 755 out/gen_package.sh $(DESTDIR)/$(PREFIX)/share/genkernel

	install out/software.sh $(DESTDIR)/$(PREFIX)/share/genkernel/defaults

	# install -d $(DESTDIR)/var/lib/genkernel/src
	# install -m 644 tarballs/* $(DESTDIR)/var/lib/genkernel/src/
