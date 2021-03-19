#!/bin/bash
# $Id$

determine_kernel_arch() {
	[ -z "${VER}" ] && gen_die "Cannot determine KERNEL_ARCH without \$VER!"
	[ -z "${SUB}" ] && gen_die "Cannot determine KERNEL_ARCH without \$SUB!"
	[ -z "${PAT}" ] && gen_die "Cannot determine KERNEL_ARCH without \$PAT!"

	KERNEL_ARCH=${ARCH}
	case ${ARCH} in
		parisc|parisc64)
			KERNEL_ARCH=parisc
			;;
		ppc|ppc64*)
			if [ "${VER}" -ge "3" ]
			then
				KERNEL_ARCH=powerpc
			elif [ "${VER}" -eq "2" -a "${PAT}" -ge "6" ]
			then
				if [ "${PAT}" -eq "6" -a "${SUB}" -ge "16" ] || [ "${PAT}" -gt "6" ]
				then
					KERNEL_ARCH=powerpc
				fi
			fi
			;;
		riscv|riscv64*)
			KERNEL_ARCH=riscv
			;;
		x86)
			if [ "${VER}" -ge "3" ]
			then
				KERNEL_ARCH=x86
			elif [ "${VER}" -eq "2" -a "${PAT}" -ge "6" ] || [ "${VER}" -gt "2" ]
			then
				if [ "${PAT}" -eq "6" -a "${SUB}" -ge "24" ] || [ "${PAT}" -gt "6" ]
				then
					KERNEL_ARCH=x86
				else
					KERNEL_ARCH=i386
				fi
			fi
			;;
		x86_64)
			if [ "${VER}" -ge "3" ]
			then
				KERNEL_ARCH=x86
			elif [ "${VER}" -eq "2" -a "${PAT}" -ge "6" ] || [ "${VER}" -gt "2" ]
			then
				if [ "${PAT}" -eq "6" -a "${SUB}" -ge "24" ] || [ "${PAT}" -gt "6" ]
				then
					KERNEL_ARCH=x86
				fi
			fi
			;;
	esac
	print_info 2 "KERNEL_ARCH set to '${KERNEL_ARCH}' ..."
}
