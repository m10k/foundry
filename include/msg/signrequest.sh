#!/bin/bash

__init() {
	if ! include "json" "foundry/msg/artifact"; then
		return 1
	fi

	declare -gxr __foundry_msg_signrequest_msgtype="signrequest"

	return 0
}

foundry_msg_signrequest_new() {
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

	if ! msg=$(foundry_msg_new "$__foundry_msg_signrequest_msgtype" "$json"); then
		return 1
	fi

	echo "$msg"
	return 0
}

foundry_msg_signrequest_get_context() {
	local signrequest="$1"

	local context

	if ! context=$(foundry_msg_get_data_field "$signrequest" "context"); then
		return 1
	fi

	echo "$context"
	return 0
}

foundry_msg_signrequest_get_artifacts() {
	local signrequest="$1"

	local query
	local raw_artifacts
	local artifacts
	local checksum
	local uri

	query='artifacts[] | "\(.checksum) \(.uri)"'
	artifacts=()

	if ! raw_artifacts=$(foundry_msg_get_data_field "$signrequest" "$query"); then
		return 1
	fi

	while read -r checksum uri; do
		local artifact

		if ! artifact=$(foundry_msg_artifact_new "$uri" "$checksum"); then
			return 1
		fi

		artifacts+=("$artifact")
	done <<< "$raw_artifacts"

	array_to_lines "${artifacts[@]}"
	return 0
}
