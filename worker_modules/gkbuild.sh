#!/bin/bash
# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

__module_main() {
	_gkbuild_main
}

_disable_distcc() {
	if [[ -z "${DISABLE_DISTCC}" ]] || ! isTrue "${DISABLE_DISTCC}"
	then
		return
	fi

	if [[ "$(tc-getCC)" != *distcc* ]] && [[ "$(tc-getCXX)" != *distcc* ]]
	then
		return
	fi

	print_warning 3 "distcc usage for ${P} is known to cause problems; Limiting to localhost ..."
	export DISTCC_HOSTS=localhost

	# We must ensure that parallel jobs aren't set higher than
	# available processing units which would kill the system now
	# that we limited distcc usage to localhost
	local MAKEOPTS_USER=$(makeopts_jobs)
	local MAKEOPTS_MAX=$(get_nproc)
	if [[ ${MAKEOPTS_USER} -gt ${MAKEOPTS_MAX} ]]
	then
		print_warning 3 "MAKEOPTS for ${P} adjusted to -j${MAKEOPTS_MAX} due to disabled distcc support ..."
		export MAKEOPTS="-j${MAKEOPTS_MAX}"
	fi
}

# Remove occurrences of strings from variable given in $1
# Strings removed are matched as globs, so for example
# '-O*' would remove -O1, -O2 etc.
_filter-var() {
	local f x var=$1 new=()
	shift

	for f in ${!var} ; do
		for x in "$@" ; do
			# Note this should work with globs like -O*
			[[ ${f} == ${x} ]] && continue 2
		done
		new+=( "${f}" )
	done
	export ${var}="${new[*]}"
}

