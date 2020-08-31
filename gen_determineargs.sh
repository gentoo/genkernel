#!/bin/bash
# $Id$

determine_KV() {
	local old_KV=
	[ -n "${KV}" ] && old_KV="${KV}"

	if ! isTrue "${KERNEL_SOURCES}" && [ -e "${KERNCACHE}" ]
	then
		"${TAR_COMMAND}" -x -C "${TEMP}" -f "${KERNCACHE}" kerncache.config \
			|| gen_die "Failed to extract 'kerncache.config' from '${KERNCACHE}' to '${TEMP}'!"

		if [ -e "${TEMP}/kerncache.config" ]
		then
			VER=$(grep ^VERSION\ \= "${TEMP}"/kerncache.config | awk '{ print $3 };')
			PAT=$(grep ^PATCHLEVEL\ \= "${TEMP}"/kerncache.config | awk '{ print $3 };')
			SUB=$(grep ^SUBLEVEL\ \= "${TEMP}"/kerncache.config | awk '{ print $3 };')
			EXV=$(grep ^EXTRAVERSION\ \= "${TEMP}"/kerncache.config | sed -e "s/EXTRAVERSION =//" -e "s/ //g")
			LOV=$(grep ^CONFIG_LOCALVERSION\ \= "${TEMP}"/kerncache.config | sed -e "s/CONFIG_LOCALVERSION=\"\(.*\)\"/\1/")
			KV=${VER}.${PAT}.${SUB}${EXV}${LOV}
		else
			gen_die "Could not find kerncache.config in the kernel cache! Exiting."
		fi
	else
		# Configure the kernel
		# If BUILD_KERNEL=0 then assume --no-clean, menuconfig is cleared

		if [ ! -f "${KERNEL_DIR}"/Makefile ]
		then
			gen_die "Kernel Makefile (${KERNEL_DIR}/Makefile) missing.  Maybe re-install the kernel sources."
		fi

		VER=$(grep ^VERSION\ \= ${KERNEL_DIR}/Makefile | awk '{ print $3 };')
		PAT=$(grep ^PATCHLEVEL\ \= ${KERNEL_DIR}/Makefile | awk '{ print $3 };')
		SUB=$(grep ^SUBLEVEL\ \= ${KERNEL_DIR}/Makefile | awk '{ print $3 };')
		EXV=$(grep ^EXTRAVERSION\ \= ${KERNEL_DIR}/Makefile | sed -e "s/EXTRAVERSION =//" -e "s/ //g" -e 's/\$([a-z]*)//gi')

		# The files we are looking for are always in KERNEL_OUTPUTDIR
		# because in most cases, KERNEL_OUTPUTDIR == KERNEL_DIR.
		# If KERNEL_OUTPUTDIR != KERNEL_DIR, --kernel-outputdir is used,
		# in which case files will only be in KERNEL_OUTPUTDIR.
		[ -f "${KERNEL_OUTPUTDIR}/include/linux/version.h" ] && \
			VERSION_SOURCE="${KERNEL_OUTPUTDIR}/include/linux/version.h"
		[ -f "${KERNEL_OUTPUTDIR}/include/linux/utsrelease.h" ] && \
			VERSION_SOURCE="${KERNEL_OUTPUTDIR}/include/linux/utsrelease.h"
		# Handle new-style releases where version.h doesn't have UTS_RELEASE
		if [ -f "${KERNEL_OUTPUTDIR}/include/config/kernel.release" ]
		then
			print_info 3 "Using '${KERNEL_OUTPUTDIR}/include/config/kernel.release' to extract LOCALVERSION ..."
			UTS_RELEASE=$(cat "${KERNEL_OUTPUTDIR}/include/config/kernel.release")
			LOV=$(echo ${UTS_RELEASE}|sed -e "s/${VER}.${PAT}.${SUB}${EXV}//")
			KV=${VER}.${PAT}.${SUB}${EXV}${LOV}
		elif [ -n "${VERSION_SOURCE}" ]
		then
			print_info 3 "Using '${VERSION_SOURCE}' to extract LOCALVERSION ..."
			UTS_RELEASE=$(grep UTS_RELEASE ${VERSION_SOURCE} | sed -e 's/#define UTS_RELEASE "\(.*\)"/\1/')
			LOV=$(echo ${UTS_RELEASE}|sed -e "s/${VER}.${PAT}.${SUB}${EXV}//")
			KV=${VER}.${PAT}.${SUB}${EXV}${LOV}
		else
			# We will be here only when currently selected kernel source
			# is untouched (i.e. after a new kernel sources version was
			# installed and will now be used for the first time) or
			# was cleaned.
			# Anyway, we have no chance to get a LOCALVERSION,
			# so don't even try -- it would be also useless at this stage.
			# Note: If we are building a kernel in this genkernel run and
			#       LOCALVERSION will become available later due to
			#       changed configuration we will notice after we have
			#       prepared the sources.
			print_info 3 "Unable to determine LOCALVERSION -- maybe cleaned/fresh sources?"
			KV=${VER}.${PAT}.${SUB}${EXV}
		fi
	fi

	KV_MAJOR=$(echo ${KV} | cut -f1 -d.)
	KV_MINOR=$(echo ${KV} | cut -f2 -d.)
	KV_NUMERIC=$((${KV_MAJOR} * 1000 + ${KV_MINOR}))

	if [ -n "${old_KV}" -a "${KV}" != "${old_KV}" ]
	then
		print_info 3 "KV changed from '${old_KV}' to '${KV}'!"
		echo "${old_KV}" > "${TEMP}/.old_kv" ||
			gen_die "failed to to store '${old_KV}' in '${TEMP}/.old_kv' marker"
	fi
}

