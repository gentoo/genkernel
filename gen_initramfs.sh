#!/bin/bash
# $Id$

COPY_BINARIES=false
CPIO_ARGS="--quiet --null -o -H newc --owner root:root --force-local"

# The copy_binaries function is explicitly released under the CC0 license to
# encourage wide adoption and re-use. That means:
# - You may use the code of copy_binaries() as CC0 outside of genkernel
# - Contributions to this function are licensed under CC0 as well.
# - If you change it outside of genkernel, please consider sending your
#   modifications back to genkernel@gentoo.org.
#
# On a side note: "Both public domain works and the simple license provided by
#                  CC0 are compatible with the GNU GPL."
#                 (from https://www.gnu.org/licenses/license-list.html#CC0)
#
# Written by:
# - Sebastian Pipping <sebastian@pipping.org> (error checking)
# - Robin H. Johnson <robbat2@gentoo.org> (complete rewrite)
# - Richard Yao <ryao@cs.stonybrook.edu> (original concept)
# Usage:
# copy_binaries DESTDIR BINARIES...
copy_binaries() {
	local destdir=${1}
	shift

	if [ ! -f "${TEMP}/.binaries_copied" ]
	then
		touch "${TEMP}/.binaries_copied" \
			|| gen_die "Failed to set '${TEMP}/.binaries_copied' marker!"
	fi

	local binary
	for binary in "$@"
	do
		[[ -e "${binary}" ]] \
			|| gen_die "Binary ${binary} could not be found"

		if "${LDDTREE_COMMAND}" "${binary}" 2>&1 | grep -F -q 'not found'
		then
			gen_die "Binary ${binary} is linked to missing libraries and may need to be re-built"
		fi
	done
	# This must be OUTSIDE the for loop, we only want to run lddtree etc ONCE.
	# lddtree does not have the -V (version) nor the -l (list) options prior to version 1.18
	(
		if "${LDDTREE_COMMAND}" -V > /dev/null 2>&1
		then
			"${LDDTREE_COMMAND}" -l "$@" \
				|| gen_die "Binary '${binary}' or some of its library dependencies could not be copied!"
		else
			"${LDDTREE_COMMAND}" "$@" \
				| tr ')(' '\n' \
				| awk '/=>/{ if($3 ~ /^\//){print $3}}' \
				|| gen_die "Binary '${binary}' or some of its library dependencies could not be copied!"
		fi
	) \
		| sort \
		| uniq \
		| "${CPIO_COMMAND}" -p --make-directories --dereference --quiet "${destdir}" \
		|| gen_die "Binary '${binary}' or some of its library dependencies could not be copied!"
}