_gkbuild_main() {
	_initialize

	addwrite "${TEMP}"

	local all_phases="src_unpack src_prepare src_configure
		src_compile src_install"
	local x

	# Set up the default functions
	for x in ${all_phases} ; do
		case "${x}" in
			src_unpack)
				default_src_unpack() { _src_unpack; }
				;;

			src_prepare)
				default_src_prepare() { _src_prepare; }
				;;

			src_configure)
				default_src_configure() { _src_configure; }
				;;

			src_compile)
				default_src_compile() { _src_compile; }
				;;

			src_install)
				default_src_install() { _src_install; }
				;;

			*)
				eval "default_${x}() {
					die \"${x}() has no default function!\"
				}"
				;;
		esac

		if ! declare -F ${x} >/dev/null && declare -F default_${x} >/dev/null
		then
			eval "${x}() { default; }"
		fi
	done

	_disable_distcc

	local current_phase=
	for current_phase in ${all_phases}
	do
		export GKBUILD_PHASE=${current_phase}

		# Make sure default() points to the correct phase
		eval "default() {
			default_${current_phase}
		}"

		case "${current_phase}" in
			src_compile)
				print_info 2 "$(get_indent 2)${P}: >> Compiling source ..."
				cd "${S}" || die "Failed to chdir to '${S}'!"
				;;

			src_configure)
				print_info 2 "$(get_indent 2)${P}: >> Configuring source ..."
				cd "${S}" || die "Failed to chdir to '${S}'!"
				;;

			src_install)
				print_info 2 "$(get_indent 2)${P}: >> Install to DESTDIR ..."
				cd "${S}" || die "Failed to chdir to '${S}'!"
				;;

			src_prepare)
				print_info 2 "$(get_indent 2)${P}: >> Preparing source ..."
				cd "${S}" || die "Failed to chdir to '${S}'!"
				;;

			src_unpack)
				print_info 2 "$(get_indent 2)${P}: >> Unpacking source ..."
				;;
		esac

		${current_phase} || die "${P} failed in '${current_phase}' phase!"

		# sanity check
		[[ "${current_phase}" == "src_unpack" && ! -d "${S}" ]] \
			&& die "The source directory '${S}' does NOT exist!"
	done

	# We don't use .la files; Let's get rid of them to avoid problems
	# due to invalid paths.
	find "${D}" -name '*.la' -type f -delete

	local BINCACHEDIR=$(dirname "${GKPKG_BINPKG}")
	addwrite "${BINCACHEDIR}"

	print_info 2 "$(get_indent 2)${P}: >> Creating binpkg ..."
	cd "${D}" || die "Failed to chdir to '${D}'!"

	if ! hash scanelf &>/dev/null
	then
		print_warning 3 "'scanelf' not found; Will not ensure that binpkg will not contain dynamically linked binaries."
	else
		print_info 5 "Scanning for dynamically linked programs ..."

		# Limiting scan to /{bin,sbin,usr/bin,usr/sbin} will allow us to keep
		# dynamically linked libs in binpkg which is sometimes required to build
		# other packages.
		local -a executable_files_to_scan=()
		local executable_file_to_scan=
		local executable_file_to_scan_wo_broot= pattern_to_ignore=
		while IFS= read -r -u 3 -d $'\0' executable_file_to_scan
		do
			executable_file_to_scan_wo_broot=${executable_file_to_scan#${D}}

			if [[ -n "${QA_IGNORE_DYNAMICALLY_LINKED_PROGRAM}" ]]
			then
				local pattern_to_ignore=
				for pattern_to_ignore in ${QA_IGNORE_DYNAMICALLY_LINKED_PROGRAM}
				do
					print_info 5 "Using pattern '${pattern_to_ignore}' ..."
					if [[ "${executable_file_to_scan_wo_broot}" =~ ${pattern_to_ignore} ]]
					then
						print_info 5 "Match on '${executable_file_to_scan_wo_broot}'; Will ignore ..."
						executable_file_to_scan=
						break
					else
						print_info 5 "No match on '${executable_file_to_scan_wo_broot}'!"
					fi
				done
			else
				print_info 5 "QA_IGNORE_DYNAMICALLY_LINKED_PROGRAM is not set; Not checking '${executable_file_to_scan_wo_broot}' for exclusion ..."
			fi

			if [[ -n "${executable_file_to_scan}" ]]
			then
				executable_files_to_scan+=( "${executable_file_to_scan}" )
			fi
		done 3< <(find "${D}"/{bin,sbin,usr/bin,usr/sbin} -type f -perm -a+x -print0 2>/dev/null)
		IFS="${GK_DEFAULT_IFS}"
		unset executable_file_to_scan executable_file_to_scan_wo_broot pattern_to_ignore

		local found_dyn_files=
		if [[ -n "${executable_files_to_scan}" ]]
		then
			found_dyn_files=$(scanelf -E ET_DYN "${executable_files_to_scan[@]}" 2>/dev/null)
		fi
	
		if [[ -n "${found_dyn_files}" ]]
		then
			print_error 1 "Found the following dynamically linked programs:"
			print_error 1 "=================================================================" 1 0 1
			print_error 1 "${found_dyn_files}" 1 0 1
			print_error 1 "=================================================================" 1 0 1
			die "Dynamically linked program(s) found in ${P} image!"
		fi
		unset found_dyn_files
	fi

	local -a tar_cmd=( "$(get_tar_cmd "${GKPKG_BINPKG}")" )
	tar_cmd+=( '.' )

	print_info 3 "COMMAND: ${tar_cmd[*]}" 1 0 1
	eval "${tar_cmd[@]}" || die "Failed to create binpkg of ${P} in '${GKPKG_BINPKG}'!"

	if [ -n "${DU_COMMAND}" ]
	then
		print_info 5 "Final size of build root:      $(get_du "${BROOT}")"
		print_info 5 "Final size of build directory: $(get_du "${S}")"
		print_info 5 "Final size of installed tree:  $(get_du "${D}")"
	fi

	cd "${TEMP}" || die "Failed to chdir to '${TEMP}'!"
	if [ ! -f "${TEMP}/.no_cleanup" ]
	then
		rm -rf "${WORKDIR}"
	fi
}

