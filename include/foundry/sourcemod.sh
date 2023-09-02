__init() {
	if ! include "foundry/vargs"; then
		return 1
	fi

	return 0
}

foundry_sourcemod_new() {
	local args=("$@")

	local -a allowed_args
	local -a required_args
	local -A parsed_args

	allowed_args=(
		"old"
		"new"
	)
	required_args=(
		"new"
	)

	if ! foundry_vargs_parse args allowed_args required_args parsed_args; then
		return 1
	fi

	json_object "new" "${parsed_args[new]}" "old" "${parsed_args[old]}"
	return "$?"
}

foundry_sourcemod_get_old() {
	local sourcemod="$1"

	if ! jq -r -e '.old' <<< "$sourcemod"; then
		return 1
	fi

	return 0
}

foundry_sourcemod_get_new() {
	local sourcemod="$1"

	if ! jq -r -e '.new' <<< "$sourcemod"; then
		return 1
	fi

	return 0
}
