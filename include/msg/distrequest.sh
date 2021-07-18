#!/bin/bash

__init() {
	if ! include "json"; then
		return 1
	fi

	declare -gxr __foundry_msg_distrequest_msgtype="distrequest"

	return 0
}

foundry_msg_distrequest_new() {
	local context="$1"
	local artifacts=("${@:2}")

	local artifacts_json
	local json
	local msg

	if ! artifacts_json=$(json_array "${artifacts[@]}"); then
		return 1
	fi

	if ! json=$(json_object "context"   "$context"       \
				"artifacts" "$artifacts_json"); then
		return 1
	fi

	if ! msg=$(foundry_msg_new "$__foundry_msg_distrequest_msgtype" "$json"); then
		return 1
	fi

	echo "$msg"
	return 0
}

foundry_msg_distrequest_get_context() {
	local distrequest="$1"

	local context

	if ! context=$(foundry_msg_get_data_field "$distrequest" "context"); then
		return 1
	fi

	echo "$context"
	return 0
}

foundry_msg_distrequest_get_artifacts() {
	local distrequest="$1"

	local raw_artifacts
	local artifacts
	local artifact
	local checksum
	local uri
	local query

	query='artifacts[] | "\(.checksum) \(.uri)"'

	if ! raw_artifacts=$(foundry_msg_get_data_field "$distrequest" \
							"$query"); then
		return 1
	fi

	while read -r checksum uri; do
		if ! artifact=$(foundry_msg_artifact_new "$uri" "$checksum"); then
			return 1
		fi

		artifacts+=("$artifact")
	done <<< "$raw_artifacts"

	for artifact in "${artifacts[@]}"; do
		echo "$artifact"
	done

	return 0
}