_initialize() {
	if [[ -z "${GKPKG_PN}" ]]
	then
		die "Unable to build: GKPKG_PN not set!"
	elif [[ -z "${GKPKG_PV}" ]]
	then
		die "Unable to build '${PN}': GKPKG_PV not set!"
	else
		declare -gr PN=${GKPKG_PN}
		declare -gr PV=${GKPKG_PV}
		declare -gr P="${PN}-${PV}"
	fi
	
	if [[ -z "${GKPKG_SRCDIR}" ]]
	then
		die "Unable to build ${P}: GKPKG_SRCDIR is not set!"
	elif [[ -z "${GKPKG_SRCTAR}" ]]
	then
		die "Unable to build ${P}: GKPKG_SRCTAR is not set!"
	elif [[ ! -r "${GKPKG_SRCTAR}" ]]
	then
		die "Unable to build ${P}: '${GKPKG_SRCTAR}' does NOT exist or is not readable!"
	elif [[ -z "${GKPKG_BINPKG}" ]]
	then
		die "Unable to build ${P}: GKPKG_BINPKG is not set!"
	elif ! declare -p GKPKG_DEPS >/dev/null
	then
		die "Unable to build ${P}: GKPKG_DEPS is not set!"
	elif [[ -z "${CBUILD}" ]]
	then
		die "Unable to build ${P}: CBUILD not set!"
	elif [[ -z "${CHOST}" ]]
	then
		die "Unable to build ${P}: CHOST is not set!"
	elif [[ -z "${TEMP}" ]]
	then
		die "Unable to build ${P}: TEMP is not set!"
	fi

	print_info 3 "Trying to determine gkbuild for ${P} ..."
	local GKBUILD= f=
	local GKBUILD_CANDIDATES=( "${GK_SHARE}/gkbuilds/${P}.gkbuild" )
	GKBUILD_CANDIDATES+=( "${GK_SHARE}/gkbuilds/${PN}.gkbuild" )
	for f in "${GKBUILD_CANDIDATES[@]}"
	do
		if [[ ! -e "${f}" ]]
		then
			print_info 3 "'${f}' not found; Skipping ..."
			continue
		else
			print_info 3 "Will use '${f}' to build ${P} ..."
			GKBUILD="${f}"
			break
		fi
	done
	unset f GKBUILD_CANDIDATES

	if [[ -z "${GKBUILD}" ]]
	then
		die "Unable to build ${P}: '${GK_SHARE}/gkbuilds/${PN}.gkbuild' does NOT exist!"
	fi

	declare -gr WORKDIR="${TEMP}/${PN}"
	mkdir "${WORKDIR}" || die "Failed to create '${WORKDIR}'!"

	declare -gr BROOT="${WORKDIR}/buildroot"
	mkdir "${BROOT}" || die "Failed to create '${BROOT}'!"

	declare -gr DESTDIR="${WORKDIR}/image"
	mkdir "${DESTDIR}" || die "Failed to create '${DESTDIR}'!"

	declare -gr HOME="${WORKDIR}/home"
	mkdir "${HOME}" || die "Failed to create '${HOME}'!"

	# Set up some known variables used in ebuilds for smooth gkbuild
	# transition
	declare -gr ED=${DESTDIR}
	declare -gr D=${DESTDIR}

	local libdir=$(get_chost_libdir)
	if [[ "${libdir}" =~ ^/(lib|usr/lib) ]]
	then
		declare -gr SYSROOT="/"
	else
		declare -gr SYSROOT="/usr/${CHOST}"
	fi
	unset libdir
	print_info 4 "SYSROOT set to '${SYSROOT}'!"

	declare -gr T="${WORKDIR}/temp"
	mkdir "${T}" || die "Failed to create '${T}'!"

	S="${WORKDIR}/${GKPKG_SRCDIR}"

	source "${GKBUILD}" \
		|| die "Failed to source '${GKBUILD}'!"

	# Some tools like eltpatch (libtoolize) depend on these variables
	export S D

	if [[ -n "${GKPKG_DEPS}" ]]
	then
		IFS=';' read -r -a GKPKG_DEPS <<< "${GKPKG_DEPS}"
		local GKPKG_DEP=
		for GKPKG_DEP in "${GKPKG_DEPS[@]}"
		do
			if [[ ! -r "${GKPKG_DEP}" ]]
			then
				die "Unable to build ${P}: Required binpkg '${GKPKG_DEP}' does NOT exist or is not readable!"
			fi

			print_info 2 "$(get_indent 2)${P}: >> Unpacking required binpkg '${GKPKG_DEP}' ..."
			"${TAR_COMMAND}" -xaf "${GKPKG_DEP}" -C "${BROOT}" \
				|| die "Unable to build ${P}: Failed to extract required binpkg '${GKPKG_DEP}' to '${BROOT}'!"
		done
		unset GKPKG_DEP

		append-cflags -I"${BROOT}"/usr/include
		append-cppflags -I"${BROOT}"/usr/include
		append-cxxflags -I"${BROOT}"/usr/include
		append-ldflags -L"${BROOT}"/usr/lib
	fi

	if [[ ! -d "${BROOT}/usr/bin" ]]
	then
		mkdir -p "${BROOT}"/usr/bin || die "Failed to create '${BROOT}/usr/bin'!"
	fi

	cat >"${BROOT}"/usr/bin/pkg-config-wrapper <<-EOF
	#!/bin/sh

	SYSROOT=\$(dirname "\$(dirname "\$(dirname "\$(readlink -fm "\$0")")")")

	# https://git.dereferenced.org/pkgconf/pkgconf/issues/30
	unset PKG_CONFIG_PATH PKG_CONFIG_DIR LIBRARY_PATH

	export PKG_CONFIG_LIBDIR=\${SYSROOT}/usr/lib/pkgconfig:\${SYSROOT}/usr/share/pkgconfig
	export PKG_CONFIG_SYSROOT_DIR=\${SYSROOT}

	exec pkg-config "\$@"
	EOF

	chmod +x "${BROOT}"/usr/bin/pkg-config-wrapper \
		|| die "Failed to chmod of '${BROOT}/usr/bin/pkg-config-wrapper'!"

	export PATH="${BROOT}/usr/sbin:${BROOT}/usr/bin:${BROOT}/sbin:${BROOT}/bin:${PATH}"
	export PKG_CONFIG="${BROOT}/usr/bin/pkg-config-wrapper"
}

