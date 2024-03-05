#!/bin/bash
# $Id$

mod_dep_list() {
	if [ ! -f "${TEMP}/moddeps" ]
	then
		gen_dep_list > "${TEMP}/moddeps"
	fi

	cat "${TEMP}/moddeps"
}

xbasename() {
	local -a moddeplist=( $( </dev/stdin ) )

	if (( ${#moddeplist[@]} > 0 ))
	then
		# prepend slash to each moddeplist element
		# to avoid passing elements as basename options
		basename -s "${KEXT}" "${moddeplist[@]/#/\/}"
	fi
}

gen_dep_list() {
	local moddir="${KERNEL_MODULES_PREFIX%/}/lib/modules/${KV}"

	if isTrue "${ALLRAMDISKMODULES}"
	then
		cat "${moddir}/modules.builtin"
		cat "${moddir}/modules.dep" | cut -d':' -f1
	else
		local -a modlist=() moddeplist=()

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
			rxargs=( "${rxargs[@]/%/${KEXT}:}" )

			cat "${moddir}/modules.dep" \
				| grep -F "${rxargs[@]}"
		)

		# Always include firmware for built-in modules
		cat "${moddir}/modules.builtin"

		printf '%s\n' "${moddeplist[@]}"
	fi | xbasename | sort | uniq
}
