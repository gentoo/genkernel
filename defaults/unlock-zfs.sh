#!/bin/sh

print_usage() {
	echo "Usage: $0 [-a] [-u]" >&2
}

case "${1}" in
	-a)
		ZFS_LOADKEY_FOR_ALL=1
		;;
	-u)
		ZFS_LOADKEY_UNIFIED=1
		;;
	-h)
		print_usage
		exit 1
		;;
esac

case "${2}" in
	-a)
		ZFS_LOADKEY_FOR_ALL=1
		;;
	-u)
		ZFS_LOADKEY_UNIFIED=1
		;;
esac

. /etc/initrd.defaults
. /etc/initrd.scripts

GK_INIT_LOG_PREFIX=${0}
if [ -n "${SSH_CLIENT_IP}" ] && [ -n "${SSH_CLIENT_PORT}" ]
then
	GK_INIT_LOG_PREFIX="${0}[${SSH_CLIENT_IP}:${SSH_CLIENT_PORT}]"
fi

if [ -f "${ZFS_ENC_ENV_FILE}" ]
then
	. "${ZFS_ENC_ENV_FILE}"
else
	bad_msg "${ZFS_ENC_ENV_FILE} does not exist! Did you boot without 'dozfs' kernel command-line parameter?"
	exit 1
fi

main() {
	if ! hash zfs >/dev/null 2>&1
	then
		bad_msg "zfs program is missing. Was initramfs built without --zfs parameter?"
		exit 1
	elif ! hash zpool >/dev/null 2>&1
	then
		bad_msg "zpool program is missing. Was initramfs built without --zfs parameter?"
		exit 1
	elif [ -z "${ROOTFSTYPE}" ]
	then
		bad_msg "Something went wrong. ROOTFSTYPE is not set!"
		exit 1
	elif [ "${ROOTFSTYPE}" != "zfs" ]
	then
		bad_msg "ROOTFSTYPE of 'zfs' required but '${ROOTFSTYPE}' detected!"
		exit 1
	elif [ -z "${REAL_ROOT}" ]
	then
		bad_msg "Something went wrong. REAL_ROOT is not set!"
		exit 1
	fi

	if [ "$(zpool list -H -o feature@encryption "${REAL_ROOT%%/*}" 2>/dev/null)" != 'active' ]
	then
		bad_msg "Root device ${REAL_ROOT} is not encrypted!"
		exit 1
	fi

	local ZFS_ENCRYPTIONROOT="$(get_zfs_property "${REAL_ROOT}" encryptionroot)"
	if [ "${ZFS_ENCRYPTIONROOT}" = '-' ]
	then
		bad_msg "Failed to determine encryptionroot for ${REAL_ROOT}!"
		exit 1
	fi

	local ZFS_KEYSTATUS=
	while true
	do
		if [ -e "${ZFS_ENC_OPENED_LOCKFILE}" ]
		then
			good_msg "${REAL_ROOT} device meanwhile was opened by someone else."
			break
		fi

		if [ "${ZFS_LOADKEY_FOR_ALL}" = '1' ]
		then
			if [ "${ZFS_LOADKEY_UNIFIED}" = '1' ]
			then
				read -s -p "Enter unified passphrase for ZFS dataset ${ZFS_ENCRYPTIONROOT}: " ZFS_PASSWORD

				if [ -n "${ZFS_PASSWORD}" ]
				then
					yes "${ZFS_PASSWORD}" | run zfs load-key -a
				fi
				ZFS_PASSWORD="00000000000000000000000000000000"
				unset ZFS_PASSWORD
			else
				zfs load-key -a
			fi
		else
			zfs load-key "${ZFS_ENCRYPTIONROOT}"
		fi

		ZFS_KEYSTATUS="$(get_zfs_property "${REAL_ROOT}" keystatus)"
		if [ "${ZFS_KEYSTATUS}" = 'available' ]
		then
			run touch "${ZFS_ENC_OPENED_LOCKFILE}"
			good_msg "ZFS device ${REAL_ROOT} opened"
			break
		else
			bad_msg "Failed to open ZFS device ${REAL_ROOT}"

			# We need to stop here with a non-zero exit code to prevent
			# a loop when invalid keyfile was sent.
			exit 1
		fi
	done

	if [ "${ZFS_KEYSTATUS}" = 'available' ]
	then
		# Kill any running load-key prompt.
		run pkill -f "load-key" >/dev/null 2>&1
		run pkill -xf "head -n 1" >/dev/null 2>&1
	fi
}

main

exit 0