_src_compile() {
	if [ -f Makefile ] || [ -f GNUmakefile ] || [ -f makefile ]
	then
		gkmake V=1
	fi
}

_src_configure() {
	if [[ -x ${GKCONF_SOURCE:-.}/configure ]]
	then
		gkconf
	fi
}

_src_install() {
	if [ -f Makefile ] || [ -f GNUmakefile ] || [ -f makefile ]
	then
		gkmake V=1 DESTDIR="${D}" install
	fi
}

_src_prepare() {
	# let's try to be smart and run autoreconf only when needed
	# when no value was set in gkbuild
	local want_autoreconf=${WANT_AUTORECONF}

	# by default always run libtoolize
	local want_libtoolize=${WANT_LIBTOOLIZE:-yes}

	local patchdir="${GK_SHARE}/patches/${PN}/${PV}"

	uses_autoconf() {
		if [[ -f configure.ac || -f configure.in ]]
		then
			return 0
		fi

		return 1
	}

	at_checksum() {
		find '(' -name 'Makefile.am' \
			-o -name 'configure.ac' \
			-o -name 'configure.in' ')' \
			-exec cksum {} + | sort -k2
	}

	if [ -z "${want_autoreconf}" ] && $(uses_autoconf)
	then
		local checksum=$(at_checksum)
	fi

	if [[ -d "${patchdir}" ]]
	then
		local silent="-s "
		if [[ "${LOGLEVEL}" -gt 3 ]]
		then
			silent=
		fi

		print_info 2 "$(get_indent 2)${P}: >> Applying patches ..."
		local i
		for i in "${patchdir}"/*{diff,patch}
		do
			[ -f "${i}" ] || continue
			local patch_success=0
			local j=
			for j in $(seq 0 5)
			do
				patch -p${j} --backup-if-mismatch -f < "${i}" --dry-run >/dev/null \
					&& patch ${silent}-p${j} --backup-if-mismatch -f < "${i}"
				if [ $? = 0 ]
				then
					patch_success=1
					break
				fi
			done
			if [ ${patch_success} -eq 1 ]
			then
				print_info 3 "$(get_indent 3) - $(basename "${i}")"
			else
				die "Failed to apply patch '${i}' for '${P}'!"
			fi
		done
		unset i j patch_success
	else
		print_info 2 "$(get_indent 2)${P}: >> No patches found in '$patchdir'; Skipping ..."
	fi

	if [ -z "${want_autoreconf}" ] && $(uses_autoconf)
	then
		if [[ ${checksum} != $(at_checksum) ]]
		then
			print_info 3 "$(get_indent 2)${P}: >> Will autoreconfigure due to applied patches ..."
			want_autoreconf=yes
		fi
	fi

	if $(uses_autoconf) && isTrue "${want_autoreconf}"
	then
		gkautoreconf
	fi

	if isTrue "${want_libtoolize}"
	then
		gklibtoolize
	fi
}

_src_unpack() {
	cd "${WORKDIR}" || die "Failed to chdir to '${WORKDIR}'!"
	"${TAR_COMMAND}" -xaf "${GKPKG_SRCTAR}" \
		|| die "Failed to unpack '${GKPKG_SRCTAR}' to '${WORKDIR}'!"
}

# Return all the flag variables that our high level funcs operate on.
all-flag-vars() {
	echo {ADA,C,CPP,CXX,CCAS,F,FC,LD}FLAGS
}

# @FUNCTION: append-cflags
# @USAGE: <flags>
# @DESCRIPTION:
# Add extra <flags> to the current CFLAGS.  If a flag might not be supported
# with different compilers (or versions), then use test-flags-CC like so:
# @CODE
# append-cflags $(test-flags-CC -funky-flag)
# @CODE
append-cflags() {
	[[ $# -eq 0 ]] && return 0
	# Do not do automatic flag testing ourselves. #417047
	export CFLAGS+=" $*"
	return 0
}

# @FUNCTION: append-cppflags
# @USAGE: <flags>
# @DESCRIPTION:
# Add extra <flags> to the current CPPFLAGS.
append-cppflags() {
	[[ $# -eq 0 ]] && return 0
	export CPPFLAGS+=" $*"
	return 0
}

# @FUNCTION: append-cxxflags
# @USAGE: <flags>
# @DESCRIPTION:
# Add extra <flags> to the current CXXFLAGS.  If a flag might not be supported
# with different compilers (or versions), then use test-flags-CXX like so:
# @CODE
# append-cxxflags $(test-flags-CXX -funky-flag)
# @CODE
append-cxxflags() {
	[[ $# -eq 0 ]] && return 0
	# Do not do automatic flag testing ourselves. #417047
	export CXXFLAGS+=" $*"
	return 0
}

# @FUNCTION: append-fflags
# @USAGE: <flags>
# @DESCRIPTION:
# Add extra <flags> to the current {F,FC}FLAGS.  If a flag might not be supported
# with different compilers (or versions), then use test-flags-F77 like so:
# @CODE
# append-fflags $(test-flags-F77 -funky-flag)
# @CODE
append-fflags() {
	[[ $# -eq 0 ]] && return 0
	# Do not do automatic flag testing ourselves. #417047
	export FFLAGS+=" $*"
	export FCFLAGS+=" $*"
	return 0
}

# @FUNCTION: append-flags
# @USAGE: <flags>
# @DESCRIPTION:
# Add extra <flags> to your current {C,CXX,F,FC}FLAGS.
append-flags() {
	[[ $# -eq 0 ]] && return 0
	case " $* " in
	*' '-[DIU]*) die 'please use append-cppflags for preprocessor flags' ;;
	*' '-L*|\
	*' '-Wl,*)  die 'please use append-ldflags for linker flags' ;;
	esac
	append-cflags "$@"
	append-cxxflags "$@"
	append-fflags "$@"
	return 0
}

# @FUNCTION: append-ldflags
# @USAGE: <flags>
# @DESCRIPTION:
# Add extra <flags> to the current LDFLAGS.
append-ldflags() {
	[[ $# -eq 0 ]] && return 0
	export LDFLAGS="${LDFLAGS} $*"
	return 0
}

# @FUNCTION: append-lfs-flags
# @DESCRIPTION:
# Add flags that enable Large File Support.
append-lfs-flags() {
	[[ $# -ne 0 ]] && die "append-lfs-flags takes no arguments"
	# see comments in filter-lfs-flags func for meaning of these
	append-cppflags -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE
}


# @FUNCTION: filter-flags
# @USAGE: <flags>
# @DESCRIPTION:
# Remove particular <flags> from {C,CPP,CXX,CCAS,F,FC,LD}FLAGS.  Accepts shell globs.
filter-flags() {
	local v
	for v in $(all-flag-vars) ; do
		_filter-var ${v} "$@"
	done
	return 0
}

# @FUNCTION: filter-ldflags
# @USAGE: <flags>
# @DESCRIPTION:
# Remove particular <flags> from LDFLAGS.  Accepts shell globs.
filter-ldflags() {
	_filter-var LDFLAGS "$@"
	return 0
}

# @FUNCTION: gkautomake
# @USAGE: [<additional-automake-parameter>]
# @DESCRIPTION:
# Wrapper for automake.
# Will die when command will exit with nonzero exit status.
gkautomake() {
	if [[ -n "${WANT_AUTOMAKE}" ]]
	then
		gkexec "WANT_AUTOMAKE=${WANT_AUTOMAKE} automake ${*}"
	else
		gkexec "automake ${*}"
	fi
}

# @FUNCTION: gkautoreconf
# @USAGE: [<additional-autoreconf-parameter>]
# @DESCRIPTION:
# Wrapper for autoreconf.
# Will die when command will exit with nonzero exit status.
gkautoreconf() {
	# >autoconf-2.69 will call gtkdocize when used in macros
	# when called with --install parameter.
	local -x GTKDOCIZE=true

	gkexec "autoreconf --force --install ${*}"
}

# @FUNCTION: gkconf
# @USAGE: [<additional-configure-parameter>]
# @DESCRIPTION:
# Wrapper for configure.
# Will die when command will exit with nonzero exit status.
gkconf() {
	: ${GKCONF_SOURCE:=.}
	if [ -x "${GKCONF_SOURCE}/configure" ]
	then
		local pid=${BASHPID}
		local x

		if [ -e "/usr/share/gnuconfig/" ]
		then
			find "${WORKDIR}" -type f '(' \
			-name config.guess -o -name config.sub ')' -print0 | \
			while read -r -d $'\0' x ; do
				print_info 3 "$(get_indent 2)${P}: >> Updating ${x/${WORKDIR}\/} with /usr/share/gnuconfig/${x##*/} ..."
				# Make sure we do this atomically incase we're run in parallel. #487478
				cp -f /usr/share/gnuconfig/"${x##*/}" "${x}.${pid}"
				mv -f "${x}.${pid}" "${x}"
			done
		fi

		local -a conf_args=()
		local conf_help=$("${GKCONF_SOURCE}/configure" --help 2>/dev/null)

		if [[ ${conf_help} == *--disable-dependency-tracking* ]]; then
			conf_args+=( --disable-dependency-tracking )
		fi

		if [[ ${conf_help} == *--disable-silent-rules* ]]; then
			conf_args+=( --disable-silent-rules )
		fi

		if [[ ${conf_help} == *--docdir* ]]; then
			conf_args+=( --docdir=/usr/share/doc/${P} )
		fi

		if [[ ${conf_help} == *--htmldir* ]]; then
			conf_args+=( --htmldir=/usr/share/doc/${P}/html )
		fi

		if [[ ${conf_help} == *--with-sysroot* ]]; then
			conf_args+=( "--with-sysroot='${BROOT}/usr:${SYSROOT}'" )
		fi

		# Handle arguments containing quoted whitespace (see bug #457136).
		eval "local -a EXTRA_ECONF=(${EXTRA_ECONF})"

		set -- \
			--prefix=/usr \
			${CBUILD:+--build=${CBUILD}} \
			--host=${CHOST} \
			${CTARGET:+--target=${CTARGET}} \
			--mandir=/usr/share/man \
			--infodir=/usr/share/info \
			--datadir=/usr/share \
			--sysconfdir=/etc \
			--localstatedir=/var/lib \
			"${conf_args[@]}" \
			"$@" \
			"${EXTRA_ECONF[@]}"

		gkexec "${GKCONF_SOURCE}/configure $*"
	elif [ -f "${GKCONF_SOURCE}/configure" ]; then
		die "configure is not executable"
	else
		die "no configure script found"
	fi
}

