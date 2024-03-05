#!/bin/bash
# $Id$

mod_dep_list() {
	if [ ! -f "${TEMP}/moddeps" ]
	then
		gen_dep_list > "${TEMP}/moddeps"
	fi

	cat "${TEMP}/moddeps"
}

gen_dep_list() {
	local -a modlist=() moddeplist=()
	local moddir="${KERNEL_MODULES_PREFIX%/}/lib/modules/${KV}"

	# Always include firmware for built-in modules
	moddeplist=( $(cat "${moddir}/modules.builtin") )

	if isTrue "${ALLRAMDISKMODULES}"
	then
		moddeplist+=( $(cat "${moddir}/modules.dep" | cut -d':' -f1) )
	else
		local mygroups
		for mygroups in ${!MODULES_*} GK_INITRAMFS_ADDITIONAL_KMODULES
		do
			modlist+=( ${!mygroups} )
		done

		modlist=( $(printf '%s\n' "${modlist[@]}" | sort | uniq) )

		modlist+=( $(
			local -a rxargs=( "${modlist[@]}" )

			rxargs=( "${rxargs[@]/#/-ealias\ }" )
			rxargs=( "${rxargs[@]/%/\ }" )

			cat "${moddir}/modules.alias" \
				| grep -F "${rxargs[@]}" \
				| cut -d' ' -f3-
		) )

		modlist=( $(printf '%s\n' "${modlist[@]}" | sort | uniq) )

		local mydeps mymod
		while IFS=" " read -r -u 3 mymod mydeps
		do
			moddeplist+=( ${mymod%:} ${mydeps} )
		done 3< <(
			local -a rxargs=( "${modlist[@]}" )

			rxargs=( "${rxargs[@]/#/-e\/}" )
			rxargs=(
				"${rxargs[@]/%/.ko:}"
				"${rxargs[@]/%/${KEXT}:}"
			)

			cat "${moddir}/modules.dep" \
				| grep -F "${rxargs[@]}"
		)
	fi

	moddeplist=( ${moddeplist[@]##*/} )
	moddeplist=( ${moddeplist[@]%%.*} )

	printf '%s\n' "${moddeplist[@]}" | sort | uniq
}
