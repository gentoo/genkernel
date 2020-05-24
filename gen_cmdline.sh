#!/bin/bash
# $Id$

longusage() {
  echo "Gentoo Linux Genkernel ${GK_V}"
  echo
  echo "Usage: "
  echo "  genkernel [options] action"
  echo
  echo "Available Actions: "
  echo "  all				Build all steps"
  echo "  bzImage			Build only the kernel"
  echo "  initramfs			Build only the ramdisk/initramfs"
  echo "  kernel			Build only the kernel and modules"
  echo "  ramdisk			Build only the ramdisk/initramfs"
  echo
  echo "Available Options: "
  echo "  Configuration settings"
  echo "	--config=<file>		genkernel configuration file to use"
  echo "  Debug settings"
  echo "	--loglevel=<0-5>	Debug Verbosity Level"
  echo "	--logfile=<outfile>	Output file for debug info"
  echo "	--color			Output debug in color"
  echo "	--no-color		Do not output debug in color"
  echo "	--cleanup		Clean up temporary directories on exit"
  echo "	--no-cleanup		Do not remove any temporary directories on exit"
  echo "  Kernel Configuration settings"
  echo "	--menuconfig		Run menuconfig after oldconfig"
  echo "	--no-menuconfig		Do not run menuconfig after oldconfig"
  echo "	--nconfig		Run nconfig after oldconfig"
  echo "	--no-nconfig		Do not run nconfig after oldconfig"
  echo "	--gconfig		Run gconfig after oldconfig"
  echo "	--no-gconfig		Don't run gconfig after oldconfig"
  echo "	--xconfig		Run xconfig after oldconfig"
  echo "	--no-xconfig		Don't run xconfig after oldconfig"
  echo "	--save-config		Save the configuration to /etc/kernels"
  echo "	--no-save-config	Don't save the configuration to /etc/kernels"
  echo "	--bcache		Enable block layer cache (bcache) support in kernel"
  echo "	--no-bcache		Don't enable block layer cache (bcache) support in kernel"
  echo "	--hyperv		Enable Microsoft Hyper-V kernel options in kernel"
  echo "	--no-hyperv		Don't enable Microsoft Hyper-V kernel options in kernel"
  echo "	--microcode=(all|amd|intel)"
  echo "				Enable early microcode support in kernel configuration,"
  echo "				'all' for all (default), 'amd' for AMD and 'intel' for"
  echo "				Intel CPU types"
  echo "	--no-microcode		Don't enable early microcode support in kernel configuration"
  echo "	--virtio		Enable VirtIO kernel options in kernel"
  echo "	--no-virtio		Don't enable VirtIO kernel options in kernel"
  echo "  Kernel Compile settings"
  echo "	--oldconfig		Implies --no-clean and runs a 'make oldconfig'"
  echo "	--no-oldconfig		Do not run 'make oldconfig' before compilation"
  echo "	--clean			Run 'make clean' before compilation"
  echo "	--no-clean		Do not run 'make clean' before compilation"
  echo "	--mrproper		Run 'make mrproper' before compilation"
  echo "	--no-mrproper		Do not run 'make mrproper' before compilation"
  echo "	--splash		Install framebuffer splash support into initramfs"
  echo "	--no-splash		Do not install framebuffer splash"
  echo "	--install		Install the kernel after building"
  echo "	--no-install		Do not install the kernel after building"
  echo "	--symlink		Manage symlinks in /boot for installed images"
  echo "	--no-symlink		Do not manage symlinks"
  echo "	--ramdisk-modules	Copy required modules to the initramfs"
  echo "	--no-ramdisk-modules	Don't copy any modules to the initramfs"
  echo "	--all-ramdisk-modules	Copy all kernel modules to the initramfs"
  echo "	--module-rebuild	Automatically run 'emerge @module-rebuild' when"
  echo "				necessary (and possible)"
  echo "	--no-module-rebuild	Don't automatically run 'emerge @module-rebuild'"
  echo "	--module-rebuild-cmd=<...>"
  echo "				Overwrite default --module-rebuild command"
  echo "	--callback=<...>	Run the specified arguments after the"
  echo "				kernel and modules have been compiled"
  echo "	--static		Build a static (monolithic kernel)"
  echo "	--no-static		Do not build a static (monolithic kernel)"
  echo "  Kernel settings"
  echo "	--kerneldir=<dir>	Location of the kernel sources"
  echo "	--kernel-append-localversion=<...>"
  echo "				Appends value to genkernel's KERNEL_LOCALVERSION option"
  echo "	--kernel-config=<file|default>"
  echo "				Kernel configuration file to use for compilation; Use"
  echo "				'default' to explicitly start from scratch using"
  echo "				genkernel defaults"
  echo "	--kernel-localversion=<...>"
  echo "				Set kernel CONFIG_LOCALVERSION, use special value"
  echo "				'UNSET' to unset any set LOCALVERSION"
  echo "	--module-prefix=<dir>	Prefix to kernel module destination, modules"
  echo "				will be installed in <prefix>/lib/modules"
  echo "  Low-Level Compile settings"
  echo "	--cross-compile=<target-triplet>"
  echo "				Target triple (i.e. aarch64-linux-gnu) to build for"
  echo "	--kernel-as=<assembler>	Assembler to use for kernel"
  echo "	--kernel-cc=<compiler>	Compiler to use for kernel (e.g. distcc)"
  echo "	--kernel-ld=<linker>	Linker to use for kernel"
  echo "	--kernel-make=<makeprg> GNU Make to use for kernel"
  echo "	--kernel-target=<t>	Override default make target (bzImage)"
  echo "	--kernel-binary=<path>	Override default kernel binary path (arch/foo/boot/bar)"
  echo "	--kernel-outputdir=<path>"
  echo "				Save output files outside the source tree"
  echo "	--utils-as=<assembler>	Assembler to use for utils"
  echo "	--utils-cc=<compiler>	C Compiler to use for utilities"
  echo "	--utils-cxx=<compiler>	C++ Compiler to use for utilities"
  echo "	--utils-cflags=<cflags> C compiler flags used to compile utilities"
  echo "	--utils-ld=<linker>	Linker to use for utils"
  echo "	--utils-make=<makeprog>	GNU Make to use for utils"
  echo "	--makeopts=<makeopts>	Make options such as -j2, etc ..."
  echo "	--mountboot		Mount BOOTDIR automatically if mountable"
  echo "	--no-mountboot		Don't mount BOOTDIR automatically"
  echo "	--bootdir=<dir>		Set the location of the boot-directory, default is /boot"
  echo "	--modprobedir=<dir>	Set the location of the modprobe.d-directory, default is /etc/modprobe.d"
  echo "	--nice			Run the kernel make at the default nice level (10)"
  echo "	--nice=<0-19>		Run the kernel make at the selected nice level"
  echo "	--no-nice		Don't be nice while running the kernel make"
  echo "  Initialization"
  echo "	--splash=<theme>	Enable framebuffer splash using <theme>"
  echo "	--splash-res=<res>	Select splash theme resolutions to install"
  echo "	--splash=<theme>	Enable framebuffer splash using <theme>"
  echo "	--splash-res=<res>	Select splash theme resolutions to install"
  echo "	--do-keymap-auto	Forces keymap selection at boot"
  echo "	--keymap		Enables keymap selection support"
  echo "	--no-keymap		Disables keymap selection support"
  echo "	--lvm			Include LVM support"
  echo "	--no-lvm		Exclude LVM support"
  echo "	--mdadm			Include MDADM/MDMON support"
  echo "	--no-mdadm		Exclude MDADM/MDMON support"
  echo "	--mdadm-config=<file>	Use file as mdadm.conf in initramfs"
  echo "	--microcode-initramfs	Prepend early microcode to initramfs"
  echo "	--no-microcode-initramfs"
  echo "				Don't prepend early microcode to initramfs"
  echo "	--nfs			Include NFS support"
  echo "	--no-nfs		Exclude NFS support"
  echo "	--dmraid		Include DMRAID support"
  echo "	--no-dmraid		Exclude DMRAID support"
  echo "	--e2fsprogs		Include e2fsprogs"
  echo "	--no-e2fsprogs		Exclude e2fsprogs"
  echo "	--xfsprogs		Include xfsprogs"
  echo "	--no-xfsprogs		Exclude xfsprogs"
  echo "	--zfs			Include ZFS support (enabled by default if rootfs is ZFS)"
  echo "	--no-zfs		Exclude ZFS support"
  echo "	--btrfs			Include Btrfs support (enabled by default if rootfs is Btrfs)"
  echo "	--no-btrfs		Exclude Btrfs support"
  echo "	--multipath		Include Multipath support"
  echo "	--no-multipath		Exclude Multipath support"
  echo "	--iscsi			Include iSCSI support"
  echo "	--no-iscsi		Exclude iSCSI support"
  echo "	--sandbox		Enable sandbox-ing when building initramfs"
  echo "	--no-sandbox		Disable sandbox-ing when building initramfs"
  echo "	--ssh			Include SSH (dropbear) support"
  echo "	--no-ssh		Exclude SSH (dropbear) support"
  echo "	--ssh-authorized-keys-file=<file>"
  echo "				Specifies a user created authorized_keys file"
  echo "	--ssh-host-keys=(create|create-from-host|runtime)"
  echo "				Use host keys from /etc/dropbear, but CREATE (default) new host key(s)"
  echo "				if missing, CREATE host key(s) FROM current HOST running genkernel"
  echo "				(not recommended) or don't embed any host key in initramfs and"
  echo "				generate at RUNTIME (dropbear -R)"
  echo "	--boot-font=(current|<file>|none)"
  echo "				Embed CURRENT active console font from host running genkernel"
  echo "				or specified PSF font file into initramfs and activate early on boot."
  echo "				Use NONE (default) to not embed any PSF file."
  echo "	--bootloader=(grub|grub2)"
  echo "				Add new kernel to GRUB (grub) or GRUB2 (grub2) bootloader"
  echo "	--no-bootloader		Skip bootloader update"
  echo "	--linuxrc=<file>	Specifies a user created linuxrc"
  echo "	--busybox-config=<file>	Specifies a user created busybox config"
  echo "	--genzimage		Make and install kernelz image (PowerPC)"
  echo "	--disklabel		Include disk label and uuid support in your initramfs"
  echo "	--no-disklabel		Exclude disk label and uuid support in your initramfs"
  echo "	--luks			Include LUKS support"
  echo "	--no-luks		Exclude LUKS support"
  echo "	--gpg			Include GPG-armored LUKS key support"
  echo "	--no-gpg		Exclude GPG-armored LUKS key support"
  echo "	--b2sum			Include b2sum"
  echo "	--no-b2sum		Exclude b2sum"
  echo "	--busybox		Include busybox"
  echo "	--no-busybox		Exclude busybox"
  echo "	--unionfs		Include support for unionfs"
  echo "	--no-unionfs		Exclude support for unionfs"
  echo "	--netboot		Create a self-contained env in the initramfs"
  echo "	--no-netboot		Exclude netboot env"
  echo "	--real-root=<foo>	Specify a default for real_root="
  echo "  Internals"
  echo "	--cachedir=<dir>	Override the default cache location"
  echo "	--check-free-disk-space-bootdir=<MB>"
  echo "				Check for specified amount of free disk space in MB in BOOTDIR"
  echo "				at genkernel start"
  echo "	--check-free-disk-space-kerneloutputdir=<MB>"
  echo "				Check for specified amount of free disk space in MB in"
  echo "				kernel outputdir at genkernel start"
  echo "	--clear-cachedir	Clear genkernel's cache location on start. Useful"
  echo "				if you want to force rebuild of included tools"
  echo "				like BusyBox, DMRAID, GnuPG, LVM, MDADM ..."
  echo "	--no-clear-cachedir	Do not clean up on genkernel start"
  echo "	--tmpdir=<dir>		Location of genkernel's temporary directory"
  echo "	--postclear		Clear all tmp files and caches after genkernel has run"
  echo "	--no-postclear		Do not clean up after genkernel has run"
  echo "  Output Settings"
  echo "	--kernel-config-filename=<...>"
  echo "				Set kernel config filename"
  echo "	--kernel-filename=<...>"
  echo "				Set kernel filename"
  echo "	--kernel-symlink-name=<...>"
  echo "				Set kernel symlink name"
  echo "	--minkernpackage=<archive>"
  echo "				Archive file created using tar containing kernel and"
  echo "				initramfs"
  echo "	--modulespackage=<archive>"
  echo "				Archive file created using tar containing modules after"
  echo "				the callbacks have run"
  echo "	--kerncache=<archive>	Archive file created using tar containing kernel binary,"
  echo "				content of /lib/modules and the kernel config after the"
  echo "				callbacks have run"
  echo "	--no-kernel-sources	This option is only valid if kerncache is"
  echo "				defined. If there is a valid kerncache no checks"
  echo "				will be made against a kernel source tree"
  echo "	--initramfs-filename=<...>"
  echo "				Set initramfs filename"
  echo "	--initramfs-overlay=<dir>"
  echo "				Directory structure to include in the initramfs,"
  echo "				only available on 2.6 kernels"
  echo "	--initramfs-symlink-name=<...>"
  echo "				Set initramfs symlink name"
  echo "	--firmware		Enable copying of firmware into initramfs"
  echo "	--firmware-dir=<dir>"
  echo "				Specify directory to copy firmware from (defaults"
  echo "				to /lib/firmware)"
  echo "	--firmware-files=<files>"
  echo "				Specifies specific firmware files to copy. This"
  echo "				overrides --firmware-dir. For multiple files,"
  echo "				separate the filenames with a comma"
  echo "	--firmware-install	Enable installing firmware onto root filesystem"
  echo "				(only available for kernels older than v4.14)"
  echo "	--no-firmware-install	Do not install firmware onto root filesystem"
  echo "	--integrated-initramfs"
  echo "				Include the generated initramfs in the kernel"
  echo "				instead of keeping it as a separate file"
  echo "	--no-integrated-initramfs"
  echo "				Do not include the generated initramfs in the kernel"
  echo "	--wrap-initrd		Wrap initramfs using mkimage for u-boot boots"
  echo "	--no-wrap-initrd	Do not wrap initramfs using mkimage for u-boot boots"
  echo "	--compress-initramfs"
  echo "				Compress initramfs"
  echo "	--no-compress-initramfs"
  echo "				Do not compress initramfs"
  echo "	--compress-initrd	Deprecated alias for --compress-initramfs"
  echo "	--no-compress-initrd	Deprecated alias for --no-compress-initramfs"
  echo "	--compress-initramfs-type=<arg>"
  echo "				Compression type for initramfs (best, xz, lzma, bzip2, gzip, lzop, lz4)"
  echo "	--strip=(all|kernel|modules|none)"
  echo "				Strip debug symbols from none, all, installed kernel (obsolete) or"
  echo "				modules (default)"
  echo "	--no-strip		Don't strip installed kernel or modules, alias for --strip=none"
  echo "	--systemmap-filename=<...>"
  echo "				Set System.map filename"
  echo "	--systemmap-symlink-name=<...>"
  echo "				Set System.map symlink name"
  echo
  echo "For a detailed list of supported initramfs options and flags; issue:"
  echo "	man 8 genkernel"
}

