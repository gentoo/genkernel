#!/bin/sh

print_usage() {
	echo "Usage: $0 root|swap" >&2
}

if [ -z "${1}" ]
then
	print_usage
	exit 1
fi

case "${1}" in
	root)
		NAME="${1}"
		TYPE=ROOT
		;;
	swap)
		NAME="${1}"
		TYPE=SWAP
		;;
	*)
		echo "ERROR: Unknown type '${1}' specified!"
		print_usage
		exit 1
		;;
esac

. /etc/initrd.defaults
. /etc/initrd.scripts
. "${CRYPT_ENV_FILE}"

GK_INIT_LOG_PREFIX=${0}
if [ -n "${SSH_CLIENT_IP}" ] && [ -n "${SSH_CLIENT_PORT}" ]
then
	GK_INIT_LOG_PREFIX="${0}[${SSH_CLIENT_IP}:${SSH_CLIENT_PORT}]"
fi

main() {
	if ! hash cryptsetup >/dev/null 2>&1
	then
		bad_msg "cryptsetup program is missing. Was initramfs built without --luks parameter?"
		exit 1
	fi

	local LUKS_NAME="${NAME}"
	eval local LUKS_DEVICE='"${CRYPT_'${TYPE}'}"'
	eval local LUKS_KEY='"${CRYPT_'${TYPE}'_KEYFILE}"'
	eval local cryptsetup_options='"${CRYPT_'${TYPE}'_OPTIONS}"'
	cryptsetup_options="$(trim "${cryptsetup_options}")"
	eval local OPENED_LOCKFILE='"${CRYPT_'${TYPE}'_OPENED_LOCKFILE}"'

	if [ -z "${LUKS_DEVICE}" ]
	then
		bad_msg "'crypt_${NAME}' kernel command-line argument is not set!"
		exit 1
	fi

	while true
	do
		local gpg_cmd crypt_filter_ret

		if [ -e "${OPENED_LOCKFILE}" ]
		then
			good_msg "The LUKS device ${LUKS_DEVICE} was opened by someone else in the meanwhile."
			break
		else
			LUKS_DEVICE=$(find_real_device "${LUKS_DEVICE}")
			if [ -z "${LUKS_DEVICE}" ]
			then
				bad_msg "Failed to find LUKS device. If crypt_${NAME} kernel command-line argument is correct you are probably missing kernel support for your storage!" ${CRYPT_SILENT}
				exit 1
			fi

			if ! run cryptsetup isLuks "${LUKS_DEVICE}"
			then
				bad_msg "The LUKS device ${LUKS_DEVICE} does not contain a LUKS header" ${CRYPT_SILENT}

				# User has SSH access and is able to call script again or
				# able to investigate the problem on its own.
				exit 1
			else
				if [ -n "${cryptsetup_options}" ]
				then
					good_msg "Using the following cryptsetup options for ${LUKS_NAME}: ${cryptsetup_options}" ${CRYPT_SILENT}
				fi

				# Handle keys
				if [ -s "${LUKS_KEY}" ]
				then
					# we received raw, unencrypted key through SSH -- no GPG possible
					cryptsetup_options="${cryptsetup_options} -d ${LUKS_KEY}"
				fi

				# At this point, keyfile or not, we're ready!
				crypt_filter "${gpg_cmd}cryptsetup ${cryptsetup_options} luksOpen ${LUKS_DEVICE} ${LUKS_NAME}"
				crypt_filter_ret=$?

				[ -e /dev/tty.org ] \
					&& run rm -f /dev/tty \
					&& run mv /dev/tty.org /dev/tty

				if [ ${crypt_filter_ret} -eq 0 ]
				then
					run touch "${OPENED_LOCKFILE}"
					good_msg "LUKS device ${LUKS_DEVICE} opened" ${CRYPT_SILENT}
					break
				else
					bad_msg "Failed to open LUKS device ${LUKS_DEVICE}" ${CRYPT_SILENT}

					# We need to stop here with a non-zero exit code to prevent
					# a loop when invalid keyfile was sent.
					exit 1
				fi
			fi
		fi
	done

	udevsettle

	if [ -s "${LUKS_KEY}" ]
	then
		if  ! is_debug
		then
			run rm -f "${LUKS_KEY}"
		else
			warn_msg "LUKS key file '${LUKS_KEY}' not deleted because DEBUG mode is enabled!"
		fi
	fi

	if [ "${crypt_filter_ret}" = '0' ]
	then
		# Kill any running cryptsetup prompt for this device.
		# But SIGINT only to keep shell functional.
		run pkill -2 -f "luksOpen.*${LUKS_NAME}\$" >/dev/null 2>&1
	fi
}

main

exit 0