determine_output_filenames() {
	print_info 5 '' 1 0

	GK_FILENAME_KERNELZ="kernelz-${KV}"
	GK_FILENAME_TEMP_CONFIG="config-${ARCH}-${KV}"
	GK_FILENAME_TEMP_INITRAMFS="initramfs-${ARCH}-${KV}"
	GK_FILENAME_TEMP_KERNEL="kernel-${ARCH}-${KV}"
	GK_FILENAME_TEMP_KERNELZ="kernelz-${ARCH}-${KV}"
	GK_FILENAME_TEMP_SYSTEMMAP="System.map-${ARCH}-${KV}"

	# Do we have values?
	if [ -z "${KERNEL_CONFIG_FILENAME}" ]
	then
		gen_die "--kernel-config-filename must be set to a non-empty value!"
	elif [ -z "${KERNEL_FILENAME}" ]
	then
		gen_die "--kernel-filename must be set to a non-empty value!"
	elif [ -z "${KERNEL_SYMLINK_NAME}" ]
	then
		gen_die "--kernel-symlink-name must be set to a non-empty value!"
	elif [ -z "${SYSTEMMAP_FILENAME}" ]
	then
		gen_die "--systemmap-filename must be set to a non-empty value!"
	elif [ -z "${SYSTEMMAP_SYMLINK_NAME}" ]
	then
		gen_die "--systemmap-symlink-name must be set to a non-empty value!"
	elif [ -z "${INITRAMFS_FILENAME}" ]
	then
		gen_die "--initramfs-filename must be set to a non-empty value!"
	elif [ -z "${INITRAMFS_FILENAME}" ]
	then
		gen_die "--initramfs-filename must be set to a non-empty value!"
	fi

	# Kernel .config
	GK_FILENAME_CONFIG=$(arch_replace "${KERNEL_CONFIG_FILENAME}")
	GK_FILENAME_CONFIG=$(kv_replace "${GK_FILENAME_CONFIG}")

	if [ -z "${GK_FILENAME_CONFIG}" ]
	then
		gen_die "Internal error: Variable 'GK_FILENAME_CONFIG' is empty!"
	else
		print_info 5 "GK_FILENAME_CONFIG set to '${GK_FILENAME_CONFIG}' (was: '${KERNEL_CONFIG_FILENAME}')"
	fi

	# Kernel
	GK_FILENAME_KERNEL=$(arch_replace "${KERNEL_FILENAME}")
	GK_FILENAME_KERNEL=$(kv_replace "${GK_FILENAME_KERNEL}")

	if [ -z "${GK_FILENAME_KERNEL}" ]
	then
		gen_die "Internal error: Variable 'GK_FILENAME_KERNEL' is empty!"
	else
		print_info 5 "GK_FILENAME_KERNEL set to '${GK_FILENAME_KERNEL}' (was: '${KERNEL_FILENAME}')"
	fi

	# Kernel symlink
	GK_FILENAME_KERNEL_SYMLINK=$(arch_replace "${KERNEL_SYMLINK_NAME}")
	GK_FILENAME_KERNEL_SYMLINK=$(kv_replace "${GK_FILENAME_KERNEL_SYMLINK}")

	if [ -z "${GK_FILENAME_KERNEL_SYMLINK}" ]
	then
		gen_die "Internal error: Variable 'GK_FILENAME_KERNEL_SYMLINK' is empty!"
	else
		print_info 5 "GK_FILENAME_KERNEL_SYMLINK set to '${GK_FILENAME_KERNEL_SYMLINK}' (was: '${KERNEL_SYMLINK_NAME}')"
	fi

	if [[ "${GK_FILENAME_KERNEL}" == "${GK_FILENAME_KERNEL_SYMLINK}" ]]
	then
		gen_die "--kernel-filename cannot be identical with --kernel-symlink-name!"
	fi

	# System.map
	GK_FILENAME_SYSTEMMAP=$(arch_replace "${SYSTEMMAP_FILENAME}")
	GK_FILENAME_SYSTEMMAP=$(kv_replace "${GK_FILENAME_SYSTEMMAP}")

	if [ -z "${GK_FILENAME_SYSTEMMAP}" ]
	then
		gen_die "Internal error: Variable 'GK_FILENAME_SYSTEMMAP' is empty!"
	else
		print_info 5 "GK_FILENAME_SYSTEMMAP set to '${GK_FILENAME_SYSTEMMAP}' (was: '${SYSTEMMAP_FILENAME}')"
	fi

	# System.map symlink
	GK_FILENAME_SYSTEMMAP_SYMLINK=$(arch_replace "${SYSTEMMAP_SYMLINK_NAME}")
	GK_FILENAME_SYSTEMMAP_SYMLINK=$(kv_replace "${GK_FILENAME_SYSTEMMAP_SYMLINK}")

	if [ -z "${GK_FILENAME_SYSTEMMAP_SYMLINK}" ]
	then
		gen_die "Internal error: Variable 'GK_FILENAME_SYSTEMMAP_SYMLINK' is empty!"
	else
		print_info 5 "GK_FILENAME_SYSTEMMAP_SYMLINK set to '${GK_FILENAME_SYSTEMMAP_SYMLINK}' (was: '${SYSTEMMAP_SYMLINK_NAME}')"
	fi

	if [[ "${GK_FILENAME_SYSTEMMAP}" == "${GK_FILENAME_SYSTEMMAP_SYMLINK}" ]]
	then
		gen_die "--systemmap-filename cannot be identical with --systemmap-symlink-name!"
	fi

	# Initramfs
	GK_FILENAME_INITRAMFS=$(arch_replace "${INITRAMFS_FILENAME}")
	GK_FILENAME_INITRAMFS=$(kv_replace "${GK_FILENAME_INITRAMFS}")

	if [ -z "${GK_FILENAME_INITRAMFS}" ]
	then
		gen_die "Internal error: Variable 'GK_FILENAME_INITRAMFS' is empty!"
	else
		print_info 5 "GK_FILENAME_INITRAMFS set to '${GK_FILENAME_INITRAMFS}' (was: '${INITRAMFS_FILENAME}')"
	fi

	# Initramfs symlink
	GK_FILENAME_INITRAMFS_SYMLINK=$(arch_replace "${INITRAMFS_SYMLINK_NAME}")
	GK_FILENAME_INITRAMFS_SYMLINK=$(kv_replace "${GK_FILENAME_INITRAMFS_SYMLINK}")

	if [ -z "${GK_FILENAME_INITRAMFS_SYMLINK}" ]
	then
		gen_die "Internal error: Variable 'GK_FILENAME_INITRAMFS_SYMLINK' is empty!"
	else
		print_info 5 "GK_FILENAME_INITRAMFS_SYMLINK set to '${GK_FILENAME_INITRAMFS_SYMLINK}' (was: '${INITRAMFS_SYMLINK_NAME}')"
	fi

	if [[ "${GK_FILENAME_INITRAMFS}" == "${GK_FILENAME_INITRAMFS_SYMLINK}" ]]
	then
		gen_die "--initramfs-filename cannot be identical with --initramfs-symlink-name!"
	fi

	# Make sure we have unique filenames
	if [[ "${GK_FILENAME_KERNEL}" == "${GK_FILENAME_INITRAMFS}" ]]
	then
		gen_die "--kernel-filename cannot be identical with --initramfs-filename!"
	elif [[ "${GK_FILENAME_KERNEL}" == "${GK_FILENAME_SYSTEMMAP}" ]]
	then
		gen_die "--kernel-filename cannot be identical with --systemmap-filename!"
	elif [[ "${GK_FILENAME_INITRAMFS}" == "${GK_FILENAME_SYSTEMMAP}" ]]
	then
		gen_die "--initramfs-filename cannot be identical with --systemmap-filename!"
	fi

	if [[ "${GK_FILENAME_KERNEL_SYMLINK}" == "${GK_FILENAME_INITRAMFS_SYMLINK}" ]]
	then
		gen_die "--kernel-symlink-name cannot be identical with --initramfs-symlink-name!"
	elif [[ "${GK_FILENAME_KERNEL_SYMLINK}" == "${GK_FILENAME_SYSTEMMAP_SYMLINK}" ]]
	then
		gen_die "--kernel-symlink-name cannot be identical with --systemmap-symlink-name!"
	elif [[ "${GK_FILENAME_INITRAMFS_SYMLINK}" == "${GK_FILENAME_SYSTEMMAP_SYMLINK}" ]]
	then
		gen_die "--initramfs-symlink-name cannot be identical with --systemmap-symlink-name!"
	fi

	local -a filename_vars
	filename_vars+=( 'GK_FILENAME_CONFIG;--kernel-config-filename' )
	filename_vars+=( 'GK_FILENAME_KERNEL;--kernel-filename' )
	filename_vars+=( 'GK_FILENAME_KERNEL_SYMLINK;--kernel-symlink-name' )
	filename_vars+=( 'GK_FILENAME_INITRAMFS;--initramfs-filename' )
	filename_vars+=( 'GK_FILENAME_INITRAMFS_SYMLINK;--initramfs-symlink-name' )
	filename_vars+=( 'GK_FILENAME_SYSTEMMAP;--systemmap-filename' )
	filename_vars+=( 'GK_FILENAME_SYSTEMMAP_SYMLINK;--systemmap-symlink-name' )

	local valid_filename_pattern='^[a-zA-Z0-9_.+-]{1,}$'
	local filename_combo filename_varname filename_option

	for filename_combo in "${filename_vars[@]}"
	do
		filename_combo=( ${filename_combo//;/ } )
		filename_varname=${filename_combo[0]}
		filename_option=${filename_combo[1]}

		if [[ ! "${!filename_varname}" =~ ${valid_filename_pattern} ]]
		then
			gen_die "${filename_varname} value '${!filename_varname}' does not match regex '${valid_filename_pattern}'. Check ${filename_option} option!"
		fi
	done
}

determine_real_args() {
	# Unset known variables which will interfere with _tc-getPROG().
	local tc_var tc_varname_build tc_vars=$(get_tc_vars)
	for tc_var in ${tc_vars} BROOT
	do
		tc_varname_build="BUILD_${tc_var}"
		unset ${tc_var} ${tc_varname_build}
	done
	unset tc_var tc_varname_build tc_vars

	if ! hash realpath &>/dev/null
	then
		gen_die "realpath not found. Is sys-apps/coreutils installed?"
	fi

	realpath -m / &>/dev/null
	if [ $? -ne 0 ]
	then
		gen_die "'realpath -m /' failed. We need a realpath version which supports '-m' mode!"
	fi

	if hash grep &>/dev/null
	then
		GREP_CMD=grep
	else
		gen_die "grep not found. Is sys-apps/grep installed?"
	fi

	if hash zgrep &>/dev/null
	then
		ZGREP_CMD=zgrep
	else
		print_warning 1 "zgrep not found. Is app-arch/gzip installed? You will be unable to use compressed config files!"
	fi

	print_info 4 "Resolving config file, command line, and arch default settings."

	#                               Dest / Config File                    Command Line                              Arch Default
	#                               ------------------                    ------------                              ------------
	set_config_with_override STRING TMPDIR                                CMD_TMPDIR                                "/var/tmp/genkernel"
	set_config_with_override STRING LOGFILE                               CMD_LOGFILE                               "/var/log/genkernel.conf"
	set_config_with_override STRING KERNEL_DIR                            CMD_KERNEL_DIR                            "${DEFAULT_KERNEL_SOURCE}"
	set_config_with_override STRING KERNEL_MODULES_PREFIX                 CMD_KERNEL_MODULES_PREFIX
	set_config_with_override BOOL   KERNEL_SOURCES                        CMD_KERNEL_SOURCES                        "yes"
	set_config_with_override STRING INITRAMFS_FILENAME                    CMD_INITRAMFS_FILENAME                    "${DEFAULT_INITRAMFS_FILENAME}"
	set_config_with_override STRING INITRAMFS_SYMLINK_NAME                CMD_INITRAMFS_SYMLINK_NAME                "${DEFAULT_INITRAMFS_SYMLINK_NAME}"
	set_config_with_override STRING KERNEL_CONFIG_FILENAME                CMD_KERNEL_CONFIG_FILENAME                "${DEFAULT_KERNEL_CONFIG_FILENAME}"
	set_config_with_override STRING KERNEL_FILENAME                       CMD_KERNEL_FILENAME                       "${DEFAULT_KERNEL_FILENAME}"
	set_config_with_override STRING KERNEL_SYMLINK_NAME                   CMD_KERNEL_SYMLINK_NAME                   "${DEFAULT_KERNEL_SYMLINK_NAME}"
	set_config_with_override STRING SYSTEMMAP_FILENAME                    CMD_SYSTEMMAP_FILENAME                    "${DEFAULT_SYSTEMMAP_FILENAME}"
	set_config_with_override STRING SYSTEMMAP_SYMLINK_NAME                CMD_SYSTEMMAP_SYMLINK_NAME                "${DEFAULT_SYSTEMMAP_SYMLINK_NAME}"

	set_config_with_override STRING CHECK_FREE_DISK_SPACE_BOOTDIR         CMD_CHECK_FREE_DISK_SPACE_BOOTDIR
	set_config_with_override STRING CHECK_FREE_DISK_SPACE_KERNELOUTPUTDIR CMD_CHECK_FREE_DISK_SPACE_KERNELOUTPUTDIR

	set_config_with_override STRING COMPRESS_INITRD                       CMD_COMPRESS_INITRD                       "${DEFAULT_COMPRESS_INITRD}"
	set_config_with_override STRING COMPRESS_INITRD_TYPE                  CMD_COMPRESS_INITRD_TYPE                  "${DEFAULT_COMPRESS_INITRD_TYPE}"
	set_config_with_override STRING CHOST                                 CMD_CHOST                                 "${DEFAULT_CHOST}"
	set_config_with_override STRING MAKEOPTS                              CMD_MAKEOPTS                              "${DEFAULT_MAKEOPTS}"
	set_config_with_override STRING NICE                                  CMD_NICE                                  "10"
	set_config_with_override STRING KERNEL_AS                             CMD_KERNEL_AS                             "${DEFAULT_KERNEL_AS}"
	set_config_with_override STRING KERNEL_AR                             CMD_KERNEL_AR                             "${DEFAULT_KERNEL_AR}"
	set_config_with_override STRING KERNEL_CC                             CMD_KERNEL_CC                             "${DEFAULT_KERNEL_CC}"
	set_config_with_override STRING KERNEL_CFLAGS                         CMD_KERNEL_CFLAGS                         "${DEFAULT_KERNEL_CFLAGS}"
	set_config_with_override STRING KERNEL_CXX                            CMD_KERNEL_CXX                            "${DEFAULT_KERNEL_CXX}"
	set_config_with_override STRING KERNEL_LD                             CMD_KERNEL_LD                             "${DEFAULT_KERNEL_LD}"
	set_config_with_override STRING KERNEL_NM                             CMD_KERNEL_NM                             "${DEFAULT_KERNEL_NM}"
	set_config_with_override STRING KERNEL_MAKE                           CMD_KERNEL_MAKE                           "${DEFAULT_KERNEL_MAKE}"
	set_config_with_override STRING KERNEL_OBJCOPY                        CMD_KERNEL_OBJCOPY                        "${DEFAULT_KERNEL_OBJCOPY}"
	set_config_with_override STRING KERNEL_OBJDUMP                        CMD_KERNEL_OBJDUMP                        "${DEFAULT_KERNEL_OBJDUMP}"
	set_config_with_override STRING KERNEL_RANLIB                         CMD_KERNEL_RANLIB                         "${DEFAULT_KERNEL_RANLIB}"
	set_config_with_override STRING KERNEL_READELF                        CMD_KERNEL_READELF                        "${DEFAULT_KERNEL_READELF}"
	set_config_with_override STRING KERNEL_STRIP                          CMD_KERNEL_STRIP                          "${DEFAULT_KERNEL_STRIP}"
	set_config_with_override STRING UTILS_AS                              CMD_UTILS_AS                              "${DEFAULT_UTILS_AS}"
	set_config_with_override STRING UTILS_AR                              CMD_UTILS_AR                              "${DEFAULT_UTILS_AR}"
	set_config_with_override STRING UTILS_CC                              CMD_UTILS_CC                              "${DEFAULT_UTILS_CC}"
	set_config_with_override STRING UTILS_CFLAGS                          CMD_UTILS_CFLAGS                          "${DEFAULT_UTILS_CFLAGS}"
	set_config_with_override STRING UTILS_CXX                             CMD_UTILS_CXX                             "${DEFAULT_UTILS_CXX}"
	set_config_with_override STRING UTILS_LD                              CMD_UTILS_LD                              "${DEFAULT_UTILS_LD}"
	set_config_with_override STRING UTILS_NM                              CMD_UTILS_NM                              "${DEFAULT_UTILS_NM}"
	set_config_with_override STRING UTILS_MAKE                            CMD_UTILS_MAKE                            "${DEFAULT_UTILS_MAKE}"
	set_config_with_override STRING UTILS_OBJCOPY                         CMD_UTILS_OBJCOPY                         "${DEFAULT_UTILS_OBJCOPY}"
	set_config_with_override STRING UTILS_OBJDUMP                         CMD_UTILS_OBJDUMP                         "${DEFAULT_UTILS_OBJDUMP}"
	set_config_with_override STRING UTILS_RANLIB                          CMD_UTILS_RANLIB                          "${DEFAULT_UTILS_RANLIB}"
	set_config_with_override STRING UTILS_READELF                         CMD_UTILS_READELF                         "${DEFAULT_UTILS_READELF}"
	set_config_with_override STRING UTILS_STRIP                           CMD_UTILS_STRIP                           "${DEFAULT_UTILS_STRIP}"

	set_config_with_override STRING CROSS_COMPILE                         CMD_CROSS_COMPILE
	set_config_with_override STRING BOOTDIR                               CMD_BOOTDIR                               "/boot"
	set_config_with_override STRING KERNEL_APPEND_LOCALVERSION            CMD_KERNEL_APPEND_LOCALVERSION
	set_config_with_override STRING KERNEL_LOCALVERSION                   CMD_KERNEL_LOCALVERSION                   "-%%ARCH%%"
	set_config_with_override STRING MODPROBEDIR                           CMD_MODPROBEDIR                           "/etc/modprobe.d"

	set_config_with_override BOOL   SPLASH                                CMD_SPLASH                                "no"
	set_config_with_override BOOL   CLEAR_CACHEDIR                        CMD_CLEAR_CACHEDIR                        "no"
	set_config_with_override BOOL   POSTCLEAR                             CMD_POSTCLEAR                             "no"
	set_config_with_override BOOL   MRPROPER                              CMD_MRPROPER                              "yes"
	set_config_with_override BOOL   MENUCONFIG                            CMD_MENUCONFIG                            "no"
	set_config_with_override BOOL   GCONFIG                               CMD_GCONFIG                               "no"
	set_config_with_override BOOL   NCONFIG                               CMD_NCONFIG                               "no"
	set_config_with_override BOOL   XCONFIG                               CMD_XCONFIG                               "no"
	set_config_with_override BOOL   CLEAN                                 CMD_CLEAN                                 "yes"

	set_config_with_override STRING MINKERNPACKAGE                        CMD_MINKERNPACKAGE
	set_config_with_override STRING MODULESPACKAGE                        CMD_MODULESPACKAGE
	set_config_with_override BOOL   MODULEREBUILD                         CMD_MODULEREBUILD                         "yes"
	set_config_with_override STRING MODULEREBUILD_CMD                     CMD_MODULEREBUILD_CMD                     "${DEFAULT_MODULEREBUILD_CMD}"
	set_config_with_override STRING KERNCACHE                             CMD_KERNCACHE
	set_config_with_override BOOL   RAMDISKMODULES                        CMD_RAMDISKMODULES                        "yes"
	set_config_with_override BOOL   ALLRAMDISKMODULES                     CMD_ALLRAMDISKMODULES                     "no"
	set_config_with_override STRING INITRAMFS_OVERLAY                     CMD_INITRAMFS_OVERLAY
	set_config_with_override STRING LINUXRC                               CMD_LINUXRC
	set_config_with_override BOOL   MOUNTBOOT                             CMD_MOUNTBOOT                             "yes"
	set_config_with_override BOOL   BUILD_STATIC                          CMD_STATIC                                "no"
	set_config_with_override BOOL   SAVE_CONFIG                           CMD_SAVE_CONFIG                           "yes"
	set_config_with_override BOOL   SYMLINK                               CMD_SYMLINK                               "no"
	set_config_with_override BOOL   OLDCONFIG                             CMD_OLDCONFIG                             "yes"
	set_config_with_override BOOL   SANDBOX                               CMD_SANDBOX                               "yes"
	set_config_with_override BOOL   SSH                                   CMD_SSH                                   "no"
	set_config_with_override STRING SSH_AUTHORIZED_KEYS_FILE              CMD_SSH_AUTHORIZED_KEYS_FILE              "/etc/dropbear/authorized_keys"
	set_config_with_override STRING SSH_HOST_KEYS                         CMD_SSH_HOST_KEYS                         "create"
	set_config_with_override BOOL   STRACE                                CMD_STRACE                                "no"
	set_config_with_override BOOL   BCACHE                                CMD_BCACHE                                "no"
	set_config_with_override BOOL   LVM                                   CMD_LVM                                   "no"
	set_config_with_override BOOL   DMRAID                                CMD_DMRAID                                "no"
	set_config_with_override BOOL   ISCSI                                 CMD_ISCSI                                 "no"
	set_config_with_override BOOL   HYPERV                                CMD_HYPERV                                "no"
	set_config_with_override STRING BOOTFONT                              CMD_BOOTFONT                              "none"
	set_config_with_override STRING BOOTLOADER                            CMD_BOOTLOADER                            "no"
	set_config_with_override BOOL   B2SUM                                 CMD_B2SUM                                 "no"
	set_config_with_override BOOL   BUSYBOX                               CMD_BUSYBOX                               "yes"
	set_config_with_override STRING BUSYBOX_CONFIG                        CMD_BUSYBOX_CONFIG
	set_config_with_override BOOL   NFS                                   CMD_NFS                                   "yes"
	set_config_with_override STRING MICROCODE                             CMD_MICROCODE                             "all"
	set_config_with_override BOOL   MICROCODE_INITRAMFS                   CMD_MICROCODE_INITRAMFS                   "no"
	set_config_with_override BOOL   UNIONFS                               CMD_UNIONFS                               "no"
	set_config_with_override BOOL   NETBOOT                               CMD_NETBOOT                               "no"
	set_config_with_override STRING REAL_ROOT                             CMD_REAL_ROOT
	set_config_with_override BOOL   LUKS                                  CMD_LUKS                                  "no"
	set_config_with_override BOOL   GPG                                   CMD_GPG                                   "no"
	set_config_with_override BOOL   MDADM                                 CMD_MDADM                                 "no"
	set_config_with_override STRING MDADM_CONFIG                          CMD_MDADM_CONFIG
	set_config_with_override BOOL   E2FSPROGS                             CMD_E2FSPROGS                             "no"
	set_config_with_override BOOL   XFSPROGS                              CMD_XFSPROGS                              "no"
	set_config_with_override BOOL   ZFS                                   CMD_ZFS                                   "$(rootfs_type_is zfs)"
	set_config_with_override BOOL   BTRFS                                 CMD_BTRFS                                 "$(rootfs_type_is btrfs)"
	set_config_with_override BOOL   VIRTIO                                CMD_VIRTIO                                "no"
	set_config_with_override BOOL   MULTIPATH                             CMD_MULTIPATH                             "no"
	set_config_with_override BOOL   FIRMWARE                              CMD_FIRMWARE                              "no"
	set_config_with_override STRING FIRMWARE_DIR                          CMD_FIRMWARE_DIR                          "/lib/firmware"
	set_config_with_override STRING FIRMWARE_FILES                        CMD_FIRMWARE_FILES
	set_config_with_override BOOL   FIRMWARE_INSTALL                      CMD_FIRMWARE_INSTALL                      "no"
	set_config_with_override BOOL   INTEGRATED_INITRAMFS                  CMD_INTEGRATED_INITRAMFS                  "no"
	set_config_with_override BOOL   WRAP_INITRD                           CMD_WRAP_INITRD                           "no"
	set_config_with_override BOOL   GENZIMAGE                             CMD_GENZIMAGE                             "no"
	set_config_with_override BOOL   KEYMAP                                CMD_KEYMAP                                "yes"
	set_config_with_override BOOL   DOKEYMAPAUTO                          CMD_DOKEYMAPAUTO                          "no"
	set_config_with_override STRING STRIP_TYPE                            CMD_STRIP_TYPE                            "modules"
	set_config_with_override BOOL   INSTALL                               CMD_INSTALL                               "yes"
	set_config_with_override BOOL   CLEANUP                               CMD_CLEANUP                               "yes"

	# Special case:  If --no-clean is specified on the command line,
	# imply --no-mrproper.
	if ! isTrue "${CLEAN}"
	then
		if isTrue "${MRPROPER}"
		then
			print_info 5 "  MRPROPER forced to \"no\" due to --no-clean."
			MRPROPER="no"
		fi
	fi

	# We need to expand and normalize provided $KERNEL_DIR and
	# we need to do it early because $KERNEL_OUTPUTDIR will be
	# set to $KERNEL_DIR by default.
	KERNEL_DIR=$(cd -L "${CMD_KERNEL_DIR}" &>/dev/null && pwd -L 2>/dev/null)
	if [ -z "${KERNEL_DIR}" ]
	then
		# We tried to use cd first to keep symlinks (i.e. to preserve
		# a path like /usr/src/linux) which probably failed
		# because $KERNEL_DIR does NOT exist. However, at this stage
		# we don't know if $KERNEL_DIR is required so we have to
		# accept an invalid value...
		KERNEL_DIR=$(expand_file "${CMD_KERNEL_DIR}" 2>/dev/null)
	fi

	if [[ "${KERNEL_DIR}" != "${CMD_KERNEL_DIR}" ]]
	then
		print_info 5 "  KERNEL_DIR value \"${CMD_KERNEL_DIR}\" normalized to \"${KERNEL_DIR}\""
	fi

	# Now that $KERNEL_DIR value is expanded and normalized we can
	# initialize $KERNEL_OUTPUTDIR...
	set_config_with_override STRING KERNEL_OUTPUTDIR CMD_KERNEL_OUTPUTDIR "${KERNEL_DIR}"

	LOGFILE=$(expand_file "${CMD_LOGFILE}" 2>/dev/null)
	if [ -z "${LOGFILE}" ]
	then
		small_die "Failed to expand --logfile value '${CMD_LOGFILE}'!"
	fi

	local can_write_log=no
	if [ -w "${LOGFILE}" ]
	then
		can_write_log=yes
	elif [ -w "$(dirname "${LOGFILE}")" ]
	then
		can_write_log=yes
	fi

	if ! isTrue "${can_write_log}"
	then
		small_die "Cannot write to '${LOGFILE}'!"
	fi

	echo ">>> Started genkernel v${GK_V} on: $(date +"%Y-%m-%d %H:%M:%S")" > "${LOGFILE}" 2>/dev/null || small_die "Could not write to '${LOGFILE}'!"

	dump_debugcache

	TMPDIR=$(expand_file "${CMD_TMPDIR}" 2>/dev/null)
	if [ -z "${TMPDIR}" ]
	then
		gen_die "Failed to expand --tmpdir value '${CMD_TMPDIR}'!"
	fi

	if isTrue "$(has_space_characters "${TMPDIR}")"
	then
		# Packages like util-linux will fail to compile when path to
		# build dir contains spaces
		gen_die "--tmpdir '${TMPDIR}' contains space character(s) which are not supported!"
	fi

	if [ ! -d "${TMPDIR}" ]
	then
		mkdir -p "${TMPDIR}" || gen_die "Failed to create '${TMPDIR}'!"
	fi

	declare -gr TEMP=$(mktemp -d -p "${TMPDIR}" gk_XXXXXXXX 2>/dev/null)
	[ -z "${TEMP}" ] && gen_die "'mktemp -d -p \"${TMPDIR}\" gk_XXXXXXXX' failed!"

	if ! isTrue "${CLEANUP}"
	then
		local no_cleanup_marker="${TEMP}/.no_cleanup"
		print_info 5 "Creating no cleanup marker '${no_cleanup_marker}' ..."
		touch "${no_cleanup_marker}" || gen_die "Failed to create '${no_cleanup_marker}'!"
	fi

	declare -gr GK_V_CACHEDIR="${CACHE_DIR}/${GK_V}"

	declare -gr KCONFIG_MODIFIED_MARKER="${TEMP}/.kconfig_modified"

	declare -gr KCONFIG_REQUIRED_OPTIONS="${TEMP}/.kconfig_required_options"

	if [ -n "${CMD_CROSS_COMPILE}" ]
	then
		if ! isTrue "$(is_valid_triplet "${CMD_CROSS_COMPILE}")"
		then
			gen_die "--cross-compile value '${CMD_CROSS_COMPILE}' does NOT represent a valid triplet!"
		fi

		ARCH=${CMD_CROSS_COMPILE%%-*}
		case "${ARCH}" in
			aarch64*)
				ARCH="arm64"
				;;
			arm*)
				ARCH="arm"
				;;
			hppa64*)
				ARCH="parisc64"
				;;
			hppa*)
				ARCH="parisc"
				;;
			i386)
				ARCH="ia32"
				;;
			i486)
				ARCH="x86"
				;;
			i586)
				ARCH="x86"
				;;
			i686)
				ARCH="x86"
				;;
			mips|mips64*)
				ARCH="mips"
				;;
			powerpc)
				ARCH="ppc"
				;;
			powerpc64)
				ARCH="ppc64"
				;;
			powerpc64le)
				ARCH="ppc64le"
				;;
			*)
				;;
		esac

		print_info 2 "ARCH forced to '${ARCH}' ..."
	else
		ARCH=$(uname -m)
		if [ -z "${ARCH}" ]
		then
			gen_die "Was unable to determine machine hardware name using 'uname -m'!"
		else
			print_info 5 "Read '${ARCH}' from 'uname -m' ..."
		fi

		case "${ARCH}" in
			aarch64*)
				ARCH="arm64"
				;;
			arm*)
				ARCH="arm"
				;;
			i?86)
				ARCH="x86"
				;;
			mips|mips64*)
				ARCH="mips"
				;;
			*)
				;;
		esac

		print_info 2 "ARCH '${ARCH}' detected ..."
	fi

	ARCH_CONFIG="${GK_SHARE}/arch/${ARCH}/config.sh"
	[ -f "${ARCH_CONFIG}" ] || gen_die "${ARCH} not yet supported by genkernel. Please add the arch-specific config file '${ARCH_CONFIG}'!"

	# Set CBUILD and CHOST
	if ! isTrue "$(is_valid_triplet "${CHOST}")"
	then
		gen_die "Set CHOST '${CHOST}' does NOT represent a valid triplet!"
	else
		# Initialize CBUILD with CHOST value
		CBUILD=${CHOST}
		print_info 5 "CBUILD set to '${CBUILD}' ..."
	fi

	if [ -n "${CMD_CROSS_COMPILE}" ]
	then
		CHOST="${CMD_CROSS_COMPILE}"
	fi

	print_info 5 "CHOST set to '${CHOST}' ..."

	# Initialize variables
	BOOTDIR=$(arch_replace "${BOOTDIR}")
	BOOTDIR=${BOOTDIR%/}    # Remove any trailing slash
	MODPROBEDIR=${MODPROBEDIR%/}    # Remove any trailing slash

	local -a pkg_prefixes=()
	local -a vars_to_initialize=()
	vars_to_initialize+=( "CACHE_DIR" )
	vars_to_initialize+=( "BUSYBOX_CONFIG" )
	vars_to_initialize+=( "DEFAULT_KERNEL_CONFIG" )

	local binpkgs=( $(compgen -A variable | grep '^GKPKG_.*_BINPKG$') )
	local binpkg
	for binpkg in "${binpkgs[@]}"
	do
		pkg_prefixes+=( "${binpkg%_BINPKG}" )
		vars_to_initialize+=( "${binpkg}" )
	done
	unset binpkg binpkgs

	local v=
	for v in "${vars_to_initialize[@]}"
	do
		eval "$v='$(arch_replace "${!v}")'"
		eval "$v='$(cache_replace "${!v}")'"
	done
	unset v vars_to_initialize

	declare -gA GKPKG_LOOKUP_TABLE=()
	local pn_varname= pn=
	for v in "${pkg_prefixes[@]}"
	do
		pn_varname="${v}_PN"
		pn=${!pn_varname}

		GKPKG_LOOKUP_TABLE[${pn}]=${v}
	done
	unset v pn pn_varname pkg_prefixes

	declare -gA GKICM_LOOKUP_TABLE_CMD=()
	declare -gA GKICM_LOOKUP_TABLE_EXT=()
	declare -gA GKICM_LOOKUP_TABLE_PKG=()
	local known_initramfs_compression_methods_by_compression=( $(get_initramfs_compression_method_by_compression) )
	local known_initramfs_compression_methods_by_speed=( $(get_initramfs_compression_method_by_speed) )
	local initramfs_compression_methods=( $(compgen -A variable | grep '^GKICM_.*_KOPTNAME$') )
	local initramfs_compression_method key var_name var_prefix
	for initramfs_compression_method in "${initramfs_compression_methods[@]}"
	do
		if [ -z "${!initramfs_compression_method}" ]
		then
			gen_die "Invalid config found: Check value of '${initramfs_compression_method}'!"
		fi

		if [[ "${known_initramfs_compression_methods_by_compression[@]} " != *"${!initramfs_compression_method}"* ]]
		then
			gen_die "Internal error: Initramfs compression method '${!initramfs_compression_method}' was not added to get_initramfs_compression_method_by_compression()!"
		else
			known_initramfs_compression_methods_by_compression=( $(printf '%s\n' "${known_initramfs_compression_methods_by_compression[@]//${!initramfs_compression_method}/}") )
		fi

		if [[ "${known_initramfs_compression_methods_by_speed[@]} " != *"${!initramfs_compression_method}"* ]]
		then
			gen_die "Internal error: Initramfs compression method '${!initramfs_compression_method}' was not added to get_initramfs_compression_method_by_speed()!"
		else
			known_initramfs_compression_methods_by_speed=( $(printf '%s\n' "${known_initramfs_compression_methods_by_speed[@]//${!initramfs_compression_method}/}") )
		fi

		var_prefix="${initramfs_compression_method%_KOPTNAME}"

		for key in CMD EXT PKG
		do
			var_name="${var_prefix}_${key}"
			if [ -z "${!var_name}" ]
			then
				gen_die "Internal error: Variable '${var_name}' is not set!"
			fi

			case ${key} in
				CMD)
					GKICM_LOOKUP_TABLE_CMD[${!initramfs_compression_method}]="${!var_name}"
					;;
				EXT)
					GKICM_LOOKUP_TABLE_EXT[${!initramfs_compression_method}]="${!var_name}"
					;;
				PKG)
					GKICM_LOOKUP_TABLE_PKG[${!initramfs_compression_method}]="${!var_name}"
					;;
			esac
		done
	done
	unset initramfs_compression_methods initramfs_compression_method key var_name var_prefix

	# It is enough to check just one data set because we validated
	# both data sets above.
	if [[ ${#known_initramfs_compression_methods_by_compression[@]} -gt 0 ]]
	then
		local unhandled_method
		for unhandled_method in "${known_initramfs_compression_methods_by_compression[@]}"
		do
			print_error 1 "Do not know how to handle initramfs compression type '${unhandled_method}'!"
		done

		gen_die "Internal error: Not all known initramfs compression methods are defined!"
	fi
	unset known_initramfs_compression_methods_by_compression known_initramfs_compression_methods_by_speed

	if [ -n "${CMD_BOOTLOADER}" ]
	then
		BOOTLOADER="${CMD_BOOTLOADER}"
		if [ "${CMD_BOOTLOADER}" != "${CMD_BOOTLOADER/:/}" ]
		then
			BOOTFS=$(echo "${CMD_BOOTLOADER}" | cut -f2- -d:)
			BOOTLOADER=$(echo "${CMD_BOOTLOADER}" | cut -f1 -d:)
		fi
	fi

	case "${BOOTLOADER}" in
		no|grub|grub2)
			;;
		*)
			gen_die "Invalid bootloader '${BOOTLOADER}'; --bootloader=<bootloader> requires one of: no, grub, grub2"
			;;
	esac

	if isTrue "${KERNEL_SOURCES}"
	then
		if [ ! -d "${KERNEL_DIR}" ]
		then
			gen_die "kernel source directory \"${KERNEL_DIR}\" was not found!"
		fi
	fi

	if [ -z "${KERNCACHE}" ]
	then
		if [ "${KERNEL_DIR}" = '' ] && isTrue "${KERNEL_SOURCES}"
		then
			gen_die 'No kernel source directory!'
		fi
		if [ ! -e "${KERNEL_DIR}" ] && isTrue "${KERNEL_SOURCES}"
		then
			gen_die 'No kernel source directory!'
		fi
	else
		if [ "${KERNEL_DIR}" = '' ]
		then
			gen_die 'Kernel Cache specified but no kernel tree to verify against!'
		fi
	fi

	local need_tar=no

	if [ -n "${MINKERNPACKAGE}" ]
	then
		MINKERNPACKAGE=$(expand_file "${CMD_MINKERNPACKAGE}")
		if [[ -z "${MINKERNPACKAGE}" || "${MINKERNPACKAGE}" != *.tar* ]]
		then
			gen_die "--minkernpackage value '${CMD_MINKERNPACKAGE}' is invalid!"
		fi

		local minkernpackage_dir=$(dirname "${MINKERNPACKAGE}")
		if [ ! -d "${minkernpackage_dir}" ]
		then
			mkdir -p "${minkernpackage_dir}" \
				|| gen_die "Failed to create '${minkernpackage_dir}'!"
		fi

		need_tar=yes
	fi

	if [ -n "${MODULESPACKAGE}" ]
	then
		MODULESPACKAGE=$(expand_file "${CMD_MODULESPACKAGE}")
		if [[ -z "${MODULESPACKAGE}" || "${MODULESPACKAGE}" != *.tar* ]]
		then
			gen_die "--modulespackage value '${CMD_MODULESPACKAGE}' is invalid!"
		fi

		local modulespackage_dir=$(dirname "${MODULESPACKAGE}")
		if [ ! -d "${modulespackage_dir}" ]
		then
			mkdir -p "${modulespackage_dir}" \
				|| gen_die "Failed to create '${modulespackage_dir}'!"
		fi

		need_tar=yes
	fi

	if [ -n "${KERNCACHE}" ]
	then
		KERNCACHE=$(expand_file "${CMD_KERNCACHE}")
		if [[ -z "${KERNCACHE}" || "${KERNCACHE}" != *.tar* ]]
		then
			gen_die "--kerncache value '${CMD_KERNCACHE}' is invalid!"
		fi

		local kerncache_dir=$(dirname "${KERNCACHE}")
		if [ ! -d "${kerncache_dir}" ]
		then
			mkdir -p "${kerncache_dir}" \
				|| gen_die "Failed to create '${kerncache_dir}'!"
		fi

		need_tar=yes
	fi

	# We always need to populate KERNEL_LOCALVERSION to be able to warn
	# if user changed value but didn't rebuild kernel
	local valid_localversion_pattern='^[A-Za-z0-9_.+-]{1,}$'

	if [ -n "${KERNEL_LOCALVERSION}" ]
	then
		case "${KERNEL_LOCALVERSION}" in
			UNSET)
				;;
			*)
				KERNEL_LOCALVERSION=$(arch_replace "${KERNEL_LOCALVERSION}")
				if [ -z "${KERNEL_LOCALVERSION}" ]
				then
					# We somehow lost value...
					gen_die "Internal error: Variable 'KERNEL_LOCALVERSION' is empty!"
				fi

				if [[ ! "${KERNEL_LOCALVERSION}" =~ ${valid_localversion_pattern} ]]
				then
					gen_die "--kernel-localversion value '${KERNEL_LOCALVERSION}' does not match '${valid_localversion_pattern}' regex!"
				fi
				;;
		esac
	fi

	if [ -n "${KERNEL_APPEND_LOCALVERSION}" ]
	then
		if [[ ! "${KERNEL_APPEND_LOCALVERSION}" =~ ${valid_localversion_pattern} ]]
		then
			gen_die "--kernel-append-localversion value '${KERNEL_APPEND_LOCALVERSION}' does not match '${valid_localversion_pattern}' regex!"
		fi

		if [[ "${KERNEL_LOCALVERSION}" == "UNSET" ]]
		then
			gen_die "Cannot append '${KERNEL_APPEND_LOCALVERSION}' to KERNEL_LOCALVERSION you want to unset!"
		else
			KERNEL_LOCALVERSION+="${KERNEL_APPEND_LOCALVERSION}"
		fi
	fi

	if isTrue "${BUILD_KERNEL}"
	then
		case "${CMD_STRIP_TYPE}" in
			all|kernel|modules|none)
				;;
			*)
				gen_die "Invalid strip type '${CMD_STRIP_TYPE}'; --strip=<type> requires one of: all, kernel, modules, none"
				;;
		esac

		if [[ "${KERNEL_DIR}" != "${KERNEL_OUTPUTDIR}" ]]
		then
			if [ -z "${KERNEL_OUTPUTDIR}" ]
			then
				gen_die "No --kernel-outputdir specified!"
			fi

			KERNEL_OUTPUTDIR=$(expand_file "${KERNEL_OUTPUTDIR}")
			if [ -z "${KERNEL_OUTPUTDIR}" ]
			then
				gen_die "Failed to expand set --kernel-outputdir '${CMD_KERNEL_OUTPUTDIR}'!"
			fi

			if [[ "${KERNEL_OUTPUTDIR}" != "${CMD_KERNEL_OUTPUTDIR}" ]]
			then
				print_info 5 "KERNEL_OUTPUTDIR value '${CMD_KERNEL_OUTPUTDIR}' normalized to '${KERNEL_OUTPUTDIR}'"
			fi

			if [ ! -d "${KERNEL_OUTPUTDIR}" ]
			then
				print_warning 3 "Set --kernel-outputdir '${KERNEL_OUTPUTDIR}' does not exist; Will try to create ..."
				mkdir -p "${KERNEL_OUTPUTDIR}" || gen_die "Failed to create '${KERNEL_OUTPUTDIR}'!"
			fi
		fi

		if isTrue "$(has_space_characters "${KERNEL_OUTPUTDIR}")"
		then
			# Kernel Makefile doesn't support spaces in outputdir path...
			gen_die "--kernel-outputdir '${KERNEL_OUTPUTDIR}' contains space character(s) which are not supported!"
		fi

		if isTrue "${CMD_MODULEREBUILD}"
		then
			if [ -z "${MODULEREBUILD_CMD}" ]
			then
				gen_die "--module-rebuild-cmd cannot be empty when --module-rebuild is set!"
			elif [[ "${MODULEREBUILD_CMD}" == *[\$\&\|\>\(\)]* ]]
			then
				gen_die "--module-rebuild-cmd '${MODULEREBUILD_CMD}' contains at least one of the following disallowed characters: '\$&|>()'!"
			fi
		fi

		if isTrue "${SAVE_CONFIG}"
		then
			local kconf_savedir=/etc/kernels
			if [ ! -d "${kconf_savedir}" ]
			then
				kconf_savedir=/etc
				[ ! -d "${kconf_savedir}" ] && kconf_savedir=/
			fi

			if [ ! -w "${kconf_savedir}" ]
			then
				gen_die "Cannot write to '${kconf_savedir}' but --save-config is set!"
			fi
		fi
	fi

	if isTrue "${BUILD_RAMDISK}"
	then
		# Internal module group to get modules used in genkernel features
		# into initramfs.
		GK_INITRAMFS_ADDITIONAL_KMODULES=""

		if [[ "${CMD_BOOTFONT}" != "none" ]]
		then
			if [[ "${CMD_BOOTFONT}" == "current" ]]
			then
				SETFONT_COMMAND="$(which setfont 2>/dev/null)"
				if [ -z "${SETFONT_COMMAND}" ]
				then
					gen_die "setfont not found. Is sys-apps/kbd installed?"
				fi

				"${SETFONT_COMMAND}" -O /dev/null 2>/dev/null
				if [ $? -ne 0 ]
				then
					if [ ${UID} -eq 0 ]
					then
						gen_die "'${SETFONT_COMMAND}' cannot read from console. You cannot use --boot-font=current!"
					else
						gen_die "'${SETFONT_COMMAND}' cannot read from console. You probably need root permission or cannot use --boot-font=current!"
					fi
				fi
			else
				local bootfont_file=$(expand_file "${BOOTFONT}")
				if [ -z "${bootfont_file}" ]
				then
					gen_die "--boot-file value '${BOOTFONT}' failed to expand!"
				elif [ ! -e "${bootfont_file}" ]
				then
					gen_die "--boot-file file '${bootfont_file}' does not exist!"
				elif ! isTrue $(is_psf_file "${bootfont_file}")
				then
					gen_die "--boot-font file '${bootfont_file}' is not a valid PC Screen Font (PSF)!"
				else
					BOOTFONT="${bootfont_file}"
				fi
			fi
		fi

		if isTrue "${CMD_DOKEYMAPAUTO}" && ! isTrue "${CMD_KEYMAP}"
		then
			gen_die "--do-keymap-auto requires --keymap but --no-keymap is set!"
		fi

		if isTrue "${MULTIPATH}" && ! isTrue "${LVM}"
		then
			gen_die "--multipath requires --lvm but --no-lvm is set!"
		fi

		if isTrue "${SPLASH}"
		then
			if ! hash splash_geninitramfs &>/dev/null
			then
				gen_die "splash_geninitramfs is required for --splash but was not found!"
			fi
		fi

		if isTrue "${SSH}"
		then
			local ssh_authorized_keys_file=$(expand_file "${SSH_AUTHORIZED_KEYS_FILE}")
			if [ -z "${ssh_authorized_keys_file}" ]
			then
				gen_die "--ssh-authorized-keys value '${SSH_AUTHORIZED_KEYS_FILE}' failed to expand!"
			elif [ ! -e "${ssh_authorized_keys_file}" ]
			then
				gen_die "authorized_keys file '${ssh_authorized_keys_file}' does not exist!"
			elif ! grep -qE '^(ecdsa|ssh)-' "${ssh_authorized_keys_file}" &>/dev/null
			then
				gen_die "authorized_keys file '${ssh_authorized_keys_file}' does not look like a valid authorized_keys file: File does not contain any entry matching regular expression '^(ecdsa|ssh)-'!"
			else
				declare -gr DROPBEAR_AUTHORIZED_KEYS_FILE="${ssh_authorized_keys_file}"
			fi
		fi

		if isTrue "${BCACHE}"
		then
			GK_INITRAMFS_ADDITIONAL_KMODULES+=" bcache"
		fi

		if isTrue "${ZFS}"
		then
			if isTrue "$(tc-is-cross-compiler)"
			then
				local error_msg="Using binpkg for ZFS is not supported."
				error_msg+=" Therefore we cannot cross-compile like requested!"
				gen_die "${error_msg}"
			fi

			if [ ! -x "/sbin/zfs" ]
			then
				local error_msg="'/sbin/zfs' is required for --zfs but file does not exist or is not executable!"
				error_msg+=" Is sys-fs/zfs installed?"
				gen_die "${error_msg}"
			fi
		fi

		if isTrue "${MULTIPATH}"
		then
			if isTrue "$(tc-is-cross-compiler)"
			then
				local error_msg="Using binpkg for multipath-tools is not supported."
				error_msg+=" Therefore we cannot cross-compile like requested!"
				gen_die "${error_msg}"
			fi

			if [ ! -x "/sbin/multipath" ]
			then
				local error_msg="'/sbin/multipath' is required for --multipath but file does not exist or is not executable!"
				error_msg+=" Is sys-fs/multipath-tools installed?"
				gen_die "${error_msg}"
			fi

			if [ ! -x "/lib/udev/scsi_id" ]
			then
				local error_msg="'/lib/udev/scsi_id' is required for --multipath but file does not exist or is not executable!"
				error_msg+=" This file is usually provided by sys-fs/{eudev,udev} or sys-apps/systemd!"
				gen_die "${error_msg}"
			fi

			if [ ! -e "/etc/multipath.conf" ]
			then
				gen_die "'/etc/multipath.conf' is required for --multipath but file does not exist!"
			elif [[ -d "/etc/multipath.conf" || ! -s "/etc/multipath.conf" ]]
			then
				gen_die "'/etc/multipath.conf' is required for --multipath but it is either not a file or is empty!"
			fi
		fi

		if ! isTrue "${BUSYBOX}"
		then
			local -a FEATURES_REQUIRING_BUSYBOX
			FEATURES_REQUIRING_BUSYBOX+=( BTRFS )
			FEATURES_REQUIRING_BUSYBOX+=( DMRAID )
			FEATURES_REQUIRING_BUSYBOX+=( ISCSI )
			FEATURES_REQUIRING_BUSYBOX+=( KEYMAP )
			FEATURES_REQUIRING_BUSYBOX+=( LVM )
			FEATURES_REQUIRING_BUSYBOX+=( LUKS )
			FEATURES_REQUIRING_BUSYBOX+=( MDADM )
			FEATURES_REQUIRING_BUSYBOX+=( MULTIPATH )
			FEATURES_REQUIRING_BUSYBOX+=( SPLASH )
			FEATURES_REQUIRING_BUSYBOX+=( SSH )
			FEATURES_REQUIRING_BUSYBOX+=( ZFS )

			local FEATURE_REQUIRING_BUSYBOX
			for FEATURE_REQUIRING_BUSYBOX in "${FEATURES_REQUIRING_BUSYBOX[@]}"
			do
				if isTrue "${!FEATURE_REQUIRING_BUSYBOX}"
				then
					gen_die "--no-busybox set but --${FEATURE_REQUIRING_BUSYBOX,,} requires --busybox!"
				fi
			done
			unset FEATURE_REQUIRING_BUSYBOX FEATURES_REQUIRING_BUSYBOX
		elif [ -n "${CMD_BUSYBOX_CONFIG}" ]
		then
			local BUSYBOX_CONFIG=$(expand_file "${CMD_BUSYBOX_CONFIG}")
			if [ -z "${BUSYBOX_CONFIG}" ]
			then
				gen_die "--busybox-config value '${CMD_BUSYBOX_CONFIG}' failed to expand!"
			elif [ ! -e "${BUSYBOX_CONFIG}" ]
			then
				gen_die "--busybox-config file '${BUSYBOX_CONFIG}' does not exist!"
			fi

			if ! grep -qE '^CONFIG_.*=' "${BUSYBOX_CONFIG}" &>/dev/null
			then
				gen_die "--busybox-config file '${BUSYBOX_CONFIG}' does not look like a valid busybox config: File does not contain any CONFIG_* value!"
			elif ! grep -qE '^CONFIG_STATIC=y$' "${BUSYBOX_CONFIG}" &>/dev/null
			then
				# We cannot check all required options but check at least for CONFIG_STATIC...
				gen_die "--busybox-config file '${BUSYBOX_CONFIG}' does not contain CONFIG_STATIC=y. This busybox config will not work with genkernel!"
			fi
		fi

		DU_COMMAND="$(which du 2>/dev/null)"

		LDDTREE_COMMAND="$(which lddtree 2>/dev/null)"
		if [ -z "${LDDTREE_COMMAND}" ]
		then
			gen_die "lddtree not found. Is app-misc/pax-utils installed?"
		fi

		CPIO_COMMAND="$(which cpio 2>/dev/null)"
		if [[ -z "${CPIO_COMMAND}" ]]
		then
			# This will be fatal because we cpio either way
			gen_die "cpio binary not found. Is app-arch/cpio installed?"
		elif ! "${LDDTREE_COMMAND}" -l "${CPIO_COMMAND}" &>/dev/null
		then
			# This is typically the case when app-misc/pax-utils[python] is used
			# and selected Python version isn't supported by pax-utils or
			# dev-python/pyelftools yet, #618056.
			gen_die "'\"${LDDTREE_COMMAND}\" -l \"${CPIO_COMMAND}\"' failed -- cannot generate initramfs without working lddtree!"
		fi

		if isTrue "${COMPRESS_INITRD}"
		then
			local pattern_auto='^(BEST|FASTEST)$'
			local pattern_manual="$(get_initramfs_compression_method_by_speed)"
			pattern_manual=${pattern_manual// /|}
			pattern_manual="^(${pattern_manual})$"

			if [[ "${COMPRESS_INITRD_TYPE^^}" =~ ${pattern_auto} ]]
			then
				# Will be handled in set_initramfs_compression_method()
				:;
			elif [[ ! "${COMPRESS_INITRD_TYPE^^}" =~ ${pattern_manual} ]]
			then
				gen_die "Specified --compress-initramfs-type '${COMPRESS_INITRD_TYPE}' is unknown"
			elif ! hash ${GKICM_LOOKUP_TABLE_CMD[${COMPRESS_INITRD_TYPE^^}]/%\ */} &>/dev/null
			then
				gen_die "'${GKICM_LOOKUP_TABLE_CMD[${COMPRESS_INITRD_TYPE^^}]/%\ */}', the tool to compress initramfs based on selected --compress-initramfs-type was not found. Is ${GKICM_LOOKUP_TABLE_PKG[${COMPRESS_INITRD_TYPE^^}]} installed?"
			fi
			unset pattern_auto pattern_manual

			# Ensure that value matches keys in GKICM_* arrays
			COMPRESS_INITRD_TYPE=${COMPRESS_INITRD_TYPE^^}
		fi

		SANDBOX_COMMAND=
		if isTrue "${SANDBOX}"
		then
			if [[ "${SANDBOX_ON}" == "1" ]]
			then
				gen_die "SANDBOX_ON=1 detected -- You cannot use --sandbox when already running within a sandbox!"
			fi

			SANDBOX_COMMAND="$(which sandbox 2>/dev/null)"
			if [ -z "${SANDBOX_COMMAND}" ]
			then
				gen_die "Sandbox not found. Is sys-apps/sandbox installed?"
			fi
		fi

		if [ -n "${LINUXRC}" ]
		then
			LINUXRC=$(expand_file "${CMD_LINUXRC}" 2>/dev/null)
			if [ -z "${LINUXRC}" ]
			then
				gen_die "--linuxrc value '${CMD_LINUXRC}' failed to expand!"
			elif [ ! -e "${LINUXRC}" ]
			then
				gen_die "--linuxrc file '${LINUXRC}' does not exist!"
			fi
		fi

		need_tar=yes
	fi

	if isTrue "${need_tar}"
	then
		TAR_COMMAND="$(which tar 2>/dev/null)"
		if [ -z "${TAR_COMMAND}" ]
		then
			gen_die "tar not found. Is app-arch/tar installed?"
		fi
	fi

	if isTrue "${INTEGRATED_INITRAMFS}"
	then
		if  ! isTrue "${BUILD_KERNEL}" || ! isTrue "${BUILD_RAMDISK}"
		then
			gen_die "Invalid action specified: --integrated-initramfs option requires action \"all\", i.e. building of kernel and initramfs at the same time!"
		fi
	fi

	if ! isTrue "${CMD_INSTALL}"
	then
		if [ -n "${KERNEL_MODULES_PREFIX}" ]
		then
			print_warning 1 '--no-install is set; Ignoring --kernel-modules-prefix ...'
		fi

		# User does not want that anything will get installed
		# so install modules into our temporary directory instead.
		KERNEL_MODULES_PREFIX="${TEMP}/mod_prefix"
	elif [ -n "${KERNEL_MODULES_PREFIX}" ]
	then
		KERNEL_MODULES_PREFIX=$(expand_file "${CMD_KERNEL_MODULES_PREFIX}")
		if [ -z "${KERNEL_MODULES_PREFIX}" ]
		then
			gen_die "Failed to expand set --kernel-modules-prefix '${CMD_KERNEL_MODULES_PREFIX}'!"
		fi

		if [ ! -d "${KERNEL_MODULES_PREFIX}" ]
		then
			print_warning 3 "Set --kernel-modules-prefix '${KERNEL_MODULES_PREFIX}' does not exist; Will try to create ..."
			mkdir -p "${KERNEL_MODULES_PREFIX}" || gen_die "Failed to create '${KERNEL_MODULES_PREFIX}'!"
		fi
	fi

	MICROCODE=${MICROCODE,,}
	case "${MICROCODE}" in
		all|amd|intel) ;;
		y|yes|1|true|t) MICROCODE='all' ;;
		n|no|none|0|false|f) MICROCODE='' ;;
		*) gen_die "Invalid microcode '${MICROCODE}'; --microcode=<type> requires one of: no, all, intel, amd" ;;
	esac

	if isTrue "${BUILD_RAMDISK}"  && isTrue "${MICROCODE_INITRAMFS}" && [[ -z "${MICROCODE}" ]]
	then
		print_warning 1 '--microcode=no implies --no-microcode-initramfs; Will not add any microcode to initramfs ...'
		print_warning 1 '' 1 0
		MICROCODE_INITRAMFS=no
	fi

	if isTrue "${BUILD_RAMDISK}"  && isTrue "${MICROCODE_INITRAMFS}" && isTrue "${INTEGRATED_INITRAMFS}"
	then
		# Force a user decision
		gen_die "Cannot embed microcode in initramfs when --integrated-initramfs is set. Either change option to --no-integrated-initramfs or --no-microcode-initramfs!"
	fi

	if isTrue "${FIRMWARE}"
	then
		for ff in ${FIRMWARE_FILES}; do
			[[ ${ff} = /* ]] && gen_die "FIRMWARE_FILES should list paths relative to FIRMWARE_DIR, not absolute."
		done

		[[ "${FIRMWARE_FILES}" = *,* ]] && gen_die "FIRMWARE_FILES should be a space-separated list."
	fi
}
