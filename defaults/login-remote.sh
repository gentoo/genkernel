#!/bin/sh
# vim: set noexpandtab:

. /etc/initrd.defaults
. /etc/initrd.scripts
. "${CRYPT_ENV_FILE}"

[ -e /etc/initrd.splash ] && . /etc/initrd.splash

GK_INIT_LOG_PREFIX=${0}
if [ -n "${SSH_CLIENT}" ]
then
	SSH_CLIENT_IP=$(echo "${SSH_CLIENT}" | awk '{ print $1 }')
	SSH_CLIENT_PORT=$(echo "${SSH_CLIENT}" | awk '{ print $2 }')

	if [ -n "${SSH_CLIENT_IP}" ] && [ -n "${SSH_CLIENT_PORT}" ]
	then
		GK_INIT_LOG_PREFIX="${0}[${SSH_CLIENT_IP}:${SSH_CLIENT_PORT}]"
		export SSH_CLIENT_IP
		export SSH_CLIENT_PORT
	fi
fi

receivefile() {
	case ${1} in
		root)
			file=${CRYPT_ROOT_KEYFILE}
			;;
		swap)
			file=${CRYPT_SWAP_KEYFILE}
			;;
		'')
			bad_msg "No keyfile specified." ${CRYPT_SILENT}
			exit 1
			;;
		*)
			bad_msg "Unknown '${1}' keyfile received." ${CRYPT_SILENT}
			exit 1
			;;
	esac

	# limit maximum stored bytes to 1M to avoid killing the server
	run dd of="${file}" count=1k bs=1k 2>/dev/null
	return $?
}

if [ "x${1}" = "x-c" ]
then
	command=$(echo "${2}" | awk '{ print $1 }')
	type=$(echo "${2}" | awk '{ print $2 }')

	case ${command} in 
		post)
			if receivefile "${type}"
			then
				if unlock-luks "${type}"
				then
					if [ "${type}" = 'root' ]
					then
						# this is required to keep scripted unlock working
						# without requring an additional command.
						resume-boot
					fi

					exit 0
				else
					exit 1
				fi
			else
				bad_msg "Keyfile was not properly received!" ${CRYPT_SILENT}
				exit 1
			fi
			;;
		*)
			bad_msg "Command '${command}' is not supported!" ${CRYPT_SILENT}
			exit 1
	esac
else
	run touch "${GK_SSHD_LOCKFILE}"

	# Don't log further remote shell output
	GK_INIT_LOG=

	export PS1='remote rescueshell \w \# '

	GOOD=${BLUE} good_msg "${NORMAL}Welcome to ${BOLD}${GK_META_VERSION}${NORMAL} (${GK_META_BUILD_DATE}) ${BOLD}remote rescue shell${NORMAL}!"
	GOOD=${BLUE} good_msg "${NORMAL}...running Linux kernel ${BOLD}${KV}${NORMAL}"
	echo
	good_msg "${NORMAL}The lockfile '${BOLD}${GK_SSHD_LOCKFILE}${NORMAL}' was created."
	good_msg "${NORMAL}In order to resume boot process, run '${BOLD}resume-boot${NORMAL}'."
	good_msg "${NORMAL}Be aware that it will kill your connection which means"
	good_msg "${NORMAL}you will no longer be able to work in this shell."

	if [ -n "${CRYPT_ROOT}" ] && [ ! -f "${CRYPT_ROOT_OPENED_LOCKFILE}" ]
	then
		good_msg "${NORMAL}To remote unlock LUKS-encrypted root device, run '${BOLD}unlock-luks root${NORMAL}'."
	fi

	if [ -n "${CRYPT_SWAP}" ] && [ ! -f "${CRYPT_ROOT_OPENED_LOCKFILE}" ]
	then
		good_msg "${NORMAL}To remote unlock LUKS-encrypted swap device, run '${BOLD}unlock-luks swap${NORMAL}'."
	fi

	if [ -e "${ZFS_ENC_ENV_FILE}" ] && [ ! -f "${ZFS_ENC_OPENED_LOCKFILE}" ]
	then
		good_msg "${NORMAL}To remote unlock ZFS root device, run '${BOLD}unlock-zfs${NORMAL}'."
	fi

	echo

	[ -x /bin/sh ] && SH=/bin/sh || SH=/bin/ash

	exec \
		env \
		SSH_CLIENT_IP="${SSH_CLIENT_IP}" \
		SSH_CLIENT_PORT="${SSH_CLIENT_PORT}" \
		${SH} --login
fi

exit 0
