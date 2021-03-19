#!/bin/bash
# $Id$

isTrue() {
	case "$1" in
		[Tt][Rr][Uu][Ee])
			return 0
		;;
		[Tt])
			return 0
		;;
		[Yy][Ee][Ss])
			return 0
		;;
		[Yy])
			return 0
		;;
		1)
			return 0
		;;
	esac
	return 1
}

set_color_vars() {
	if ! isTrue "${NOCOLOR}"
	then
		BOLD=$'\e[0;01m'
		UNDER=$'\e[4m'
		GOOD=$'\e[32;01m'
		WARN=$'\e[33;01m'
		BAD=$'\e[31;01m'
		NORMAL=$'\e[0m'
	else
		BOLD=''
		UNDER=''
		GOOD=''
		WARN=''
		BAD=''
		NORMAL=''
	fi
}
set_color_vars

dump_debugcache() {
	TODEBUGCACHE=no

	if [ -w "${LOGFILE}" ]
	then
		echo "${DEBUGCACHE}" >> "${LOGFILE}"
	else
		echo "WARNING: Cannot write to '${LOGFILE}'!"
		echo "${DEBUGCACHE}"
	fi

	DEBUGCACHE=
}

# print_info(loglevel, print [, newline [, prefixline [, forcefile ] ] ])
print_info() {
	local reset_x=0
	if [ -o xtrace ]
	then
		set +x
		reset_x=1
	fi

	local NEWLINE=1
	local FORCEFILE=1
	local PREFIXLINE=1
	local SCRPRINT=0
	local STR=''

	[[ ${#} -lt 2 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes at least two arguments (${#} given)!"

	[[ ${#} -gt 5 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes at most five arguments (${#} given)!"

	# IF 3 OR MORE ARGS, CHECK IF WE WANT A NEWLINE AFTER PRINT
	if [ ${#} -gt 2 ]
	then
		if isTrue "$3"
		then
			NEWLINE=1
		else
			NEWLINE=0
		fi
	fi

	# IF 4 OR MORE ARGS, CHECK IF WE WANT TO PREFIX WITH A *
	if [ ${#} -gt 3 ]
	then
		if isTrue "$4"
		then
			PREFIXLINE=1
		else
			PREFIXLINE=0
		fi
	fi

	# IF 5 OR MORE ARGS, CHECK IF WE WANT TO FORCE OUTPUT TO DEBUG
	# FILE EVEN IF IT DOESN'T MEET THE MINIMUM DEBUG REQS
	if [ ${#} -gt 4 ]
	then
		if isTrue "$5"
		then
			FORCEFILE=1
		else
			FORCEFILE=0
		fi
	fi

	# PRINT TO SCREEN ONLY IF PASSED LOGLEVEL IS HIGHER THAN
	# OR EQUAL TO SET LOG LEVEL
	if [[ ${1} -lt ${LOGLEVEL} || ${1} -eq ${LOGLEVEL} ]]
	then
		SCRPRINT=1
	fi

	# RETURN IF NOT OUTPUTTING ANYWHERE
	if [ ${SCRPRINT} -ne 1 -a ${FORCEFILE} -ne 1 ]
	then
		[ ${reset_x} -eq 1 ] && set -x

		return 0
	fi

	# STRUCTURE DATA TO BE OUTPUT TO SCREEN, AND OUTPUT IT
	if [ ${SCRPRINT} -eq 1 ]
	then
		if [ ${PREFIXLINE} -eq 1 ]
		then
			STR="${GOOD}*${NORMAL} ${2}"
		else
			STR="${2}"
		fi

		printf "%b" "${STR}"

		if [ ${NEWLINE} -ne 0 ]
		then
			echo
		fi
	fi

	# STRUCTURE DATA TO BE OUTPUT TO FILE, AND OUTPUT IT
	if [ ${SCRPRINT} -eq 1 -o ${FORCEFILE} -eq 1 ]
	then
		local STRR=${2//${WARN}/}
		STRR=${STRR//${BAD}/}
		STRR=${STRR//${BOLD}/}
		STRR=${STRR//${NORMAL}/}

		if [ ${PREFIXLINE} -eq 1 ]
		then
			STR="* ${STRR}"
		else
			STR="${STRR}"
		fi

		if isTrue "${TODEBUGCACHE}"
		then
			DEBUGCACHE="${DEBUGCACHE}${STR}"
		else
			printf "%b" "${STR}" >> "${LOGFILE}"
		fi

		if [ ${NEWLINE} -ne 0 ]
		then
			if isTrue "${TODEBUGCACHE}"
			then
				DEBUGCACHE="${DEBUGCACHE}"$'\n'
			else
				echo >> "${LOGFILE}"
			fi
		fi
	fi

	[ ${reset_x} -eq 1 ] && set -x

	return 0
}

print_error() {
	GOOD=${BAD} print_info "$@"
}

print_warning() {
	GOOD=${WARN} print_info "$@"
}

can_run_programs_compiled_by_genkernel() {
	local can_run_programs=no

	if ! isTrue "$(tc-is-cross-compiler)"
	then
		can_run_programs=yes
	else
		if [[ ${CBUILD} = x86_64* && ${ARCH} == "x86" ]]
		then
			can_run_programs=yes
		elif [[ ${CBUILD} = powerpc64* && ${ARCH} == "powerpc" ]]
		then
			can_run_programs=yes
		fi
	fi

	echo "${can_run_programs}"
}

has_space_characters() {
	[[ ${#} -ne 1 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly one argument (${#} given)!"

	local testvalue=${1}
	local has_space_characters=no

	local space_pattern='[[:space:]]'
	if [[ "${testvalue}" =~ ${space_pattern} ]]
	then
		has_space_characters=yes
	fi

	echo "${has_space_characters}"
}

is_glibc() {
	if ! hash getconf &>/dev/null
	then
		gen_die "getconf not found. Unable to determine libc implementation!"
	fi

	local is_glibc=no

	getconf GNU_LIBC_VERSION &>/dev/null
	[ $? -eq 0 ] && is_glibc=yes

	echo "${is_glibc}"
}

is_gzipped() {
	[[ ${#} -ne 1 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly one argument (${#} given)!"

	local file_to_check=${1}

	if [ ! -f "${file_to_check}" ]
	then
		gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): File '${file_to_check}' does not exist!"
	fi

	local file_is_gzipped=no
	local file_mimetype=$(file --brief --mime-type "${file_to_check}" 2>/dev/null)

	case "${file_mimetype}" in
		application/x-gzip)
			file_is_gzipped=yes
			;;
		application/gzip)
			file_is_gzipped=yes
			;;
	esac

	echo "${file_is_gzipped}"
}

is_psf_file() {
	[[ ${#} -ne 1 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly one argument (${#} given)!"

	local file_to_check=${1}

	if [ ! -f "${file_to_check}" ]
	then
		gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): File '${file_to_check}' does not exist!"
	fi

	local file_is_psf=no
	local file_brief=$(file --brief "${file_to_check}" 2>/dev/null)

	if [[ "${file_brief}" == *"PC Screen Font"* ]]
	then
		file_is_psf=yes
	fi

	echo "${file_is_psf}"
}

is_valid_ssh_host_keys_parameter_value() {
	local parameter_value=${1}

	local is_valid=no
	case "${parameter_value}" in
		create|create-from-host|runtime)
			is_valid=yes
			;;
	esac

	echo "${is_valid}"
}

is_valid_triplet() {
	[[ ${#} -ne 1 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly one argument (${#} given)!"

	local triplet=${1}
	local is_triplet=no

	if [[ "${triplet}" =~ ^[^-]{2,}-[^-]{2,}-.{2,} ]]
	then
		is_triplet=yes
	fi

	echo "${is_triplet}"
}

# var_replace(var_name, var_value, string)
# $1 = variable name
# $2 = variable value
# $3 = string

var_replace() {
	[[ ${#} -ne 3 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly three arguments (${#} given)!"

	# Escape '\' and '.' in $2 to make it safe to use
	# in the later sed expression
	local SAFE_VAR
	SAFE_VAR=$(echo "${2}" | sed -e 's#\([/.]\)#\\\1#g')

	echo "${3}" | sed -e "s/%%${1}%%/${SAFE_VAR}/g" -
	if [ $? -ne 0 ]
	then
		gen_die "var_replace() failed: 1: '${1}'  2: '${2}'  3: '${3}'"
	fi
}

arch_replace() {
	[[ ${#} -ne 1 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly one argument (${#} given)!"

	var_replace "ARCH" "${ARCH}" "${1}"
}

cache_replace() {
	[[ ${#} -ne 1 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly one argument (${#} given)!"

	var_replace "CACHE" "${GK_V_CACHEDIR}" "${1}"
}

kv_replace() {
	[[ ${#} -ne 1 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly one argument (${#} given)!"

	var_replace "KV" "${KV}" "${1}"
}

# Internal func.  The first argument is the version info to expand.
# Query the preprocessor to improve compatibility across different
# compilers rather than maintaining a --version flag matrix. #335943
_gcc_fullversion() {
	local ver="$1"; shift
	set -- $($(tc-getCPP "$@") -E -P - <<<"__GNUC__ __GNUC_MINOR__ __GNUC_PATCHLEVEL__")
	eval echo "$ver"
}

# @FUNCTION: gcc-fullversion
# @RETURN: compiler version (major.minor.micro: [3.4.6])
gcc-fullversion() {
	_gcc_fullversion '$1.$2.$3' "$@"
}
# @FUNCTION: gcc-version
# @RETURN: compiler version (major.minor: [3.4].6)
gcc-version() {
	_gcc_fullversion '$1.$2' "$@"
}
# @FUNCTION: gcc-major-version
# @RETURN: major compiler version (major: [3].4.6)
gcc-major-version() {
	_gcc_fullversion '$1' "$@"
}
# @FUNCTION: gcc-minor-version
# @RETURN: minor compiler version (minor: 3.[4].6)
gcc-minor-version() {
	_gcc_fullversion '$2' "$@"
}
# @FUNCTION: gcc-micro-version
# @RETURN: micro compiler version (micro: 3.4.[6])
gcc-micro-version() {
	_gcc_fullversion '$3' "$@"
}

gen_die() {
	set +x

	dump_debugcache

	if [ "$#" -gt '0' ]
	then
		print_error 1 "ERROR: ${1}"
	fi

	if [[ -n "${GK_MASTER_PID}" && ${BASHPID} != ${GK_MASTER_PID} ]]
	then
		# We died in a subshell! Let's trigger trap function...
		kill -s SIGTERM ${GK_MASTER_PID}
	else
		if [ -z "${GK_DIED_IN}" ]
		then
			GK_DIED_IN="$(get_useful_function_stack)"
		else
			# We are already dying
			exit 1
		fi

		# Don't trust $LOGFILE before determine_real_args() was called
		if [ -n "${CMD_LOGFILE}" -a -s "${LOGFILE}" ]
		then
			print_error 1 "Please consult '${LOGFILE}' for more information and any"
			print_error 1 "errors that were reported above."
			print_error 1 ''
		fi

		print_error 1 "Report any genkernel bugs to bugs.gentoo.org and"
		print_error 1 "assign your bug to genkernel@gentoo.org. Please include"
		print_error 1 "as much information as you can in your bug report; attaching"
		print_error 1 "'${LOGFILE}' so that your issue can be dealt with effectively."
		print_error 1 ''
		print_error 1 "Please do ${BOLD}*not*${NORMAL} report ${BOLD}kernel${NORMAL} compilation failures as genkernel bugs!"
		print_error 1 ''

		restore_boot_mount_state

		# Cleanup temp dirs and caches if requested
		cleanup
	fi

	exit 1
}

get_grep_cmd_for_file() {
	[[ ${#} -ne 1 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly one argument (${#} given)!"

	local config_file=${1}

	local grep_cmd=${GREP_CMD}
	if isTrue "$(is_gzipped "${config_file}")"
	then
		grep_cmd=${ZGREP_CMD}
	fi

	# zgrep for example is optional
	if [ -z "${grep_cmd}" ]
	then
		gen_die "$(get_useful_function_stack "${FUNCNAME}")No grep implementation found which can process '${config_file}'!"
	fi

	echo "${grep_cmd}"
}

# @FUNCTION: get_indent
# @USAGE: <level>
# @DESCRIPTION:
# Returns the indent level in spaces.
#
# <level> Indentation level.
get_indent() {
	[[ ${#} -ne 1 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly one argument (${#} given)!"

	local _level=${1}
	local _indent=
	local _indentTemplate="        "
	local i=0

	while [[ ${i} -lt ${_level} ]]
	do
		_indent+=${_indentTemplate}
		i=$[$i+1]
	done

	echo "${_indent}"
}

get_initramfs_compression_method_by_compression() {
	local -a methods=()
	methods+=( XZ )
	methods+=( LZMA )
	methods+=( ZSTD )
	methods+=( GZIP )
	methods+=( BZIP2 )
	methods+=( LZO )
	methods+=( LZ4 )

	echo "${methods[@]}"
}

get_initramfs_compression_method_by_speed() {
	local -a methods=()
	methods+=( LZ4 )
	methods+=( ZSTD )
	methods+=( LZO )
	methods+=( GZIP )
	methods+=( BZIP2 )
	methods+=( LZMA )
	methods+=( XZ )

	echo "${methods[@]}"
}

setup_cache_dir() {
	if [ ! -d "${GK_V_CACHEDIR}" ]
	then
		mkdir -p "${GK_V_CACHEDIR}" || gen_die "Failed to create '${GK_V_CACHEDIR}'!"
	fi

	if isTrue "${CLEAR_CACHEDIR}"
	then
		print_info 2 "Clearing cache dir contents from ${CACHE_DIR} ..."
		while read i
		do
			print_info 3 "$(get_indent 1)>> removing ${i}"
			rm "${i}"
		done < <(find "${CACHE_DIR}" -maxdepth 2 -type f -name '*.tar.*' -o -name '*.bz2' -o -name '*.xz')
	fi
}

cleanup() {
	# Child processes we maybe want to kill can only appear in
	# current session
	local session=$(ps -o sess= ${$} 2>/dev/null | awk '{ print $1 }')
	if [ -n "${session}" ]
	then
		# Time to kill any still running child process.
		# All our childs will have GK_SHARE environment variable set.
		local -a killed_pids

		local pid_to_kill=
		while IFS= read -r -u 3 pid_to_kill
		do
			# Don't kill ourselves or we will trigger trap
			[ "${pid_to_kill}" = "${BASHPID}" ] && continue

			# Killing process group allows us to catch grandchilds
			# with clean environment, too.
			if kill -${pid_to_kill} &>/dev/null
			then
				killed_pids+=( ${pid_to_kill} )
			fi
		done 3< <(ps e -s ${session} 2>/dev/null | grep GK_SHARE= 2>/dev/null | awk '{ print $1 }')

		if [ ${#killed_pids[@]} -gt 0 ]
		then
			# Be patient -- still running process could prevent cleanup!
			sleep 3

			# Add one valid pid so that ps command won't fail
			killed_pids+=( ${BASHPID} )

			killed_pids=$(IFS=,; echo "${killed_pids[*]}")

			# Processes had enough time to gracefully terminate!
			while IFS= read -r -u 3 pid_to_kill
			do
				# Don't kill ourselves or we will trigger trap
				[ "${pid_to_kill}" = "${BASHPID}" ] && continue

				kill -9 -${pid_to_kill} &>/dev/null
			done 3< <(ps --no-headers -q ${killed_pids} 2>/dev/null | awk '{ print $1 }')
		fi
	else
		print_warning 1 "Failed to determine session leader; Will not try to stop child processes"
	fi

	if isTrue "${CLEANUP}"
	then
		if [ -n "${TEMP}" -a -d "${TEMP}" ]
		then
			rm -rf "${TEMP}"
		fi

		if isTrue "${POSTCLEAR}"
		then
			echo
			print_info 2 'Running final cache/tmp cleanup ...'
			print_info 3 "CACHE_DIR: ${CACHE_DIR}"
			CLEAR_CACHEDIR=yes setup_cache_dir
			echo
			print_info 3 "TMPDIR: ${TMPDIR}"
			clear_tmpdir
		fi
	else
		print_info 2 "--no-cleanup is set; Skipping cleanup ..."
		print_info 3 "TEMP: ${TEMP}"
		print_info 3 "CACHE_DIR: ${CACHE_DIR}"
		print_info 3 "TMPDIR: ${TMPDIR}"
	fi

	GK_TIME_END=$(date +%s)
	let GK_TIME_RUNTIME_SECONDS=${GK_TIME_END}-${GK_TIME_START}
	let GK_TIME_RUNTIME_DAYS=${GK_TIME_RUNTIME_SECONDS}/86400
	TZ= printf ">>> Ended on: $(date +"%Y-%m-%d %H:%M:%S") (after %d days%(%k hours %M minutes %S seconds)T)\n" ${GK_TIME_RUNTIME_DAYS} ${GK_TIME_RUNTIME_SECONDS} >> "${LOGFILE}" 2>/dev/null
}

clear_tmpdir() {
	if isTrue "${CMD_INSTALL}"
	then
		TMPDIR_CONTENTS=$(ls "${TMPDIR}")
		print_info 2 "Removing tmp dir contents"
		for i in ${TMPDIR_CONTENTS}
		do
			print_info 3 "$(get_indent 1)>> removing ${i}"
			rm -r "${TMPDIR}/${i}"
		done
	fi
}

# @FUNCTION: copy_image_with_preserve
# @USAGE: <symlink name> <source image> <dest image>
# @DESCRIPTION:
# Function to copy various kernel boot image products to the boot directory,
# preserve a generation of old images (just like the manual kernel build's
# "make install" does), and maintain the symlinks (if enabled).
#
# <symlink name> Symlink in the boot directory. Path not included.
#
# <source image> Fully qualified path name of the source image.
#
# <dest image>   Name of the destination image in the boot directory,
#                no path included.
copy_image_with_preserve() {
	[[ ${#} -ne 3 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly three arguments (${#} given)!"

	local symlinkName=${1}
	local newSrceImage=${2}
	local fullDestName=${3}

	local currDestImage
	local prevDestImage

	print_info 3 "Shall copy new ${symlinkName} image, " 0

	# Old product might be a different version.  If so, we need to read
	# the symlink to see what it's name is, if there are symlinks.
	cd "${KERNEL_OUTPUTDIR}" || gen_die "Failed to chdir to '${KERNEL_OUTPUTDIR}'!"
	if isTrue "${SYMLINK}"
	then
		print_info 3 "automatically managing symlinks and old images." 1 0
		if [ -e "${BOOTDIR}/${symlinkName}" ]
		then
			# JRG: Do I need a special case here for when the standard symlink
			# name is, in fact, not a symlink?
			currDestImage=$(readlink --no-newline "${BOOTDIR}/${symlinkName}")
			print_info 4 "Current ${symlinkName} symlink exists:"
			print_info 4 "  ${currDestImage}"
		else
			currDestImage="${fullDestName}"
			print_info 4 "Current ${symlinkName} symlink does NOT exist."
			print_info 4 "  Defaulted to: ${currDestImage}"
		fi

		if [ -e "${BOOTDIR}/${symlinkName}.old" ]
		then
			# JRG: Do I need a special case here for when the standard symlink
			# name is, in fact, not a symlink?
			prevDestImage=$(readlink --no-newline "${BOOTDIR}/${symlinkName}.old")
			print_info 4 "Old ${symlinkName} symlink exists:"
			print_info 4 "  ${prevDestImage}"
		else
			prevDestImage="${fullDestName}.old"
			print_info 4 "Old ${symlinkName} symlink does NOT exist."
			print_info 4 "  Defaulted to: ${prevDestImage}"
		fi
	else
		print_info 3 "symlinks not being handled by genkernel." 1 0
		currDestImage="${fullDestName}"
		prevDestImage="${fullDestName}.old"
	fi

	if [ -e "${BOOTDIR}/${currDestImage}" ]
	then
		local currDestImageExists=yes
		print_info 4 "Actual image file '${BOOTDIR}/${currDestImage}' does exist."
	else
		local currDestImageExists=no
		print_info 4 "Actual image file '${BOOTDIR}/${currDestImage}' does NOT exist."
	fi

	if [ -e "${BOOTDIR}/${prevDestImage}" ]
	then
		local prevDestImageExists=yes
		print_info 4 "Actual old image file '${BOOTDIR}/${prevDestImage}' does exist."
	else
		local prevDestImageExists=no
		print_info 4 "Actual old image file '${BOOTDIR}/${prevDestImage}' does NOT exist."
	fi

	# When symlinks are not being managed by genkernel, old symlinks might
	# still be useful.  Leave 'em alone unless managed.
	if isTrue "${SYMLINK}"
	then
		local -a old_symlinks=()
		old_symlinks+=( "${BOOTDIR}/${symlinkName}" )
		old_symlinks+=( "${BOOTDIR}/${symlinkName}.old" )

		local old_symlink=
		for old_symlink in "${old_symlinks[@]}"
		do
			if [ -L "${old_symlink}" ]
			then
				print_info 4 "Deleting old symlink '${old_symlink}' ..."
				rm "${old_symlink}" || gen_die "Failed to delete '${old_symlink}'!"
			else
				print_info 4 "Old symlink '${old_symlink}' does NOT exist; Skipping ..."
			fi
		done
		unset old_symlinks old_symlink
	fi

	# We only erase the .old image when it is the exact same version as the
	# current and new images.  Different version .old (and current) images are
	# left behind.  This is consistent with how "make install" of the manual
	# kernel build works.
	if [ "${currDestImage}" == "${fullDestName}" ]
	then
		# Case for new and currrent of the same base version.
		print_info 4 "Same base version (${currDestImage})."

		if isTrue "${currDestImageExists}"
		then
			if [ -e "${BOOTDIR}/${currDestImage}.old" ]
			then
				print_info 3 "Deleting old identical ${symlinkName} version '${BOOTDIR}/${currDestImage}.old' ..."
				rm "${BOOTDIR}/${currDestImage}.old" \
					|| gen_die "Failed to delete '${BOOTDIR}/${currDestImage}.old'!"
			fi

			print_info 3 "Moving '${BOOTDIR}/${currDestImage}' to '${BOOTDIR}/${currDestImage}.old' ..."
			mv "${BOOTDIR}/${currDestImage}" "${BOOTDIR}/${currDestImage}.old" \
				|| gen_die "Could not rename the old ${symlinkName} image!"

			prevDestImage="${currDestImage}.old"
			prevDestImageExists=yes
		fi
	else
		# Case for new / current not of the same base version.
		print_info 4 "Different base version."
		prevDestImage="${currDestImage}"
		currDestImage="${fullDestName}"
	fi

	print_info 3 "Copying '${newSrceImage}' to '${BOOTDIR}/${currDestImage}' ..."
	cp -aL "${newSrceImage}" "${BOOTDIR}/${currDestImage}" \
		|| gen_die "Failed to copy '${newSrceImage}' to '${BOOTDIR}/${currDestImage}'!"

	if isTrue "${SYMLINK}"
	then
		print_info 3 "Creating '${symlinkName}' -> '${currDestImage}' symlink ..."
		ln -s "${currDestImage}" "${BOOTDIR}/${symlinkName}" \
			|| gen_die "Failed to create '${symlinkName}' -> '${currDestImage}' symlink!"

		if isTrue "${prevDestImageExists}"
		then
			print_info 3 "Creating '${symlinkName}.old' -> '${prevDestImage}' symlink ..."
			ln -s "${prevDestImage}" "${BOOTDIR}/${symlinkName}.old" \
				|| "Failed to create '${symlinkName}.old' -> '${prevDestImage}' symlink!"
		fi
	fi
}

dropbear_create_key() {
	[[ ${#} -ne 2 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly two arguments (${#} given)!"

	local key_file=${1}
	local command=${2}
	local key_type=$(dropbear_get_key_type_from_filename "${key_file}")

	local -a envvars=(
		"GK_SHARE='${GK_SHARE}'"
		"LOGLEVEL='${LOGLEVEL}'"
		"LOGFILE='${LOGFILE}'"
		"NOCOLOR='${NOCOLOR}'"
		"PATH='${PATH}'"
		"TEMP='${TEMP}'"
	)

	envvars+=(
		"DROPBEAR_COMMAND='${command}'"
		"DROPBEAR_KEY_FILE='${key_file}'"
		"DROPBEAR_KEY_TYPE='${key_type}'"
	)

	if isTrue "${SANDBOX}"
	then
		envvars+=( "SANDBOX_LOG='$(get_temp_file "sandbox_XXXXXX.log")'" )
		envvars+=( "SANDBOX_WRITE='${LOGFILE}:${TEMP}:/proc/thread-self/attr/fscreate'" )
	fi

	# set up worker signal handler
	local error_msg_detail="Failed to create dropbear key '${key_file}'!"
	local error_msg="gen_worker.sh aborted: ${error_msg_detail}"
	trap "gen_die \"${error_msg}\"" SIGABRT SIGHUP SIGQUIT SIGINT SIGTERM

	local dropbear_command=( "env -i" )
	dropbear_command+=( "${envvars[*]}" )
	dropbear_command+=( "${SANDBOX_COMMAND}" )
	dropbear_command+=( "${GK_SHARE}/gen_worker.sh" )
	dropbear_command+=( "dropbear" )
	dropbear_command+=( "2>&1" )
	eval "${dropbear_command[@]}"

	local RET=$?

	# restore default trap
	set_default_gk_trap

	[ ${RET} -ne 0 ] && gen_die "$(get_useful_function_stack)${error_msg_detail}"
}

dropbear_get_key_type_from_filename() {
	[[ ${#} -ne 1 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly one argument (${#} given)!"

	local key=${1}
	local type=

	case "${key}" in
		*_dss_*)
			type=dss
			;;
		*_ecdsa_*)
			type=ecdsa
			;;
		*_ed25519_*)
			type=ed25519
			;;
		*_rsa_*)
			type=rsa
			;;
		*)
			gen_die "Failed to determine key type from '${key}'!"
			;;
	esac

	echo "${type}"
}

dropbear_generate_key_info_file() {
	[[ ${#} -ne 3 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly three arguments (${#} given)!"

	local command=${1}
	local key_info_file=${2}
	local initramfs_dropbear_dir=${3}
	local key_file="${initramfs_dropbear_dir}/$(basename "${key_info_file/%_key.*/_key}")"
	local key_type=$(dropbear_get_key_type_from_filename "${key_file}")

	local -a envvars=(
		"GK_SHARE='${GK_SHARE}'"
		"LOGLEVEL='${LOGLEVEL}'"
		"LOGFILE='${LOGFILE}'"
		"NOCOLOR='${NOCOLOR}'"
		"PATH='${PATH}'"
		"TEMP='${TEMP}'"
	)

	envvars+=(
		"DROPBEAR_COMMAND='${command}'"
		"DROPBEAR_KEY_FILE='${key_file}'"
		"DROPBEAR_KEY_TYPE='${key_type}'"
		"DROPBEAR_KEY_INFO_FILE='${key_info_file}'"
	)

	if isTrue "${SANDBOX}"
	then
		envvars+=( "SANDBOX_LOG='$(get_temp_file "sandbox_XXXXXX.log")'" )
		envvars+=( "SANDBOX_WRITE='${LOGFILE}:${TEMP}:/proc/thread-self/attr/fscreate'" )
	fi

	# set up worker signal handler
	local error_msg_detail="Failed to extract dropbear key information from '${key_file}'!"
	local error_msg="gen_worker.sh aborted: ${error_msg_detail}"
	trap "gen_die \"${error_msg}\"" SIGABRT SIGHUP SIGQUIT SIGINT SIGTERM

	local dropbear_command=( "env -i" )
	dropbear_command+=( "${envvars[*]}" )
	dropbear_command+=( "${SANDBOX_COMMAND}" )
	dropbear_command+=( "${GK_SHARE}/gen_worker.sh" )
	dropbear_command+=( "dropbear" )
	dropbear_command+=( "2>&1" )
	eval "${dropbear_command[@]}"

	local RET=$?

	# restore default trap
	set_default_gk_trap

	[ ${RET} -ne 0 ] && gen_die "$(get_useful_function_stack)${error_msg_detail}"
}

# @FUNCTION: debug_breakpoint
# @USAGE: [<NAME>]
# @DESCRIPTION:
# Internal helper function which can be used during development to act like
# a breakpoint. I.e. will stop execution and show some variables.
#
# <NAME> Give breakpoint a name
debug_breakpoint() {
	set +x
	local name=${1}
	[ -n "${name}" ] && name=" '${name}'"

	echo "Debug breakpoint${name} reached"
	echo "TEMP: ${TEMP}"
	[[ -n "${WORKDIR}" ]] && echo "WORKDIR: ${WORKDIR}"
	[[ -n "${S}" ]] && echo "S: ${S}"
	[[ -n "${D}" ]] && echo "D: ${D}"

	if [ -n "${GK_WORKER_MASTER_PID}" ]
	then
		[[ ${BASHPID:-$(__bashpid)} == ${GK_WORKER_MASTER_PID} ]] || kill -s SIGTERM ${GK_WORKER_MASTER_PID}
	else
		[[ ${BASHPID:-$(__bashpid)} == ${GK_MASTER_PID} ]] || kill -s SIGTERM ${GK_MASTER_PID}
	fi

	exit 99
}

get_chost_libdir() {
	local cc=$(tc-getCC)

	local test_file=$(${cc} -print-file-name=libc.a 2>/dev/null)
	if [ -z "${test_file}" ]
	then
		gen_die "$(get_useful_function_stack "${FUNCNAME}")Unable to determine CHOST's libdir: '${cc} -print-file-name=libc.a' returned nothing!"
	elif [[ "${test_file}" == "libc.a" ]]
	then
		gen_die "$(get_useful_function_stack "${FUNCNAME}")Unable to determine CHOST's libdir: '${cc} -print-file-name=libc.a' returned no path!"
	fi

	local test_file_realpath=$(realpath "${test_file}" 2>/dev/null)
	if [ -z "${test_file_realpath}" ]
	then
		gen_die "$(get_useful_function_stack "${FUNCNAME}")Unable to determine CHOST's libdir: 'realpath \"${test_file}\"' returned nothing!"
	fi

	local libdir=$(dirname "${test_file_realpath}" 2>/dev/null)
	if [ -z "${libdir}" ]
	then
		gen_die "$(get_useful_function_stack "${FUNCNAME}")Unable to determine CHOST's libdir!"
	fi

	echo "${libdir}"
}

get_du() {
	[[ ${#} -ne 1 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly one argument (${#} given)!"

	[ -z "${DU_COMMAND}" ] && return

	local sz=( $("${DU_COMMAND}" -hs "${1}" 2>/dev/null) )
	echo "${sz[0]}"
}

_get_gkpkg_var_value() {
	[[ ${#} -ne 2 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly two arguments (${#} given)!"

	local VARNAME=${1}
	case "${VARNAME}" in
		BINPKG|DEPS|PN|PV|SRCDIR|SRCTAR)
			;;
		*)
			# Let's make variable support explicit
			gen_die "$(get_useful_function_stack)Variable '${VARNAME}' is not supported by ${FUNCNAME}()!"
			;;
	esac

	local PN=${2}
	[[ -z "${PN}" ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): No package specified!"

	[[ -z "${GKPKG_LOOKUP_TABLE[${PN}]}" ]] \
		&& gen_die "$(get_useful_function_stack)Internal error: Package '${PN}' is unknown! Was package added to software.sh?"

	local REQUESTED_VARNAME="${GKPKG_LOOKUP_TABLE[${PN}]}_${VARNAME}"
	local REQUESTED_VALUE="${!REQUESTED_VARNAME}"
	[[ ${VARNAME} != 'DEPS' && -z "${REQUESTED_VALUE}" ]] \
		&& gen_die "$(get_useful_function_stack)Internal error: Variable '${REQUESTED_VARNAME}' is not set!"

	echo "${REQUESTED_VALUE}"
}

get_gkpkg_binpkg() {
	[[ ${#} -ne 1 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly one argument (${#} given)!"

	local PN=${1}

	_get_gkpkg_var_value BINPKG ${PN}
}

get_gkpkg_deps() {
	[[ ${#} -ne 1 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly one argument (${#} given)!"

	local PN=${1}
	[[ -z "${PN}" ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): No package specified!"

	_get_gkpkg_var_value DEPS ${PN}
}

get_gkpkg_srcdir() {
	[[ ${#} -ne 1 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly one argument (${#} given)!"

	local PN=${1}
	[[ -z "${PN}" ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): No package specified!"

	_get_gkpkg_var_value SRCDIR ${PN}
}

get_gkpkg_srctar() {
	[[ ${#} -ne 1 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly one argument (${#} given)!"

	local PN=${1}
	[[ -z "${PN}" ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): No package specified!"

	_get_gkpkg_var_value SRCTAR ${PN}
}

get_gkpkg_version() {
	[[ ${#} -ne 1 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly one argument (${#} given)!"

	local PN=${1}
	[[ -z "${PN}" ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): No package specified!"

	_get_gkpkg_var_value PV ${PN}
}

# @FUNCTION: get_tar_cmd
# @USAGE: <ARCHIVE>
# @DESCRIPTION:
# Returns tar command which can make use of pbzip2, pxz or pigz when
# possible.
#
# <ARCHIVE> Archive file
get_tar_cmd() {
	[[ ${#} -ne 1 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly one arguments (${#} given)!"

	local archive_file=${1}

	local -a tar_cmd
	tar_cmd+=( "${TAR_COMMAND}" )
	tar_cmd+=( '-c' )

	local pcmd
	if [[ "${archive_file}" == *.tar.bz2 ]]
	then
		pcmd=$(which pbzip2 2>/dev/null)
	elif [[ "${archive_file}" == *.tar.xz ]]
	then
		pcmd=$(which pxz 2>/dev/null)
	elif [[ "${archive_file}" == *.tar.gz ]]
	then
		pcmd=$(which pigz 2>/dev/null)
	fi

	if [ -n "${pcmd}" ]
	then
		tar_cmd+=( "-I ${pcmd}" )
	else
		tar_cmd+=( '-a' )
	fi

	tar_cmd+=( '-pf' )
	tar_cmd+=( "${archive_file}" )

	echo "${tar_cmd[@]}"
}

get_tc_vars() {
	local -a tc_vars=()
	tc_vars+=( AR )
	tc_vars+=( AS )
	tc_vars+=( CC )
	tc_vars+=( CPP )
	tc_vars+=( CXX )
	tc_vars+=( LD )
	tc_vars+=( STRIP )
	tc_vars+=( NM )
	tc_vars+=( RANLIB )
	tc_vars+=( READELF )
	tc_vars+=( OBJCOPY )
	tc_vars+=( OBJDUMP )
	tc_vars+=( PKG_CONFIG )

	echo "${tc_vars[@]}"
}

# @FUNCTION: get_temp_file
# @USAGE: [<TEMPLATE>] [<TMPDIR>]
# @DESCRIPTION:
# Create and return a temporary file (wrapper for mktemp with
# built-in error checking and handling).
#
# <TEMPLATE> TEMPLATE must contain at least 3 consecutive 'X's in
#            last component.
#            Defaults to tmp_XXXXXXXX
#
# <TMPDIR>   Directory where the temporary file will be created in.
#            Defaults to $TEMP
get_temp_file() {
	local template=${1:-"tmp_XXXXXXXX"}
	local tmpdir=${2:-"${TEMP}"}
	local tempfile=$(mktemp -p "${tmpdir}" ${template} 2>/dev/null)

	[ -z "${tempfile}" ] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")'mktemp -p \"${tmpdir}\" ${template}' failed!"

	echo "${tempfile}"
}

get_udevdir() {
	local pkg_config=$(tc-getPKG_CONFIG)

	if ${pkg_config} --exists udev
	then
		local udevdir="$(${pkg_config} --variable=udevdir udev)"

		if [ -n "${BROOT}" ]
		then
			udevdir="${udevdir#${BROOT%/}}"
		fi
	else
		udevdir="/lib/udev"
	fi

	echo "${udevdir}"
}

get_useful_function_stack() {
	local end_function=${1:-${FUNCNAME}}
	local n_functions=${#FUNCNAME[@]}
	local last_function=$(( n_functions - 1 )) # -1 because arrays are starting with 0
	local first_function=0

	local stack_str=
	local last_function_name=
	while [ ${last_function} -gt ${first_function} ]
	do
		last_function_name=${FUNCNAME[last_function]}
		last_function=$(( last_function - 1 ))

		case "${last_function_name}" in
			__module_main|main)
				# filter main function
				continue
				;;
			${end_function})
				# this the end
				break
				;;
			*)
				;;
		esac

		stack_str+="${last_function_name}(): "
	done

	echo "${stack_str}"
}

_tc-getPROG() {
	local tuple=${!1:-""}
	local v var vars=$2
	local prog=( $3 )

	var=${vars%% *}
	for v in ${vars} ; do
		if [[ -n ${!v} ]] ; then
			export ${var}="${!v}"
			echo "${!v}"
			return 0
		fi
	done

	# We allow user to specify different CC/AS/MAKE/LD... values for
	# building kernel and utilities. To avoid having multiple tc-get*
	# functions, we default to utilities and allow switching via
	# TC_PROG_TYPE variable.
	local type=UTILS
	if [ -n "${TC_PROG_TYPE}" -a "${TC_PROG_TYPE}" = "KERNEL" ]
	then
		type=KERNEL
	fi

	local prog_default_varname=
	local prog_override_varname=
	for v in ${vars} ; do
		prog_default_varname="DEFAULT_${type}_${v}"
		if [[ -n "${!prog_default_varname}" ]]
		then
			prog_override_varname="${type}_${v}"
			break
		fi
	done

	if [[ -n "${!prog_default_varname}" ]] \
		&& [[ -n "${!prog_override_varname}" ]] \
		&& [[ "${!prog_override_varname}" != "${!prog_default_varname}" ]]
	then
		# User wants to run specific program
		prog[0]=${!prog_override_varname}
	elif isTrue "$(tc-is-cross-compiler)"
	then
		# Let's try to handle multilib:
		# We will mimic profile's make.defaults.

		local multilib_cflags multilib_ldflags
		local cpu_cbuild=${CBUILD%%-*}
		local cpu_chost=${CHOST%%-*}

		case "${cpu_cbuild}" in
			powerpc64*)
				if [[ "${cpu_chost}" == "powerpc" ]]
				then
					tuple=${tuple/${cpu_chost}/${cpu_cbuild}}
					multilib_cflags="-m32"
					multilib_ldflags="-m elf32ppc"
				fi
				;;
			x86_64*)
				if [[ "${cpu_chost}" == "i686" ]]
				then
					# changing tuple so that we don't call pure gcc
					tuple=${tuple/${cpu_chost}/${cpu_cbuild}}
					multilib_cflags="-m32"
					multilib_ldflags="-m elf_i386"
				fi
				;;
		esac

		case "${var}" in
			CC)
				[[ -n "${multilib_cflags}" ]] && prog+=( "${multilib_cflags}" )
				;;
			CXX)
				[[ -n "${multilib_cflags}" ]] && prog+=( "${multilib_cflags}" )
				;;
			LD)
				[[ -n "${multilib_ldflags}" ]] &&  prog+=( "${multilib_ldflags}" )
				;;
		esac
	fi

	local search=
	[[ -n ${tuple} ]] && search=$(type -p "${tuple}-${prog[0]}")
	[[ -n ${search} ]] && prog[0]=${search##*/}

	export ${var}="${prog[*]}"
	echo "${!var}"
}

tc-export() {
	local var
	for var in "$@"
	do
		[[ $(type -t "tc-get${var}") != "function" ]] && gen_die "tc-export: invalid export variable '${var}'"
		"tc-get${var}" > /dev/null
	done
}

tc-getAR() {
	tc-getPROG AR ar "$@"
}

tc-getAS() {
	tc-getPROG AS as "$@"
}

tc-getBUILD_AR() {
	tc-getBUILD_PROG AR ar "$@"
}

tc-getBUILD_CC() {
	tc-getBUILD_PROG CC gcc "$@"
}

tc-getBUILD_CPP() {
	local cc=$(tc-getBUILD_CC)
	tc-getPROG CPP "${cc} -E" "$@"
}

tc-getBUILD_CXX() {
	tc-getBUILD_PROG CXX g++ "$@"
}

tc-getBUILD_LD() {
	tc-getBUILD_PROG LD ld "$@"
}

tc-getBUILD_READELF() {
	tc-getBUILD_PROG READELF readelf "$@"
}

tc-getCC() {
	tc-getPROG CC gcc "$@"
}

tc-getCPP() {
	local cc=$(tc-getCC)
	tc-getPROG CPP "${cc} -E" "$@"
}

tc-getCXX() {
	tc-getPROG CXX g++ "$@"
}

tc-getLD() {
	tc-getPROG LD ld "$@"
}

tc-getNM() {
	tc-getPROG NM nm "$@"
}

tc-getOBJCOPY() {
	tc-getPROG OBJCOPY objcopy "$@"
}

tc-getOBJDUMP() {
	tc-getPROG OBJDUMP objdump "$@"
}

tc-getPKG_CONFIG() {
	if [ -n "${BROOT}" ]
	then
		echo "${BROOT}/usr/bin/pkg-config-wrapper"
	else
		tc-getPROG PKG_CONFIG pkg-config "$@"
	fi
}

tc-getREADELF() {
	tc-getPROG READELF readelf "$@"
}

tc-getBUILD_PROG() {
	local vars="BUILD_$1 $1_FOR_BUILD HOST$1"
	# respect host vars if not cross-compiling
	# https://bugs.gentoo.org/630282
	isTrue "$(tc-is-cross-compiler)" || vars+=" $1"
	_tc-getPROG CBUILD "${vars}" "${@:2}"
}

tc-getPROG() {
	_tc-getPROG CHOST "$@"
}

tc-getRANLIB() {
	tc-getPROG RANLIB ranlib "$@"
}

tc-getSTRIP() {
	tc-getPROG STRIP strip "$@"
}

tc-is-cross-compiler() {
	local wants_cross_compile=no
	if [[ "${CBUILD:-${CHOST}}" != "${CHOST}" ]]
	then
		wants_cross_compile=yes
	fi

	echo ${wants_cross_compile}
}

trap_cleanup() {
	# Call exit code of 1 for failure
	if [ -t 0 ]
	then
		# try to restore output in case we were trapped while
		# redirecting output...
		exec &> /dev/tty
	fi

	local signal_msg=
	if [ -n "${GK_TRAP_SIGNAL}" ]
	then
		case "${GK_TRAP_SIGNAL}" in
			SIGABRT|SIGHUP|SIGQUIT|SIGINT|SIGTERM)
				signal_msg=" (signal ${GK_TRAP_SIGNAL} received)"
				;;
			*)
				signal_msg=" (unknown signal ${GK_TRAP_SIGNAL} received)"
				;;
		esac
	fi

	echo ''
	print_error 1 "Genkernel was unexpectedly terminated${signal_msg}."
	print_error 1 "Please consult '${LOGFILE}' for more information and any"
	print_error 1 "errors that were reported above."
	restore_boot_mount_state silent
	cleanup
	exit 1
}

# @FUNCTION: gkbuild
# @USAGE: <PKG> <PKG_VERSION> <PKG_SRCDIR> <PKG_SRCTAR> <PKG_BINCACHE> [<PKG_DEPS>]
# @DESCRIPTION:
# Builds a package for genkernel's initramfs, with cross-compile support.
#
# Genkernel's initramfs uses various utilities like Busybox, LVM,
# MDADM, cryptsetup or others. gkbuild() will run an ebuild-like script
# to build such utilities in sandbox environment with cross-compile
# support (requires existing cross-compile toolchain!).
#
# For developers:
# Any package you want to build using gkbuild() must be correctly added to
# ${GK_SHARE}/software.sh file, check_distfiles() and determine_real_args()
# function.
#
# For users:
# Any package you want to add must have set same (initialized!) variables
# like you can see in ${GK_SHARE}/software.sh.
#
# <PKG> Name of the package (as used in ${GK_SHARE}/patches).
#
# <PKG_VERSION> Version of the package.
#
# <PKG_SRCDIR> Source directory when unpacked.
#
# <PKG_SRCTAR> Source file. Only archives supported by `tar -xaf` are
# supported.
#
# <PKG_BINCACHE> File where genkernel will store the package's image.
#
# <PKG_DEPS> Single word string of required package's PKG_BINCACHE.
gkbuild() {
	[[ ${#} -lt 5 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes at least five arguments (${#} given)!"
	[[ ${#} -gt 7 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes at most six arguments (${#} given)!"

	local PKG=${1}
	local VERSION=${2}
	local SRCDIR=${3}
	local SRCTAR=${4}
	local BINPKG=${5}

	if [[ "$#" -eq '6' ]]
	then
		local DEPS=${6}
	else
		local DEPS=""
	fi

	if [ -z "${PKG}" ]
	then
		gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): PKG is not set!"
	elif [ -z "${VERSION}" ]
	then
		gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): VERSION is not set!"
	elif [ -z "${SRCDIR}" ]
	then
		gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): SRCDIR is not set!"
	elif [ -z "${SRCTAR}" ]
	then
		gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): SRCTAR is not set!"
	elif [ -z "${BINPKG}" ]
	then
		gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): BINPKG is not set!"
	fi

	local -a envvars=(
		"GK_SHARE='${GK_SHARE}'"
		"LOGLEVEL='${LOGLEVEL}'"
		"LOGFILE='${LOGFILE}'"
		"NOCOLOR='${NOCOLOR}'"
		"PATH='${PATH}'"
		"TEMP='${TEMP}'"
		"TMPDIR='${TEMP}'"
	)

	envvars+=(
		"GKPKG_PN='${PKG}'"
		"GKPKG_PV='${VERSION}'"
		"GKPKG_SRCDIR='${SRCDIR}'"
		"GKPKG_SRCTAR='${SRCTAR}'"
		"GKPKG_BINPKG='${BINPKG}'"
		"GKPKG_DEPS='${DEPS}'"
		"DU_COMMAND='${DU_COMMAND}'"
		"TAR_COMMAND='${TAR_COMMAND}'"
	)

	envvars+=(
		"CFLAGS='${CMD_UTILS_CFLAGS}'"
		"CXXFLAGS='${CMD_UTILS_CFLAGS}'"
		"CBUILD='${CBUILD}'"
		"CHOST='${CHOST}'"
		"AR='$(tc-getAR)'"
		"AS='$(tc-getAS)'"
		"CC='$(tc-getCC)'"
		"CPP='$(tc-getCPP)'"
		"CXX='$(tc-getCXX)'"
		"LD='$(tc-getLD)'"
		"NM='$(tc-getNM)'"
		"MAKE='${CMD_UTILS_MAKE}'"
		"OBJCOPY='$(tc-getOBJCOPY)'"
		"OBJDUMP='$(tc-getOBJDUMP)'"
		"RANLIB='$(tc-getRANLIB)'"
		"READELF='$(tc-getREADELF)'"
		"STRIP='$(tc-getSTRIP)'"
	)

	local envvar_prefix envvars_to_export envvar_to_export
	for envvar_prefix in CCACHE_ DISTCC_
	do
		envvars_to_export=$(compgen -A variable | grep "^${envvar_prefix}")
		for envvar_to_export in ${envvars_to_export}
		do
			[ -z "${envvar_to_export}" ] && break

			envvars+=( "${envvar_to_export}='${!envvar_to_export}'" )
		done
	done
	unset envvar_prefix envvars_to_export envvar_to_export

	if [ ${NICE} -ne 0 ]
	then
		NICEOPTS="nice -n${NICE} "
	else
		NICEOPTS=""
	fi
	envvars+=( "NICEOPTS='${NICEOPTS}'" )

	envvars+=( "MAKEOPTS='${MAKEOPTS}'" )

	if isTrue "${SANDBOX}"
	then
		envvars+=( "SANDBOX_LOG='$(get_temp_file "sandbox_XXXXXX.log")'" )
		envvars+=( "SANDBOX_WRITE='${LOGFILE}:${TEMP}:/proc/thread-self/attr/fscreate'" )
	fi

	# set up gkbuild signal handler
	local error_msg="gen_worker.sh aborted: Failed to compile ${PKG}-${VERSION}!"
	trap "gen_die \"${error_msg}\"" SIGABRT SIGHUP SIGQUIT SIGINT SIGTERM

	local build_command=( "env -i" )
	build_command+=( "${envvars[*]}" )
	build_command+=( "${SANDBOX_COMMAND}" )
	build_command+=( "${GK_SHARE}/gen_worker.sh" )
	build_command+=( "build" )
	build_command+=( "2>&1" )
	eval "${build_command[@]}"

	local RET=$?

	# remove gkbuild signal handler
	set_default_gk_trap

	[ ${RET} -ne 0 ] && gen_die "$(get_useful_function_stack)Failed to create binpkg of ${PKG}-${VERSION}!"
}

# @FUNCTION: unpack
# @USAGE: <ARCHIVE> <DEST>
# @DESCRIPTION:
# Unpack archive file to dest dir using sandbox.
#
# <ARCHIVE> Archive to unpack.
#
# <DEST> Folder to unpack to.
unpack() {
	[[ ${#} -ne 2 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly two arguments (${#} given)!"

	local unpack_file=${1}
	local unpack_dir=${2}

	local -a envvars=(
		"GK_SHARE='${GK_SHARE}'"
		"LOGLEVEL='${LOGLEVEL}'"
		"LOGFILE='${LOGFILE}'"
		"NOCOLOR='${NOCOLOR}'"
		"PATH='${PATH}'"
		"TEMP='${TEMP}'"
	)

	envvars+=(
		"TAR_COMMAND='${TAR_COMMAND}'"
		"UNPACK_FILE='${unpack_file}'"
		"UNPACK_DIR='${unpack_dir}'"
	)

	if isTrue "${SANDBOX}"
	then
		envvars+=( "SANDBOX_LOG='$(get_temp_file "sandbox_XXXXXX.log")'" )
		envvars+=( "SANDBOX_WRITE='${LOGFILE}:${TEMP}:/proc/thread-self/attr/fscreate'" )
	fi

	# set up unpack signal handler
	local error_msg_detail="Failed to unpack '${unpack_file}' to '${unpack_dir}'!"
	local error_msg="gen_worker.sh aborted: ${error_msg_detail}"
	trap "gen_die \"${error_msg}\"" SIGABRT SIGHUP SIGQUIT SIGINT SIGTERM

	local unpack_command=( "env -i" )
	unpack_command+=( "${envvars[*]}" )
	unpack_command+=( "${SANDBOX_COMMAND}" )
	unpack_command+=( "${GK_SHARE}/gen_worker.sh" )
	unpack_command+=( "unpack" )
	unpack_command+=( "2>&1" )
	eval "${unpack_command[@]}"

	local RET=$?

	# restore default trap
	set_default_gk_trap

	[ ${RET} -ne 0 ] && gen_die "$(get_useful_function_stack)${error_msg_detail}"
}

set_default_gk_trap() {
	local signal
	for signal in SIGABRT SIGHUP SIGQUIT SIGINT SIGTERM
	do
		trap "GK_TRAP_SIGNAL=${signal}; trap_cleanup" ${signal}
	done
}

#
# Helper function to allow command line arguments to override configuration
# file specified values and to apply defaults.
#
# Arguments:
#     $1  Argument type:
#           1  Switch type arguments (e.g., --color / --no-color).
#           2  Value type arguments (e.g., --debuglevel=5).
#     $2  Config file variable name.
#     $3  Command line variable name.
#     $4  Default.  If both the config file variable and the command line
#         option are not present, then the config file variable is set to
#         this default value.  Optional.
#
# The order of priority of these three sources (highest first) is:
#     Command line, which overrides
#     Config file (/etc/genkernel.conf), which overrides
#     Default.
#
# Arguments $2 and $3 are variable *names*, not *values*.  This function uses
# various forms of indirection to access the values.
#
# For switch type arguments, all forms of "True" are converted to a numeric 1
# and all forms of "False" (everything else, really) to a numeric 0.
#
# - JRG
#
set_config_with_override() {
	local VarType=${1}
	local CfgVar=${2}
	local OverrideVar=${3}
	local Default=${4}
	local Result

	#
	# Syntax check the function arguments.
	#
	case "${VarType}" in
		BOOL|STRING)
			;;
		*)
			gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Variable type \"${VarType}\" is unknown!"
			;;
	esac

	if [ -n "${!OverrideVar}" ]
	then
		Result=${!OverrideVar}
		if [ -n "${!CfgVar}" ]
		then
			print_info 5 "  ${CfgVar} overridden on command line to \"${Result}\"."
		else
			print_info 5 "  ${CfgVar} set on command line to \"${Result}\"."
		fi
	else
		if [ -n "${!CfgVar}" ]
		then
			Result=${!CfgVar}
			# we need to set the CMD_* according to configfile...
			eval ${OverrideVar}=\"${Result}\" \
				|| small_die "Failed to set variable '${OverrideVar}=${Result}' !"

			print_info 5 "  ${CfgVar} set in config file to \"${Result}\"."
		else
			if [ -n "${Default}" ]
			then
				Result=${Default}
				# set OverrideVar to Result, otherwise CMD_* may not be initialized...
				eval ${OverrideVar}=\"${Result}\" \
					|| small_die "Failed to set variable '${OverrideVar}=${Result}' !"

				print_info 5 "  ${CfgVar} defaulted to \"${Result}\"."
			else
				print_info 5 "  ${CfgVar} not set."
			fi
		fi
	fi

	if [ "${VarType}" = BOOL ]
	then
		if isTrue "${Result}"
		then
			Result=1
		else
			Result=0
		fi
	fi

	eval ${CfgVar}=\"${Result}\" \
		|| small_die "Failed to set variable '${CfgVar}=${Result}' !"
}

# @FUNCTION: restore_boot_mount_state
# @USAGE: [<silent>]
# @DESCRIPTION:
# Restores mount state of boot partition to state before genkernel start.
#
# <silent> When set makes umount errors non-fatal and will use a loglevel
#          of 5 for any output.
restore_boot_mount_state() {
	local silent=no
	[ -n "${1}" ] && silent=yes

	isTrue "${MOUNTBOOT}" || return

	if [ -f "${TEMP}/.bootdir.remount" ]
	then
		local msg="mount: >> Automatically remounting boot partition as read-only on '${BOOTDIR}' as it was previously ..."
		if isTrue "${silent}"
		then
			print_info 5 "${msg}"
		else
			print_info 1 '' 1 0
			print_info 1 "${msg}"
		fi

		mount -o remount,ro "${BOOTDIR}" &>/dev/null
		if [ $? -ne 0 ]
		then
			local error_msg="Failed to restore read-only state of boot partition on '${BOOTDIR}'!"
			if isTrue "${silent}"
			then
				print_error 1 "${error_msg}"
				return
			else
				gen_die "${error_msg}"
			fi
		else
			rm "${TEMP}/.bootdir.remount" \
				|| gen_die "Failed to remove bootdir state file '${TEMP}/.bootdir.remount'!"
		fi
	elif [ -f "${TEMP}/.bootdir.mount" ]
	then
		local msg="mount: >> Automatically unmounting boot partition from '${BOOTDIR}' as it was previously ..."
		if isTrue "${silent}"
		then
			print_info 5 "${msg}"
		else
			print_info 1 '' 1 0
			print_info 1 "${msg}"
		fi

		umount "${BOOTDIR}" &>/dev/null
		if [ $? -ne 0 ]
		then
			local error_msg="Failed to restore mount state of boot partition on '${BOOTDIR}'!"
			if isTrue "${silent}"
			then
				print_error 1 "${error_msg}"
				return
			else
				gen_die "${error_msg}"
			fi
		else
			rm "${TEMP}/.bootdir.mount" \
				|| gen_die "Failed to remove bootdir state file '${TEMP}/.bootdir.mount'!"
		fi
	else
		local msg="mount: >> Boot partition state on '${BOOTDIR}' was not changed; Skipping restore boot partition state ..."
		if [ -f "${TEMP}/.bootdir.no_boot_partition" ]
		then
			msg="mount: >> '${BOOTDIR}' is not a mountpoint; Nothing to restore ..."

			rm "${TEMP}/.bootdir.no_boot_partition" \
				|| gen_die "Failed to remove bootdir state file '${TEMP}/.bootdir.no_boot_partition'!"
		fi

		print_info 5 '' 1 0
		print_info 5 "${msg}"

		return
	fi
}

rootfs_type_is() {
	local fstype=$1

	# It is possible that the awk will return MULTIPLE lines, depending on your
	# initramfs setup (one of the entries will be 'rootfs').
	if awk '($2=="/"){print $3}' /proc/mounts | grep -sq --line-regexp "${fstype}"
	then
		echo yes
	else
		echo no
	fi
}

check_disk_space_requirements() {
	local number_pattern='^[1-9]{1}[0-9]+$'
	local available_free_disk_space=

	# Start check for BOOTDIR
	local need_to_check=yes

	if [ -z "${CHECK_FREE_DISK_SPACE_BOOTDIR}" -o "${CHECK_FREE_DISK_SPACE_BOOTDIR}" = '0' ]
	then
		need_to_check=no
	fi

	if isTrue "${need_to_check}" && ! isTrue "${CMD_INSTALL}"
	then
		need_to_check=no
	fi

	if isTrue "${need_to_check}"
	then
		if [[ ! "${CHECK_FREE_DISK_SPACE_BOOTDIR}" =~ ${number_pattern} ]]
		then
			gen_die "--check-free-disk-space-bootdir value '${CHECK_FREE_DISK_SPACE_BOOTDIR}' is not a valid number!"
		fi

		available_free_disk_space=$(unset POSIXLY_CORRECT && df -BM "${BOOTDIR}" | awk '$3 ~ /[0-9]+/ { print $4 }')
		if [ -n "${available_free_disk_space}" ]
		then
			print_info 2 '' 1 0
			print_info 2 "Checking for at least ${CHECK_FREE_DISK_SPACE_BOOTDIR} MB free disk space in '${BOOTDIR}' ..."
			print_info 5 "df reading: ${available_free_disk_space}"

			available_free_disk_space=${available_free_disk_space%M}
			if [ ${available_free_disk_space} -lt ${CHECK_FREE_DISK_SPACE_BOOTDIR} ]
			then
				gen_die "${CHECK_FREE_DISK_SPACE_BOOTDIR} MB free disk space is required in '${BOOTDIR}' but only ${available_free_disk_space} MB is available!"
			fi
		else
			print_warning 1 "Invalid df value; Skipping free disk space check for '${BOOTDIR}' ..."
		fi
	fi

	# Start check for kernel outputdir
	need_to_check=yes

	if [ -z "${CHECK_FREE_DISK_SPACE_KERNELOUTPUTDIR}" -o "${CHECK_FREE_DISK_SPACE_KERNELOUTPUTDIR}" = '0' ]
	then
		need_to_check=no
	fi

	if isTrue "${need_to_check}" && ! isTrue "${BUILD_KERNEL}"
	then
		need_to_check=no
	fi

	if isTrue "${need_to_check}"
	then
		if [[ ! "${CHECK_FREE_DISK_SPACE_KERNELOUTPUTDIR}" =~ ${number_pattern} ]]
		then
			gen_die "--check-free-disk-space-kerneloutputdir value '${CHECK_FREE_DISK_SPACE_KERNELOUTPUTDIR}' is not a valid number!"
		fi

		available_free_disk_space=$(unset POSIXLY_CORRECT && df -BM "${KERNEL_OUTPUTDIR}" | awk '$3 ~ /[0-9]+/ { print $4 }')
		if [ -n "${available_free_disk_space}" ]
		then
			print_info 2 '' 1 0
			print_info 2 "Checking for at least ${CHECK_FREE_DISK_SPACE_KERNELOUTPUTDIR} MB free disk space in '${KERNEL_OUTPUTDIR}' ..."
			print_info 5 "df reading: ${available_free_disk_space}"

			available_free_disk_space=${available_free_disk_space%M}
			if [ ${available_free_disk_space} -lt ${CHECK_FREE_DISK_SPACE_KERNELOUTPUTDIR} ]
			then
				gen_die "${CHECK_FREE_DISK_SPACE_KERNELOUTPUTDIR} MB free disk space is required in '${KERNEL_OUTPUTDIR}' but only ${available_free_disk_space} MB is available!"
			fi
		else
			print_warning 1 "Invalid df value; Skipping free disk space check for '${KERNEL_OUTPUTDIR}' ..."
		fi
	fi
}

check_distfiles() {
	local source_files=( $(compgen -A variable | grep '^GKPKG_.*_SRCTAR$') )

	local -a missing_sources
	local source_file=
	for source_file in "${source_files[@]}"
	do
		if [ ! -f "${!source_file}" ]
		then
			missing_sources+=( "${!source_file}" )
		fi
	done

	if [[ ${#missing_sources[@]} -gt 0 ]]
	then
		for source_file in "${missing_sources[@]}"
		do
			print_error 1 "Could not find source file '${source_file}'!"
		done

		gen_die "Please add missing source file(s) or re-install genkernel!"
	fi
}

# @FUNCTION: expand_file
# @USAGE: <file>
# @DESCRIPTION:
# Expands given file.
#
# Will return empty string on error.
expand_file() {
	if [[ "${#}" -lt 1 ]]
	then
		# Nothing to do for us
		echo ''
		return
	fi

	[[ ${#} -gt 1 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes at most five arguments (${#} given)!"

	local file="${1}"
	local expanded_file=

	expanded_file=$(python -c "import os; print(os.path.expanduser('${file}'))" 2>/dev/null)
	if [ -z "${expanded_file}" ]
	then
		# if Python failed for some reason, just reset
		expanded_file=${file}
	fi

	# Try to emulate tilde expansion
	if [[ "${expanded_file}" == ~+* ]]
	then
		expanded_file="${PWD}/${expanded_file:2}"
	elif [[ "${expanded_file}" == ~-* ]]
	then
		expanded_file="${OLDPWD}/${expanded_file:2}"
	elif [[ "${expanded_file}" == ~* ]]
	then
		# We don't support this tilde expansion
		echo ''
		return
	fi

	expanded_file=$(realpath -q -m "${expanded_file}" 2>/dev/null)

	echo "${expanded_file}"
}

find_kernel_binary() {
	local kernel_binary=${*}
	local kernel_binary_found=

	pushd "${KERNEL_OUTPUTDIR}" &>/dev/null || gen_die "Failed to chdir to '${KERNEL_OUTPUTDIR}'!"

	local i
	for i in ${kernel_binary}
	do
		if [ -e "${i}" ]
		then
			kernel_binary_found=${i}
			break
		fi
	done

	popd &>/dev/null || gen_die "Failed to chdir!"

	echo "${kernel_binary_found}"
}

kconfig_get_opt() {
	[[ ${#} -ne 2 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes exactly two arguments (${#} given)!"

	local kconfig="${1}"
	local optname="${2}"
	sed -n "${kconfig}" \
		-e "/^#\? \?${optname}[ =].*/{ s/.*${optname}[ =]//g; s/is not set\| +//g; p; q }"
}

kconfig_set_opt() {
	[[ ${#} -lt 3 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes at least three arguments (${#} given)!"
	[[ ${#} -gt 4 ]] \
		&& gen_die "$(get_useful_function_stack "${FUNCNAME}")Invalid usage of ${FUNCNAME}(): Function takes at most four arguments (${#} given)!"

	local kconfig="${1}"
	local optname="${2}"
	local optval="${3}"
	local indentlevel=${4:-2}

	local curropt=$(grep -E "^#? ?${optname}[ =].*$" "${kconfig}")
	if [[ -z "${curropt}" ]]
	then
		print_info 3 "$(get_indent ${indentlevel}) - Adding option '${optname}' with value '${optval}' to '${kconfig}'..."
		echo "${optname}=${optval}" >> "${kconfig}" \
			|| gen_die "Failed to add '${optname}=${optval}' to '${kconfig}'"

		[ ! -f "${TEMP}/.kconfig_modified" ] && touch "${TEMP}/.kconfig_modified"
	elif [[ "${curropt}" != "*#*" && "${curropt#*=}" == "${optval}" ]]
	then
		print_info 3 "$(get_indent ${indentlevel}) - Option '${optname}=${optval}' already set in '${kconfig}'; Skipping ..."
	else
		print_info 3 "$(get_indent ${indentlevel}) - Setting option '${optname}' to '${optval}' in '${kconfig}'..."
		sed -i "${kconfig}" \
			-e "s|^#\? \?${optname}[ =].*|${optname}=${optval}|g" \
			|| gen_die "Failed to set '${optname}=${optval}' in '${kconfig}'"

		[ ! -f "${KCONFIG_MODIFIED_MARKER}" ] && touch "${KCONFIG_MODIFIED_MARKER}"
	fi
}

make_bootdir_writable() {
	[ -z "${BOOTDIR}" ] && gen_die "--bootdir is not set!"

	local bootdir_status=unknown

	# Based on mount-boot.eclass code
	local fstabstate=$(awk "!/^#|^[[:blank:]]+#|^${BOOTDIR//\//\\/}/ {print \$2}" /etc/fstab 2>/dev/null | grep -E "^${BOOTDIR}$" )
	local procstate=$(awk "\$2 ~ /^${BOOTDIR//\//\\/}\$/ {print \$2}" /proc/mounts 2>/dev/null)
	local proc_ro=$(awk '{ print $2 " ," $4 "," }' /proc/mounts 2>/dev/null | sed -n "/^${BOOTDIR//\//\\/} .*,ro,/p")

	if [ -n "${fstabstate}" ] && [ -n "${procstate}" ]
	then
		if [ -n "${proc_ro}" ]
		then
			bootdir_status=1
		else
			bootdir_status=0
		fi
	elif [ -n "${fstabstate}" ] && [ -z "${procstate}" ]
	then
		bootdir_status=2
	else
		bootdir_status=3
	fi

	case "${bootdir_status}" in
		0)
			# Nothing to do -- just pimp the logfile output
			print_info 5 '' 1 0
			print_info 5 "mount: >> Boot partition is already mounted in read-write mode on '${BOOTDIR}'."
			;;
		1)	# Remount it rw.
			if ! isTrue "${MOUNTBOOT}"
			then
				gen_die "Boot partition is mounted read-only on '${BOOTDIR}' and I am not allowed to remount due to set --no-mountboot option!"
			fi

			mount -o remount,rw "${BOOTDIR}" &>/dev/null
			if [ $? -eq 0 ]
			then
				print_info 1 "mount: >> Boot partition was temporarily remounted in read-write mode on '${BOOTDIR}' ..."

				touch "${TEMP}"/.bootdir.remount
			else
				gen_die "Failed to remount boot partition in read-write mode on '${BOOTDIR}'!"
			fi
			;;
		2)	# Mount it rw.
			if ! isTrue "${MOUNTBOOT}"
			then
				gen_die "Boot partition is not mounted on '${BOOTDIR}' and I am not allowed to mount due to set --no-mountboot option!"
			fi

			mount "${BOOTDIR}" -o rw &>/dev/null
			if [ $? -eq 0 ]
			then
				print_info 1 '' 1 0
				print_info 1 "mount: >> Boot partition was temporarily mounted on '${BOOTDIR}' ..."

				touch "${TEMP}"/.bootdir.mount
			else
				gen_die "Failed to mount set bootdir '${BOOTDIR}'!"
			fi
			;;
		3)
			# Nothing really to do
			print_info 5 '' 1 0
			print_info 5 "mount: >> '${BOOTDIR}' is not a mountpoint; Assuming no separate boot partition ..."

			touch "${TEMP}"/.bootdir.no_boot_partition
			;;
		*)
			gen_die "Internal error: BOOTDIR status ${bootdir_status} is unknown!"
			;;
	esac

	if [ ! -w "${BOOTDIR}" ]
	then
		gen_die "Cannot write to bootdir '${BOOTDIR}'!"
	fi
}

# @FUNCTION: get_nproc
# @USAGE: [${fallback:-1}]
# @DESCRIPTION:
# Attempt to figure out the number of processing units available.
# If the value can not be determined, prints the provided fallback
# instead. If no fallback is provided, defaults to 1.
get_nproc() {
	local nproc

	# GNU
	if type -P nproc &>/dev/null; then
		nproc=$(nproc)
	fi

	# fallback to python2.6+
	# note: this may fail (raise NotImplementedError)
	if [[ -z ${nproc} ]] && type -P python &>/dev/null; then
		nproc=$(python -c 'import multiprocessing; print(multiprocessing.cpu_count());' 2>/dev/null)
	fi

	if [[ -n ${nproc} ]]; then
		echo "${nproc}"
	else
		echo "${1:-1}"
	fi
}

# @FUNCTION: makeopts_jobs
# @USAGE: [${MAKEOPTS}] [${inf:-999}]
# @DESCRIPTION:
# Searches the arguments (defaults to ${MAKEOPTS}) and extracts the jobs number
# specified therein.  Useful for running non-make tools in parallel too.
# i.e. if the user has MAKEOPTS=-j9, this will echo "9" -- we can't return the
# number as bash normalizes it to [0, 255].  If the flags haven't specified a
# -j flag, then "1" is shown as that is the default `make` uses.  Since there's
# no way to represent infinity, we return ${inf} (defaults to 999) if the user
# has -j without a number.
makeopts_jobs() {
	[[ $# -eq 0 ]] && set -- "${MAKEOPTS}"
	# This assumes the first .* will be more greedy than the second .*
	# since POSIX doesn't specify a non-greedy match (i.e. ".*?").
	local jobs=$(echo " $* " | sed -r -n \
		-e 's:.*[[:space:]](-[a-z]*j|--jobs[=[:space:]])[[:space:]]*([0-9]+).*:\2:p' \
		-e "s:.*[[:space:]](-[a-z]*j|--jobs)[[:space:]].*:${2:-999}:p")
	echo ${jobs:-1}
}

unset GK_DEFAULT_IFS
declare -r GK_DEFAULT_IFS="${IFS}"