# @FUNCTION: gklibtoolize
# @USAGE: [dirs] [--portage] [--reverse-deps] [--patch-only] [--remove-internal-dep=xxx] [--shallow] [--no-uclibc]
# @DESCRIPTION:
# Apply a smorgasbord of patches to bundled libtool files.  This function
# should always be safe to run.  If no directories are specified, then
# ${S} will be searched for appropriate files.
#
# If the --shallow option is used, then only ${S}/ltmain.sh will be patched.
#
# The other options should be avoided in general unless you know what's going on.
gklibtoolize() {
	type -P eltpatch &>/dev/null || die "eltpatch not found; is app-portage/elt-patches installed?"

	local command=( "ELT_LOGDIR='${T}'" )
	command+=( "LD='$(tc-getLD)'" )
	command+=( "eltpatch" )
	command+=( "${@}" )

	gkexec "${command[*]}"
}

# @FUNCTION: gkmake
# @USAGE: [<additional-make-parameter>]
# @DESCRIPTION:
# Wrapper for make.
# Will die when command will exit with nonzero exit status.
gkmake() {
	local command=( "${NICEOPTS}${MAKE} ${MAKEOPTS}" )
	command+=( "${@}" )

	gkexec "${command[*]}"
}

# @FUNCTION: replace-flags
# @USAGE: <old> <new>
# @DESCRIPTION:
# Replace the <old> flag with <new>.  Accepts shell globs for <old>.
replace-flags() {
	[[ $# != 2 ]] && die "Usage: replace-flags <old flag> <new flag>"

	local f var new
	for var in $(all-flag-vars) ; do
		# Looping over the flags instead of using a global
		# substitution ensures that we're working with flag atoms.
		# Otherwise globs like -O* have the potential to wipe out the
		# list of flags.
		new=()
		for f in ${!var} ; do
			# Note this should work with globs like -O*
			[[ ${f} == ${1} ]] && f=${2}
			new+=( "${f}" )
		done
		export ${var}="${new[*]}"
	done

	return 0
}