usage() {
  echo "Gentoo Linux Genkernel ${GK_V}"
  echo
  echo "Usage: "
  echo "	genkernel [options] (all|bzImage|initramfs|kernel)"
  echo
  echo 'Some useful options:'
  echo '	--menuconfig		Run menuconfig after oldconfig'
  echo '	--nconfig		Run nconfig after oldconfig (requires ncurses)'
  echo "	--no-clean		Do not run 'make clean' before compilation"
  echo "	--no-mrproper		Do not run 'make mrproper' before compilation,"
  echo '				this is implied by --no-clean'
  echo
  echo 'For a detailed list of supported commandline options and flags; issue:'
  echo '	genkernel --help'
  echo 'For a detailed list of supported initramfs options and flags; issue:'
  echo '	man 8 genkernel'
}

parse_optbool() {
	local opt=${1/--no-*/no} # false
	opt=${opt/--*/yes} # true
	echo ${opt}
}

parse_cmdline() {
	case "$*" in
		--cross-compile=*)
			CMD_CROSS_COMPILE="${*#*=}"
			print_info 3 "CMD_CROSS_COMPILE: ${CMD_CROSS_COMPILE}"
			;;
		--kernel-cc=*)
			CMD_KERNEL_CC="${*#*=}"
			print_info 3 "CMD_KERNEL_CC: ${CMD_KERNEL_CC}"
			;;
		--kernel-ld=*)
			CMD_KERNEL_LD="${*#*=}"
			print_info 3 "CMD_KERNEL_LD: ${CMD_KERNEL_LD}"
			;;
		--kernel-as=*)
			CMD_KERNEL_AS="${*#*=}"
			print_info 3 "CMD_KERNEL_AS: ${CMD_KERNEL_AS}"
			;;
		--kernel-make=*)
			CMD_KERNEL_MAKE="${*#*=}"
			print_info 3 "CMD_KERNEL_MAKE: ${CMD_KERNEL_MAKE}"
			;;
		--kernel-target=*)
			KERNEL_MAKE_DIRECTIVE_OVERRIDE="${*#*=}"
			print_info 3 "KERNEL_MAKE_DIRECTIVE_OVERRIDE: ${KERNEL_MAKE_DIRECTIVE_OVERRIDE}"
			;;
		--kernel-binary=*)
			KERNEL_BINARY_OVERRIDE="${*#*=}"
			print_info 3 "KERNEL_BINARY_OVERRIDE: ${KERNEL_BINARY_OVERRIDE}"
			;;
		--kernel-outputdir=*)
			CMD_KERNEL_OUTPUTDIR="${*#*=}"
			print_info 3 "CMD_KERNEL_OUTPUTDIR: ${CMD_KERNEL_OUTPUTDIR}"
			;;
		--utils-cc=*)
			CMD_UTILS_CC="${*#*=}"
			print_info 3 "CMD_UTILS_CC: ${CMD_UTILS_CC}"
			;;
		--utils-cxx=*)
			CMD_UTILS_CXX="${*#*=}"
			print_info 3 "CMD_UTILS_CXX: ${CMD_UTILS_CXX}"
			;;
		--utils-cflags=*)
			CMD_UTILS_CFLAGS="${*#*=}"
			print_info 3 "CMD_UTILS_CFLAGS: ${CMD_UTILS_CFLAGS}"
			;;
		--utils-ld=*)
			CMD_UTILS_LD="${*#*=}"
			print_info 3 "CMD_UTILS_LD: ${CMD_UTILS_LD}"
			;;
		--utils-as=*)
			CMD_UTILS_AS="${*#*=}"
			print_info 3 "CMD_UTILS_AS: ${CMD_UTILS_AS}"
			;;
		--utils-make=*)
			CMD_UTILS_MAKE="${*#*=}"
			print_info 3 "CMD_UTILS_MAKE: ${CMD_UTILS_MAKE}"
			;;
		--makeopts=*)
			CMD_MAKEOPTS="${*#*=}"
			print_info 3 "CMD_MAKEOPTS: ${CMD_MAKEOPTS}"
			;;
		--mountboot|--no-mountboot)
			CMD_MOUNTBOOT=$(parse_optbool "$*")
			print_info 3 "CMD_MOUNTBOOT: ${CMD_MOUNTBOOT}"
			;;
		--bootdir=*)
			CMD_BOOTDIR="${*#*=}"
			print_info 3 "CMD_BOOTDIR: ${CMD_BOOTDIR}"
			;;
		--modprobedir=*)
			CMD_MODPROBEDIR="${*#*=}"
			print_info 3 "CMD_MODPROBEDIR: ${CMD_MODPROBEDIR}"
			;;
		--do-keymap-auto)
			CMD_DOKEYMAPAUTO="yes"
			CMD_KEYMAP="yes"
			print_info 3 "CMD_DOKEYMAPAUTO: ${CMD_DOKEYMAPAUTO}"
			;;
		--keymap|--no-keymap)
			CMD_KEYMAP=$(parse_optbool "$*")
			print_info 3 "CMD_KEYMAP: ${CMD_KEYMAP}"
			;;
		--bcache|--no-bcache)
			CMD_BCACHE=$(parse_optbool "$*")
			print_info 3 "CMD_BCACHE: ${CMD_BCACHE}"
			;;
		--lvm|--no-lvm)
			CMD_LVM=$(parse_optbool "$*")
			print_info 3 "CMD_LVM: ${CMD_LVM}"
			;;
		--lvm2|--no-lvm2)
			CMD_LVM=$(parse_optbool "$*")
			print_info 3 "CMD_LVM: ${CMD_LVM}"
			echo
			print_warning 1 "Please use --lvm, as --lvm2 is deprecated."
			;;
		--mdadm|--no-mdadm)
			CMD_MDADM=$(parse_optbool "$*")
			print_info 3 "CMD_MDADM: ${CMD_MDADM}"
			;;
		--mdadm-config=*)
			CMD_MDADM_CONFIG="${*#*=}"
			print_info 3 "CMD_MDADM_CONFIG: ${CMD_MDADM_CONFIG}"
			;;
		--b2sum|--no-b2sum)
			CMD_B2SUM=$(parse_optbool "$*")
			print_info 3 "CMD_B2SUM: ${CMD_B2SUM}"
			;;
		--busybox|--no-busybox)
			CMD_BUSYBOX=$(parse_optbool "$*")
			print_info 3 "CMD_BUSYBOX: ${CMD_BUSYBOX}"
			;;
		--microcode|--no-microcode)
			case $(parse_optbool "$*") in
				no)  CMD_MICROCODE='no' ;;
				yes) CMD_MICROCODE='all' ;;
			esac
			print_info 3 "CMD_MICROCODE: ${CMD_MICROCODE}"
			;;
		--microcode=*)
			CMD_MICROCODE="${*#*=}"
			print_info 3 "CMD_MICROCODE: ${CMD_MICROCODE}"
			;;
		--microcode-initramfs|--no-microcode-initramfs)
			CMD_MICROCODE_INITRAMFS=$(parse_optbool "$*")
			print_info 3 "CMD_MICROCODE_INITRAMFS: ${CMD_MICROCODE_INITRAMFS}"
			;;
		--nfs|--no-nfs)
			CMD_NFS=$(parse_optbool "$*")
			print_info 3 "CMD_NFS: ${CMD_NFS}"
			;;
		--unionfs|--no-unionfs)
			CMD_UNIONFS=$(parse_optbool "$*")
			print_info 3 "CMD_UNIONFS: ${CMD_UNIONFS}"
			;;
		--netboot|--no-netboot)
			CMD_NETBOOT=$(parse_optbool "$*")
			print_info 3 "CMD_NETBOOT: ${CMD_NETBOOT}"
			;;
		--real-root=*)
			CMD_REAL_ROOT="${*#*=}"
			print_info 3 "CMD_REAL_ROOT: ${CMD_REAL_ROOT}"
			;;
		--dmraid|--no-dmraid)
			CMD_DMRAID=$(parse_optbool "$*")
			print_info 3 "CMD_DMRAID: ${CMD_DMRAID}"
			;;
		--e2fsprogs|--no-e2fsprogs)
			CMD_E2FSPROGS=$(parse_optbool "$*")
			print_info 3 "CMD_E2FSPROGS: ${CMD_E2FSPROGS}"
			;;
		--xfsprogs|--no-xfsprogs)
			CMD_XFSPROGS=$(parse_optbool "$*")
			print_info 3 "CMD_XFSPROGS: ${CMD_XFSPROGS}"
			;;
		--zfs|--no-zfs)
			CMD_ZFS=$(parse_optbool "$*")
			print_info 3 "CMD_ZFS: ${CMD_ZFS}"
			;;
		--btrfs|--no-btrfs)
			CMD_BTRFS=$(parse_optbool "$*")
			print_info 3 "CMD_BTRFS: ${CMD_BTRFS}"
			;;
		--virtio|--no-virtio)
			CMD_VIRTIO=$(parse_optbool "$*")
			print_info 3 "CMD_VIRTIO: ${CMD_VIRTIO}"
			;;
		--multipath|--no-multipath)
			CMD_MULTIPATH=$(parse_optbool "$*")
			print_info 3 "CMD_MULTIPATH: ${CMD_MULTIPATH}"
			;;
		--boot-font=*)
			CMD_BOOTFONT="${*#*=}"
			[ -z "${CMD_BOOTFONT}" ] && CMD_BOOTFONT="none"
			print_info 3 "CMD_BOOTFONT: ${CMD_BOOTFONT}"
			;;
		--bootloader=*)
			CMD_BOOTLOADER="${*#*=}"
			[ -z "${CMD_BOOTLOADER}" ] && CMD_BOOTLOADER="no"
			print_info 3 "CMD_BOOTLOADER: ${CMD_BOOTLOADER}"
			;;
		--no-bootloader)
			CMD_BOOTLOADER="no"
			print_info 3 "CMD_BOOTLOADER: ${CMD_BOOTLOADER}"
			;;
		--iscsi|--no-iscsi)
			CMD_ISCSI=$(parse_optbool "$*")
			print_info 3 "CMD_ISCSI: ${CMD_ISCSI}"
			;;
		--hyperv|--no-hyperv)
			CMD_HYPERV=$(parse_optbool "$*")
			print_info 3 "CMD_HYPERV: ${CMD_HYPERV}"
			;;
		--sandbox|--no-sandbox)
			CMD_SANDBOX=$(parse_optbool "$*")
			print_info 3 "CMD_SANDBOX: ${CMD_SANDBOX}"
			;;
		--ssh|--no-ssh)
			CMD_SSH=$(parse_optbool "$*")
			print_info 3 "CMD_SSH: ${CMD_SSH}"
			;;
		--ssh-authorized-keys-file=*)
			CMD_SSH_AUTHORIZED_KEYS_FILE="${*#*=}"
			print_info 3 "CMD_SSH_AUTHORIZED_KEYS_FILE: ${CMD_SSH_AUTHORIZED_KEYS_FILE}"
			;;
		--ssh-host-keys=*)
			CMD_SSH_HOST_KEYS="${*#*=}"
			if ! isTrue "$(is_valid_ssh_host_keys_parameter_value "${CMD_SSH_HOST_KEYS}")"
			then
				echo "Error: --ssh-host-keys value '${CMD_SSH_HOST_KEYS}' is unsupported."
				exit 1
			fi
			print_info 3 "CMD_SSH_HOST_KEYS: ${CMD_SSH_HOST_KEYS}"
			;;
		--strace|--no-strace)
			CMD_STRACE=$(parse_optbool "$*")
			print_info 3 "CMD_STRACE: ${CMD_STRACE}"
			;;
		--loglevel=*)
			CMD_LOGLEVEL="${*#*=}"
			LOGLEVEL="${CMD_LOGLEVEL}"
			print_info 3 "CMD_LOGLEVEL: ${CMD_LOGLEVEL}"
			;;
		--menuconfig)
			TERM_LINES=$(stty -a | head -n 1 | cut -d\  -f5 | cut -d\; -f1)
			TERM_COLUMNS=$(stty -a | head -n 1 | cut -d\  -f7 | cut -d\; -f1)
			if [[ TERM_LINES -lt 19 || TERM_COLUMNS -lt 80 ]]
			then
				echo 'Error: You need a terminal with at least 80 columns' \
					'and 19 lines for --menuconfig; try --no-menuconfig ...'
				exit 1
			fi
			CMD_MENUCONFIG="yes"
			print_info 3 "CMD_MENUCONFIG: ${CMD_MENUCONFIG}"
			;;
		--no-menuconfig)
			CMD_MENUCONFIG="no"
			print_info 3 "CMD_MENUCONFIG: ${CMD_MENUCONFIG}"
			;;
		--nconfig)
			TERM_LINES=$(stty -a | head -n 1 | cut -d\  -f5 | cut -d\; -f1)
			TERM_COLUMNS=$(stty -a | head -n 1 | cut -d\  -f7 | cut -d\; -f1)
			if [[ TERM_LINES -lt 19 || TERM_COLUMNS -lt 80 ]]
			then
				echo 'Error: You need a terminal with at least 80 columns' \
					'and 19 lines for --nconfig; try --no-nconfig ...'
				exit 1
			fi
			CMD_NCONFIG="yes"
			print_info 3 "CMD_NCONFIG: ${CMD_NCONFIG}"
			;;
		--no-nconfig)
			CMD_NCONFIG="no"
			print_info 3 "CMD_NCONFIG: ${CMD_NCONFIG}"
			;;
		--gconfig|--no-gconfig)
			CMD_GCONFIG=$(parse_optbool "$*")
			print_info 3 "CMD_GCONFIG: ${CMD_GCONFIG}"
			;;
		--xconfig|--no-xconfig)
			CMD_XCONFIG=$(parse_optbool "$*")
			print_info 3 "CMD_XCONFIG: ${CMD_XCONFIG}"
			;;
		--save-config|--no-save-config)
			CMD_SAVE_CONFIG=$(parse_optbool "$*")
			print_info 3 "CMD_SAVE_CONFIG: ${CMD_SAVE_CONFIG}"
			;;
		--mrproper|--no-mrproper)
			CMD_MRPROPER=$(parse_optbool "$*")
			print_info 3 "CMD_MRPROPER: ${CMD_MRPROPER}"
			;;
		--clean|--no-clean)
			CMD_CLEAN=$(parse_optbool "$*")
			print_info 3 "CMD_CLEAN: ${CMD_CLEAN}"
			;;
		--oldconfig|--no-oldconfig)
			CMD_OLDCONFIG=$(parse_optbool "$*")
			isTrue "${CMD_OLDCONFIG}" && CMD_CLEAN="no"
			print_info 3 "CMD_CLEAN: ${CMD_CLEAN}"
			print_info 3 "CMD_OLDCONFIG: ${CMD_OLDCONFIG}"
			;;
		--gensplash=*)
			CMD_SPLASH="yes"
			SPLASH_THEME="${*#*=}"
			print_info 3 "CMD_SPLASH: ${CMD_SPLASH}"
			print_info 3 "SPLASH_THEME: ${SPLASH_THEME}"
			echo
			print_warning 1 "Please use --splash, as --gensplash is deprecated."
			;;
		--gensplash|--no-gensplash)
			CMD_SPLASH=$(parse_optbool "$*")
			SPLASH_THEME='default'
			print_info 3 "CMD_SPLASH: ${CMD_SPLASH}"
			echo
			print_warning 1 "Please use --splash, as --gensplash is deprecated."
			;;
		--splash=*)
			CMD_SPLASH="yes"
			SPLASH_THEME="${*#*=}"
			print_info 3 "CMD_SPLASH: ${CMD_SPLASH}"
			print_info 3 "SPLASH_THEME: ${SPLASH_THEME}"
			;;
		--splash|--no-splash)
			CMD_SPLASH=$(parse_optbool "$*")
			SPLASH_THEME='default'
			print_info 3 "CMD_SPLASH: ${CMD_SPLASH}"
			;;
		--gensplash-res=*)
			SPLASH_RES="${*#*=}"
			print_info 3 "SPLASH_RES: ${SPLASH_RES}"
			echo
			print_warning 1 "Please use --splash-res, as --gensplash-res is deprecated."
			;;
		--splash-res=*)
			SPLASH_RES="${*#*=}"
			print_info 3 "SPLASH_RES: ${SPLASH_RES}"
			;;
		--install|--no-install)
			CMD_INSTALL=$(parse_optbool "$*")
			print_info 3 "CMD_INSTALL: ${CMD_INSTALL}"
			;;
		--ramdisk-modules|--no-ramdisk-modules)
			CMD_RAMDISKMODULES=$(parse_optbool "$*")
			print_info 3 "CMD_RAMDISKMODULES: ${CMD_RAMDISKMODULES}"
			;;
		--all-ramdisk-modules|--no-all-ramdisk-modules)
			CMD_ALLRAMDISKMODULES=$(parse_optbool "$*")
			print_info 3 "CMD_ALLRAMDISKMODULES: ${CMD_ALLRAMDISKMODULES}"
			;;
		--module-rebuild|--no-module-rebuild)
			CMD_MODULEREBUILD=$(parse_optbool "$*")
			print_info 3 "CMD_MODULEREBUILD: ${CMD_MODULEREBUILD}"
			;;
		--module-rebuild-cmd=*)
			CMD_MODULEREBUILD_CMD="${*#--module-rebuild-cmd=}"
			print_info 3 "CMD_MODULEREBUILD_CMD: ${CMD_MODULEREBUILD_CMD}"
			;;
		--callback=*)
			CMD_CALLBACK="${*#--callback=}"
			print_info 3 "CMD_CALLBACK: ${CMD_CALLBACK}"
			;;
		--static|--no-static)
			CMD_STATIC=$(parse_optbool "$*")
			print_info 3 "CMD_STATIC: ${CMD_STATIC}"
			;;
		--tmpdir=*)
			CMD_TMPDIR="${*#*=}"
			print_info 3 "CMD_TMPDIR: ${CMD_TMPDIR}"
			;;
		--postclear|--no-postclear)
			CMD_POSTCLEAR=$(parse_optbool "$*")
			print_info 3 "CMD_POSTCLEAR: ${CMD_POSTCLEAR}"
			;;
		--check-free-disk-space-bootdir=*)
			CMD_CHECK_FREE_DISK_SPACE_BOOTDIR="${*#*=}"
			print_info 3 "CMD_CHECK_FREE_DISK_SPACE_BOOTDIR: ${CMD_CHECK_FREE_DISK_SPACE_BOOTDIR}"
			;;
		--check-free-disk-space-kerneloutputdir=*)
			CMD_CHECK_FREE_DISK_SPACE_KERNELOUTPUTDIR="${*#*=}"
			print_info 3 "CMD_CHECK_FREE_DISK_SPACE_KERNELOUTPUTDIR: ${CMD_CHECK_FREE_DISK_SPACE_KERNELOUTPUTDIR}"
			;;
		--color|--no-color)
			CMD_COLOR=$(parse_optbool "$*")
			if isTrue "${CMD_COLOR}"
			then
				NOCOLOR=false
			else
				NOCOLOR=true
			fi
			print_info 3 "CMD_COLOR: ${CMD_COLOR}"
			set_color_vars
			;;
		--cleanup|--no-cleanup)
			CMD_CLEANUP=$(parse_optbool "$*")
			print_info 3 "CMD_CLEANUP: ${CMD_CLEANUP}"
			;;
		--logfile=*)
			CMD_LOGFILE="${*#*=}"
			print_info 3 "CMD_LOGFILE: ${CMD_LOGFILE}"
			;;
		--kerneldir=*)
			CMD_KERNEL_DIR="${*#*=}"
			print_info 3 "CMD_KERNEL_DIR: ${CMD_KERNEL_DIR}"
			;;
		--kernel-append-localversion=*)
			CMD_KERNEL_APPEND_LOCALVERSION="${*#*=}"
			print_info 3 "CMD_KERNEL_APPEND_LOCALVERSION: ${CMD_KERNEL_APPEND_LOCALVERSION}"
			;;
		--kernel-config=*)
			CMD_KERNEL_CONFIG="${*#*=}"
			print_info 3 "CMD_KERNEL_CONFIG: ${CMD_KERNEL_CONFIG}"
			;;
		--kernel-localversion=*)
			CMD_KERNEL_LOCALVERSION="${*#*=}"
			print_info 3 "CMD_KERNEL_LOCALVERSION: ${CMD_KERNEL_LOCALVERSION}"
			;;
		--module-prefix=*)
			CMD_INSTALL_MOD_PATH="${*#*=}"
			print_info 3 "CMD_INSTALL_MOD_PATH: ${CMD_INSTALL_MOD_PATH}"
			;;
		--cachedir=*)
			CACHE_DIR="${*#*=}"
			print_info 3 "CACHE_DIR: ${CACHE_DIR}"
			;;
		--clear-cachedir|--no-clear-cachedir)
			CMD_CLEAR_CACHEDIR=$(parse_optbool "$*")
			print_info 3 "CMD_CLEAR_CACHEDIR: ${CMD_CLEAR_CACHEDIR}"
			;;
		--minkernpackage=*)
			CMD_MINKERNPACKAGE="${*#*=}"
			print_info 3 "MINKERNPACKAGE: ${CMD_MINKERNPACKAGE}"
			;;
		--modulespackage=*)
			CMD_MODULESPACKAGE="${*#*=}"
			print_info 3 "MODULESPACKAGE: ${CMD_MODULESPACKAGE}"
			;;
		--kerncache=*)
			CMD_KERNCACHE="${*#*=}"
			print_info 3 "KERNCACHE: ${CMD_KERNCACHE}"
			;;
		--kernel-config-filename=*)
			CMD_KERNEL_CONFIG_FILENAME="${*#*=}"
			print_info 3 "CMD_KERNEL_CONFIG_FILENAME: ${CMD_KERNEL_CONFIG_FILENAME}"
			;;
		--kernel-filename=*)
			CMD_KERNEL_FILENAME="${*#*=}"
			print_info 3 "CMD_KERNEL_FILENAME: ${CMD_KERNEL_FILENAME}"
			;;
		--kernel-symlink-name=*)
			CMD_KERNEL_SYMLINK_NAME="${*#*=}"
			print_info 3 "CMD_KERNEL_SYMLINK_NAME: ${CMD_KERNEL_SYMLINK_NAME}"
			;;
		--symlink|--no-symlink)
			CMD_SYMLINK=$(parse_optbool "$*")
			print_info 3 "CMD_SYMLINK: ${CMD_SYMLINK}"
			;;
		--kernel-sources|--no-kernel-sources)
			CMD_KERNEL_SOURCES=$(parse_optbool "$*")
			print_info 3 "CMD_KERNEL_SOURCES: ${CMD_KERNEL_SOURCES}"
			;;
		--initramfs-filename=*)
			CMD_INITRAMFS_FILENAME="${*#*=}"
			print_info 3 "CMD_INITRAMFS_FILENAME: ${CMD_INITRAMFS_FILENAME}"
			;;
		--initramfs-overlay=*)
			CMD_INITRAMFS_OVERLAY="${*#*=}"
			print_info 3 "CMD_INITRAMFS_OVERLAY: ${CMD_INITRAMFS_OVERLAY}"
			;;
		--initramfs-symlink-name=*)
			CMD_INITRAMFS_SYMLINK_NAME="${*#*=}"
			print_info 3 "CMD_INITRAMFS_SYMLINK_NAME: ${CMD_INITRAMFS_SYMLINK_NAME}"
			;;
		--systemmap-filename=*)
			CMD_SYSTEMMAP_FILENAME="${*#*=}"
			print_info 3 "CMD_SYSTEMMAP_FILENAME: ${CMD_SYSTEMMAP_FILENAME}"
			;;
		--systemmap-symlink-name=*)
			CMD_SYSTEMMAP_SYMLINK_NAME="${*#*=}"
			print_info 3 "CMD_SYSTEMMAP_SYMLINK_NAME: ${CMD_SYSTEMMAP_SYMLINK_NAME}"
			;;
		--linuxrc=*)
			CMD_LINUXRC="${*#*=}"
			print_info 3 "CMD_LINUXRC: ${CMD_LINUXRC}"
			;;
		--busybox-config=*)
			CMD_BUSYBOX_CONFIG="${*#*=}"
			print_info 3 "CMD_BUSYBOX_CONFIG: ${CMD_BUSYBOX_CONFIG}"
			;;
		--genzimage)
			KERNEL_MAKE_DIRECTIVE_2='zImage.initrd'
			KERNEL_BINARY_2='arch/powerpc/boot/zImage.initrd'
			CMD_GENZIMAGE="yes"
			print_info 3 "CMD_GENZIMAGE: ${CMD_GENZIMAGE}"
