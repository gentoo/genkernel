#!/bin/sh
# vim: set noexpandtab:

. /etc/login-remote.conf
. /etc/initrd.defaults
. /etc/initrd.scripts
KEYFILE_ROOT="/tmp/root.key"
KEYFILE_SWAP="/tmp/swap.key"

splash() {
	return 0
}

[ -e /etc/initrd.splash ] && . /etc/initrd.splash

receivefile() {
	case ${1} in
		root)
			file=${KEYFILE_ROOT}
			;;
		swap)
			file=${KEYFILE_SWAP}
			;;
	esac
	# limit maximum stored bytes to 1M to avoid killing the server
	dd of=${file} count=1k bs=1k 2>/dev/null
	exit $?
}

openLUKSremote() {
	case $1 in
		root)
			local TYPE=ROOT
			;;
		swap)
			local TYPE=SWAP
			;;
	esac
	
	[ ! -d /tmp/key ] && mkdir -p /tmp/key
	
	eval local LUKS_DEVICE='"${CRYPT_'${TYPE}'}"' LUKS_NAME="$1" LUKS_KEY='"${KEYFILE_'${TYPE}'}"'
	local DEV_ERROR=0 KEY_ERROR=0
	local input="" cryptsetup_options="" flag_opened="/${TYPE}.decrypted"
	while [ 1 ]
	do
		local gpg_cmd="" crypt_filter_ret=42

		if [ -e ${flag_opened} ]
		then
			good_msg "The LUKS device ${LUKS_DEVICE} meanwhile was opened by someone else."
			break
		elif [ ${DEV_ERROR} -eq 1 ]
		then
			prompt_user "LUKS_DEVICE" "${LUKS_NAME}"
			DEV_ERROR=0
		else
			LUKS_DEVICE=$(find_real_device "${LUKS_DEVICE}")

			setup_md_device ${LUKS_DEVICE}
			cryptsetup isLuks ${LUKS_DEVICE}
			if [ $? -ne 0 ]
			then
				bad_msg "The LUKS device ${LUKS_DEVICE} does not contain a LUKS header" ${CRYPT_SILENT}
				DEV_ERROR=1
				continue
			else
				# Handle keys
				if [ "x${LUKS_TRIM}" = "xyes" ]
				then
					good_msg "Enabling TRIM support for ${LUKS_NAME}." ${CRYPT_SILENT}
					cryptsetup_options="${cryptsetup_options} --allow-discards"
				fi

				if [ ${crypt_filter_ret} -ne 0 ]
				then
					# 1st try: unencrypted keyfile
					crypt_filter "cryptsetup ${cryptsetup_options} --key-file ${LUKS_KEY} luksOpen ${LUKS_DEVICE} ${LUKS_NAME}"
					crypt_filter_ret=$?
				fi

				if [ -f /sbin/gpg ] && [ ${crypt_filter_ret} -ne 0 ]
				then
					# 2nd try: gpg-encrypted keyfile
					[ -e /dev/tty ] && mv /dev/tty /dev/tty.org
					mknod /dev/tty c 5 1
					gpg_cmd="/sbin/gpg --logger-file /dev/null --quiet --decrypt ${LUKS_KEY} |"
					crypt_filter "${gpg_cmd}cryptsetup ${cryptsetup_options} --key-file ${LUKS_KEY} luksOpen ${LUKS_DEVICE} ${LUKS_NAME}"
					crypt_filter_ret=$?

					[ -e /dev/tty.org ] \
						&& rm -f /dev/tty \
						&& mv /dev/tty.org /dev/tty
				fi

				if [ ${crypt_filter_ret} -ne 0 ]
				then
					# 3rd try: user-submitted passphrase
					crypt_filter "cryptsetup ${cryptsetup_options} luksOpen ${LUKS_DEVICE} ${LUKS_NAME}"
					crypt_filter_ret=$?
				fi

				if [ ${crypt_filter_ret} -eq 0 ]
				then
					touch ${flag_opened}
					good_msg "LUKS device ${LUKS_DEVICE} opened" ${CRYPT_SILENT}
					# Kill the cryptsetup process started by init
					# so that the boot process can continue
					killall cryptsetup
					break
				else
					bad_msg "Failed to open LUKS device ${LUKS_DEVICE}" ${CRYPT_SILENT}
					DEV_ERROR=1
				fi
			fi
		fi
	done
	rm -f ${LUKS_KEY}
	cd /
	rmdir -p tmp/key
}

if [ "x${1}" = "x-c" ]
then
	command=$(echo ${2} | awk -F" " '{print $1}')
	type=$(echo ${2} | awk -F" " '{print $2}')

	case ${command} in 
		post)
			receivefile ${type}
			;;
	esac
else
	[ -n "${CRYPT_ROOT}" ] && openLUKSremote root
	[ -n "${CRYPT_SWAP}" ] && openLUKSremote swap
fi
