#!/bin/bash

__init() {
	if ! include "json" "foundry/msg/artifact"; then
		return 1
	fi

	return 0
}

foundry_msg_sign_new() {
	local tid="$1"
	local key="$2"
	local artifact_data=("${@:3}")

	local msg
	local artifacts
	local artifact_array
	local i

	if (( ${#artifact_data} & 1 != 0 )); then
		return 1
	fi

	artifacts=()

	for (( i = 0; i + 1 < ${#artifact_data[@]}; i += 2 )); do
	        local artifact
		local uri
		local checksum

		uri="${artifact_data[$i]}"
		checksum="${artifact_data[$((i + 1))]}"

		if ! artifact=$(foundry_msg_artifact_new "$uri" \
							 "$checksum"); then
			return 1
		fi

		artifacts+=("$artifact")
	done

	if ! artifact_array=$(json_array "${artifacts[@]}"); then
		return 1
	fi

        if ! msg=$(json_object "tid"       "$tid"           \
			       "key"       "$key"           \
			       "artifacts" "$artifact_array"); then
		return 1
	fi

	echo "$msg"
	return 0
}

foundry_msg_sign_get_tid() {
	local msg="$1"

	local tid

	if ! tid=$(json_object_get "$msg" "tid"); then
		return 1
	fi

	echo "$tid"
	return 0
}

foundry_msg_sign_get_key() {
	local msg="$1"

	local key

	if ! key=$(json_object_get "$msg" "key"); then
		return 1
	fi

	echo "$key"
	return 0
}

foundry_msg_sign_get_artifacts() {
	local msg="$1"

	local query
	local raw_artifacts
	local artifacts
	local checksum
	local uri

	query='artifacts[] | "\(.checksum) \(.uri)"'
	artifacts=()

	if ! raw_artifacts=$(json_object_get "$msg" "$query"); then
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