# @FUNCTION: copy_system_binaries
# @USAGE: <DESTDIR> <system binaries to copy>
# @DESCRIPTION:
# Copies system binaries into dest dir.
#
# Difference to copy_binaries() is, that copy_system_binaries() does NOT
# try to recreate directory structure. Any system binary to copy will be
# placed into same DESTination DIRectory.
# Because we focus on *system* binaries, it's safe to assume that everything
# belongs to the same directory. This assumption will allow us to copy from
# crossdev environments (i.e. /usr/$CHOST).
copy_system_binaries() {
	[[ ${#} -lt 2 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes at least two arguments (${#} given)!"

	local destdir=${1}
	shift

	[[ ! -d "${destdir}" ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Destdir '${destdir}' does NOT exist!"

	if [ ! -f "${TEMP}/.system_binaries_copied" ]
	then
		touch "${TEMP}/.system_binaries_copied" \
			|| gen_die "Failed to set '${TEMP}/.system_binaries_copied' marker!"
	fi

	local binary binary_realpath binary_basename base_dir
	local binary_dependency binary_dependency_basename
	for binary in "$@"
	do
		[[ -e "${binary}" ]] \
			|| gen_die "$(get_useful_function_stack)System binary '${binary}' could not be found!"

		print_info 5 "System binary '${binary}' should be copied to '${destdir}' ..."

		binary_basename=$(basename "${binary}")
		if [[ -z "${binary_basename}" ]]
		then
			gen_die "$(get_useful_function_stack)Failed to determine basename of '${binary}'!"
		else
			print_info 5 "System binary's basename is '${binary_basename}'."
		fi

		if [[ -e "${destdir}/${binary_basename}" ]]
		then
			print_info 5 "System binary '${binary_basename}' already exists in '${destdir}'; Skipping ..."
			continue
		fi

		if [[ -L "${binary}" ]]
		then
			binary_realpath=$(realpath "${binary}")
			if [[ -z "${binary_realpath}" ]]
			then
				gen_die "$(get_useful_function_stack)Failed to resolve path to '${binary}'!"
			elif [[ ! -e "${binary_realpath}" ]]
			then
				gen_die "$(get_useful_function_stack)System binary '${binary}' was resolved to '${binary_realpath}' but file does NOT exist!"
			else
				print_info 5 "System binary '${binary}' resolved to '${binary_realpath}'."
				binary=${binary_realpath}
			fi
		fi

		base_dir=$(dirname "${binary}")
		if [[ -z "${base_dir}" ]]
		then
			gen_die "$(get_useful_function_stack)Failed to determine directory of '${binary}'!"
		else
			print_info 5 "System binary dirname set to '${base_dir}'."
		fi

		local is_first=1
		while IFS= read -r -u 3 binary_dependency
		do
			binary_dependency_basename=$(basename "${binary_dependency}")
			if [[ -z "${binary_dependency_basename}" ]]
			then
				gen_die "$(get_useful_function_stack)Failed to determine basename of '${binary_dependency}'!"
			fi

			if [[ ${is_first} -eq 1 ]]
			then
				# `lddtree -l` first line is always the binary itself
				print_info 5 "Copying '${base_dir}/${binary_dependency_basename}' to '${destdir}/' ..."
				cp -aL "${base_dir}/${binary_dependency_basename}" "${destdir}/${binary_basename}" \
					|| gen_die "$(get_useful_function_stack)Failed to copy '${base_dir}/${binary_dependency_basename}' to '${destdir}'!"

				is_first=0
			elif [[ -e "${destdir}/${binary_dependency_basename}" ]]
			then
				print_info 5 "System binary '${binary_basename}' already exists in '${destdir}'; Skipping ..."
				continue
			else
				print_info 5 "Need to copy dependency '${base_dir}/${binary_dependency_basename}' ..."
				"${FUNCNAME}" "${destdir}" "${base_dir}/${binary_dependency_basename}"
			fi
		done 3< <("${LDDTREE_COMMAND}" -l "${binary}" 2>/dev/null)
		IFS="${GK_DEFAULT_IFS}"
	done
}

log_future_cpio_content() {
	local dir_size=$(get_du "${PWD}")
	if [ -n "${dir_size}" ]
	then
		dir_size=" (${dir_size})"
	fi

	print_info 3 "=================================================================" 1 0 1
	print_info 3 "About to add these files${dir_size} from '${PWD}' to cpio archive:" 1 0 1
	print_info 3 "$(find . -print0 | xargs --null ls -ald)" 1 0 1
	print_info 3 "=================================================================" 1 0 1
}

append_devicemanager() {
	local PN="lvm"
	local TDIR="${TEMP}/initramfs-dm-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	populate_binpkg ${PN}

	mkdir -p "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	unpack "$(get_gkpkg_binpkg "${PN}")" "${TDIR}"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

	# Delete unneeded files
	rm -rf \
		sbin/lvm \
		usr/include \
		usr/lib/device-mapper \
		usr/lib/pkgconfig \
		usr/lib/lib* \
		usr/sbin/lvm \
		usr/share

	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append bcache to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_devices() {
	if isTrue "${BUSYBOX}"
	then
		local TDIR="${TEMP}/initramfs-devices-temp"
		if [ -d "${TDIR}" ]
		then
			rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
		fi

		mkdir -p "${TDIR}/dev" || gen_die "Failed to create '${TDIR}/dev'!"
		cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

		chmod 0755 dev || gen_die "Failed to chmod of '${TDIR}/dev' to 0755!"

		log_future_cpio_content
		find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} -F "${CPIO_ARCHIVE}" \
			|| gen_die "Failed to append devices to cpio!"

		cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
		if isTrue "${CLEANUP}"
		then
			rm -rf "${TDIR}"
		fi
	else
		local TFILE="${TEMP}/initramfs-base-temp.devices"
		if [ -f "${TFILE}" ]
		then
			rm "${TFILE}" || gen_die "Failed to clean out existing '${TFILE}'!"
		fi

		if [[ ! -x "${KERNEL_OUTPUTDIR}/usr/gen_init_cpio" ]]; then
			compile_gen_init_cpio
		fi

		# WARNING, does NOT support appending to cpio!
		cat >"${TFILE}" <<-EOF
		dir /dev 0755 0 0
		nod /dev/console 660 0 0 c 5 1
		nod /dev/null 666 0 0 c 1 3
		nod /dev/random 600 0 0 c 1 8
		nod /dev/tty0 600 0 0 c 4 0
		nod /dev/tty1 600 0 0 c 4 1
		nod /dev/ttyS0 600 0 0 c 4 64
		nod /dev/ttyS1 600 0 0 c 4 65
		nod /dev/urandom 600 0 0 c 1 9
		nod /dev/zero 666 0 0 c 1 5
		EOF

		print_info 3 "=================================================================" 1 0 1
		print_info 3 "Adding the following devices to cpio:" 1 0 1
		print_info 3 "$(cat "${TFILE}")" 1 0 1
		print_info 3 "=================================================================" 1 0 1

		"${KERNEL_OUTPUTDIR}"/usr/gen_init_cpio "${TFILE}" >"${CPIO_ARCHIVE}" \
			|| gen_die "Failed to append devices to cpio!"
	fi
}

append_base_layout() {
	local TDIR="${TEMP}/initramfs-base-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	mkdir "${TDIR}" || gen_die "Failed to create '${TDIR}'!"
	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

	local mydir=
	for mydir in \
		.initrd \
		bin \
		dev \
		etc \
		lib \
		lib/console \
		lib/dracut \
		mnt \
		proc \
		run \
		sbin \
		sys \
		tmp \
		usr \
		usr/bin \
		usr/lib \
		usr/sbin \
		var/empty \
		var/log \
		var/run/lock \
	; do
		mkdir -p "${TDIR}"/${mydir} || gen_die "Failed to create '${TDIR}/${mydir}'!"
	done

	chmod 1777 "${TDIR}"/tmp || gen_die "Failed to chmod of '${TDIR}/tmp' to 1777!"

	# In general, we don't really need lib{32,64} anymore because we now
	# compile most stuff on our own and therefore don't have to deal with
	# multilib anymore. However, when copy_binaries() was used to copy
	# binaries from a multilib-enabled system, this could be a problem.
	# So let's keep symlinks to ensure that all libraries will land in
	# /lib.
	local myliblink
	for myliblink in \
		lib32 \
		lib64 \
		usr/lib32 \
		usr/lib64 \
	; do
		ln -s lib ${myliblink} || gen_die "Failed to create symlink '${TDIR}/${myliblink}' to '${TDIR}/lib'!"
	done

	print_info 2 "$(get_indent 2)>> Populating '/etc/fstab' ..."
	echo "/dev/ram0     /           ext2    defaults	0 0" > "${TDIR}"/etc/fstab \
		|| gen_die "Failed to add /dev/ram0 to '${TDIR}/etc/fstab'!"

	echo "proc          /proc       proc    defaults    0 0" >> "${TDIR}"/etc/fstab \
		|| gen_die "Failed to add proc to '${TDIR}/etc/fstab'!"

	print_info 2 "$(get_indent 2)>> Adding /etc/{group,passwd,shadow} ..."
	cat >"${TDIR}"/etc/group <<-EOF
	root:x:0:root
	bin:x:1:root,bin,daemon
	daemon:x:2:root,bin,daemon
	sys:x:3:root,bin,adm
	adm:x:4:root,adm,daemon
	tty:x:5:
	disk:x:6:root,adm
	lp:x:7:lp
	mem:x:8:
	kmem:x:9:
	wheel:x:10:root
	floppy:x:11:root
	news:x:13:news
	uucp:x:14:uucp
	console:x:17:
	audio:x:18:
	cdrom:x:19:
	dialout:x:20:
	tape:x:26:root
	video:x:27:root
	render:x:28:
	rpc:x:32:
	kvm:x:78:
	usb:x:85:
	input:x:97:
	utmp:x:406:
	nogroup:x:65533:
	nobody:x:65534:
	EOF

	chmod 0644 "${TDIR}"/etc/group \
		|| gen_die "Failed to chmod of '${TDIR}/etc/group'!"

	cat >"${TDIR}"/etc/passwd <<-EOF
	root:x:0:0:root:/root:/usr/bin/login-remote.sh
	nobody:x:65534:65534:nobody:/var/empty:/bin/false
	EOF

	chmod 0644 "${TDIR}"/etc/passwd \
		|| gen_die "Failed to chmod of '${TDIR}/etc/passwd'!"

	echo "root:!:0:0:99999:7:::" > "${TDIR}"/etc/shadow \
		|| gen_die "Failed to create '/etc/shadow'!"

	chmod 0640 "${TDIR}"/etc/shadow \
		|| gen_die "Failed to chmod of '${TDIR}/etc/shadow'!"

	print_info 2 "$(get_indent 2)>> Adding /etc/nsswitch.conf ..."
	cat >"${TDIR}"/etc/nsswitch.conf <<-EOF
	# /etc/nsswitch.conf generated by genkernel
	passwd:    files
	shadow:    files
	group:     files
	EOF

	print_info 2 "$(get_indent 2)>> Adding /etc/ld.so.conf ..."
	cat >"${TDIR}"/etc/ld.so.conf <<-EOF
	# ld.so.conf generated by genkernel
	include ld.so.conf.d/*.conf
	/lib
	/usr/lib
	EOF

	print_info 2 "$(get_indent 2)>> Adding misc files ..."
	date -u '+%Y-%m-%d %H:%M:%S UTC' > "${TDIR}"/etc/build_date \
		|| gen_die "Failed to create '${TDIR}/etc/build_date'!"

	echo "Genkernel ${GK_V}" > "${TDIR}"/etc/build_id \
		|| gen_die "Failed to create '${TDIR}/etc/build_id'!"

	cat >"${TDIR}"/etc/initrd-release <<-EOF
	NAME="genkernel"
	VERSION="genkernel-${GK_V}"
	ID=genkernel
	VERSION_ID=${GK_V}
	PRETTY_NAME="Gentoo/Linux genkernel-${GK_V} (Initramfs)"
	ANSI_COLOR="0;34"
	EOF

	cp -a "${GK_SHARE}"/defaults/gksosreport.sh "${TDIR}"/usr/sbin/gksosreport \
		|| gen_die "Failed to copy '${GK_SHARE}/defaults/gksosreport.sh' to '${TDIR}/usr/sbin/gksosreport'"

	chmod 0755 "${TDIR}"/usr/sbin/gksosreport \
		|| gen_die "Failed to chmod of '${TDIR}/usr/sbin/gksosreport'!"

	ln -s /proc/self/mounts "${TDIR}"/etc/mtab \
		|| gen_die "Failed to symlink '/etc/mtab' to '/proc/self/mounts'!"

	# Allow lsinitrd from dracut to process our initramfs
	echo "$(cat "${TDIR}/etc/build_id") ($(cat "${TDIR}/etc/build_date"))" > "${TDIR}"/lib/dracut/dracut-gk-version.info \
		|| gen_die "Failed to create '${TDIR}/lib/dracut/dracut-gk-version.info'!"

	if [[ "${CMD_BOOTFONT}" == "none" ]]
	then
		print_info 3 "$(get_indent 2)>> --boot-font=none set; Not embedding console font ..."
	else
		local BOOTFONT_FILE="${TDIR}/lib/console/font"

		if [[ "${CMD_BOOTFONT}" == "current" ]]
		then
			print_info 2 "$(get_indent 2)>> Embedding current active console font ..."
			local -a setfont_cmd=( "${SETFONT_COMMAND}" )
			setfont_cmd+=( "-O ${BOOTFONT_FILE}" )

			print_info 3 "COMMAND: ${setfont_cmd[*]}" 1 0 1
			eval "${setfont_cmd[@]}" || gen_die "Failed to dump current active console font!"

			if ! isTrue $(is_psf_file "${BOOTFONT_FILE}")
			then
				gen_die "Sanity check failed: Dumped current active console font does NOT look like a valid PC Screen Font (PSF) file!"
			fi
		else
			print_info 2 "$(get_indent 2)>> Embedding '${BOOTFONT}' as console font ..."

			# Already validated in determine_real_args()
			cp -aL "${BOOTFONT}" "${BOOTFONT_FILE}" \
				|| gen_die "Failed to copy '${BOOTFONT}' to '${BOOTFONT_FILE}'!"
		fi
	fi

	local -a build_parameters

	build_parameters+=( --boot-font=${CMD_BOOTFONT} )

	if isTrue "${KEYMAP}"
	then
		build_parameters+=( --keymap )
		isTrue "${DOKEYMAPAUTO}" && build_parameters+=( --do-keymap-auto )
	else
		build_parameters+=( --no-keymap )
	fi

	isTrue "${COMPRESS_INITRD}" && build_parameters+=( --compress-initramfs ) || build_parameters+=( --no-compress-initramfs )
	isTrue "${MICROCODE_INITRAMFS}" && build_parameters+=( --microcode-initramfs ) || build_parameters+=( --no-microcode-initramfs )
	isTrue "${RAMDISKMODULES}" && build_parameters+=( --ramdisk-modules ) || build_parameters+=( --no-ramdisk-modules )
	isTrue "${BUSYBOX}" && build_parameters+=( --busybox ) || build_parameters+=( --no-busybox )
	isTrue "${BCACHE}" && build_parameters+=( --bcache ) || build_parameters+=( --no-bcache )
	isTrue "${B2SUM}" && build_parameters+=( --b2sum ) || build_parameters+=( --no-b2sum )
	isTrue "${BTRFS}" && build_parameters+=( --btrfs ) || build_parameters+=( --no-btrfs )
	isTrue "${ISCSI}" && build_parameters+=( --iscsi ) || build_parameters+=( --no-iscsi )
	isTrue "${MULTIPATH}" && build_parameters+=( --multipath ) || build_parameters+=( --no-multipath )
	isTrue "${DMRAID}" && build_parameters+=( --dmraid ) || build_parameters+=( --no-dmraid )
	isTrue "${MDADM}" && build_parameters+=( --mdadm ) || build_parameters+=( --no-mdadm )
	isTrue "${LVM}" && build_parameters+=( --lvm ) || build_parameters+=( --no-lvm )
	isTrue "${UNIONFS}" && build_parameters+=( --unionfs ) || build_parameters+=( --no-unionfs )
	isTrue "${ZFS}" && build_parameters+=( --zfs ) || build_parameters+=( --no-zfs )
	isTrue "${SPLASH}" && build_parameters+=( --splash ) || build_parameters+=( --no-splash )
	isTrue "${PLYMOUTH}" && build_parameters+=( --plymouth ) || build_parameters+=( --no-plymouth )
	isTrue "${SEDUTIL}" && build_parameters+=( --sedutil ) || build_parameters+=( --no-sedutil )
	isTrue "${STRACE}" && build_parameters+=( --strace ) || build_parameters+=( --no-strace )
	isTrue "${KEYCTL}" && build_parameters+=( --keyctl ) || build_parameters+=( --no-keyctl )
	isTrue "${GPG}" && build_parameters+=( --gpg ) || build_parameters+=( --no-gpg )
	isTrue "${LUKS}" && build_parameters+=( --luks ) || build_parameters+=( --no-luks )
	isTrue "${FIRMWARE}" && build_parameters+=( --firmware ) || build_parameters+=( --no-firmware )
	[ -n "${FIRMWARE_DIR}" ] && build_parameters+=( --firmware-dir="${FIRMWARE_DIR}" )
	[ -n "${FIRMWARE_FILES}" ] && build_parameters+=( --firmware-files="${FIRMWARE_FILES}" )
	isTrue "${SSH}" && build_parameters+=( --ssh ) || build_parameters+=( --no-ssh )
	isTrue "${E2FSPROGS}" && build_parameters+=( --e2fsprogs ) || build_parameters+=( --no-e2fsprogs )
	isTrue "${XFSPROGS}" && build_parameters+=( --xfsprogs ) || build_parameters+=( --no-xfsprogs )

	echo "${build_parameters[@]}" > "${TDIR}"/lib/dracut/build-parameter.txt \
		|| gen_die "Failed to create '${TDIR}/lib/dracut/build-parameter.txt'!"

	dd if=/dev/zero of="${TDIR}/var/log/lastlog" bs=1 count=0 seek=0 &>/dev/null \
		|| die "Failed to create '${TDIR}/var/log/lastlog'!"

	dd if=/dev/zero of="${TDIR}/var/log/wtmp" bs=1 count=0 seek=0 &>/dev/null \
		|| die "Failed to create '${TDIR}/var/log/wtmp'!"

	dd if=/dev/zero of="${TDIR}/var/run/utmp" bs=1 count=0 seek=0 &>/dev/null \
		|| die "Failed to create '${TDIR}/var/run/utmp'!"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append baselayout to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_busybox() {
	local PN=busybox
	local TDIR="${TEMP}/initramfs-${PN}-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	populate_binpkg ${PN}

	mkdir "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	unpack "$(get_gkpkg_binpkg "${PN}")" "${TDIR}"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

	# Delete unneeded files
	rm -rf configs/

	mkdir -p "${TDIR}"/usr/share/udhcpc || gen_die "Failed to create '${TDIR}/usr/share/udhcpc'!"

	cp -a "${GK_SHARE}"/defaults/udhcpc.scripts usr/share/udhcpc/default.script 2>/dev/null \
		|| gen_die "Failed to copy '${GK_SHARE}/defaults/udhcpc.scripts' to '${TDIR}/usr/share/udhcpc/default.script'!"

	local myfile=
	for myfile in \
		bin/busybox \
		usr/share/udhcpc/default.script \
	; do
		chmod +x "${TDIR}"/${myfile} || gen_die "Failed to chmod of '${TDIR}/${myfile}'!"
	done

	# Set up a few default symlinks
	local required_applets='[ ash sh mkdir mknod mount uname echo chmod cut cat touch'
	local required_applet=
	for required_applet in ${required_applets}
	do
		ln -s busybox "${TDIR}"/bin/${required_applet} \
			|| gen_die "Failed to create Busybox symlink for '${required_applet}' applet!"
	done

	# allow for DNS resolution
	if isTrue "$(is_glibc)"
	then
		local libdir=$(get_chost_libdir)
		local libnss_dns="${libdir}/libnss_dns.so"

		# NSS dns module was moved into libc in >=glibc-2.34
		# but when this file exists we are probably dealing with older glibc
		# and need to manually copy the module.
		if [[ -f "${libnss_dns}" ]]
		then
			mkdir -p "${TDIR}"/lib || gen_die "Failed to create '${TDIR}/lib'!"
			copy_system_binaries "${TDIR}"/lib "${libnss_dns}"
		fi
	fi

	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append ${PN} to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_e2fsprogs() {
	local PN=e2fsprogs
	local TDIR="${TEMP}/initramfs-${PN}-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	populate_binpkg ${PN}

	mkdir "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	unpack "$(get_gkpkg_binpkg "${PN}")" "${TDIR}"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append ${PN} to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_eudev() {
	local PN=eudev
	local TDIR="${TEMP}/initramfs-${PN}-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	populate_binpkg ${PN}
	populate_binpkg hwids

	mkdir "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	unpack "$(get_gkpkg_binpkg "${PN}")" "${TDIR}"
	unpack "$(get_gkpkg_binpkg hwids)" "${TDIR}"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

	if isTrue "$(can_run_programs_compiled_by_genkernel)"
	then
		print_info 2 "$(get_indent 2)${PN}: >> Pre-generating initramfs' /etc/udev/hwdb.bin ..."

		local gen_hwdb_cmd=( "${TDIR}/usr/bin/udevadm" )
		gen_hwdb_cmd+=( hwdb --update --root "${TDIR}" )
		print_info 3 "COMMAND: ${gen_hwdb_cmd[*]}" 1 0 1
		eval "${gen_hwdb_cmd[@]}" 2>&1 | tee -a "${LOGFILE}" \
			|| gen_die "Failed to pre-generate initramfs' /etc/udev/hwdb.bin!"

		# Now that we have a pre-generated hwdb in initramfs
		# we can delete source files
		rm -rf usr/lib/udev/hwdb.d/
	fi

	# Delete unneeded files
	rm -rf usr/include \
		usr/lib/libu* \
		usr/lib/pkgconfig \
		usr/share

	# Disable predictable network interface names in initramfs
	echo "" > usr/lib/udev/rules.d/80-net-name-slot.rules \
		|| gen_die "Failed to disable predictable network interface naming rule"

	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append ${PN} to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_b2sum() {
	local PN="coreutils"
	local TDIR="${TEMP}/initramfs-b2sum-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	populate_binpkg ${PN}

	mkdir -p "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	unpack "$(get_gkpkg_binpkg "${PN}")" "${TDIR}"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append b2sum to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_bcache() {
	local PN="bcache-tools"
	local TDIR="${TEMP}/initramfs-bcache-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	populate_binpkg ${PN}

	mkdir -p "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	unpack "$(get_gkpkg_binpkg "${PN}")" "${TDIR}"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append bcache to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_unionfs_fuse() {
	local PN=unionfs-fuse
	local TDIR="${TEMP}/initramfs-${PN}-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	populate_binpkg ${PN}

	mkdir -p "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	unpack "$(get_gkpkg_binpkg "${PN}")" "${TDIR}"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append ${PN} to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_util-linux() {
	local PN="util-linux"
	local TDIR="${TEMP}/initramfs-util-linux-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	populate_binpkg ${PN}

	mkdir -p "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	unpack "$(get_gkpkg_binpkg "${PN}")" "${TDIR}"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

	# Delete unneeded files
	rm -rf usr/

	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append ${PN} to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_multipath() {
	local PN=multipath-tools
	local TDIR="${TEMP}/initramfs-${PN}-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	mkdir -p "${TDIR}"/etc || gen_die "Failed to create '${TDIR}/etc'!"

	mkdir -p "${TDIR}"/usr/lib/udev/rules.d || gen_die "Failed to create '${TDIR}/usr/lib/udev/rules.d'!"

	local libdir=$(get_chost_libdir)
	if [[ "${libdir}" =~ ^/usr ]]
	then
		libdir=${libdir/\/usr/}
	fi

	copy_binaries \
		"${TDIR}" \
		/sbin/multipath \
		/sbin/kpartx \
		/sbin/mpathpersist \
		${libdir}/multipath/lib*.so

	local udevdir=$(get_udevdir)
	local udevdir_initramfs="/usr/lib/udev"
	local udev_files=( $(qlist -eC sys-fs/multipath-tools:0 \
		| grep -E -- "^${udevdir}")
	)

	if [ ${#udev_files[@]} -eq 0 ]
	then
		gen_die "Something went wrong: Did not found any udev-related files for sys-fs/multipath-tools!"
	fi

	local udev_files
	for udev_file in "${udev_files[@]}"
	do
		local dest_file="${TDIR%/}${udev_file/${udevdir}/${udevdir_initramfs}}"
		cp -aL "${udev_file}" "${dest_file}" \
			|| gen_die "Failed to copy '${udev_file}' to '${dest_file}'"
	done

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

	cp -aL /etc/multipath.conf "${TDIR}"/etc/multipath.conf 2>/dev/null \
		|| gen_die "Failed to copy '/etc/multipath.conf'!"

	# /etc/scsi_id.config does not exist in newer udevs
	# copy it optionally.
	if [ -f /etc/scsi_id.config ]
	then
		cp -aL /etc/scsi_id.config "${TDIR}"/etc/scsi_id.config 2>/dev/null \
			|| gen_die "Failed to copy '/etc/scsi_id.config'!"
	fi

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append ${PN} to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_dmraid() {
	local PN=dmraid
	local TDIR="${TEMP}/initramfs-${PN}-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	populate_binpkg ${PN}

	mkdir "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	unpack "$(get_gkpkg_binpkg "${PN}")" "${TDIR}"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

	# Delete unneeded files
	rm -rf \
		usr/lib \
		usr/share \
		usr/include

	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append dmraid to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_iscsi() {
	local PN=open-iscsi
	local TDIR="${TEMP}/initramfs-${PN}-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	populate_binpkg ${PN}

	mkdir -p "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	unpack "$(get_gkpkg_binpkg "${PN}")" "${TDIR}"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append iscsi to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_keyutils() {
	local PN=keyutils
	local TDIR="${TEMP}/initramfs-${PN}-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	populate_binpkg ${PN}

	mkdir "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	unpack "$(get_gkpkg_binpkg "${PN}")" "${TDIR}"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append ${PN} to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_lvm() {
	local PN=lvm
	local TDIR="${TEMP}/initramfs-${PN}-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	populate_binpkg ${PN}
	populate_binpkg thin-provisioning-tools

	mkdir "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	unpack "$(get_gkpkg_binpkg "${PN}")" "${TDIR}"
	unpack "$(get_gkpkg_binpkg "thin-provisioning-tools")" "${TDIR}"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

	local mydir=
	for mydir in \
		etc/lvm/cache \
		sbin \
	; do
		mkdir -p ${mydir} || gen_die "Failed to create '${TDIR}/${mydir}'!"
	done

	# Delete unneeded files
	rm -rf \
		usr/lib/device-mapper \
		usr/lib/pkgconfig \
		usr/lib/lib* \
		usr/sbin/dm* \
		usr/share \
		usr/include

	# Include the LVM config
	if [ -x /sbin/lvm -o -x /bin/lvm ]
	then
		local ABORT_ON_ERRORS=$(kconfig_get_opt "/etc/lvm/lvm.conf" "abort_on_errors")
		if isTrue "${ABORT_ON_ERRORS}" && [[ ${CBUILD} == ${CHOST} ]]
		then
			# Make sure the LVM binary we created is able to handle
			# system's lvm.conf
			"${TDIR}"/sbin/lvm dumpconfig 1>"${TDIR}"/etc/lvm/lvm.conf 2>/dev/null \
				|| gen_die "Bundled LVM version does NOT support system's lvm.conf!"

			# Sanity check
			if [ ! -s "${TDIR}/etc/lvm/lvm.conf" ]
			then
				gen_die "Sanity check failed: '${TDIR}/etc/lvm/lvm.conf' looks empty?!"
			fi
		else
			cp -aL /etc/lvm/lvm.conf "${TDIR}"/etc/lvm/lvm.conf 2>/dev/null \
				|| gen_die "Failed to copy '/etc/lvm/lvm.conf'!"
		fi

		# Some LVM config options need changing, because the functionality is
		# not compiled in:
		sed -r -i \
			-e '/^[[:space:]]*obtain_device_list_from_udev/s,=.*,= 1,g' \
			-e '/^[[:space:]]*udev_sync/s,=.*,= 1,g' \
			-e '/^[[:space:]]*use_lvmetad/s,=.*,= 0,g' \
			-e '/^[[:space:]]*use_lvmlockd/s,=.*,= 0,g' \
			-e '/^[[:space:]]*use_lvmpolld/s,=.*,= 0,g' \
			-e '/^[[:space:]]*monitoring/s,=.*,= 0,g' \
			-e '/^[[:space:]]*external_device_info_source/s,=.*,= "none",g' \
			-e '/^[[:space:]]*units/s,=.*"r",= "h",g' \
			-e '/^[[:space:]]*thin_repair_executable/s,=.*,= /usr/sbin/thin_repair,g' \
			-e '/^[[:space:]]*thin_dump_executable/s,=.*,= /usr/sbin/thin_dump,g' \
			-e '/^[[:space:]]*thin_check_executable/s,=.*,= /usr/sbin/thin_check,g' \
			"${TDIR}"/etc/lvm/lvm.conf \
				|| gen_die 'Could not sed lvm.conf!'
	fi

	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append lvm to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_mdadm() {
	local PN=mdadm
	local TDIR="${TEMP}/initramfs-${PN}-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	populate_binpkg ${PN}

	mkdir "${TDIR}" || gen_die "Failed to create '${TDIR}'!"
	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

	local mydir=
	for mydir in \
		etc \
		sbin \
	; do
		mkdir -p "${TDIR}"/${mydir} || gen_die "Failed to create '${TDIR}/${mydir}'!"
	done

	unpack "$(get_gkpkg_binpkg "${PN}")" "${TDIR}"

	if [ -n "${MDADM_CONFIG}" ]
	then
		print_info 2 "$(get_indent 2)${PN}: >> Adding '${MDADM_CONFIG}' ..."

		if [ -f "${MDADM_CONFIG}" ]
		then
			cp -aL "${MDADM_CONFIG}" "${TDIR}"/etc/mdadm.conf 2>/dev/null \
				|| gen_die "Failed to copy '${MDADM_CONFIG}'!"
		else
			gen_die "Specified '${MDADM_CONFIG}' does not exist!"
		fi
	else
		print_info 2 "$(get_indent 2)${PN}: >> --mdadm-config not set; Skipping inclusion of mdadm.conf ..."
	fi

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append ${PN} to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_xfsprogs() {
	local PN=xfsprogs
	local TDIR="${TEMP}/initramfs-${PN}-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	populate_binpkg ${PN}

	mkdir "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	unpack "$(get_gkpkg_binpkg "${PN}")" "${TDIR}"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append ${PN} to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_zfs() {
	local PN=zfs
	local TDIR="${TEMP}/initramfs-${PN}-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	mkdir "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	mkdir -p "${TDIR}"/etc/zfs || gen_die "Failed to create '${TDIR}/etc/zfs'!"

	# Copy files to /etc/zfs
	local i
	for i in vdev_id.conf zdev.conf zpool.cache
	do
		if [ -f /etc/zfs/${i} ]
		then
			print_info 2 "$(get_indent 2)${PN}: >> Including ${i}"
			cp -aL "/etc/zfs/${i}" "${TDIR}/etc/zfs/${i}" 2>/dev/null \
				|| gen_die "Could not copy file '/etc/zfs/${i}' for ZFS"
		fi
	done

	if [ -f "/etc/hostid" ]
	then
		local _hostid=$(hostid 2>/dev/null)
		print_info 2 "$(get_indent 2)${PN}: >> Embedding hostid '${_hostid}' into initramfs ..."
		cp -aL /etc/hostid "${TDIR}"/etc/hostid 2>/dev/null \
			|| gen_die "Failed to copy /etc/hostid"

		echo "${_hostid}" > "${TEMP}"/.embedded_hostid \
			|| gen_die "Failed to record system's hostid!"
	else
		print_warning 1 "$(get_indent 2)${PN}: /etc/hostid not found; You must use 'spl_hostid' kernel command-line parameter!"
	fi

	copy_binaries "${TDIR}" /sbin/{mount.zfs,zdb,zfs,zpool}

	local udevdir=$(get_udevdir)
	local udevdir_initramfs="/usr/lib/udev"
	local udev_files=( $(qlist -eC sys-fs/zfs:0 \
		| grep -E -- "^${udevdir}")
	)

	if [ ${#udev_files[@]} -eq 0 ]
	then
		gen_die "Something went wrong: Did not found any udev-related files for sys-fs/zfs!"
	fi

	mkdir -p "${TDIR}"/usr/lib/udev/rules.d || gen_die "Failed to create '${TDIR}/usr/lib/udev/rules.d'!"

	local udev_files
	for udev_file in "${udev_files[@]}"
	do
		local dest_file="${TDIR%/}${udev_file/${udevdir}/${udevdir_initramfs}}"
		cp -aL "${udev_file}" "${dest_file}" \
			|| gen_die "Failed to copy '${udev_file}' to '${dest_file}'"

		if [[ "${dest_file}" == *.rules ]]
		then
			print_info 5 "Updating UDEV dir in '${dest_file}' ..."
			sed -i \
				-e "s|${udevdir}|${udevdir_initramfs}|g" \
				"${dest_file}" \
				|| gen_die "Failed to update UDEV dir in '${dest_file}'"
		fi
	done

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append ${PN} to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_btrfs() {
	local PN=btrfs-progs
	local TDIR="${TEMP}/initramfs-${PN}-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	populate_binpkg ${PN}

	mkdir "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	unpack "$(get_gkpkg_binpkg "${PN}")" "${TDIR}"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append ${PN} to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_libgcc_s() {
	local TDIR="${TEMP}/initramfs-libgcc_s-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	mkdir "${TDIR}" || gen_die "Failed to create '${TDIR}'!"
	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

	# Include libgcc_s.so.1:
	#   - workaround for zfsonlinux/zfs#4749
	#   - required for LUKS2 (libargon2 uses pthread_cancel)
	local libgccpath
	if type gcc-config 2>&1 1>/dev/null; then
		libgccpath="/usr/lib/gcc/$(s=$(gcc-config -c); echo ${s%-*}/${s##*-})/libgcc_s.so.1"
	fi
	if [[ ! -f ${libgccpath} ]]; then
		libgccpath="/usr/lib/gcc/*/*/libgcc_s.so.1"
	fi

	copy_binaries "${TDIR}" ${libgccpath}

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append libgcc_s to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_linker() {
	local TDIR="${TEMP}/initramfs-linker-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	mkdir "${TDIR}" || gen_die "Failed to create '${TDIR}'!"
	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

	mkdir -p "${TDIR}"/etc || gen_die "Failed to create '${TDIR}/etc'!"

	if isTrue "$(tc-is-cross-compiler)"
	then
		# We cannot copy ld files from host because they could be
		# incompatible with CHOST.  Instead, add ldconfig to allow
		# initramfs to regenerate on its own (default /etc/ld.so.conf
		# for initramfs was added via append_base_layout()).
		mkdir -p "${TDIR}"/sbin || gen_die "Failed to create '${TDIR}/sbin'!"

		local libdir=$(get_chost_libdir)
		copy_system_binaries "${TDIR}/sbin" "${libdir%/usr\/*}/sbin/ldconfig"
	else
		# Only copy /etc/ld.so.conf.d -- /etc/ld.so.conf was already
		# added to CPIO via append_base_layout() and because we only
		# append to CPIO, that file wouldn't be used at all.
		if [ -d "/etc/ld.so.conf.d" ]
		then
			mkdir -p "${TDIR}"/etc/ld.so.conf.d || gen_die "Failed to create '${TDIR}/etc/ld.so.conf.d'!"
			cp -arL "/etc/ld.so.conf.d" "${TDIR}"/etc \
				|| gen_die "Failed to copy '/etc/ld.so.conf.d'!"
		fi

		if [ -e "/etc/ld.so.cache" ]
		then
			cp -aL "/etc/ld.so.cache" "${TDIR}"/etc/ld.so.cache \
				|| gen_die "Failed to copy '/etc/ld.so.cache'!"
		fi
	fi

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append linker to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_splash() {
	local TDIR="${TEMP}/initramfs-splash-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	mkdir "${TDIR}" || gen_die "Failed to create '${TDIR}'!"
	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

	if [ -z "${SPLASH_THEME}" -a -e /etc/conf.d/splash ]
	then
		source /etc/conf.d/splash &>/dev/null || gen_die "Failed to source '/etc/conf.d/splash'!"
	fi

	if [ -z "${SPLASH_THEME}" ]
	then
		SPLASH_THEME=default
	fi

	print_info 1 "$(get_indent 1)>> Installing splash [ using the ${SPLASH_THEME} theme ] ..."

	local res_param=""
	[ -n "${SPLASH_RES}" ] && res_param="-r ${SPLASH_RES}"
	splash_geninitramfs -c "${TDIR}" ${res_param} ${SPLASH_THEME} \
		|| gen_die "Failed to build splash cpio archive"

	if [ -e "/usr/share/splashutils/initrd.splash" ]
	then
		mkdir -p "${TDIR}"/etc || gen_die "Failed to create '${TDIR}/etc'!"
		cp -f /usr/share/splashutils/initrd.splash "${TDIR}"/etc/ 2>/dev/null \
			gen_die "Failed to copy '/usr/share/splashutils/initrd.splash'!"
	fi

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append splash to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_plymouth() {
	local PN=plymouth
	local TDIR="${TEMP}/initramfs-${PN}-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	mkdir "${TDIR}" || gen_die "Failed to create '${TDIR}'!"
	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

	# set plymouth theme
	if [ -n "${PLYMOUTH_THEME}" ]
	then
		plymouth-set-default-theme ${PLYMOUTH_THEME} || gen_die "Failed to set default plymouth theme!"
	fi
	if [ -z "${PLYMOUTH_THEME}" -a -e /etc/plymouth/plymouthd.conf ]
	then
		PLYMOUTH_THEME=$(plymouth-set-default-theme) || gen_die "Failed to set default plymouth theme!"
	fi
	if [ -z "${PLYMOUTH_THEME}" ]
	then
		PLYMOUTH_THEME=text
	fi

	print_info 1 "$(get_indent 1)>> Installing plymouth [ using the '${PLYMOUTH_THEME}' theme ]..."

	/usr/libexec/plymouth/plymouth-populate-initrd -t "${TDIR}" \
		|| gen_die "Failed to build plymouth cpio archive!"

	# can probably get rid of this; depends if plymouth was built with static libs
	# rm -f "${TDIR}"/lib*/{ld*,libc*,libz*} \
		# || gen_die "Failed to clean up plymouth cpio archive!"

	ln -sf "${PLYMOUTH_THEME}/${PLYMOUTH_THEME}.plymouth" "${TDIR}/usr/share/plymouth/themes/default.plymouth" \
		|| gen_die "Failed to set the default plymouth theme!"

	# include required udev rules
	mkdir -p "${TDIR}"/usr/lib/udev/rules.d || gen_die "Failed to create '${TDIR}/usr/lib/udev/rules.d'!"
	cp -aL /lib/udev/rules.d/70-uaccess.rules "${TDIR}/usr/lib/udev/rules.d" || gen_die "Failed to copy '70-uaccess.rules'!"
	cp -aL /lib/udev/rules.d/71-seat.rules "${TDIR}/usr/lib/udev/rules.d" || gen_die "Failed to copy '71-seat.rules'!"

	# clean up
	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append ${PN} to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_sedutil() {
	local PN=sedutil
	local TDIR="${TEMP}/initramfs-${PN}-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	populate_binpkg ${PN}

	mkdir -p "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	unpack "$(get_gkpkg_binpkg "${PN}")" "${TDIR}"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append ${PN} to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_strace() {
	local PN=strace
	local TDIR="${TEMP}/initramfs-${PN}-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	populate_binpkg ${PN}

	mkdir -p "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	unpack "$(get_gkpkg_binpkg "${PN}")" "${TDIR}"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append ${PN} to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_overlay() {
	cd "${INITRAMFS_OVERLAY}"  || gen_die "Failed to chdir to '${INITRAMFS_OVERLAY}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append overlay to cpio!"
}

append_luks() {
	local PN=cryptsetup
	local TDIR="${TEMP}/initramfs-luks-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	populate_binpkg ${PN}

	mkdir -p "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	unpack "$(get_gkpkg_binpkg "${PN}")" "${TDIR}"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

	# Delete unneeded files
	rm -rf usr/

	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append luks to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_dropbear() {
	local PN=dropbear
	local TDIR="${TEMP}/initramfs-${PN}-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	local dropbear_command=
	if ! isTrue "$(is_valid_ssh_host_keys_parameter_value "${SSH_HOST_KEYS}")"
	then
		gen_die "--ssh-host-keys value '${SSH_HOST_KEYS}' is unsupported!"
	elif [[ "${SSH_HOST_KEYS}" == 'create' ]]
	then
		dropbear_command=dropbearkey
	else
		dropbear_command=dropbearconvert
	fi

	if [ -z "${DROPBEAR_AUTHORIZED_KEYS_FILE}" ]
	then
		gen_die "Something went wrong: DROPBEAR_AUTHORIZED_KEYS_FILE should already been set but is missing!"
	fi

	populate_binpkg ${PN}

	mkdir -p "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	unpack "$(get_gkpkg_binpkg "${PN}")" "${TDIR}"

	if [[ "${SSH_HOST_KEYS}" == 'runtime' ]]
	then
		print_info 2 "$(get_indent 2)${PN}: >> No SSH host key embedded due to --ssh-host-key=runtime; Dropbear will generate required host key(s) at runtime!"
	else
		if ! hash ssh-keygen &>/dev/null
		then
			gen_die "'ssh-keygen' program is required but missing!"
		fi

		local initramfs_dropbear_dir="${TDIR}/etc/dropbear"

		if [[ "${SSH_HOST_KEYS}" == 'create-from-host' ]]
		then
			print_info 3 "$(get_indent 2)${PN}: >> Checking for existence of all SSH host keys ..."
			local missing_ssh_host_keys=no

			if [ ! -f "/etc/ssh/ssh_host_rsa_key" ]
			then
				print_info 3 "$(get_indent 2)${PN}: >> SSH host key '/etc/ssh/ssh_host_rsa_key' is missing!"
				missing_ssh_host_keys=yes
			fi

			if [ ! -f "/etc/ssh/ssh_host_ecdsa_key" ]
			then
				print_info 3 "$(get_indent 2)${PN}: >> SSH host key '/etc/ssh/ssh_host_ecdsa_key' is missing!"
				missing_ssh_host_keys=yes
			fi

			if [ ! -f "/etc/ssh/ssh_host_ed25519_key" ]
			then
				print_info 3 "$(get_indent 2)${PN}: >> SSH host key '/etc/ssh/ssh_host_ed25519_key' is missing!"
				missing_ssh_host_keys=yes
			fi

			if isTrue "${missing_ssh_host_keys}"
			then
				# Should only happen when installing a new system ...
				print_info 3 "$(get_indent 2)${PN}: >> Creating missing SSH host key(s) ..."
				ssh-keygen -A || gen_die "Failed to generate host's SSH host key(s) using 'ssh-keygen -A'!"
			fi
		fi

		local -a required_dropbear_host_keys=(
			/etc/dropbear/dropbear_ecdsa_host_key
			/etc/dropbear/dropbear_ed25519_host_key
			/etc/dropbear/dropbear_rsa_host_key
		)

		local i=0
		local n_required_dropbear_keys=${#required_dropbear_host_keys[@]}
		local required_key=
		while [[ ${i} < ${n_required_dropbear_keys} ]]
		do
			required_key=${required_dropbear_host_keys[${i}]}
			print_info 3 "$(get_indent 2)${PN}: >> Checking for existence of dropbear host key '${required_key}' ..."
			if [[ -f "${required_key}" ]]
			then
				if [[ ! -s "${required_key}" ]]
				then
					print_info 1 "$(get_indent 2)${PN}: >> Dropbear host key '${required_key}' exists but is empty; Removing ..."
					rm "${required_key}" || gen_die "Failed to remove invalid '${required_key}' null byte file!"
				elif [[ "${SSH_HOST_KEYS}" == 'create-from-host' ]] \
					&& [[ "${required_key}" == *_rsa_* ]] \
					&& [[ "${required_key}" -ot "/etc/ssh/ssh_host_rsa_key" ]]
				then
					print_info 1 "$(get_indent 2)${PN}: >> Dropbear host key '${required_key}' exists but is older than '/etc/ssh/ssh_host_rsa_key'; Removing to force update due to --ssh-host-key=create-from-host ..."
					rm "${required_key}" || gen_die "Failed to remove outdated '${required_key}' file!"
				elif [[ "${SSH_HOST_KEYS}" == 'create-from-host' ]] \
					&& [[ "${required_key}" == *_ecdsa_* ]] \
					&& [[ "${required_key}" -ot "/etc/ssh/ssh_host_ecdsa_key" ]]
				then
					print_info 1 "$(get_indent 2)${PN}: >> Dropbear host key '${required_key}' exists but is older than '/etc/ssh/ssh_host_ecdsa_key'; Removing to force update due to --ssh-host-key=create-from-host ..."
					rm "${required_key}" || gen_die "Failed to remove outdated '${required_key}' file!"
				elif [[ "${SSH_HOST_KEYS}" == 'create-from-host' ]] \
					&& [[ "${required_key}" == *_ed25519_* ]] \
					&& [[ "${required_key}" -ot "/etc/ssh/ssh_host_ed25519_key" ]]
				then
					print_info 1 "$(get_indent 2)${PN}: >> Dropbear host key '${required_key}' exists but is older than '/etc/ssh/ssh_host_ed25519_key'; Removing to force update due to --ssh-host-key=create-from-host ..."
					rm "${required_key}" || gen_die "Failed to remove outdated '${required_key}' file!"
				else
					print_info 3 "$(get_indent 2)${PN}: >> Dropbear host key '${required_key}' exists!"
					unset required_dropbear_host_keys[${i}]
				fi
			else
				print_info 3 "$(get_indent 2)${PN}: >> Dropbear host key '${required_key}' is missing! Will create ..."
			fi

			i=$((i + 1))
		done

		if [[ ${#required_dropbear_host_keys[@]} -gt 0 ]]
		then
			if isTrue "$(can_run_programs_compiled_by_genkernel)"
			then
				dropbear_command="${TDIR}/usr/bin/${dropbear_command}"
				print_info 3 "$(get_indent 2)${PN}: >> Will use '${dropbear_command}' to create missing keys ..."
			elif hash ${dropbear_command} &>/dev/null
			then
				print_info 3 "$(get_indent 2)${PN}: >> Will use existing '${dropbear_command}' program from path to create missing keys ..."
			else
				local error_msg="Need to generate '${required_dropbear_host_keys[*]}' but '${dropbear_command}'"
				error_msg+=" program is missing. Please install net-misc/dropbear and re-run genkernel!"
				gen_die "${error_msg}"
			fi

			local missing_key=
			for missing_key in ${required_dropbear_host_keys[@]}
			do
				dropbear_create_key "${missing_key}" "${dropbear_command}"

				# just in case ...
				if [ -f "${missing_key}" ]
				then
					print_info 3 "$(get_indent 2)${PN}: >> Dropbear host key '${missing_key}' successfully created!"
				else
					gen_die "Sanity check failed: '${missing_key}' should exist at this stage but does NOT."
				fi
			done
		else
			print_info 2 "$(get_indent 2)${PN}: >> Using existing dropbear host keys from /etc/dropbear ..."
		fi

		cp -aL --target-directory "${initramfs_dropbear_dir}" /etc/dropbear/dropbear_{rsa,ecdsa,ed25519}_host_key \
			|| gen_die "Failed to copy '/etc/dropbear/dropbear_{rsa,ecdsa,ed25519}_host_key'"

		# Try to show embedded dropbear host key details for security reasons.
		# We do it that complicated to get common used formats.
		local -a key_info_files=()
		local -a missing_key_info_files=()

		local host_key_file= host_key_file_checksum= host_key_info_file=
		while IFS= read -r -u 3 -d $'\0' host_key_file
		do
			host_key_file_checksum=$(sha256sum "${host_key_file}" 2>/dev/null | awk '{print $1}')
			if [ -z "${host_key_file_checksum}" ]
			then
				gen_die "Failed to generate SHA256 checksum of '${host_key_file}'!"
			fi

			host_key_info_file="${GK_V_CACHEDIR}/$(basename "${host_key_file}").${host_key_file_checksum:0:10}.info"

			if [ ! -s "${host_key_info_file}" ]
			then
				missing_key_info_files+=( ${host_key_info_file} )
			else
				key_info_files+=( ${host_key_info_file} )
			fi
		done 3< <(find "${initramfs_dropbear_dir}" -type f -name '*_key' -print0 2>/dev/null)
		unset host_key_file host_key_file_checksum host_key_info_file
		IFS="${GK_DEFAULT_IFS}"

		if [[ ${#missing_key_info_files[@]} -ne 0 ]]
		then
			dropbear_command=
			if isTrue "$(can_run_programs_compiled_by_genkernel)"
			then
				dropbear_command="${TDIR}/usr/bin/dropbearconvert"
				print_info 3 "$(get_indent 2)${PN}: >> Will use '${dropbear_command}' to extract embedded host key information ..."
			elif hash dropbearconvert &>/dev/null
			then
				dropbear_command=dropbearconvert
				print_info 3 "$(get_indent 2)${PN}: >> Will use existing '${dropbear_command}' program to extract embedded host key information ..."
			else
				print_warning 2 "$(get_indent 2)${PN}: >> 'dropbearconvert' program not available; Cannot generate missing key information for ${#missing_key_info_files[@]} key(s)!"
			fi

			if [[ -n "${dropbear_command}" ]]
			then
				# We are missing at least information for one embedded key
				# but looks like we are able to generate the missing information ...
				local missing_key_info_file=
				for missing_key_info_file in "${missing_key_info_files[@]}"
				do
					dropbear_generate_key_info_file "${dropbear_command}" "${missing_key_info_file}" "${initramfs_dropbear_dir}"
					key_info_files+=( ${missing_key_info_file} )
				done
				unset missing_key_info_file
			fi
		fi

		if [[ ${#key_info_files[@]} -gt 0 ]]
		then
			# We have at least information about one embedded key ...
			print_info 1 "=================================================================" 1 0 1
			print_info 1 "This initramfs' sshd will use the following host key(s):" 1 0 1

			local key_info_file=
			for key_info_file in "${key_info_files[@]}"
			do
				print_info 1 "$(cat "${key_info_file}")" 1 0 1
			done
			unset key_info_file

			if [ ${LOGLEVEL} -lt 3 ]
			then
				# Don't clash with output from log_future_cpio_content
				print_info 1 "=================================================================" 1 0 1
			fi
		else
			print_warning 2 "$(get_indent 2)${PN}: >> No information about embedded SSH host key(s) available."
		fi
	fi

	if isTrue "$(is_glibc)"
	then
		local libdir=$(get_chost_libdir)
		local libnss_files="${libdir}/libnss_files.so"

		# NSS files module was moved into libc in >=glibc-2.34
		# but when this file exists we are probably dealing with older glibc
		# and need to manually copy the module.
		if [[ -f "${libnss_files}" ]]
		then
			mkdir -p "${TDIR}"/lib || gen_die "Failed to create '${TDIR}/lib'!"
			copy_system_binaries "${TDIR}"/lib "${libnss_files}"
		fi
	fi

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

	cp -a "${GK_SHARE}"/defaults/login-remote.sh "${TDIR}"/usr/bin/ \
		|| gen_die "Failed to copy '${GK_SHARE}/defaults/login-remote.sh'"

	cp -a "${GK_SHARE}"/defaults/resume-boot.sh "${TDIR}"/usr/sbin/resume-boot \
		|| gen_die "Failed to copy '${GK_SHARE}/defaults/resume-boot.sh' to '${TDIR}/usr/sbin/resume-boot'"

	cp -a "${GK_SHARE}"/defaults/unlock-luks.sh "${TDIR}"/usr/sbin/unlock-luks \
		|| gen_die "Failed to copy '${GK_SHARE}/defaults/unlock-luks.sh' to '${TDIR}/usr/sbin/unlock-luks'"

	cp -a "${GK_SHARE}"/defaults/unlock-zfs.sh "${TDIR}"/usr/sbin/unlock-zfs \
		|| gen_die "Failed to copy '${GK_SHARE}/defaults/unlock-zfs.sh' to '${TDIR}/usr/sbin/unlock-zfs'"

	cp -aL "${DROPBEAR_AUTHORIZED_KEYS_FILE}" "${TDIR}"/root/.ssh/ \
		|| gen_die "Failed to copy '${DROPBEAR_AUTHORIZED_KEYS_FILE}'!"

	cp -aL /etc/localtime "${TDIR}"/etc/ \
		|| gen_die "Failed to copy '/etc/localtime'. Please set system's timezone!"


	echo "/usr/bin/login-remote.sh" > "${TDIR}"/etc/shells \
		|| gen_die "Failed to create '/etc/shells'!"

	chmod 0755 "${TDIR}"/usr/bin/login-remote.sh \
		|| gen_die "Failed to chmod of '${TDIR}/usr/bin/login-remote.sh'!"

	chmod 0755 "${TDIR}"/usr/sbin/resume-boot \
		|| gen_die "Failed to chmod of '${TDIR}/usr/sbin/resume-boot'!"

	chmod 0755 "${TDIR}"/usr/sbin/unlock-luks \
		|| gen_die "Failed to chmod of '${TDIR}/usr/sbin/unlock-luks'!"

	chmod 0755 "${TDIR}"/usr/sbin/unlock-zfs \
		|| gen_die "Failed to chmod of '${TDIR}/usr/sbin/unlock-zfs'!"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append ${PN} to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_firmware() {
	local TDIR="${TEMP}/initramfs-firmware-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	mkdir "${TDIR}" || gen_die "Failed to create '${TDIR}'!"
	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

	if [ ! -d "${FIRMWARE_DIR}" ]
	then
		gen_die "Specified firmware directory '${FIRMWARE_DIR}' does not exist!"
	fi

	mkdir -p "${TDIR}"/lib/firmware || gen_die "Failed to create '${TDIR}/lib/firmware'!"

	local -a fwlist=()

	if isTrue "${ALLFIRMWARE}"
	then
		cp -a "${FIRMWARE_DIR}"/* "${TDIR}"/lib/firmware/ 2>/dev/null \
			|| gen_die "Failed to copy firmware files to '${TDIR}/lib/firmware'!"
	elif [ ${#FIRMWARE_FILES[@]} -gt 0 ]
	then
		fwlist=( "${FIRMWARE_FILES[@]}" )
	else
		local myfw=
		while IFS= read -r -u 3 myfw
		do
			if [ -z "${myfw}" ]
			then
				gen_die "modinfo error!"
			fi

			if [ ! -f "${FIRMWARE_DIR}/${myfw}" ]
			then
				print_warning 3 "$(get_indent 3) - ${myfw} is missing; Ignoring ..."
				continue
			fi

			fwlist+=( "${myfw}" )
		done 3< <( (
			modinfo -b "${KERNEL_MODULES_PREFIX%/}" -k "${KV}" -F firmware $(mod_dep_list) 2>/dev/null || echo
		) | sort | uniq )
	fi

	if [ ${#fwlist[@]} -gt 0 ]
	then
		pushd "${FIRMWARE_DIR}" &>/dev/null || gen_die "Failed to chdir to '${FIRMWARE_DIR}'!"
		cp -rL --parents --target-directory="${TDIR}/lib/firmware" "${fwlist[@]}" 2>/dev/null \
			|| gen_die "Failed to copy firmware files to '${TDIR}/lib/firmware'!"
		popd &>/dev/null || gen_die "Failed to chdir!"
	fi

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append firmware to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_gpg() {
	local PN=gnupg
	local TDIR="${TEMP}/initramfs-${PN}-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	populate_binpkg ${PN}

	mkdir -p "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	unpack "$(get_gkpkg_binpkg "${PN}")" "${TDIR}"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append ${PN} to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

print_list()
{
	local x
	for x in ${*}
	do
		echo ${x}
	done
}

append_modules() {
	local TDIR="${TEMP}/initramfs-modules-${KV}-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	populate_binpkg kmod

	mkdir "${TDIR}" || gen_die "Failed to create '${TDIR}'!"

	unpack "$(get_gkpkg_binpkg kmod)" "${TDIR}"

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

	# Delete unneeded files
	rm -rf \
		usr/include \
		usr/lib

	local mydir=
	for mydir in \
		etc/modules \
		lib/modules/${KV} \
	; do
		mkdir -p "${TDIR}"/${mydir} || gen_die "Failed to create '${TDIR}/${mydir}'!"
	done

	local modules_dstdir="${TDIR}/lib/modules/${KV}"
	local modules_srcdir="/lib/modules/${KV}"

	if [ -n "${KERNEL_MODULES_PREFIX}" ]
	then
		modules_srcdir="${KERNEL_MODULES_PREFIX%/}${modules_srcdir}"
	fi

	if [ ! -d "${modules_srcdir}" ]
	then
		error_message="'${modules_srcdir}' does not exist! Did you forget"
		error_message+=" to compile kernel before building initramfs?"
		error_message+=" If you know what you are doing please set '--no-ramdisk-modules'."
		gen_die "${error_message}"
	fi

	cd "${modules_srcdir}" || gen_die "Failed to chdir to '${modules_srcdir}'!"

	print_info 2 "$(get_indent 2)modules: >> Searching modules in '${modules_srcdir}' ..."

	local mymod=
	local -a modlist=()
	while IFS= read -r -u 3 mymod
	do
		if [ -z "${mymod}" ]
		then
			gen_die "modinfo error!"
		fi

		if [ "${mymod}" = '(builtin)' ]
		then
			continue
		fi

		if [ ! -f "${mymod}" ]
		then
			gen_die "Module '${i}${KEXT}' is missing!"
		fi

		modlist+=( "${mymod/#${modules_srcdir}\//}" )
	done 3< <( (
		modinfo -b "${KERNEL_MODULES_PREFIX%/}" -k "${KV}" -F filename $(mod_dep_list) 2>/dev/null || echo
	) | sort | uniq )

	if [ ${#modlist[@]} -gt 0 ]
	then
		print_info 2 "$(get_indent 2)modules: >> Copying modules from '${modules_srcdir}' to initramfs ..."
		cp -ax --parents --target-directory "${modules_dstdir}" "${modlist[@]}" 2>/dev/null \
			|| gen_die "Failed to copy modules!"
		print_info 2 "$(get_indent 2)modules: ${#modlist[@]} modules copied!"
	else
		print_warning 1 "$(get_indent 2)modules: 0 modules copied. Is that correct?"
	fi

	cp -ax --parents --target-directory "${modules_dstdir}" modules* 2>/dev/null \
		|| gen_die "Failed to copy '${modules_srcdir}/modules*' to '${modules_dstdir}'!"

	print_info 2 "$(get_indent 2)modules: Updating modules.dep ..."
	local depmod_cmd=( depmod -a -b "${TDIR}" ${KV} )
	print_info 3 "COMMAND: ${depmod_cmd[*]}" 1 0 1
	eval "${depmod_cmd[@]}" || gen_die "Failed to run '${depmod_cmd[*]}'!"

	local group_modules= group=
	for group_modules in ${!MODULES_*}
	do
		group="$(echo ${group_modules} | cut -d_ -f2- | tr "[:upper:]" "[:lower:]")"
		print_list ${!group_modules} > "${TDIR}"/etc/modules/${group} \
			|| gen_die "Failed to create '${TDIR}/etc/modules/${group}'!"
	done

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append modules-${KV} to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_modprobed() {
	local TDIR="${TEMP}/initramfs-modprobe.d-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	mkdir "${TDIR}" || gen_die "Failed to create '${TDIR}'!"
	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

	local modprobe_dir
	for modprobe_dir in /etc/modprobe.d /lib/modprobe.d
	do
		if [[ ! -e "${modprobe_dir}" ]]; then
			print_info 5 "'${modprobe_dir}' does not exist; Skipping ..."
			continue
		fi

		mkdir -p "${TDIR}${modprobe_dir}" || gen_die "Failed to create '${TDIR}${modprobe_dir}'!"

		cp -aL "${modprobe_dir}"/. "${TDIR}${modprobe_dir}" 2>/dev/null \
			|| gen_die "Failed to copy '${modprobe_dir}'!"
	done

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append modprobe.d to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_auxiliary() {
	local TDIR="${TEMP}/initramfs-aux-temp"
	if [ -d "${TDIR}" ]
	then
		rm -r "${TDIR}" || gen_die "Failed to clean out existing '${TDIR}'!"
	fi

	mkdir "${TDIR}" || gen_die "Failed to create '${TDIR}'!"
	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

	local mydir=
	for mydir in \
		etc \
		sbin \
	; do
		mkdir -p "${TDIR}"/${mydir} || gen_die "Failed to create '${TDIR}/${mydir}'!"
	done

	local mylinuxrc=
	if [ -n "${LINUXRC}" ]
	then
		mylinuxrc="${LINUXRC}"
		print_info 2 "$(get_indent 2)>> Copying user specified linuxrc '${mylinuxrc}' to '/init' ..."
	elif isTrue "${NETBOOT}"
	then
		mylinuxrc="${GK_SHARE}/netboot/linuxrc.x"
		print_info 2 "$(get_indent 2)>> Copying netboot specific linuxrc '${mylinuxrc}' to '/init' ..."
	else
		if [ -f "${GK_SHARE}/arch/${ARCH}/linuxrc" ]
		then
			mylinuxrc="${GK_SHARE}/arch/${ARCH}/linuxrc"
		else
			mylinuxrc="${GK_SHARE}/defaults/linuxrc"
		fi

		print_info 2 "$(get_indent 2)>> Copying '${mylinuxrc}' to '/init' ..."
	fi

	cp -aL "${mylinuxrc}" "${TDIR}"/init 2>/dev/null \
		|| gen_die "Failed to copy '${mylinuxrc}' to '${TDIR}/init'!"

	# Make sure it's executable
	chmod 0755 "${TDIR}"/init || gen_die "Failed to chmod of '${TDIR}/init' to 0755!"

	# Make a symlink to init .. in case we are bundled inside the kernel as one
	# big cpio.
	pushd "${TDIR}" &>/dev/null || gen_die "Failed to chdir to '${TDIR}'!"
	ln -s init linuxrc || gen_die "Failed to create symlink 'linuxrc' to 'init'!"
	popd &>/dev/null || gen_die "Failed to chdir!"

	local myinitrd_script=
	if [ -f "${GK_SHARE}/arch/${ARCH}/initrd.scripts" ]
	then
		myinitrd_script="${GK_SHARE}/arch/${ARCH}/initrd.scripts"
	else
		myinitrd_script="${GK_SHARE}/defaults/initrd.scripts"
	fi
	print_info 2 "$(get_indent 2)>> Copying '${myinitrd_script}' to '/etc/initrd.scripts' ..."
	cp -aL "${myinitrd_script}" "${TDIR}"/etc/initrd.scripts 2>/dev/null \
		|| gen_die "Failed to copy '${myinitrd_script}' to '${TDIR}/etc/initrd.scripts'!"

	local myinitrd_default=
	if [ -f "${GK_SHARE}/arch/${ARCH}/initrd.defaults" ]
	then
		myinitrd_default="${GK_SHARE}/arch/${ARCH}/initrd.defaults"
	else
		myinitrd_default="${GK_SHARE}/defaults/initrd.defaults"
	fi
	print_info 2 "$(get_indent 2)>> Copying '${myinitrd_default}' to '/etc/initrd.defaults' ..."
	cp -aL "${myinitrd_default}" "${TDIR}"/etc/initrd.defaults 2>/dev/null \
		|| gen_die "Failed to copy '${myinitrd_default}' to '${TDIR}/etc/initrd.defaults'!"

	if [ -n "${REAL_ROOT}" ]
	then
		print_info 2 "$(get_indent 2)>> Setting REAL_ROOT to '${REAL_ROOT}' in '/etc/initrd.defaults' ..."
		sed -i "s:^REAL_ROOT=.*$:REAL_ROOT='${REAL_ROOT}':" \
			"${TDIR}"/etc/initrd.defaults \
			|| gen_die "Failed to set REAL_ROOT in '${TDIR}/etc/initrd.defaults'!"
	fi

	printf "%s" 'HWOPTS="$HWOPTS ' >> "${TDIR}"/etc/initrd.defaults \
		|| gen_die "Failed to add HWOPTS to '${TDIR}/etc/initrd.defaults'!"

	local group_modules group
	for group_modules in ${!MODULES_*}; do
		group="$(echo ${group_modules} | cut -d_ -f2 | tr "[:upper:]" "[:lower:]")"
		printf "%s" "${group} " >> "${TDIR}"/etc/initrd.defaults \
			|| gen_die "Failed to add MODULES_* to '${TDIR}/etc/initrd.defaults'!"
	done

	echo '"' >> "${TDIR}"/etc/initrd.defaults \
		|| gen_die "Failed to add closing '\"' to '${TDIR}/etc/initrd.defaults'!"

	if isTrue "${CMD_KEYMAP}"
	then
		print_info 2 "$(get_indent 2)>> Copying keymaps ..."
		mkdir -p "${TDIR}"/lib || gen_die "Failed to create '${TDIR}/lib'!"
		cp -R "${GK_SHARE}/defaults/keymaps" "${TDIR}"/lib/ 2>/dev/null \
			|| gen_die "Failed to copy '${GK_SHARE}/defaults/keymaps' to '${TDIR}/lib'!"

		if isTrue "${CMD_DOKEYMAPAUTO}"
		then
			print_info 2 "$(get_indent 2)>> Forcing keymap selection in initrd script due to DOKEYMAPAUTO setting ..."
			echo 'MY_HWOPTS="${MY_HWOPTS} keymap"' >> "${TDIR}"/etc/initrd.defaults \
				|| gen_die "Failed to add keymap to MY_HWOPTS in '${TDIR}/etc/initrd.defaults'!"
		fi
	fi

	pushd "${TDIR}"/sbin &>/dev/null || gen_die "Failed to chdir to '${TDIR}/sbin'!"
	ln -s ../init init || gen_die "Failed to create symlink 'init' to '../init'!"
	popd &>/dev/null || gen_die "Failed to chdir!"

	if isTrue "${NETBOOT}"
	then
		pushd "${GK_SHARE}/netboot/misc" &>/dev/null || gen_die "Failed to chdir to '${GK_SHARE}/netboot/misc'!"
		cp -pPRf * "${TDIR}"/ 2>/dev/null \
			|| gen_die "Failed to copy '${GK_SHARE}/netboot/misc' to '${TDIR}'!"
		popd &>/dev/null || gen_die "Failed to chdir!"
	fi

	cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"
	log_future_cpio_content
	find . -print0 | "${CPIO_COMMAND}" ${CPIO_ARGS} --append -F "${CPIO_ARCHIVE}" \
		|| gen_die "Failed to append auxiliary to cpio!"

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if isTrue "${CLEANUP}"
	then
		rm -rf "${TDIR}"
	fi
}

append_data() {
	[ $# -eq 0 ] && gen_die "append_data() called with zero arguments"

	local name=$1
	local func="append_${name}"

	shift

	if [ $# -eq 0 ] || anyTrue "$@"
	then
		print_info 1 "$(get_indent 1)>> Appending ${name} cpio data ..."
		${func} || gen_die "${func}() failed!"
	fi
}

create_initramfs() {
	print_info 1 "initramfs: >> Initializing ..."

	# Create empty cpio
	CPIO_ARCHIVE="${TMPDIR}/${GK_FILENAME_TEMP_INITRAMFS}"
	append_data 'devices' # WARNING, must be first!
	append_data 'base_layout'
	append_data 'util-linux'
	append_data 'eudev'
	append_data 'devicemanager' "${DMRAID}" "${LVM}" "${LUKS}" "${MULTIPATH}"
	append_data 'auxiliary' "${BUSYBOX}"
	append_data 'busybox' "${BUSYBOX}"
	append_data 'b2sum' "${B2SUM}"
	append_data 'btrfs' "${BTRFS}"
	append_data 'dmraid' "${DMRAID}"
	append_data 'dropbear' "${SSH}"
	append_data 'e2fsprogs' "${E2FSPROGS}"
	append_data 'gpg' "${GPG}"
	append_data 'iscsi' "${ISCSI}"
	append_data 'keyutils' "${KEYCTL}"
	append_data 'luks' "${LUKS}"
	append_data 'lvm' "${LVM}"
	append_data 'bcache' "${BCACHE}"
	append_data 'mdadm' "${MDADM}"
	append_data 'modprobed'
	append_data 'multipath' "${MULTIPATH}"
	append_data 'splash' "${SPLASH}"
	append_data 'plymouth' "${PLYMOUTH}"
	append_data 'sedutil' "${SEDUTIL}"
	append_data 'strace' "${STRACE}"
	append_data 'unionfs_fuse' "${UNIONFS}"
	append_data 'xfsprogs' "${XFSPROGS}"
	append_data 'zfs' "${ZFS}"

	if isTrue "${ZFS}"
	then
		append_data 'libgcc_s'
	fi

	if isTrue "${FIRMWARE}" && [ -n "${FIRMWARE_DIR}" ]
	then
		append_data 'firmware'
	fi

	if isTrue "${RAMDISKMODULES}"
	then
		append_data 'modules'
	else
		print_info 1 "$(get_indent 1)>> Not copying modules due to --no-ramdisk-modules ..."
	fi

	# This should always be appended last
	if [ -n "${INITRAMFS_OVERLAY}" ]
	then
		append_data 'overlay'
	fi

	if [[ -f "${TEMP}/.binaries_copied" || -f "${TEMP}/.system_binaries_copied" ]]
	then
		append_data 'linker'
	else
		print_info 2 "$(get_indent 1)>> Not appending linker because no binaries have been copied ..."
	fi

	# Finalize cpio by removing duplicate files
	# TODO: maybe replace this with:
	# http://search.cpan.org/~pixel/Archive-Cpio-0.07/lib/Archive/Cpio.pm
	# as then we can dedupe ourselves...
	if isTrue "${BUSYBOX}" || [[ ${UID} -eq 0 ]]
	then
		print_info 1 "$(get_indent 1)>> Deduping cpio ..."
		local TDIR="${TEMP}/initramfs-final"
		mkdir -p "${TDIR}" || gen_die "Failed to create '${TDIR}'!"
		cd "${TDIR}" || gen_die "Failed to chdir to '${TDIR}'!"

		"${CPIO_COMMAND}" --quiet -i -F "${CPIO_ARCHIVE}" 2>/dev/null \
			|| gen_die "Failed to extract cpio '${CPIO_ARCHIVE}' for dedupe"

		if ! isTrue "$(tc-is-cross-compiler)"
		then
			# We can generate or update /etc/ld.so.cache which was copied from host
			# to actually match initramfs' content.
			print_info 1 "$(get_indent 1)>> Pre-generating initramfs' /etc/ld.so.cache ..."
			# Need to disable sandbox which doesn't understand chroot(), bug #431038
			SANDBOX_ON=0 ldconfig -f /etc/ld.so.conf -r "${TDIR}" 2>/dev/null \
				|| print_warning 1 "Failed to pre-generate '${TDIR}/etc/ld.so.cache'! Probably due to sandbox/permission problem; Ignoring ..."
		fi

		find . -print0 | sort -z | "${CPIO_COMMAND}" ${CPIO_ARGS} --reproducible -F "${CPIO_ARCHIVE}" 2>/dev/null \
			|| gen_die "rebuilding cpio for dedupe"

		cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
		if isTrue "${CLEANUP}"
		then
			rm -rf "${TDIR}"
		fi
	else
		print_info 1 "$(get_indent 1)>> Cannot deduping cpio contents without root; Skipping ..."
	fi

	cd "${TEMP}" || gen_die "Failed to chdir to '${TEMP}'"

	local kconfig_file_used="${KERNEL_CONFIG}"
	if isTrue "${BUILD_KERNEL}"
	then
		kconfig_file_used="${KERNEL_OUTPUTDIR}/.config"
	fi

	if isTrue "$(is_gzipped "${kconfig_file_used}")"
	then
		print_info 5 "Compressed kernel config '${kconfig_file_used}' found; Must decompress to temporary file ..."

		local kconfig_file_tmp="${TEMP}/current_kernel.config"
		zcat "${kconfig_file_used}" > "${kconfig_file_tmp}" \
			|| gen_die "Failed to decompress '${kconfig_file_used}' to '${kconfig_file_tmp}'!"

		kconfig_file_used="${kconfig_file_tmp}"
	fi

	if isTrue "${INTEGRATED_INITRAMFS}"
	then
		# Explicitly do not compress if we are integrating into the kernel.
		# The kernel will do a better job of it than us.
		mv "${CPIO_ARCHIVE}" "${CPIO_ARCHIVE}.cpio"

		print_info 1 "$(get_indent 1)>> --integrated-initramfs is set; Setting CONFIG_INITRAMFS_* options ..."

		[ -f "${KCONFIG_MODIFIED_MARKER}" ] && rm "${KCONFIG_MODIFIED_MARKER}"
		[ -f "${KCONFIG_REQUIRED_OPTIONS}" ] && rm "${KCONFIG_REQUIRED_OPTIONS}"

		kconfig_set_opt "${kconfig_file_used}" "CONFIG_BLK_DEV_INITRD" "y"
		kconfig_set_opt "${kconfig_file_used}" "CONFIG_INITRAMFS_SOURCE" "\"${CPIO_ARCHIVE}.cpio\""
		kconfig_set_opt "${kconfig_file_used}" "CONFIG_INITRAMFS_ROOT_UID" "0"
		kconfig_set_opt "${kconfig_file_used}" "CONFIG_INITRAMFS_ROOT_GID" "0"

		set_initramfs_compression_method "${kconfig_file_used}"

		if [ -f "${KCONFIG_MODIFIED_MARKER}" ]
		then
			print_info 1 "$(get_indent 1)>> Running 'make olddefconfig' due to changed kernel options ..."
			pushd "${KERNEL_DIR}" &>/dev/null || gen_die "Failed to chdir to '${KERNEL_DIR}'!"
			compile_generic olddefconfig kernel 2>/dev/null
			popd &>/dev/null || gen_die "Failed to chdir!"
		fi
	else
		if isTrue "${COMPRESS_INITRD}"
		then
			if ! isTrue "${BUILD_KERNEL}" || isTrue "${KERNCACHE_IS_VALID}"
			then
				# We need to initialize COMPRESS_INITRD_TYPE in case it was set
				# to best/fastest and validate if used kernel config can decompress
				# set COMPRESS_INITRD_TYPE at all.
				set_initramfs_compression_method "${kconfig_file_used}"
			fi

			print_info 1 "$(get_indent 1)>> Compressing cpio data (${GKICM_LOOKUP_TABLE_EXT[${COMPRESS_INITRD_TYPE}]}) ..."
			print_info 3 "COMMAND: ${GKICM_LOOKUP_TABLE_CMD[${COMPRESS_INITRD_TYPE}]} ${CPIO_ARCHIVE}" 1 0 1
			${GKICM_LOOKUP_TABLE_CMD[${COMPRESS_INITRD_TYPE}]} "${CPIO_ARCHIVE}" || gen_die "Initramfs compression using '${GKICM_LOOKUP_TABLE_CMD[${COMPRESS_INITRD_TYPE}]}' failed"
			mv -f "${CPIO_ARCHIVE}${GKICM_LOOKUP_TABLE_EXT[${COMPRESS_INITRD_TYPE}]}" "${CPIO_ARCHIVE}" || gen_die "Rename failed"
		else
			print_info 3 "$(get_indent 1)>> --no-compress-initramfs is set; Skipping compression of initramfs ..."
		fi

		## To early load microcode we need to follow some pretty specific steps
		## mostly laid out in linux/Documentation/x86/early-microcode.txt
		## It only loads monolithic ucode from an uncompressed cpio, which MUST
		## be before the other cpio archives in the stream.
		if isTrue "${MICROCODE_INITRAMFS}"
		then
			local cfg_CONFIG_MICROCODE=$(kconfig_get_opt "${kconfig_file_used}" CONFIG_MICROCODE)
			local cfg_CONFIG_MICROCODE_INTEL=$(kconfig_get_opt "${kconfig_file_used}" CONFIG_MICROCODE_INTEL)
			local cfg_CONFIG_MICROCODE_AMD=$(kconfig_get_opt "${kconfig_file_used}" CONFIG_MICROCODE_AMD)
			print_info 1 "$(get_indent 1)>> Adding early-microcode support ..."
			local UCODEDIR="${TEMP}/ucode_tmp/kernel/x86/microcode/"
			mkdir -p "${UCODEDIR}" || gen_die "Failed to create '${UCODEDIR}'!"
			echo 1 > "${TEMP}/ucode_tmp/early_cpio"

			if [ "${cfg_CONFIG_MICROCODE}" != "y" ]
			then
				print_warning 1 "$(get_indent 2)early-microcode: Will add microcode(s) like requested but kernel has set CONFIG_MICROCODE=n"
			fi

			if [[ "${MICROCODE}" == 'all' || "${MICROCODE}" == 'intel' ]]
			then
				if [[ "${cfg_CONFIG_MICROCODE_INTEL}" != "y" ]]
				then
					print_warning 1 "$(get_indent 2)early-microcode: Will add Intel microcode(s) like requested (--microcode=${MICROCODE}) but kernel has set CONFIG_MICROCODE_INTEL=n"
				fi

				if [ -d /lib/firmware/intel-ucode ]
				then
					print_info 1 "$(get_indent 2)early-microcode: Adding GenuineIntel.bin ..."
					cat /lib/firmware/intel-ucode/* > "${UCODEDIR}/GenuineIntel.bin" || gen_die "Failed to concat intel cpu ucode"
				else
					print_warning 1 "$(get_indent 2)early-microcode: Unable to add Intel microcode like requested (--microcode=${MICROCODE}); No ucode is available."
					print_warning 1 "$(get_indent 2)                 Is sys-firmware/intel-microcode[split-ucode] installed?"
				fi
			fi

			if [[ "${MICROCODE}" == 'all' || "${MICROCODE}" == 'amd' ]]
			then
				if [[ "${cfg_CONFIG_MICROCODE_AMD}" != "y" ]]
				then
					print_warning 1 "$(get_indent 2)early-microcode: Will add AMD microcode(s) like requested (--microcode=${MICROCODE}) but kernel has set CONFIG_MICROCODE_AMD=n"
				fi

				if [ -d /lib/firmware/amd-ucode ]
				then
					print_info 1 "$(get_indent 2)early-microcode: Adding AuthenticAMD.bin ..."
					cat /lib/firmware/amd-ucode/*.bin > "${UCODEDIR}/AuthenticAMD.bin" || gen_dir "Failed to concat amd cpu ucode"
				else
					print_warning 1 "$(get_indent 2)early-microcode: Unable to add AMD microcode like requested (--microcode=${MICROCODE}); No ucode is available."
					print_warning 1 "$(get_indent 2)                 Is sys-firmware/linux-firmware installed?"
				fi
			fi

			if [ -f "${UCODEDIR}/AuthenticAMD.bin" -o -f "${UCODEDIR}/GenuineIntel.bin" ]
			then
				print_info 1 "$(get_indent 2)early-microcode: Creating cpio ..."
				pushd "${TEMP}/ucode_tmp" &>/dev/null || gen_die "Failed to chdir to '${TEMP}/ucode_tmp'!"
				log_future_cpio_content
				find . -print0 | "${CPIO_COMMAND}" --quiet --null -o -H newc > ../ucode.cpio || gen_die "Failed to create cpu microcode cpio"
				popd &>/dev/null || gen_die "Failed to chdir!"
				print_info 1 "$(get_indent 2)early-microcode: Prepending early-microcode to initramfs ..."
				cat "${TEMP}/ucode.cpio" "${CPIO_ARCHIVE}" > "${CPIO_ARCHIVE}.early-microcode" || gen_die "Failed to prepend early-microcode to initramfs"
				mv -f "${CPIO_ARCHIVE}.early-microcode" "${CPIO_ARCHIVE}" || gen_die "Rename failed"
			else
				print_warning 1 "$(get_indent 2)early-microcode: No microcode found; Will not prepend any microcode to initramfs ..."
				print_info 1    "$(get_indent 2)                 ${BOLD}Note:${NORMAL} You can set --no-microcode-initramfs if you load microcode on your own"
			fi

			if ! isTrue "${WRAP_INITRD}"
			then
				print_info 1 ''
				print_info 1 "${BOLD}Note:${NORMAL}"
				print_info 1 '--microcode-initramfs option is enabled by default for backward compatability.'
				print_info 1 'If your bootloader can load multiple initramfs it is recommended to load'
				print_info 1 '/boot/{amd,intel}-uc.img instead of embedding microcode into initramfs so you'
				print_info 1 'can update microcode via package update independently of initramfs updates.'
			fi
		else
			print_info 3 "$(get_indent 1)>> --no-microcode-initramfs is set; Skipping early-microcode support ..."
		fi

		if isTrue "${WRAP_INITRD}"
		then
			local mkimage_cmd=$(type -p mkimage)
			[[ -z ${mkimage_cmd} ]] && gen_die "mkimage is not available. Please install package 'dev-embedded/u-boot-tools'."
			local mkimage_args="-A ${ARCH} -O linux -T ramdisk -C ${compression:-none} -a 0x00000000 -e 0x00000000"
			print_info 1 "$(get_indent 1)>> Wrapping initramfs using mkimage ..."
			print_info 2 "$(get_indent 1)${mkimage_cmd} ${mkimage_args} -n ${GK_FILENAME_TEMP_INITRAMFS} -d ${CPIO_ARCHIVE} ${CPIO_ARCHIVE}.uboot"
			${mkimage_cmd} ${mkimage_args} -n "${GK_FILENAME_TEMP_INITRAMFS}" -d "${CPIO_ARCHIVE}" "${CPIO_ARCHIVE}.uboot" >> ${LOGFILE} 2>&1 || gen_die "Wrapping initramfs using mkimage failed"
			mv -f "${CPIO_ARCHIVE}.uboot" "${CPIO_ARCHIVE}" || gen_die "Rename failed"
		fi
	fi

	if isTrue "${CMD_INSTALL}"
	then
		if ! isTrue "${INTEGRATED_INITRAMFS}"
		then
			copy_image_with_preserve \
				"${GK_FILENAME_INITRAMFS_SYMLINK}" \
				"${CPIO_ARCHIVE}" \
				"${GK_FILENAME_INITRAMFS}"
		fi
	fi
}
