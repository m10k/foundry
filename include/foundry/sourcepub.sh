__init() {
	return 0
}

foundry_sourcepub_foreach_sourceref() {
	local sourcepub="$1"
	local userfunc="$2"
	local userdata=("${@:3}")

	local -i num_sourcerefs
	local -i idx

	if ! num_sourcerefs=$(jq -r -e '.sources | length' <<< "$sourcepub"); then
		return 1
	fi

	for (( idx = 0; idx < num_sourcerefs; idx++ )); do
		local sourceref
		local -i ret_val

		if ! sourceref=$(jq -r -e ".sources[$idx]" <<< "$sourcepub"); then
			return 2
		fi

		"$userfunc" "$sourceref" "${userdata[@]}"
		ret_val="$?"

		if (( ret_val != 0 )); then
			return "$ret_val"
		fi
	done

	return 0
}
