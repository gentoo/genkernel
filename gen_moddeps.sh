#!/bin/bash
# $Id$

gen_dep_list() {
	if isTrue "${ALLRAMDISKMODULES}"
	then
		strip_mod_paths $(find "${KERNEL_MODULES_PREFIX%/}/lib/modules/${KV}" -name "*$(modules_kext)") | sort
	else
		rm -f "${TEMP}/moddeps" >/dev/null

		local group_modules
		for group_modules in ${!MODULES_*} GK_INITRAMFS_ADDITIONAL_KMODULES
		do
			gen_deps ${!group_modules}
		done

		# Only list each module once
		if [ -f "${TEMP}/moddeps" ]
		then
			cat "${TEMP}/moddeps" | sort | uniq
		fi
	fi
}

gen_deps() {
	local modlist
	local deps

	local x
	for x in ${*}
	do
		echo ${x} >> "${TEMP}/moddeps"
		modlist=$(modules_dep_list ${x})
		if [ "${modlist}" != "" -a "${modlist}" != " " ]
		then
			deps=$(strip_mod_paths ${modlist})
		else
			deps=""
		fi

		local y
		for y in ${deps}
		do
			echo ${y} >> "${TEMP}/moddeps"
		done
	done
}

modules_dep_list() {
	KEXT=$(modules_kext)
	if [ -f "${KERNEL_MODULES_PREFIX%/}/lib/modules/${KV}/modules.dep" ]
	then
		grep -F -- "/${1}${KEXT}:" "${KERNEL_MODULES_PREFIX%/}/lib/modules/${KV}/modules.dep" | cut -d\:  -f2
	fi
}

modules_kext() {
	local KEXT='.ko'

	if grep -sq '^CONFIG_MODULE_COMPRESS=y' "${KERNEL_OUTPUTDIR}"/.config
	then
		grep -sq '^CONFIG_MODULE_COMPRESS_XZ=y' "${KERNEL_OUTPUTDIR}"/.config && KEXT='.ko.xz'
		grep -sq '^CONFIG_MODULE_COMPRESS_GZIP=y' "${KERNEL_OUTPUTDIR}"/.config && KEXT='.ko.gz'
	fi

	echo ${KEXT}
}

# Pass module deps list
strip_mod_paths() {
	local x
	local ret
	local myret

	for x in ${*}
	do
		ret=$(basename ${x} | cut -d. -f1)
		myret="${myret} ${ret}"
	done

	echo "${myret}"
}