#			ENABLE_PEGASOS_HACKS="yes"
#			print_info 3 "ENABLE_PEGASOS_HACKS: ${ENABLE_PEGASOS_HACKS}"
			;;
		--disklabel|--no-disklabel)
			CMD_DISKLABEL=$(parse_optbool "$*")
			print_info 3 "CMD_DISKLABEL: ${CMD_DISKLABEL}"
			;;
		--luks|--no-luks)
			CMD_LUKS=$(parse_optbool "$*")
			print_info 3 "CMD_LUKS: ${CMD_LUKS}"
			;;
		--gpg|--no-gpg)
			CMD_GPG=$(parse_optbool "$*")
			print_info 3 "CMD_GPG: ${CMD_GPG}"
			;;
		--firmware|--no-firmware)
			CMD_FIRMWARE=$(parse_optbool "$*")
			print_info 3 "CMD_FIRMWARE: ${CMD_FIRMWARE}"
			;;
		--firmware-dir=*)
			CMD_FIRMWARE_DIR="${*#*=}"
			CMD_FIRMWARE="yes"
			print_info 3 "CMD_FIRMWARE_DIR: ${CMD_FIRMWARE_DIR}"
			;;
		--firmware-files=*)
			CMD_FIRMWARE_FILES="${*#*=}"
			CMD_FIRMWARE="yes"
			print_info 3 "CMD_FIRMWARE_FILES: ${CMD_FIRMWARE_FILES}"
			;;
		--firmware-install|--no-firmware-install)
			CMD_FIRMWARE_INSTALL=$(parse_optbool "$*")
			print_info 3 "CMD_FIRMWARE_INSTALL: ${CMD_FIRMWARE_INSTALL}"
			;;
		--integrated-initramfs|--no-integrated-initramfs)
			CMD_INTEGRATED_INITRAMFS=$(parse_optbool "$*")
			print_info 3 "CMD_INTEGRATED_INITRAMFS=${CMD_INTEGRATED_INITRAMFS}"
			;;
		--wrap-initrd|--no-wrap-initrd)
			CMD_WRAP_INITRD=$(parse_optbool "$*")
			print_info 3 "CMD_WRAP_INITRD=${CMD_WRAP_INITRD}"
			;;
		--compress-initramfs|--no-compress-initramfs)
			CMD_COMPRESS_INITRD=$(parse_optbool "$*")
			print_info 3 "CMD_COMPRESS_INITRD=${CMD_COMPRESS_INITRD}"
			;;
		--compress-initrd|--no-compress-initrd)
			CMD_COMPRESS_INITRD=$(parse_optbool "$*")
			print_info 3 "CMD_COMPRESS_INITRD=${CMD_COMPRESS_INITRD}"
			echo
			print_warning 1 "Please use --[no-]compress-initramfs, as --[no-]compress-initrd is deprecated."
			;;
		--compress-initramfs-type=*|--compress-initrd-type=*)
			CMD_COMPRESS_INITRD_TYPE="${*#*=}"
			print_info 3 "CMD_COMPRESS_INITRD_TYPE: ${CMD_COMPRESS_INITRD_TYPE}"
			;;
		--config=*)
			print_info 3 "CMD_GK_CONFIG: "${*#*=}""
			;;
		--nice)
			CMD_NICE=10
			print_info 3 "CMD_NICE: ${CMD_NICE}"
			;;
		--nice=*)
			CMD_NICE="${*#*=}"
			if [ ${CMD_NICE} -lt 0 -o ${CMD_NICE} -gt 19 ]
			then
				echo 'Error:  Illegal value specified for --nice= parameter.'
				exit 1
			fi
			print_info 3 "CMD_NICE: ${CMD_NICE}"
			;;
		--no-nice)
			CMD_NICE=0
			print_info 3 "CMD_NICE: ${CMD_NICE}"
			;;
		--strip=*)
			CMD_STRIP_TYPE="${*#*=}"
			print_info 3 "CMD_STRIP_TYPE: ${CMD_STRIP_TYPE}"
			;;
		--no-strip)
			CMD_STRIP_TYPE=none
			print_info 3 "CMD_STRIP_TYPE: ${CMD_STRIP_TYPE}"
			;;
		all)
			BUILD_KERNEL="yes"
			BUILD_MODULES="yes"
			BUILD_RAMDISK="yes"
			;;
		ramdisk|initramfs)
			BUILD_KERNEL="no"
			BUILD_MODULES="no"
			BUILD_RAMDISK="yes"
			;;
		kernel)
			BUILD_KERNEL="yes"
			BUILD_MODULES="yes"
			BUILD_RAMDISK="no"
			;;
		bzImage)
			BUILD_KERNEL="yes"
			BUILD_MODULES="no"
			BUILD_RAMDISK="no"
			CMD_RAMDISKMODULES="no"
			print_info 3 "CMD_RAMDISKMODULES: ${CMD_RAMDISKMODULES}"
			;;
		--help)
			longusage
			exit 1
			;;
		--version)
			echo "${GK_V}"
			exit 0
			;;
		*)
			small_die "Unknown option '$*'!"
			;;
	esac
}
