__init() {
	if ! include "foundry/vargs"; then
		return 1
	fi

	return 0
}

foundry_sourcepub_new() {
	local args=("$@")

	local -a allowed_args
	local -a required_args
	local -A parsed_args
	local -n ___sourcerefs
	local sourcerefs_json

	allowed_args=(
		"sources"
	)
	required_args=(
		"sources"
	)

	if ! foundry_vargs_parse args allowed_args required_args parsed_args; then
		return 1
	fi

	___sourcerefs="${parsed_args[sources]}"
	sourcerefs_json=$(json_array "${___sourcerefs[@]}")

	json_object "sources" "$sourcerefs_json"
	return "$?"
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
